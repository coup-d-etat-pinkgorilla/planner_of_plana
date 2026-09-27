import unittest
import hashlib,json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock,patch
from PIL import Image
from core.inventory_catalog import CATALOG_REVISION
from core.recognition_assets import RecognitionAssetCatalog
from core.inventory_detail_recovery import InventoryDetailRecognizer,InventoryDetailRecovery,DetailRecoveryResult,DetailResult,DetailCount
from core.inventory_navigation import PageMove,PreparedInventory
from core.scanner_session import ScannerError,ScanBatchResult
from core.scanner_matchers import InventoryMatcherAdapter,Match,CountMatch
from test_student_panel_f2 import FastEvent

ITEM='Item_Icon_SkillBook_Hyakkiyako_0'
OTHER='Item_Icon_SkillBook_Hyakkiyako_1'
SLOTS=[dict(x1=0,x2=.5,y1=.2,y2=.8,cx=.25,cy=.5),dict(x1=.5,x2=1,y1=.2,y2=.8,cx=.75,cy=.5)]

class GridUI:
    def __init__(self,ignored=False,changed=False,slots=SLOTS):
        self.selected=0;self.page=0;self.clicks=[];self.ignored=ignored;self.changed=changed;self.slots=slots
    def wait_stable(self,target,cancel,timeout=2):
        if cancel.is_set():raise ScannerError('cancelled','fixture')
        f=Image.new('RGB',(40,40),'white');f.putpixel((0,0),(self.selected,0,0));f.putpixel((1,0),(self.page,0,0));return f
    def click(self,target,x,y):
        self.clicks.append(target)
        if not self.ignored:self.selected=min(range(len(self.slots)),key=lambda i:abs(self.slots[i]['cx']-x))
        if self.changed:self.page=1
    def scroll(self,*a):pass
    def reader(self):
        return SimpleNamespace(regions={'sources':{'item':{'grid_slots':self.slots}}},
            classify=lambda f:'item' if f.getpixel((1,0))[0]==0 else None,
            selected=lambda f,s,_slots=None:f.getpixel((0,0))[0],read=Mock(return_value=DetailResult(ITEM,.95,.1,DetailCount('42',.9))))

SLOTS3=[dict(x1=0,x2=.33,y1=.2,y2=.8,cx=.16,cy=.5),dict(x1=.33,x2=.66,y1=.2,y2=.8,cx=.5,cy=.5),dict(x1=.66,x2=1,y1=.2,y2=.8,cx=.83,cy=.5)]

class F9RecoveryTests(unittest.TestCase):
    """C5d: one page session selects slots in order and returns to the original selection once."""
    def setUp(self):self.enterContext(patch('core.inventory_detail_recovery.Event',FastEvent))
    def outcome(self,ui,reader=None,slot=1,**kwargs):
        reader=reader or ui.reader();recovery=InventoryDetailRecovery(ui,reader);cancel=kwargs.pop('cancel',FastEvent())
        with ui.wait_stable({},FastEvent()) as frame:recovery.begin_page({},cancel,frame)
        try:return recovery.read({},cancel,slot,kwargs.pop('grid_id',ITEM),kwargs.pop('grid_count',None),kwargs.pop('grid_confirmed',False),**kwargs)
        finally:recovery.end_page({})
    def resolve(self,ui,reader=None,**kwargs):
        outcome=self.outcome(ui,reader,**kwargs)
        self.assertIsNone(outcome.failure);return outcome.detail
    def test_select_read_restore_original_same_grid(self):
        ui=GridUI();result=self.resolve(ui)
        self.assertEqual('42',result.count.value);self.assertEqual(0,ui.selected);self.assertEqual(2,len(ui.clicks))
        self.assertTrue(ui.clicks[-1]['_scanner_cleanup'])
    def test_batch_selects_in_order_and_returns_once(self):
        ui=GridUI(slots=SLOTS3);reader=ui.reader();recovery=InventoryDetailRecovery(ui,reader)
        with ui.wait_stable({},FastEvent()) as frame:recovery.begin_page({},FastEvent(),frame)
        seen=[]
        for slot in (0,1,2):
            outcome=recovery.read({},FastEvent(),slot,ITEM,None,False);seen.append(ui.selected)
            self.assertIsNone(outcome.failure)
        recovery.end_page({})
        # Slot 0 is already selected: no click; 1 and 2 in order; one verified return (per-slot restore took 4).
        self.assertEqual([0,1,2],seen);self.assertEqual(3,len(ui.clicks));self.assertEqual(0,ui.selected)
        self.assertEqual([False,False,True],[bool(c.get('_scanner_cleanup')) for c in ui.clicks])
        self.assertEqual(3,reader.read.call_count);self.assertIsNone(recovery.page)
    def test_ignored_click_retries_twice_then_stops_after_verified_return(self):
        ui=GridUI(ignored=True);reader=ui.reader()
        outcome=self.outcome(ui,reader)
        self.assertEqual('inventory_detail_unconfirmed',outcome.failure.code);self.assertIsNone(outcome.detail)
        self.assertTrue(outcome.restored);self.assertTrue(outcome.stop)
        reader.read.assert_not_called()
        # 1 click + 2 retries while the previous selection stays visible; the original needs no cleanup click.
        self.assertEqual(3,len(ui.clicks))
    def test_selection_elsewhere_is_not_retried(self):
        ui=GridUI(slots=SLOTS3);reader=ui.reader();clicked=ui.click
        def jump(target,x,y):
            clicked(target,x,y)
            if not target.get('_scanner_cleanup'):ui.selected=2
        ui.click=jump
        outcome=self.outcome(ui,reader)
        self.assertTrue(outcome.stop);self.assertEqual(0,ui.selected)
        self.assertEqual([False,True],[bool(c.get('_scanner_cleanup')) for c in ui.clicks])
    def test_completed_page_keeps_the_last_verified_selection(self):
        ui=GridUI(slots=SLOTS3);recovery=InventoryDetailRecovery(ui,ui.reader())
        with ui.wait_stable({},FastEvent()) as frame:recovery.begin_page({},FastEvent(),frame)
        recovery.read({},FastEvent(),2,ITEM,None,False);recovery.end_page({},keep_selection=True)
        self.assertEqual(2,ui.selected);self.assertEqual(1,len(ui.clicks));self.assertIsNone(recovery.page)
    def test_page_change_never_clicks_cleanup_on_unknown_screen(self):
        ui=GridUI(changed=True)
        with self.assertRaises(ScannerError) as exc:self.outcome(ui)
        self.assertEqual('inventory_restore_failed',exc.exception.code);self.assertEqual(1,len(ui.clicks))
    def test_unknown_selection_does_not_click(self):
        ui=GridUI();reader=ui.reader();reader.selected=lambda *_:None
        with self.assertRaises(ScannerError):self.outcome(ui,reader)
        self.assertEqual([],ui.clicks)
    def test_second_page_session_requires_a_verified_return(self):
        ui=GridUI();recovery=InventoryDetailRecovery(ui,ui.reader())
        with ui.wait_stable({},FastEvent()) as frame:
            recovery.begin_page({},FastEvent(),frame)
            with self.assertRaises(ScannerError) as exc:recovery.begin_page({},FastEvent(),frame)
        self.assertEqual('inventory_page_active',exc.exception.code);recovery.close()
    def test_fading_selection_recaptures_before_any_click(self):
        ui=GridUI();reader=ui.reader();selected=reader.selected;reads=[0]
        def fading(frame,source,slots=None):
            reads[0]+=1
            return None if reads[0]<=2 else selected(frame,source,slots)
        reader.selected=fading
        result=self.resolve(ui,reader)
        self.assertEqual('42',result.count.value);self.assertEqual(2,len(ui.clicks));self.assertEqual(0,ui.selected)
    def test_read_failure_keeps_the_batch_and_restores_at_page_end(self):
        ui=GridUI();reader=ui.reader();reader.read.side_effect=ScannerError('capture_failed','fixture')
        outcome=self.outcome(ui,reader)
        self.assertEqual('capture_failed',outcome.failure.code);self.assertFalse(outcome.stop);self.assertEqual(0,ui.selected)
    def test_cancel_after_read_uses_fresh_cleanup(self):
        ui=GridUI();reader=ui.reader();cancel=FastEvent()
        def read(*a):cancel.set();return DetailResult(ITEM,.95,.1,DetailCount('42',.9))
        reader.read.side_effect=read
        with self.assertRaises(ScannerError) as exc:self.outcome(ui,reader,cancel=cancel)
        self.assertEqual('cancelled',exc.exception.code);self.assertEqual(0,ui.selected)
        self.assertFalse(ui.clicks[-1]['_scanner_cancel'].is_set())
    def test_confirmed_grid_id_conflict_never_receives_other_count(self):
        ui=GridUI();reader=ui.reader();reader.read.return_value=DetailResult(OTHER,.95,.1,DetailCount('99',.9))
        result=self.resolve(ui,reader,grid_confirmed=True)
        self.assertEqual(ITEM,result.identity);self.assertIsNone(result.count.value)
        self.assertEqual('inventory_detail_conflict',result.source)
    def test_weak_x_requires_prior_confirmed_same_profile_grid_evidence(self):
        for verified,profile,confirmed,count,allowed in [(True,'tech_notes',True,'0',True),(False,'tech_notes',True,'42',False),(True,'equipment',True,'42',False),(True,'tech_notes',False,'42',False),(True,'tech_notes',True,None,False)]:
            with self.subTest(verified=verified,profile=profile,confirmed=confirmed,count=count):
                ui=GridUI();reader=ui.reader();reader.read.return_value=DetailResult(None,.5,0,DetailCount(None,.6,'weak_x_match'))
                result=self.resolve(ui,reader,grid_confirmed=confirmed,grid_count=count,profile_verified=verified,scan_profile=profile)
                self.assertEqual(count if allowed else None,result.count.value)
    def test_non_weak_x_and_conflicting_detail_do_not_use_grid_count(self):
        for identity,reason in [(None,'weak_digit_match'),(OTHER,'weak_x_match')]:
            ui=GridUI();reader=ui.reader();reader.read.return_value=DetailResult(identity,.95,.1,DetailCount(None,.6,reason))
            result=self.resolve(ui,reader,grid_confirmed=True,grid_count='42',profile_verified=True,scan_profile='tech_notes')
            self.assertIsNone(result.count.value)

class C5dEmptyTileTests(unittest.TestCase):
    def test_flat_grey_tile_at_the_list_end_is_empty(self):
        # Live presents tail (C5d): empty tiles are one flat grey (stddev 0.0, mean 204).
        from core.scanner_matchers import image_has_visible_content
        with Image.new('RGB',(117,96),(204,204,204)) as empty:self.assertFalse(image_has_visible_content(empty))
        with Image.new('RGB',(117,96),(204,204,204)) as filled:
            for x in range(20,97):
                for y in range(15,80):filled.putpixel((x,y),(40,90,200) if (x//6+y//6)%2 else (240,240,240))
            self.assertTrue(image_has_visible_content(filled))

class F9RecognitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.reader=InventoryDetailRecognizer(RecognitionAssetCatalog())
    @classmethod
    def tearDownClass(cls):cls.reader.close()
    def test_equipment_bank_substitution_only_for_missing_templates(self):
        for reason in ['no_x_templates','missing_digit_templates','weak_x_match','weak_digit_match']:
            with self.subTest(reason=reason),patch.object(self.reader,'count',side_effect=[DetailCount(None,reason=reason),DetailCount('0',.9)]) as read,                  patch.object(self.reader,'pitch_count',return_value=DetailCount(None,reason='no_count_ink')):
                result=self.reader.read_count(None,'equipment')
                self.assertEqual(2 if reason in {'no_x_templates','missing_digit_templates'} else 1,read.call_count)
                self.assertEqual('0' if read.call_count==2 else None,result.value)
    def test_actual_item_and_equipment_capture_identity_count_and_selection(self):
        root=Path(__file__).parent/'fixtures/inventory_detail_f9_live'
        for asset in json.loads((root/'manifest.json').read_text())['assets']:
            self.assertEqual(asset['sha256'],hashlib.sha256((root/asset['file']).read_bytes()).hexdigest())
            source=asset['source_kind']
            with self.subTest(file=asset['file']),Image.open(root/asset['file']) as frame:
                self.assertEqual(source,self.reader.classify(frame));self.assertEqual(asset['selected_slot'],self.reader.selected(frame,source))
                result=self.reader.read(frame,source)
                self.assertEqual(asset['identity'],result.identity);self.assertEqual(asset['count'],result.count.value)
    def test_missing_equipment_glyph_bank_uses_item_glyphs_at_equipment_geometry(self):
        original=self.reader.image
        with Image.open(Path(__file__).parent/'fixtures/inventory_detail_f9_live/equipment.png') as frame, \
             patch.object(self.reader,'image',side_effect=lambda path:None if '/equipment_count/' in path else original(path)):
            result=self.reader.read_count(frame,'equipment')
        self.assertEqual('116',result.value)
        self.assertEqual('inventory_detail_item_bank',result.source)
    def test_unknown_page_and_uniform_digit_not_recognized(self):
        for color in ['white','black','#334455']:
            with Image.new('RGB',(1280,720),color) as frame:
                self.assertIsNone(self.reader.classify(frame));self.assertIsNone(self.reader.count(frame,'item').value)

class F9AdapterTests(unittest.TestCase):
    def adapter(self,fast=True,count='42'):
        ui=GridUI();adapter=object.__new__(InventoryMatcherAdapter)
        adapter.capture=ui;adapter.threshold=.8;adapter.margin=.03;adapter.max_pages=1;adapter.answer_samples=None;adapter.slots=SLOTS[:1]
        adapter.matcher=Mock(templates=[1]);adapter.matcher.match.return_value=Match(ITEM,.95 if fast else .7,.1)
        adapter.count_matcher=Mock();adapter.count_matcher.match.return_value=CountMatch(count,.9,.1)
        reader=ui.reader();reader.regions={'sources':{'item':{'grid_slots':SLOTS[:1]}}}
        adapter.detail_recovery=Mock(recognizer=reader)
        adapter.detail_recovery.read.return_value=DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('0',.9)))
        self.enterContext(patch('core.scanner_matchers.image_has_visible_content',return_value=True))
        return adapter
    @staticmethod
    def nav():
        # C5e-1: two agreeing gutters at the predicted phase (no correction).
        nav=Mock();nav.phase_residuals.return_value=[0.0,0.0];return nav
    def scan(self,adapter):
        result=adapter({},FastEvent(),lambda *_:None)
        for row in result.candidates if isinstance(result,ScanBatchResult) else result:
            for crop in row.get('_answer_specimen',{}).get('slot_crops',{}).values():crop.close()
        return result
    def test_grid_success_zero_detail_calls(self):
        adapter=self.adapter();result=self.scan(adapter)
        adapter.detail_recovery.read.assert_not_called();self.assertEqual('42',result[0]['payload']['entries'][0]['quantity'])
    def test_unknown_grid_count_uses_real_detail_and_preserves_zero(self):
        adapter=self.adapter(count=None);result=self.scan(adapter)
        adapter.detail_recovery.read.assert_called_once();self.assertEqual('0',result[0]['payload']['entries'][0]['quantity'])
        self.assertIn('inventory_detail_template',[e['source'] for e in result[0]['evidence']])
    def test_unresolved_detail_does_not_silently_accept_weak_x_grid_quantity(self):
        adapter=self.adapter(fast=False)
        adapter.detail_recovery.read.return_value=DetailRecoveryResult(DetailResult(None,.5,0,DetailCount(None,reason='weak_x_match')))
        result=self.scan(adapter)
        self.assertIsNone(result[0]['payload']['entries'][0]['quantity']);self.assertTrue(result[0]['review_required'])
    def test_unverified_return_stops_session(self):
        adapter=self.adapter(count=None);adapter.detail_recovery.read.side_effect=ScannerError('inventory_restore_failed','fixture')
        result=self.scan(adapter);self.assertEqual('failed',result.outcome)
        self.assertEqual('inventory_restore_failed',result.error.code)
    def test_later_slot_restore_failure_preserves_completed_entry(self):
        adapter=self.adapter(count=None)
        adapter.detail_recovery.recognizer.regions={'sources':{'item':{'grid_slots':SLOTS}}}
        adapter.detail_recovery.read.side_effect=[DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('42',.9))),ScannerError('inventory_restore_failed','later slot')]
        result=self.scan(adapter)
        self.assertEqual('failed',result.outcome)
        self.assertEqual('42',result.candidates[0]['payload']['entries'][0]['quantity'])
        self.assertEqual(1,len(result.candidates[0]['payload']['entries']))
        self.assertTrue(result.candidates[0]['review_required'])

    def test_c5d_page_session_opens_once_and_returns_once(self):
        adapter=self.adapter(count=None)
        adapter.detail_recovery.recognizer.regions={'sources':{'item':{'grid_slots':SLOTS}}}
        adapter.matcher.templates=[1,2,3]
        adapter.detail_recovery.read.side_effect=[DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('42',.9))),
                                                  DetailRecoveryResult(DetailResult(OTHER,.95,.1,DetailCount('7',.9)))]
        self.scan(adapter)
        port=adapter.detail_recovery
        self.assertEqual(1,port.begin_page.call_count);self.assertEqual(1,port.end_page.call_count)
        self.assertEqual([0,1],[c.args[2] for c in port.read.call_args_list])
    def test_c5d_unconfirmed_selection_is_partial_and_stops_input(self):
        adapter=self.adapter(count=None)
        adapter.detail_recovery.recognizer.regions={'sources':{'item':{'grid_slots':SLOTS}}}
        adapter.detail_recovery.read.return_value=DetailRecoveryResult(restored=True,failure=ScannerError('inventory_detail_unconfirmed','fixture'),stop=True)
        result=self.scan(adapter)
        self.assertEqual('failed',result.outcome);self.assertEqual('inventory_detail_unconfirmed',result.error.code)
        # The session already returned; no second slot read and no second return.
        self.assertEqual(1,adapter.detail_recovery.read.call_count);adapter.detail_recovery.end_page.assert_not_called()
        entry=result.candidates[0]['evidence'][0]
        self.assertEqual('partial',entry['status']);self.assertTrue(result.candidates[0]['review_required'])

    def test_c5e1_gutter_phase_corrects_the_offset_without_an_anchor_click(self):
        adapter=self.adapter();adapter.max_pages=3;nav=self.nav()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        offsets=[]
        def page_slots(_source,offset,**_kw):
            offsets.append(offset);return {0:SLOTS[0]} if offset==0 else {1:SLOTS[0]}
        nav.page_slots.side_effect=page_slots
        # Fixture frames are 40px tall. Page 0 calibrates at -0.2px; after the move two gutters sit 0.5px
        # lower than predicted and one disagrees (a selection shadow) and is ignored.
        nav.phase_residuals.side_effect=lambda _f,_s,offset,calibration:[-0.2,-0.2] if offset==0 else [0.5,0.5,9.0]
        moves=iter([PageMove(adapter.capture.wait_stable({},FastEvent()),101/720),
                    PageMove(adapter.capture.wait_stable({},FastEvent()),0.0,True,'verified_no_motion')])
        nav.advance.side_effect=lambda *_:next(moves)
        adapter.detail_recovery.read.side_effect=[DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('0',.9))),DetailRecoveryResult(DetailResult(OTHER,.95,.1,DetailCount('3',.9)))]
        adapter.navigation=nav
        result=self.scan(adapter);evidence=result[0]['evidence']
        self.assertEqual(['correction_px=0.5;remeasured'],[e['note'] for e in evidence if e['source']=='gutter_phase'])
        self.assertAlmostEqual(101/720-0.5/40,max(offsets))
        # the calibration passed on later pages is the first page's agreeing median
        self.assertEqual(-0.2,nav.phase_residuals.call_args_list[-1].args[3])
        adapter.detail_recovery.anchor.assert_not_called()
        # completed pages keep their last verified selection (no return click before the drag)
        self.assertEqual([{'keep_selection':True}]*2,[c.kwargs for c in adapter.detail_recovery.end_page.call_args_list])
    def test_c5e1_one_identity_at_two_content_indices_is_unverified(self):
        # Live: a one-row shift alias mapped rows 55-59 to indices 50-54; the next page read them again.
        adapter=self.adapter();adapter.max_pages=3;nav=self.nav()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.page_slots.side_effect=lambda _source,offset,**_kw:{0:SLOTS[0]} if offset==0 else {1:SLOTS[0]}
        nav.advance.side_effect=lambda *_:PageMove(adapter.capture.wait_stable({},FastEvent()),101/720)
        adapter.navigation=nav
        result=self.scan(adapter)
        self.assertEqual('inventory_scroll_unverified',result.error.code)
        self.assertEqual(1,len(result.candidates[0]['payload']['entries']))
    def test_c5e1_phase_within_tolerance_refines_without_recapture(self):
        adapter=self.adapter();adapter.max_pages=3;nav=self.nav()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        offsets=[]
        def page_slots(_source,offset,**_kw):
            offsets.append(offset);return {0:SLOTS[0]} if offset==0 else {1:SLOTS[0]}
        nav.page_slots.side_effect=page_slots
        # 0.1px on a 40px frame is inside the 3px-of-720 tolerance: refined, not recaptured
        nav.phase_residuals.side_effect=lambda _f,_s,offset,calibration:[0.0,0.0] if offset==0 else [0.1,0.1]
        moves=iter([PageMove(adapter.capture.wait_stable({},FastEvent()),101/720,requested=101/720),
                    PageMove(adapter.capture.wait_stable({},FastEvent()),0.0,True,'verified_no_motion')])
        nav.advance.side_effect=lambda *_:next(moves)
        adapter.detail_recovery.read.side_effect=[DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('0',.9))),DetailRecoveryResult(DetailResult(OTHER,.95,.1,DetailCount('3',.9)))]
        adapter.navigation=nav
        result=self.scan(adapter);evidence=result[0]['evidence']
        self.assertEqual(['correction_px=0.1'],[e['note'] for e in evidence if e['source']=='gutter_phase'])
        self.assertAlmostEqual(101/720-0.1/40,max(offsets))
        self.assertIn('requested_px=5.6',[e['note'] for e in evidence if e['field']=='scroll_overlap'][0])
    def test_c5e1_unobserved_row_phase_is_unverified(self):
        for residuals in ([],[3.0],[0.0,9.0],[40.0,40.5]):
            with self.subTest(residuals=residuals):
                adapter=self.adapter();adapter.max_pages=3;nav=self.nav()
                nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
                nav.verify_profile_order.return_value=True
                nav.page_slots.side_effect=lambda _source,offset,**_kw:{0:SLOTS[0]} if offset==0 else {1:SLOTS[0]}
                nav.phase_residuals.side_effect=lambda _f,_s,offset,calibration,_r=residuals:[0.0,0.0] if offset==0 else _r
                nav.advance.side_effect=lambda *_:PageMove(adapter.capture.wait_stable({},FastEvent()),101/720)
                adapter.navigation=nav
                result=self.scan(adapter)
                self.assertEqual('inventory_scroll_unverified',result.error.code)
                self.assertEqual([],[e for e in result.candidates[0]['payload']['entries'] if e['observed_slot'] is None])

    def test_f10_verified_terminal_enables_profile_zero_fill(self):
        adapter=self.adapter();adapter.max_pages=2;nav=self.nav();nav.page_slots.return_value={0:SLOTS[0]}
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=lambda *_:PageMove(adapter.capture.wait_stable({},FastEvent()),0.0,True,'verified_no_motion')
        adapter.navigation=nav
        result=self.scan(adapter);entries=result[0]['payload']['entries']
        self.assertGreater(len(entries),1)
        self.assertTrue(any(e['quantity']=='0' and e['item_id']!=ITEM for e in entries))
        self.assertFalse(result[0]['review_required'])
        # C1 X04/X05/X21: zero-fill evidence names its resource, entries carry the scan profile,
        # and the terminal scroll evidence names the real decision.
        evidence=result[0]['evidence']
        zero_fill=[e for e in evidence if e['source']=='verified_profile_zero_fill']
        filled={e['key'] for e in entries if e['observed_slot'] is None}
        self.assertEqual({f'zero_fill[{key}].quantity' for key in filled},{e['field'] for e in zero_fill})
        self.assertFalse(any(e['field'].startswith('entries[') for e in zero_fill))
        self.assertEqual({'tech_notes'},{e['inventory_scan_profile'] for e in entries})
        self.assertEqual({'tech_notes'},{e['profile_id'] for e in entries})
        self.assertIn('verified_no_motion',{e['source'] for e in evidence if e['field']=='scroll_overlap'})
        self.assertEqual(CATALOG_REVISION,result[0]['payload']['catalog_revision'])

    def test_f10_scroll_failure_preserves_entry_and_never_zero_fills(self):
        adapter=self.adapter();adapter.max_pages=2;nav=self.nav();nav.page_slots.return_value={0:SLOTS[0]}
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=ScannerError('inventory_scroll_unverified','fixture')
        adapter.navigation=nav
        adapter.detail_recovery.read.return_value=DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('42',.9)))
        result=self.scan(adapter)
        self.assertEqual('failed',result.outcome)
        self.assertEqual(1,len(result.candidates[0]['payload']['entries']))
        self.assertEqual('42',result.candidates[0]['payload']['entries'][0]['quantity'])
        self.assertEqual(CATALOG_REVISION,result.candidates[0]['payload']['catalog_revision'])
        # C2 X10: the safe abort re-applies verified settings so the list is back on its first page.
        nav.restore_first_page.assert_called_once()
        self.assertTrue(result.error.details['first_page_restored'])
        restore=[e for e in result.candidates[0]['evidence'] if e['field']=='inventory_restore']
        self.assertEqual([('ok','inventory_first_page_restore')],[(e['status'],e['source']) for e in restore])

    def test_f10_scroll_failure_reports_failed_first_page_restore(self):
        adapter=self.adapter();adapter.max_pages=2;nav=self.nav();nav.page_slots.return_value={0:SLOTS[0]}
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=ScannerError('inventory_scroll_unverified','fixture')
        nav.restore_first_page.side_effect=ScannerError('inventory_prepare_unconfirmed','fixture')
        adapter.navigation=nav
        result=self.scan(adapter)
        self.assertFalse(result.error.details['first_page_restored'])
        restore=[e for e in result.candidates[0]['evidence'] if e['field']=='inventory_restore']
        self.assertEqual([('failed','inventory_prepare_unconfirmed')],[(e['status'],e['note']) for e in restore])

    def test_c5_tail_then_no_motion_is_the_verified_end(self):
        # C5 (X07, C2-2): a short last move is read like any page; only a later no-motion drag ends
        # coverage, so the residual tail is always followed by the re-check.
        adapter=self.adapter();adapter.max_pages=4;nav=self.nav()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.page_slots.side_effect=lambda _source,offset,**_kw:{0:SLOTS[0]} if offset==0 else {1:SLOTS[0]}
        moves=iter([PageMove(adapter.capture.wait_stable({},FastEvent()),29/720),
                    PageMove(adapter.capture.wait_stable({},FastEvent()),0.0,True,'verified_no_motion')])
        nav.advance.side_effect=lambda *_:next(moves)
        adapter.detail_recovery.read.side_effect=[DetailRecoveryResult(DetailResult(ITEM,.95,.1,DetailCount('0',.9))),DetailRecoveryResult(DetailResult(OTHER,.95,.1,DetailCount('3',.9)))]
        adapter.navigation=nav
        result=self.scan(adapter);evidence=result[0]['evidence']
        self.assertEqual(['verified_pixel_shift','verified_no_motion'],
                         [e['source'] for e in evidence if e['field']=='scroll_overlap'])
        self.assertEqual('ok',[e for e in evidence if e['field']=='scan_coverage'][0]['status'])
        self.assertTrue(any(e['observed_slot'] is None for e in result[0]['payload']['entries']))

    def test_c5_skipped_row_is_unverified_not_silently_lost(self):
        adapter=self.adapter();adapter.max_pages=3;nav=self.nav()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.page_slots.side_effect=lambda _source,offset,**_kw:{0:SLOTS[0]} if offset==0 else {2:SLOTS[0]}
        nav.advance.side_effect=lambda *_:PageMove(adapter.capture.wait_stable({},FastEvent()),.3)
        adapter.navigation=nav
        result=self.scan(adapter)
        self.assertEqual('failed',result.outcome);self.assertEqual('inventory_scroll_unverified',result.error.code)
        self.assertEqual([],[e for e in result.candidates[0]['payload']['entries'] if e['observed_slot'] is None])

    def test_c5_profile_scans_take_identity_from_the_detail_panel(self):
        # C0-1 / C2-1 / C5 live: bundled icon art does not match current tiles (tech notes all rank as one
        # icon, real equipment ranks as its blueprint piece at .80), so a grid match to an outside
        # identity never skips a slot on a profile scan; the detail identity decides membership.
        outside_of_notes='Equipment_Icon_WeaponExpGrowthZ_2'
        exp='Equipment_Icon_Exp_0'
        cases=(('item','tech_notes',outside_of_notes,ITEM,0.001,False),('item','tech_notes',outside_of_notes,ITEM,0.10,False),
               ('equipment','equipment',ITEM,exp,0.001,False),('equipment','equipment',ITEM,exp,0.10,False))
        for source,profile,outside,member,margin,skipped in cases:
            with self.subTest(source=source,margin=margin):
                adapter=self.adapter(fast=False);adapter.max_pages=1;nav=self.nav();nav.page_slots.return_value={0:SLOTS[0]}
                adapter.detail_recovery.recognizer.regions={'sources':{source:{'grid_slots':SLOTS[:1]}}}
                adapter.detail_recovery.read.return_value=DetailRecoveryResult(DetailResult(member,.95,.1,DetailCount('7',.9)))
                nav.prepare.return_value=PreparedInventory(source,profile,True,True)
                nav.verify_profile_order.return_value=True
                nav.advance.side_effect=lambda *_:PageMove(adapter.capture.wait_stable({},FastEvent()),0.0,True,'verified_no_motion')
                adapter.navigation=nav
                adapter.matcher.match.side_effect=lambda _crop,_m=member,_o=outside,_g=margin,**kw:(Match(_m,.7,.01) if kw.get('allowed_identities') else Match(_o,.69,_g))
                with patch.object(adapter.detail_recovery.recognizer,'classify',return_value=source):
                    result=self.scan(adapter)
                notes=[e['note'] for e in result[0]['evidence'] if e['field'].startswith('slots[')]
                if skipped:
                    self.assertEqual(['confident visible identity is outside the explicit scan profile'],notes)
                    adapter.detail_recovery.read.assert_not_called()
                else:
                    self.assertEqual([],notes);adapter.detail_recovery.read.assert_called_once()
                    self.assertEqual(member,result[0]['payload']['entries'][0]['item_id'])

    def test_c5_unresolved_detail_identity_is_never_recorded_from_the_grid(self):
        adapter=self.adapter(fast=True);adapter.max_pages=1;nav=self.nav();nav.page_slots.return_value={0:SLOTS[0]}
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=lambda *_:PageMove(adapter.capture.wait_stable({},FastEvent()),0.0,True,'verified_no_motion')
        adapter.navigation=nav
        adapter.detail_recovery.read.return_value=DetailRecoveryResult(DetailResult(None,.4,0,DetailCount(None,reason='weak_x_match')))
        result=self.scan(adapter)
        self.assertEqual([],result[0]['payload']['entries'])
        slot=[e for e in result[0]['evidence'] if e['field']=='slots[0]']
        self.assertEqual([('partial','inventory_detail_panel')],[(e['status'],e['source']) for e in slot])
        self.assertTrue(result[0]['review_required'])
        self.assertEqual('partial',[e for e in result[0]['evidence'] if e['field']=='scan_coverage'][0]['status'])

if __name__=='__main__':unittest.main()
