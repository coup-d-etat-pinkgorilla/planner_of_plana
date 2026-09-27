"""F9 inventory selection/detail boundary. No consumable or repository operations."""
from dataclasses import dataclass
from threading import Event
from PIL import Image
from core.inventory_catalog import BY_KEY
from core import recognition_thresholds as rt
from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import ratio_crop, quad_crop
from core.recognition_image_ops import ncc_signed_lanczos as correlation, color_similarity


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


def binary_bits(image,size):
    """glyph_score's resize + Otsu binarization of image as an int bitmask (for popcount NCC)."""
    with image.resize(size) as scaled, binary(scaled) as bits:
        return int(''.join('1' if value else '0' for value in bits.getdata()),2)


def bits_score(left,right,count):
    """glyph_score of two binary images given as bitmasks of count pixels (same NCC, popcount arithmetic)."""
    a,b=left.bit_count(),right.bit_count();den=(count*a-a*a)*(count*b-b*b)
    return max(0,((count*(left&right).bit_count()-a*b)/den**.5+1)/2) if den>0 else 0


def icon_score(crop,template):
    with template.copy() as small:
        small.thumbnail((80,80))
        return max(0,correlation(crop,small))


def deskewed_ink(crop,shear):
    """Count-label ink (green level of the cyan glyphs; white badges and grey panels are not ink), slant removed."""
    width,height=crop.size;pad=round(shear*height)+1
    out=Image.new('L',(width+pad,height),0);src=crop.load();dst=out.load()
    for y in range(height):
        dx=round(shear*(y-height))+pad
        for x in range(width):
            r,g,b=src[x,y]
            if r<=170 and b>=150 and g>dst[x+dx,y]:dst[x+dx,y]=g
    return out


def ink_runs(mask,level):
    """(x1, y1, x2, y2) of each run of columns holding ink at or above level."""
    width,height=mask.size;px=mask.load();runs=[];start=None
    for x in range(width+1):
        column=x<width and any(px[x,y]>=level for y in range(height))
        if column and start is None:start=x
        if not column and start is not None:
            ys=[y for y in range(height) for i in range(start,x) if px[i,y]>=level]
            runs.append((start,min(ys),x,max(ys)+1));start=None
    return runs


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
        # C5e-6d: synthetic detail-icon vectors per source ({source: {identity: vectors}}), set by the scan.
        self.synth_details={}
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

    def selected(self,frame,source,slots=None):
        hits=[]
        for i,slot in enumerate(slots or self.regions['sources'][source]['grid_slots']):
            with ratio_crop(frame,slot) as crop:
                band=max(2,round(frame.height*5/720));fractions=[]
                # The border can sit a few pixels off a scrolled or re-aligned slot; take each edge's best band.
                reach=max(1,round(frame.height*3/720))
                for starts in (range(0,reach+1),range(crop.height-band-reach,crop.height-band+1)):
                    best=0.0
                    for y in starts:
                        with crop.crop((0,y,crop.width,y+band)) as edge:
                            best=max(best,sum(r>220 and g>190 and b<185 and r-b>55 for r,g,b in edge.getdata())/(edge.width*edge.height))
                    fractions.append(best)
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
        if count.value is None:
            pitched=self.pitch_count(frame,source)
            if pitched.value is not None:return pitched
        return count

    def digit_templates(self):
        """{digit: [(size, bitmask)]} of the v6 4-digit cells (all ten digits at every position, both sources), binarized once.

        The 5-digit cells are the misaligned layout (C5d-1); shorter lengths only add near-duplicates that thin margins.
        """
        if not hasattr(self,'_digit_templates'):
            self._digit_templates={}
            for rows in self.regions['counts'].values():
                for cell in rows.get('4',{}).get('digits',[]):
                    for label,path in cell.get('templates',{}).items():
                        image=self.image(path)
                        if image is not None:
                            self._digit_templates.setdefault(str(int(label)%10),[]).append((image.size,binary_bits(image,image.size)))
        return self._digit_templates

    def pitch_count(self,frame,source):
        """C5d-1: read the label on its fixed digit pitch.

        The label is tabular italic and the client shrinks 5-digit counts, so the v6 per-length cells no longer
        line up. The strip is deskewed by the font's slant, anchored on the x mark (it starts lower than the
        digits), the digit span is split into n equal cells with n fixed by pitch/height, and each cell is ranked
        against every v6 digit template.
        """
        geometry=self.regions['counts'].get(source,{});templates=self.digit_templates()
        if not geometry or not templates:return DetailCount(None,reason='no_pitch_templates')
        width,height=frame.size
        points=[p for row in geometry.values() for cell in (row['x'],*row['digits']) for p in cell['region']['points_ratio']]
        digit_ys=[p['y'] for row in geometry.values() for cell in row['digits'] for p in cell['region']['points_ratio']]
        box=(round((min(p['x'] for p in points)-.02)*width),round((min(digit_ys)-.006)*height),
             round((max(p['x'] for p in points)+.03)*width),round((max(digit_ys)+.006)*height))
        with frame.crop(box) as crop:mask=deskewed_ink(crop,rt.value('inventory.detail.pitch.shear'))
        runs=ink_runs(mask,rt.value('inventory.detail.pitch.ink'))
        tall=max((y2-y1 for _,y1,_,y2 in runs),default=0)
        runs=[r for r in runs if r[3]-r[1]>=.5*tall]
        if not runs:mask.close();return DetailCount(None,reason='no_count_ink')
        top=min(r[1] for r in runs);bottom=max(r[3] for r in runs);glyph=bottom-top
        marks=[i for i,r in enumerate(runs) if r[1]-top>.25*glyph]
        digits=[r for r in runs[marks[0]+1:] if r[1]-top<=.25*glyph] if marks else []
        if not digits:mask.close();return DetailCount(None,reason='no_x_mark')
        left,right=digits[0][0],digits[-1][2];reach=max(1,round(height/720))
        best=None
        for n in range(1,8):
            pitch=(right-left+1.5)/n
            if not rt.value('inventory.detail.pitch.ratio_low')<=pitch/glyph<=rt.value('inventory.detail.pitch.ratio_high'):continue
            read=[]
            for i in range(n):
                x1=round(left-.75+i*pitch);x2=round(left-.75+(i+1)*pitch);ranked=None
                for dx in range(-reach,reach+1):
                    with mask.crop((x1+dx,top,x2+dx,bottom)) as cell:
                        bits={size:binary_bits(cell,size) for size in {size for images in templates.values() for size,_ in images}}
                        scores=sorted(((max(bits_score(bits[size],template,size[0]*size[1]) for size,template in images),digit)
                                       for digit,images in templates.items()),reverse=True)
                    if ranked is None or scores[0][0]>ranked[0][0]:ranked=scores
                read.append((ranked[0][1],ranked[0][0],ranked[0][0]-ranked[1][0]))
            text,score,margin=''.join(r[0] for r in read),min(r[1] for r in read),min(r[2] for r in read)
            if best is None or score>best[1]:best=(text,score,margin)
        mask.close()
        if best is None:return DetailCount(None,reason='no_pitch_fit')
        text,score,margin=best
        if score<rt.value('inventory.detail.pitch.digit.score') or margin<rt.value('inventory.detail.pitch.digit.margin'):
            return DetailCount(None,score,'weak_pitch_digit')
        if len(text)>1 and text[0]=='0':return DetailCount(None,score,'leading_zero')
        return DetailCount(text,score,source='inventory_detail_pitch')

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
        if identity is None and self.synth_details.get(source):
            synthetic=self.synth_identity(frame,source)
            if synthetic is not None:
                return DetailResult(synthetic[0],synthetic[1],synthetic[2],self.read_count(frame,source),'synth_detail_icon')
        return DetailResult(identity,score,margin,self.read_count(frame,source))

    def synth_identity(self,frame,source):
        """C5e-6d fallback: the detail ROI against synthetic detail icons (after the captured templates)."""
        from core.recognition_image_ops import icon_vector_similarity,icon_vectors
        from core.recognition_synth import DETAIL_ROI,normalize_detail
        w,h=frame.size
        with frame.crop((round(DETAIL_ROI[0]*w),round(DETAIL_ROI[1]*h),round(DETAIL_ROI[2]*w),round(DETAIL_ROI[3]*h))) as crop,normalize_detail(crop) as normal:
            query=icon_vectors(normal)
        ranked=sorted(((icon_vector_similarity(query,vectors),identity) for identity,vectors in self.synth_details[source].items()),reverse=True)
        if not ranked:return None
        score,identity=ranked[0];margin=score-(ranked[1][0] if len(ranked)>1 else 0)
        if score<rt.value('inventory.synth_detail.score') or margin<rt.value('inventory.synth_detail.margin'):return None
        return identity,score,margin

    def close(self):
        for image in self.images.values():image.close()
        self.images.clear()


@dataclass(frozen=True)
class DetailRecoveryResult:
    """One detail read inside a page session (C5d).

    ``failure`` with ``stop`` means the selection was unconfirmed: the session already made its one
    verified return and no further input is allowed. Without ``stop`` the selection was confirmed and
    only the panel read failed, so the batch may continue.
    """
    detail: DetailResult|None=None
    restored: bool=True
    failure: ScannerError|None=None
    stop: bool=False


@dataclass
class _PageSelection:
    source: str
    slots: list|None
    original: int
    selected: int
    baseline: Image.Image


class InventoryDetailRecovery:
    """Batch detail reads on one verified page (C5d, X18: the StudentPanelRecovery open/restore contract).

    ``begin_page`` records the page's visible selection, ``read`` selects slots in order (1, 2, ... N)
    with the last verified selection frame as the baseline, and ``end_page`` either keeps the last
    verified selection (completed page, C5e-1) or makes the one verified return to the original
    selection (failure, cancel). F9 holds for every click: a visible selection before it and the same
    grid after it.
    """
    SELECT_RETRIES=2

    def __init__(self,capture,recognizer):
        self.capture,self.recognizer=capture,recognizer;self.trace=[];self.page=None

    def same_grid(self,baseline,current,source,slots=None,ignore=()):
        if baseline.size!=current.size or self.recognizer.classify(current)!=source:return False
        for index,slot in enumerate(slots or self.recognizer.regions['sources'][source]['grid_slots']):
            # A tile whose selection changes also tints its interior (live gifts: .972); the others verify the page.
            if index in ignore:continue
            # Ignore selection edges; every slot interior must stay in the same place.
            dx=(slot['x2']-slot['x1'])*.18;dy=(slot['y2']-slot['y1'])*.18
            r=dict(x1=slot['x1']+dx,x2=slot['x2']-dx,y1=slot['y1']+dy,y2=slot['y2']-dy)
            with ratio_crop(baseline,r) as a,ratio_crop(current,r) as b:
                if color_similarity(a,b)<rt.value('inventory.detail.same_grid.color'):return False
        return True

    def observe_selection(self,target,cancel,baseline,source,expected=None,slots=None):
        observed=None
        for attempt in range(3):
            if attempt and cancel.wait(.25):raise ScannerError('cancelled','inventory selection cancelled')
            try:frame=self.capture.wait_stable(target,cancel)
            except ScannerError as exc:
                if exc.code in {'capture_failed','capture_timeout'}:continue
                raise
            selected=self.recognizer.selected(frame,source,slots)
            changing={index for index in (expected,selected,self.recognizer.selected(baseline,source,slots)) if index is not None}
            if not self.same_grid(baseline,frame,source,slots,changing):
                frame.close();raise ScannerError('inventory_page_changed','unverified inventory page; no input')
            if selected is not None and (expected is None or selected==expected):return frame,selected
            observed=selected if selected is not None else observed
            frame.close()
        raise ScannerError('inventory_selection_unknown' if expected is None else 'inventory_detail_unconfirmed',
                           'selection unresolved after three captures',details={'observed':observed})

    def _click_until(self,target,cancel,baseline,source,slot_index,previous,slots):
        """Click slot_index until it is the visible selection; re-click only while the previous one still shows."""
        slot=(slots or self.recognizer.regions['sources'][source]['grid_slots'])[slot_index]
        context=ScanContext.of(target)
        for attempt in range(1+self.SELECT_RETRIES):
            if cancel.is_set():raise ScannerError('cancelled','inventory selection cancelled')
            try:
                self.capture.click(context.replace(cancel=cancel),slot['cx'],slot['cy'])
                self.trace.append(dict(input='select_slot',slot=slot_index,attempt=attempt+1,cleanup=bool(context.cleanup)))
            except ScannerError as exc:
                # D21: the user's own input overlapped this click; the observation below decides what happened,
                # and the disturbed click counts as one of the retries.
                if exc.code!='input_busy':raise
                self.trace.append(dict(input_busy=slot_index,attempt=attempt+1,performed=exc.details.get('performed')))
            if cancel.wait(.25):raise ScannerError('cancelled','inventory selection cancelled')
            try:
                frame,_=self.observe_selection(target,cancel,baseline,source,slot_index,slots)
                return frame
            except ScannerError as exc:
                # A lost click leaves the previous selection visible (F9 a); anything else stops input.
                if exc.code!='inventory_detail_unconfirmed' or exc.details.get('observed')!=previous or attempt==self.SELECT_RETRIES:raise

    def select(self,target,cancel,baseline,source,slot_index,slots=None):
        frame,selected=self.observe_selection(target,cancel,baseline,source,slots=slots)
        if selected==slot_index:return frame
        frame.close()
        return self._click_until(target,cancel,baseline,source,slot_index,selected,slots)

    def begin_page(self,target,cancel,frame,slots=None):
        if self.page is not None:raise ScannerError('inventory_page_active','previous page selection has not returned safely')
        self.trace=[];source=self.recognizer.classify(frame)
        if cancel.is_set():raise ScannerError('cancelled','inventory detail cancelled before input')
        if source is None:raise ScannerError('inventory_selection_unknown','page unconfirmed; no input')
        original=self.recognizer.selected(frame,source,slots)
        if original is None:baseline,original=self.observe_selection(target,cancel,frame,source,slots=slots)
        else:baseline=frame.copy()
        self.page=_PageSelection(source,slots,original,original,baseline)

    def read(self,target,cancel,slot_index,grid_id,grid_count,grid_confirmed,profile_verified=False,scan_profile=None):
        page=self.page
        if page is None:raise ScannerError('inventory_page_inactive','detail read has no open page')
        if cancel.is_set():raise ScannerError('cancelled','inventory detail cancelled before input')
        if not 0<=slot_index<len(page.slots or self.recognizer.regions['sources'][page.source]['grid_slots']):
            raise ScannerError('inventory_slot_invalid','slot is outside the verified visible grid')
        if page.selected!=slot_index:
            try:frame=self._click_until(target,cancel,page.baseline,page.source,slot_index,page.selected,page.slots)
            except ScannerError as exc:
                if exc.code!='inventory_detail_unconfirmed':raise
                # The one verified return happens at the failure; the caller stops input (C5d).
                self.end_page(target)
                return DetailRecoveryResult(restored=True,failure=exc,stop=True)
            page.baseline.close();page.baseline,page.selected=frame,slot_index
        try:result=self.recognizer.read(page.baseline,page.source)
        except ScannerError as exc:return DetailRecoveryResult(restored=False,failure=exc)
        if cancel.is_set():raise ScannerError('cancelled','inventory detail read cancelled')
        if grid_confirmed and result.identity and result.identity!=grid_id:
            return DetailRecoveryResult(DetailResult(grid_id,result.score,result.margin,DetailCount(None,reason='identity_conflict'),'inventory_detail_conflict'))
        profile=BY_KEY.get(grid_id)
        if (result.count.reason=='weak_x_match' and profile_verified and profile is not None
            and profile.profile_id==scan_profile and grid_confirmed and grid_count is not None
            and result.identity in (None,grid_id)):
            return DetailRecoveryResult(DetailResult(grid_id,result.score,result.margin,DetailCount(grid_count,0,'weak_x_match','verified_grid_count_fallback'),'verified_grid_detail_fallback'))
        return DetailRecoveryResult(result)

    def end_page(self,target,keep_selection=False):
        """Close the page session.

        keep_selection ends a completed page on its last verified selection without input (C5e-1);
        otherwise this is the one verified return to the page's original selection, with a fresh
        cleanup token.
        """
        page=self.page
        if page is None:return
        if keep_selection:
            self.trace.append(dict(kept=page.selected))
            page.baseline.close();self.page=None
            return
        cleanup=Event();context=ScanContext.of(target).replace(cleanup=True,cancel=cleanup)
        try:
            # F9 (a): observe the visible selection on the same grid before any cleanup click.
            frame,current=self.observe_selection(context,cleanup,page.baseline,page.source,slots=page.slots)
            frame.close()
            if current!=page.original:
                with self._click_until(context,cleanup,page.baseline,page.source,page.original,current,page.slots):pass
            self.trace.append(dict(restored=page.original))
        except Exception as exc:raise ScannerError('inventory_restore_failed','original page/selection unverified') from exc
        finally:
            page.baseline.close();self.page=None

    def close(self):
        if self.page is not None:
            self.page.baseline.close();self.page=None
