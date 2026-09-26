"""F9 inventory selection/detail boundary. No consumable or repository operations."""
from dataclasses import dataclass
from threading import Event
from PIL import Image
from core.inventory_catalog import BY_KEY
from core import recognition_thresholds as rt
from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import ratio_crop, quad_crop
from core.student_weapon_recognizer import _normalized_correlation as correlation, _color_similarity as color_similarity


def binary(image):
    gray=image.convert('L');hist=gray.histogram();total=sum(hist);weight=0;subtotal=0;best=-1;threshold=0
    mean=sum(i*n for i,n in enumerate(hist))
    for i,n in enumerate(hist):
        weight+=n;subtotal+=i*n
        if not weight or weight==total:continue
        score=weight*(total-weight)*(subtotal/weight-(mean-subtotal)/(total-weight))**2
        if score>best:best=score;threshold=i
    result=gray.point(lambda p:255 if p>threshold else 0);gray.close();return result


def glyph_score(crop,template):
    if template.width>160 or template.height>64:
        with template.copy() as small:
            small.thumbnail((160,64))
            return glyph_score(crop,small)
    with crop.resize(template.size) as scaled, binary(scaled) as a, binary(template) as b:
        return max(0,(correlation(a,b)+1)/2) if len(set(a.getdata()))>1 else 0


def icon_score(crop,template):
    with template.copy() as small:
        small.thumbnail((80,80))
        return max(0,correlation(crop,small))


@dataclass(frozen=True)
class DetailCount:
    value: str | None
    score: float=0
    reason: str=''
    source: str='inventory_detail_count'


@dataclass(frozen=True)
class DetailResult:
    identity: str | None
    score: float
    margin: float
    count: DetailCount
    source: str='inventory_detail_template'


class InventoryDetailRecognizer:
    def __init__(self,catalog):
        self.catalog=catalog
        self.regions=catalog.region_for_purpose('inventory','inventory-detail-regions')
        self.images={}
        self.last_ranking=[]

    def image(self,path):
        if path not in self.images:
            try:
                with Image.open(self.catalog.resolve(path)) as image:self.images[path]=image.convert('RGB')
            except OSError:return None
        return self.images[path]

    def classify(self,frame):
        scores={}
        for asset in self.catalog.assets('inventory','inventory-page-template'):
            source,key=asset.identity.split(':');template=self.image(asset.path)
            with ratio_crop(frame,self.regions[key]) as crop:
                scores[(source,key)]=template is not None and correlation(crop,template)>=rt.value('inventory.detail.source_title.correlation') and color_similarity(crop,template)>=rt.value('inventory.detail.source_title.color')
        matches=[s for s in ('item','equipment') if scores.get((s,'title')) and scores.get((s,'list_title'))]
        return matches[0] if len(matches)==1 else None

    def selected(self,frame,source):
        hits=[]
        for i,slot in enumerate(self.regions['sources'][source]['grid_slots']):
            with ratio_crop(frame,slot) as crop:
                band=max(2,round(frame.height*5/720));fractions=[]
                for y in (0,crop.height-band):
                    with crop.crop((0,y,crop.width,y+band)) as edge:
                        fractions.append(sum(r>220 and g>190 and b<185 and r-b>55 for r,g,b in edge.getdata())/(edge.width*edge.height))
                if min(fractions)>=rt.value('inventory.detail.selection.edge_fraction'):hits.append(i)
        return hits[0] if len(hits)==1 else None

    def count(self,frame,source,bank=None):
        bank=bank or source;geometry=self.regions['counts'].get(source,{})
        templates=self.regions['counts'].get(bank,{})
        def rank(cell,template_cell):
            candidates={}
            for label,path in template_cell.get('templates',{}).items():
                image=self.image(path)
                if image is None:continue
                with quad_crop(frame,cell['region']) as crop:candidates[label]=glyph_score(crop,image)
            return sorted(candidates.items(),key=lambda p:p[1],reverse=True)
        lengths=[]
        for n,row in geometry.items():
            ranked=rank(row['x'],templates.get(n,{}).get('x',{}))
            if ranked:lengths.append((n,ranked[0][1]))
        if not lengths:return DetailCount(None,reason='no_x_templates')
        lengths.sort(key=lambda x:x[1],reverse=True);n,xscore=lengths[0]
        if xscore<rt.value('inventory.detail.x_mark.score') or (len(lengths)>1 and xscore-lengths[1][1]<rt.value('inventory.detail.x_mark.margin')):
            return DetailCount(None,xscore,'weak_x_match')
        digits=[];score=xscore
        for i,cell in enumerate(geometry[n]['digits']):
            banks=templates.get(n,{}).get('digits',[])
            ranked=rank(cell,banks[i] if i<len(banks) else {})
            if not ranked:return DetailCount(None,score,'missing_digit_templates')
            value,confidence=ranked[0];score=min(score,confidence)
            if confidence<rt.value('inventory.detail.digit.score') or (len(ranked)>1 and confidence-ranked[1][1]<rt.value('inventory.detail.digit.margin')):
                return DetailCount(None,score,'weak_digit_match')
            value=str(int(value)%10)
            if i==0 and value=='0' and int(n)>1:return DetailCount(None,score,'leading_zero')
            digits.append(value)
        if len(digits)!=int(n):return DetailCount(None,score,'missing_digit_templates')
        return DetailCount(''.join(digits),score,source='inventory_detail_count' if bank==source else 'inventory_detail_item_bank')

    def read_count(self,frame,source):
        count=self.count(frame,source)
        if source=='equipment' and count.reason in {'no_x_templates','missing_digit_templates'}:
            count=self.count(frame,source,'item')
        return count

    def read(self,frame,source):
        names={asset.identity:asset.path for asset in self.catalog.assets('inventory','inventory-detail-name')}
        scores={};crops={}
        try:
            for profile,r in self.regions['profiles'].items():
                if r['source']==source:crops[profile]=(ratio_crop(frame,r['icon']),ratio_crop(frame,r['name']))
            for asset in self.catalog.assets('inventory','inventory-detail-icon'):
                profile,identity=asset.identity.split(':',1)
                if profile not in crops:continue
                template=self.image(asset.path)
                if template is None:continue
                icon,name=crops[profile]
                visual_score=icon_score(icon,template);name_template=self.image(names[asset.identity]) if asset.identity in names else None
                name_score=glyph_score(name,name_template) if name_template is not None else 0
                score=.4*visual_score+.6*name_score if name_score else visual_score
                scores[identity]=max(score,scores.get(identity,0))
        finally:
            for pair in crops.values():
                for crop in pair:crop.close()
        ranked=sorted(scores.items(),key=lambda p:p[1],reverse=True);self.last_ranking=ranked[:4]
        identity,score=ranked[0] if ranked else (None,0)
        margin=score-(ranked[1][1] if len(ranked)>1 else 0)
        threshold,min_margin=(.92,.03) if identity and identity.startswith('Equipment_Icon_WeaponExpGrowth') else (.88,.015)
        if score<threshold or margin<min_margin:identity=None
        return DetailResult(identity,score,margin,self.read_count(frame,source))

    def close(self):
        for image in self.images.values():image.close()
        self.images.clear()


@dataclass(frozen=True)
class DetailRecoveryResult:
    """One detail read. A failure is returned only after the original selection was verified."""
    detail: DetailResult|None=None
    restored: bool=True
    failure: ScannerError|None=None


class InventoryDetailRecovery:
    def __init__(self,capture,recognizer):
        self.capture,self.recognizer=capture,recognizer;self.trace=[]

    def same_grid(self,baseline,current,source):
        if baseline.size!=current.size or self.recognizer.classify(current)!=source:return False
        for slot in self.recognizer.regions['sources'][source]['grid_slots']:
            # Ignore selection edges; every slot interior must stay in the same place.
            dx=(slot['x2']-slot['x1'])*.18;dy=(slot['y2']-slot['y1'])*.18
            r=dict(x1=slot['x1']+dx,x2=slot['x2']-dx,y1=slot['y1']+dy,y2=slot['y2']-dy)
            with ratio_crop(baseline,r) as a,ratio_crop(current,r) as b:
                if color_similarity(a,b)<rt.value('inventory.detail.same_grid.color'):return False
        return True

    def observe_selection(self,target,cancel,baseline,source,expected=None):
        for attempt in range(3):
            if attempt and cancel.wait(.25):raise ScannerError('cancelled','inventory selection cancelled')
            try:frame=self.capture.wait_stable(target,cancel)
            except ScannerError as exc:
                if exc.code in {'capture_failed','capture_timeout'}:continue
                raise
            if not self.same_grid(baseline,frame,source):
                frame.close();raise ScannerError('inventory_page_changed','unverified inventory page; no input')
            selected=self.recognizer.selected(frame,source)
            if selected is not None and (expected is None or selected==expected):return frame,selected
            frame.close()
        raise ScannerError('inventory_selection_unknown' if expected is None else 'inventory_detail_unconfirmed','selection unresolved after three captures')

    def select(self,target,cancel,baseline,source,slot_index):
        frame,selected=self.observe_selection(target,cancel,baseline,source)
        if selected==slot_index:return frame
        frame.close()
        slot=self.recognizer.regions['sources'][source]['grid_slots'][slot_index]
        if cancel.is_set():raise ScannerError('cancelled','inventory selection cancelled')
        context=ScanContext.of(target)
        self.capture.click(context.replace(cancel=cancel),slot['cx'],slot['cy'])
        self.trace.append(dict(input='select_slot',slot=slot_index,cleanup=bool(context.cleanup)))
        if cancel.wait(.25):raise ScannerError('cancelled','inventory selection cancelled')
        frame,_=self.observe_selection(target,cancel,baseline,source,slot_index)
        return frame

    def anchor(self,target,cancel,baseline,slot_index):
        """Move the visible selection to slot_index before a scroll (C5).

        The next page overlaps this one by at least one row, so a selection anchored in the last
        row stays visible there and later detail reads keep F9's restore-to-visible-selection rule.
        """
        source=self.recognizer.classify(baseline)
        if source is None:raise ScannerError('inventory_selection_unknown','page unconfirmed; no input')
        self.trace=[]
        with self.select(ScanContext.of(target),cancel,baseline,source,slot_index):pass
        self.trace.append(dict(anchored=slot_index))

    def resolve(self,target,cancel,baseline,slot_index,grid_id,grid_count,grid_confirmed,profile_verified=False,scan_profile=None):
        self.trace=[];source=self.recognizer.classify(baseline)
        if cancel.is_set():raise ScannerError('cancelled','inventory detail cancelled before input')
        original=self.recognizer.selected(baseline,source) if source else None
        if source is None:raise ScannerError('inventory_selection_unknown','page unconfirmed; no input')
        if original is None:
            frame,original=self.observe_selection(target,cancel,baseline,source)
            frame.close()
        if not 0<=slot_index<len(self.recognizer.regions['sources'][source]['grid_slots']):
            raise ScannerError('inventory_slot_invalid','slot is outside the verified visible grid')
        result=None;failure=None
        try:
            with self.select(target,cancel,baseline,source,slot_index) as frame:result=self.recognizer.read(frame,source)
        except Exception as exc:failure=exc
        finally:
            cleanup=Event()
            try:
                with self.select(ScanContext.of(target).replace(cleanup=True,cancel=cleanup),cleanup,baseline,source,original):pass
                self.trace.append(dict(restored=original))
            except Exception as exc:raise ScannerError('inventory_restore_failed','original page/selection unverified') from exc
        if failure:
            if isinstance(failure,ScannerError):return DetailRecoveryResult(restored=True,failure=failure)
            raise failure
        if cancel.is_set():raise ScannerError('cancelled','inventory detail read cancelled after safe restore')
        if grid_confirmed and result.identity and result.identity!=grid_id:
            return DetailRecoveryResult(DetailResult(grid_id,result.score,result.margin,DetailCount(None,reason='identity_conflict'),'inventory_detail_conflict'))
        profile=BY_KEY.get(grid_id)
        if (result.count.reason=='weak_x_match' and profile_verified and profile is not None
            and profile.profile_id==scan_profile and grid_confirmed and grid_count is not None
            and result.identity in (None,grid_id)):
            return DetailRecoveryResult(DetailResult(grid_id,result.score,result.margin,DetailCount(grid_count,0,'weak_x_match','verified_grid_count_fallback'),'verified_grid_detail_fallback'))
        return DetailRecoveryResult(result)
