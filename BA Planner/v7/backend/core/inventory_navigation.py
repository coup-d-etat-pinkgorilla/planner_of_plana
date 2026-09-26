"""F10 verified inventory filter/sort preparation and row-aware scrolling."""
from dataclasses import dataclass
import math
from PIL import Image
from core.inventory_catalog import CATALOG, ITEM_SCAN_PROFILES
from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import ratio_crop
from core.student_weapon_recognizer import _normalized_correlation as correlation, _color_similarity as color_similarity


# Region assets locate controls, but only these names may be clicked (C2): a new asset
# entry can never make the scanner press an unreviewed button.
ALLOWED_CONTROLS=frozenset({'filtermenu_button','eq_filtermenu_button','filter_tab','sort_tab',
    'sort_rule_check','sort_name_rule_check','eq_sort_rule_check','filter_confirm_button','eq_filter_confirm_button'})


@dataclass(frozen=True)
class PreparedInventory:
    source: str
    profile_id: str
    filter_verified: bool
    sort_verified: bool


@dataclass
class ScrollResult:
    frame: Image.Image
    overlap_rows: int
    slot_indices: tuple[int,...]
    terminal: bool=False
    terminal_after_page: bool=False
    reason: str='verified_row_overlap'


def _center(region):return ((region['x1']+region['x2'])/2,(region['y1']+region['y2'])/2)


def _signature(image):
    with image.resize((24,24)) as small:
        values=[]
        for channel in small.split():
            histogram=channel.histogram()
            values.extend(sum(histogram[index*32:(index+1)*32]) for index in range(8))
        norm=math.sqrt(sum(value*value for value in values))
        return tuple(value/norm for value in values) if norm else ()


def _similarity(a,b):return sum(x*y for x,y in zip(a,b)) if a and b else 0


class InventoryNavigation:
    def __init__(self,capture,catalog,detail_recognizer):
        self.capture,self.catalog,self.detail_recognizer=capture,catalog,detail_recognizer
        self.regions=catalog.region_for_purpose('inventory','inventory-navigation-regions')
        self.templates={a.identity:a.path for a in catalog.assets('inventory','inventory-navigation-template')}
        self.images={};self.trace=[]

    def image(self,name):
        if name not in self.images:
            with Image.open(self.catalog.resolve(self.templates[name])) as image:self.images[name]=image.convert('RGB')
        return self.images[name]

    def score(self,frame,name):
        with ratio_crop(frame,self.regions[name]) as crop:
            template=self.image(name)
            return .7*max(0,correlation(crop,template))+.3*color_similarity(crop,template)

    def menu_ready(self,frame,source):
        if self.score(frame,'filter_title')>=.85:return True
        names=('eq_sort_rule_check',) if source=='equipment' else ('sort_rule_check','sort_name_rule_check')
        return any(self.score(frame,n)>=.68 for n in names)

    def click(self,target,cancel,name,cleanup=False):
        if cancel.is_set():raise ScannerError('cancelled','inventory preparation cancelled')
        if name not in ALLOWED_CONTROLS:raise ScannerError('control_not_allowed',f'inventory control {name} is not allowlisted')
        region=self.regions['controls'].get(name) or self.regions.get(name)
        if not isinstance(region,dict):raise ScannerError('region_missing',f'inventory control {name} is missing')
        x,y=_center(region)
        self.capture.click(ScanContext.of(target).replace(cancel=cancel,cleanup=cleanup),x,y)
        self.trace.append(dict(input=name,cleanup=cleanup))

    def observe(self,target,cancel,predicate,code,attempts=3):
        for attempt in range(attempts):
            if attempt and cancel.wait(.15):raise ScannerError('cancelled','inventory preparation cancelled')
            with self.capture.wait_stable(target,cancel) as frame:
                if predicate(frame):return frame.copy()
        raise ScannerError(code,f'{code} after {attempts} observations')

    def open_menu(self,target,cancel,source):
        button='eq_filtermenu_button' if source=='equipment' else 'filtermenu_button'
        for attempt in range(2):
            self.click(target,cancel,button)
            try:return self.observe(target,cancel,lambda f:self.menu_ready(f,source),'inventory_filter_unconfirmed')
            except ScannerError as exc:
                if exc.code!='inventory_filter_unconfirmed' or attempt==1:raise
        raise ScannerError('inventory_filter_unconfirmed','inventory filter did not open')

    def ensure_sort(self,target,cancel,source,profile):
        name='eq_sort_rule_check' if source=='equipment' else ('sort_name_rule_check' if profile=='student_elephs' else 'sort_rule_check')
        threshold=.70 if source=='equipment' else .68
        for attempt in range(3):
            with self.capture.wait_stable(target,cancel) as frame:
                score=self.score(frame,name)
            self.trace.append(dict(observe=name,score=score,attempt=attempt+1))
            if score>=threshold:return True
            if attempt<2:self.click(target,cancel,name)
        raise ScannerError('inventory_sort_unconfirmed',f'{name} stayed below {threshold:.2f}')

    def prepare(self,target,cancel,baseline):
        self.trace=[];source=self.detail_recognizer.classify(baseline)
        if source not in {'item','equipment'}:raise ScannerError('inventory_page_unknown','inventory page is unverified')
        profile=target.get('inventory_scan_profile') or ('equipment' if source=='equipment' else None)
        if source=='item' and profile not in ITEM_SCAN_PROFILES:
            raise ScannerError('inventory_profile_required','item scan requires one explicit inventory scan profile')
        if source=='equipment' and profile!='equipment':
            raise ScannerError('inventory_profile_mismatch','equipment page requires equipment scan profile')
        with self.open_menu(target,cancel,source):pass
        if source=='item':
            # The current display panel has basic/name/quantity/expiry plus sort direction;
            # v6 category checkboxes are no longer present. Profile filtering is enforced
            # by the matcher catalog, never by clicking blank legacy coordinates.
            # The sort radio lives on the sort tab; ensure_sort observes it before any click.
            self.click(target,cancel,'filter_tab');self.click(target,cancel,'sort_tab')
        self.ensure_sort(target,cancel,source,profile)
        self.click(target,cancel,'eq_filter_confirm_button' if source=='equipment' else 'filter_confirm_button')
        frame=self.observe(target,cancel,lambda f:self.detail_recognizer.classify(f)==source,'inventory_prepare_unconfirmed')
        frame.close()
        return PreparedInventory(source,profile,True,True)

    def signatures(self,frame,source):
        result=[]
        for slot in self.detail_recognizer.regions['sources'][source]['grid_slots']:
            with ratio_crop(frame,slot) as crop:
                # inset removes selection border and count baseline motion.
                w,h=crop.size
                with crop.crop((round(w*.16),round(h*.10),round(w*.84),round(h*.72))) as interior:
                    result.append(_signature(interior))
        return result

    @staticmethod
    def page_similarity(left,right):
        return sum(_similarity(a,b) for a,b in zip(left,right))/len(left)

    @staticmethod
    def overlap(before,after,cols=5):
        rows=min(len(before),len(after))//cols;candidates=[]
        for overlap in range(1,rows):
            left=before[(rows-overlap)*cols:rows*cols];right=after[:overlap*cols]
            candidates.append((sum(_similarity(a,b) for a,b in zip(left,right))/len(left),overlap))
        candidates.sort(reverse=True)
        if not candidates:return None
        best=candidates[0];margin=best[0]-(candidates[1][0] if len(candidates)>1 else 0)
        return best[1],best[0],margin

    def settled_after(self,target,cancel,source):
        previous=None;stable=0
        if cancel.wait(.35):raise ScannerError('cancelled','inventory scroll cancelled')
        capture_failures=0
        for _ in range(8):
            try:frame=self.capture.wait_stable(target,cancel,timeout=4)
            except ScannerError as exc:
                if exc.code in {'capture_timeout','capture_failed'} and capture_failures<2:
                    capture_failures+=1;continue
                raise
            signatures=self.signatures(frame,source)
            if previous is not None and self.page_similarity(previous,signatures)>=.985:stable+=1
            else:stable=0
            if stable>=2:return frame,signatures
            previous=signatures;frame.close()
            if cancel.wait(.08):raise ScannerError('cancelled','inventory scroll cancelled')
        raise ScannerError('inventory_scroll_unsettled','scroll did not stabilize')

    def scroll_once(self,target,cancel,attempt):
        """Drag inside the list's right padding: it scrolls, but a mis-read tap selects nothing."""
        if cancel.is_set():raise ScannerError('cancelled','inventory scroll cancelled')
        track=self.regions['scroll_track'];x,start_y=track['x'],track['start_y'];end_y=track['end_y'][attempt-1]
        drag=getattr(self.capture,'drag_scroll',None)
        if callable(drag):
            drag(ScanContext.of(target).replace(cancel=cancel),(x,start_y),(x,end_y))
            self.trace.append(dict(input='drag_scroll',start=[x,start_y],end=[x,end_y],attempt=attempt))
        else:
            # Two wheel notches keep at least two complete overlap rows in the five-row viewport.
            delta=(-240,-360)[attempt-1]
            self.capture.scroll(ScanContext.of(target).replace(cancel=cancel,scroll_point=(x,start_y)),delta)
            self.trace.append(dict(input='scroll',delta=delta,attempt=attempt,point=[x,start_y]))

    def confirm_terminal(self,target,cancel,before,source):
        """One more scroll after a residual tail page must show no motion (X07)."""
        before_signatures=self.signatures(before,source)
        self.scroll_once(target,cancel,2)
        after,after_signatures=self.settled_after(target,cancel,source)
        after.close()
        same=self.page_similarity(before_signatures,after_signatures)
        self.trace.append(dict(terminal_recheck=same))
        return same>=.97

    def restore_first_page(self,target,cancel,frame):
        """Re-apply the verified display settings; the client then shows the first page (X10)."""
        return self.prepare(target,cancel,frame)

    def advance(self,target,cancel,before,source):
        before_signatures=self.signatures(before,source);slots=len(before_signatures);cols=5;rows=slots//cols
        for attempt in (1,2):
            self.scroll_once(target,cancel,attempt)
            after,after_signatures=self.settled_after(target,cancel,source)
            same=self.page_similarity(before_signatures,after_signatures)
            if same>=.97:
                if attempt==2:return ScrollResult(after,rows,(),terminal=True,reason='verified_no_motion')
                after.close();continue
            overlap=self.overlap(before_signatures,after_signatures,cols)
            if overlap is None:
                after.close();raise ScannerError('inventory_scroll_unverified','row overlap unavailable')
            count,score,margin=overlap
            self.trace.append(dict(overlap_rows=count,score=score,margin=margin))
            margin_threshold = .025 if source == 'equipment' else .03
            if .88<=score<.94 and margin>=margin_threshold:
                return ScrollResult(after,count,tuple(range(slots)),False,True,'verified_tail_residual')
            if score<.94 or margin<margin_threshold:
                after.close();raise ScannerError('inventory_scroll_unverified',f'ambiguous row overlap score={score:.3f} margin={margin:.3f}')
            return ScrollResult(after,count,tuple(range(count*cols,slots)))
        raise ScannerError('inventory_scroll_unverified','scroll recovery exhausted')

    def verify_profile_order(self,profile,item_ids):
        order={row.item_id:row.order_index for row in CATALOG if row.profile_id==profile}
        if not item_ids or any(item not in order for item in item_ids):return False
        indices=[order[item] for item in item_ids]
        return indices==sorted(indices) and len(indices)==len(set(indices))

    def close(self):
        for image in self.images.values():image.close()
        self.images.clear()
