"""F10 verified inventory filter/sort preparation and row-aware scrolling."""
from dataclasses import dataclass
import math
from threading import Event
from PIL import Image, ImageChops, ImageStat
from core.inventory_catalog import CATALOG, ITEM_SCAN_PROFILES
from core import recognition_thresholds as rt
from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import ratio_crop
from core.student_weapon_recognizer import _normalized_correlation as correlation, _color_similarity as color_similarity


# Region assets locate controls, but only these names may be clicked (C2): a new asset
# entry can never make the scanner press an unreviewed button.
# Category checkbox per item scan profile (C5): prepare shows exactly one category.
CATEGORY_FILTERS={'student_elephs':'eleph_filter','tech_notes':'note_filter','tactical_bd':'bd_filter',
                  'ooparts':'ooparts_filter','activity_reports':'reports_filter','presents':'presents_filter'}
CATEGORY_BOXES=(*CATEGORY_FILTERS.values(),'coin_filter','consumable_filter','collectible_filter','crafting_filter','other_filter')
if set(CATEGORY_FILTERS)!=set(ITEM_SCAN_PROFILES):raise RuntimeError('category filters must cover every item scan profile')
ALLOWED_CONTROLS=frozenset({'filtermenu_button','eq_filtermenu_button','filter_tab','sort_tab',
    'sort_rule_check','sort_name_rule_check','eq_sort_rule_check','filter_confirm_button','eq_filter_confirm_button',
    'filter_reset_button','filter_cancel_button',*CATEGORY_FILTERS.values()})


@dataclass(frozen=True)
class PreparedInventory:
    source: str
    profile_id: str
    filter_verified: bool
    sort_verified: bool


@dataclass
class PageMove:
    """One verified scroll: the measured upward content shift as a fraction of frame height (C5)."""
    frame: Image.Image
    shift: float
    terminal: bool=False
    reason: str='verified_pixel_shift'


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
        if self.score(frame,'filter_title')>=rt.value('inventory.menu.filter_title'):return True
        names=('eq_sort_rule_check',) if source=='equipment' else ('sort_rule_check','sort_name_rule_check')
        return any(self.score(frame,n)>=rt.value('inventory.menu.sort_check_visible') for n in names)

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

    def category_state(self,frame,name):
        """'selected' (cyan check), 'empty', 'all' (grey check after reset) or None when unclear."""
        region=self.regions['controls'][name];w,h=frame.size
        box=(round(region['x1']*w)+4,round(region['y1']*h)+4,round(region['x2']*w)-4,round(region['y2']*h)-4)
        with frame.crop(box) as crop:
            pixels=list(crop.convert('RGB').getdata())
        count=max(1,len(pixels))
        cyan=sum(1 for r,g,b in pixels if b>200 and g>180 and r<150)/count
        grey=sum(1 for r,g,b in pixels if 170<r<225 and abs(r-g)<15 and b-r>8 and b<240)/count
        if cyan>=rt.value('inventory.category.selected_cyan'):return 'selected'
        if cyan<=rt.value('inventory.category.empty_cyan_max') and grey<=rt.value('inventory.category.empty_grey_max'):return 'empty'
        if cyan<=rt.value('inventory.category.empty_cyan_max'):return 'all'
        return None

    def tab_active(self,frame,tab):
        region=self.regions['controls'][tab];w,h=frame.size
        box=(round(region['x1']*w),round(region['y1']*h),round(region['x2']*w),round(region['y2']*h))
        with frame.crop(box) as crop:
            pixels=list(crop.convert('RGB').getdata())
        white=sum(1 for r,g,b in pixels if r>235 and g>235 and b>235)/max(1,len(pixels))
        return white>=rt.value('inventory.menu.tab_active_white')

    def switch_tab(self,target,cancel,tab):
        """The menu reopens on the last-used tab; tab-specific clicks wait until this tab is shown."""
        for click_attempt in range(2):
            self.click(target,cancel,tab)
            for attempt in range(3):
                if attempt and cancel.wait(.15):raise ScannerError('cancelled','inventory preparation cancelled')
                with self.capture.wait_stable(target,cancel) as frame:
                    active=self.tab_active(frame,tab)
                self.trace.append(dict(observe=tab,active=active,attempt=click_attempt*3+attempt+1))
                if active:return True
        raise ScannerError('inventory_tab_unconfirmed',f'{tab} did not become active')

    def observe_categories(self,target,cancel,step,accept):
        for attempt in range(3):
            if attempt and cancel.wait(.15):raise ScannerError('cancelled','inventory preparation cancelled')
            with self.capture.wait_stable(target,cancel) as frame:
                states={name:self.category_state(frame,name) for name in CATEGORY_BOXES}
            self.trace.append(dict(observe='category',step=step,states=states,attempt=attempt+1))
            if accept(states):return True
        return False

    def ensure_category(self,target,cancel,profile):
        """Reset, wait for the reset to show, tick the profile category, and verify it is the only one."""
        wanted=CATEGORY_FILTERS[profile]
        self.click(target,cancel,'filter_reset_button')
        # The reset animates; a category click before it lands is overwritten by the reset.
        if not self.observe_categories(target,cancel,'reset',lambda states:set(states.values())=={'all'}):
            raise ScannerError('inventory_category_unconfirmed','category reset did not show')
        self.click(target,cancel,wanted)
        if not self.observe_categories(target,cancel,wanted,lambda states:states[wanted]=='selected'
                and all(state=='empty' for name,state in states.items() if name!=wanted)):
            raise ScannerError('inventory_category_unconfirmed',f'{wanted} is not the only selected category')
        return True

    def ensure_sort(self,target,cancel,source,profile):
        name='eq_sort_rule_check' if source=='equipment' else ('sort_name_rule_check' if profile=='student_elephs' else 'sort_rule_check')
        threshold=rt.value('inventory.sort_check.equipment' if source=='equipment' else 'inventory.sort_check.item')
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
            # The filter tab has one checkbox per category (C2-1 corrected the F12 contract);
            # only the scan profile's category is shown. The sort radio lives on the sort tab
            # and ensure_sort observes it before any click.
            try:
                self.switch_tab(target,cancel,'filter_tab');self.ensure_category(target,cancel,profile)
                self.switch_tab(target,cancel,'sort_tab');self.ensure_sort(target,cancel,source,profile)
            except ScannerError:
                # Leave the display settings unchanged: cancel the menu before reporting.
                self.click(target,Event(),'filter_cancel_button',cleanup=True)
                raise
        else:
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
            if previous is not None and self.page_similarity(previous,signatures)>=rt.value('inventory.scroll.settled_same'):stable+=1
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

    def restore_first_page(self,target,cancel,frame):
        """Re-apply the verified display settings; the client then shows the first page (X10)."""
        return self.prepare(target,cancel,frame)

    def page_slots(self,source,offset,readable=True):
        """{content index: slot region} for tiles fully inside the list viewport at a content offset.

        offset is the total upward scroll (fraction of frame height) since the first page; rows keep
        the first page's column geometry and move by whole content rows plus the measured phase.
        """
        base=self.detail_recognizer.regions['sources'][source]['grid_slots'];rows=len(base)//5
        pitch=base[5]['cy']-base[0]['cy'];viewport=self.regions['list_viewport'][source]
        # A readable tile keeps its selection border inside the list; the panel edge clips it otherwise.
        margin=self.regions['list_viewport']['edge_margin'] if readable else 0.0
        # Whole rows scrolled plus a small phase; offset 0 reproduces the first-page grid exactly.
        whole=round(offset/pitch);phase=whole*pitch-offset
        result={}
        for row in range(-1,rows+1):
            template=base[min(max(row,0),rows-1)*5:min(max(row,0),rows-1)*5+5]
            dy=phase+(row-min(max(row,0),rows-1))*pitch
            if row+whole<0:continue
            for col,slot in enumerate(template):
                region=dict(x1=slot['x1'],x2=slot['x2'],cx=slot['cx'],y1=slot['y1']+dy,y2=slot['y2']+dy,cy=slot['cy']+dy)
                if region['y1']>=viewport['y1']+margin and region['y2']<=viewport['y2']-margin:result[(row+whole)*5+col]=region
        return result

    def measure_shift(self,before,after,source):
        """(upward shift as a fraction of height, mean grey residual) of the list between two frames."""
        base=self.detail_recognizer.regions['sources'][source]['grid_slots'];viewport=self.regions['list_viewport'][source]
        w,h=before.size
        box=(round(base[0]['x1']*w),round(viewport['y1']*h),round(base[4]['x2']*w),round(viewport['y2']*h))
        with before.convert('L') as a_full,after.convert('L') as b_full:
            a=a_full.crop(box);b=b_full.crop(box)
        try:
            height=a.height;limit=height-80
            def cost(x,y,shift,span):
                with x.crop((0,shift,x.width,span)) as top,y.crop((0,0,y.width,span-shift)) as bottom:
                    with ImageChops.difference(top,bottom) as diff:return ImageStat.Stat(diff).mean[0]
            with a.resize((a.width//2,height//2)) as a2,b.resize((b.width//2,height//2)) as b2:
                coarse=min(range(0,limit//2),key=lambda shift:cost(a2,b2,shift,a2.height))
            candidates=range(max(0,coarse*2-4),min(limit,coarse*2+4)+1)
            best=min(candidates,key=lambda shift:cost(a,b,shift,height))
            return best/h,cost(a,b,best,height)
        finally:
            a.close();b.close()

    def advance(self,target,cancel,before,source):
        """Scroll once and measure the real shift; two no-motion drags verify the end of the list."""
        for attempt in (1,2):
            self.scroll_once(target,cancel,attempt)
            after,_signatures=self.settled_after(target,cancel,source)
            shift,residual=self.measure_shift(before,after,source)
            self.trace.append(dict(shift_px=round(shift*after.height),residual=residual,attempt=attempt))
            if residual>rt.value('inventory.shift.max_residual'):
                after.close();raise ScannerError('inventory_scroll_unverified',f'list shift unmatched residual={residual:.2f}')
            if shift<=rt.value('inventory.shift.no_motion'):
                if attempt==2:return PageMove(after,0.0,True,'verified_no_motion')
                after.close();continue
            return PageMove(after,shift)
        raise ScannerError('inventory_scroll_unverified','scroll recovery exhausted')

    def verify_profile_order(self,profile,item_ids):
        order={row.item_id:row.order_index for row in CATALOG if row.profile_id==profile}
        if not item_ids or any(item not in order for item in item_ids):return False
        indices=[order[item] for item in item_ids]
        return indices==sorted(indices) and len(indices)==len(set(indices))

    def close(self):
        for image in self.images.values():image.close()
        self.images.clear()
