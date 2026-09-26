import unittest
import hashlib,json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock,patch
from PIL import Image
from core.inventory_catalog import CATALOG_REVISION
from core.recognition_assets import RecognitionAssetCatalog
from core.inventory_detail_recovery import InventoryDetailRecognizer,InventoryDetailRecovery,DetailResult,DetailCount
from core.inventory_navigation import PreparedInventory,ScrollResult
from core.scanner_session import ScannerError,ScanBatchResult
from core.scanner_matchers import InventoryMatcherAdapter,Match,CountMatch
from test_student_panel_f2 import FastEvent

ITEM='Item_Icon_SkillBook_Hyakkiyako_0'
OTHER='Item_Icon_SkillBook_Hyakkiyako_1'
SLOTS=[dict(x1=0,x2=.5,y1=.2,y2=.8,cx=.25,cy=.5),dict(x1=.5,x2=1,y1=.2,y2=.8,cx=.75,cy=.5)]

class GridUI:
    def __init__(self,ignored=False,changed=False):
        self.selected=0;self.page=0;self.clicks=[];self.ignored=ignored;self.changed=changed
    def wait_stable(self,target,cancel,timeout=2):
        if cancel.is_set():raise ScannerError('cancelled','fixture')
        f=Image.new('RGB',(40,40),'white');f.putpixel((0,0),(self.selected,0,0));f.putpixel((1,0),(self.page,0,0));return f
    def click(self,target,x,y):
        self.clicks.append(target)
        if not self.ignored:self.selected=0 if x<.5 else 1
        if self.changed:self.page=1
    def scroll(self,*a):pass
    def reader(self):
        return SimpleNamespace(regions={'sources':{'item':{'grid_slots':SLOTS}}},
            classify=lambda f:'item' if f.getpixel((1,0))[0]==0 else None,
            selected=lambda f,s:f.getpixel((0,0))[0],read=Mock(return_value=DetailResult(ITEM,.95,.1,DetailCount('42',.9))))

class F9RecoveryTests(unittest.TestCase):
    def setUp(self):self.enterContext(patch('core.inventory_detail_recovery.Event',FastEvent))
    def resolve(self,ui,reader=None,**kwargs):
        reader=reader or ui.reader();recovery=InventoryDetailRecovery(ui,reader)
        with ui.wait_stable({},FastEvent()) as frame:
            return recovery.resolve({},kwargs.pop('cancel',FastEvent()),frame,1,kwargs.pop('grid_id',ITEM),kwargs.pop('grid_count',None),kwargs.pop('grid_confirmed',False),**kwargs)
    def test_select_read_restore_original_same_grid(self):
        ui=GridUI();result=self.resolve(ui)
        self.assertEqual('42',result.count.value);self.assertEqual(0,ui.selected);self.assertEqual(2,len(ui.clicks))
        self.assertTrue(ui.clicks[-1]['_scanner_cleanup'])
    def test_ignored_click_never_reads_detail(self):
        ui=GridUI(ignored=True);reader=ui.reader()
        with self.assertRaises(ScannerError) as exc:self.resolve(ui,reader)
        self.assertEqual('inventory_detail_unconfirmed',exc.exception.code)
        self.assertTrue(exc.exception.details['inventory_restored']);reader.read.assert_not_called()
        self.assertEqual(1,len(ui.clicks))
    def test_page_change_never_clicks_cleanup_on_unknown_screen(self):
        ui=GridUI(changed=True)
        with self.assertRaises(ScannerError) as exc:self.resolve(ui)
        self.assertEqual('inventory_restore_failed',exc.exception.code);self.assertEqual(1,len(ui.clicks))
    def test_unknown_selection_does_not_click(self):
        ui=GridUI();reader=ui.reader();reader.selected=lambda *_:None
        with self.assertRaises(ScannerError):self.resolve(ui,reader)
        self.assertEqual([],ui.clicks)
    def test_fading_selection_recaptures_before_any_click(self):
        ui=GridUI();reader=ui.reader();selected=reader.selected;reads=[0]
        def fading(frame,source):
            reads[0]+=1
            return None if reads[0]<=2 else selected(frame,source)
        reader.selected=fading
        result=self.resolve(ui,reader)
        self.assertEqual('42',result.count.value);self.assertEqual(2,len(ui.clicks));self.assertEqual(0,ui.selected)
    def test_read_failure_restores_selection(self):
        ui=GridUI();reader=ui.reader();reader.read.side_effect=ScannerError('capture_failed','fixture')
        with self.assertRaises(ScannerError) as exc:self.resolve(ui,reader)
        self.assertTrue(exc.exception.details['inventory_restored']);self.assertEqual(0,ui.selected)
    def test_cancel_after_read_uses_fresh_cleanup(self):
        ui=GridUI();reader=ui.reader();cancel=FastEvent()
        def read(*a):cancel.set();return DetailResult(ITEM,.95,.1,DetailCount('42',.9))
        reader.read.side_effect=read
        with self.assertRaises(ScannerError) as exc:self.resolve(ui,reader,cancel=cancel)
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

class F9RecognitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.reader=InventoryDetailRecognizer(RecognitionAssetCatalog())
    @classmethod
    def tearDownClass(cls):cls.reader.close()
    def test_equipment_bank_substitution_only_for_missing_templates(self):
        for reason in ['no_x_templates','missing_digit_templates','weak_x_match','weak_digit_match']:
            with self.subTest(reason=reason),patch.object(self.reader,'count',side_effect=[DetailCount(None,reason=reason),DetailCount('0',.9)]) as read:
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
        adapter.detail_recovery.resolve.return_value=DetailResult(ITEM,.95,.1,DetailCount('0',.9))
        self.enterContext(patch('core.scanner_matchers.image_has_visible_content',return_value=True))
        return adapter
    def scan(self,adapter):
        result=adapter({},FastEvent(),lambda *_:None)
        for row in result.candidates if isinstance(result,ScanBatchResult) else result:
            for crop in row.get('_answer_specimen',{}).get('slot_crops',{}).values():crop.close()
        return result
    def test_grid_success_zero_detail_calls(self):
        adapter=self.adapter();result=self.scan(adapter)
        adapter.detail_recovery.resolve.assert_not_called();self.assertEqual('42',result[0]['payload']['entries'][0]['quantity'])
    def test_unknown_grid_count_uses_real_detail_and_preserves_zero(self):
        adapter=self.adapter(count=None);result=self.scan(adapter)
        adapter.detail_recovery.resolve.assert_called_once();self.assertEqual('0',result[0]['payload']['entries'][0]['quantity'])
        self.assertIn('inventory_detail_template',[e['source'] for e in result[0]['evidence']])
    def test_unresolved_detail_does_not_silently_accept_weak_x_grid_quantity(self):
        adapter=self.adapter(fast=False)
        adapter.detail_recovery.resolve.return_value=DetailResult(None,.5,0,DetailCount(None,reason='weak_x_match'))
        result=self.scan(adapter)
        self.assertIsNone(result[0]['payload']['entries'][0]['quantity']);self.assertTrue(result[0]['review_required'])
    def test_unverified_return_stops_session(self):
        adapter=self.adapter(count=None);adapter.detail_recovery.resolve.side_effect=ScannerError('inventory_restore_failed','fixture')
        result=self.scan(adapter);self.assertEqual('failed',result.outcome)
        self.assertEqual('inventory_restore_failed',result.error.code)
    def test_later_slot_restore_failure_preserves_completed_entry(self):
        adapter=self.adapter(count=None)
        adapter.detail_recovery.recognizer.regions={'sources':{'item':{'grid_slots':SLOTS}}}
        adapter.detail_recovery.resolve.side_effect=[DetailResult(ITEM,.95,.1,DetailCount('42',.9)),ScannerError('inventory_restore_failed','later slot')]
        result=self.scan(adapter)
        self.assertEqual('failed',result.outcome)
        self.assertEqual('42',result.candidates[0]['payload']['entries'][0]['quantity'])
        self.assertEqual(1,len(result.candidates[0]['payload']['entries']))
        self.assertTrue(result.candidates[0]['review_required'])

    def test_f10_verified_terminal_enables_profile_zero_fill(self):
        adapter=self.adapter();adapter.max_pages=2;nav=Mock()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=lambda *_:ScrollResult(adapter.capture.wait_stable({},FastEvent()),5,(),terminal=True,reason='verified_no_motion')
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
        adapter=self.adapter();adapter.max_pages=2;nav=Mock()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=ScannerError('inventory_scroll_unverified','fixture')
        adapter.navigation=nav
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
        adapter=self.adapter();adapter.max_pages=2;nav=Mock()
        nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
        nav.verify_profile_order.return_value=True
        nav.advance.side_effect=ScannerError('inventory_scroll_unverified','fixture')
        nav.restore_first_page.side_effect=ScannerError('inventory_prepare_unconfirmed','fixture')
        adapter.navigation=nav
        result=self.scan(adapter)
        self.assertFalse(result.error.details['first_page_restored'])
        restore=[e for e in result.candidates[0]['evidence'] if e['field']=='inventory_restore']
        self.assertEqual([('failed','inventory_prepare_unconfirmed')],[(e['status'],e['note']) for e in restore])

    def test_f10_residual_tail_is_terminal_only_after_no_motion_recheck(self):
        # C2 X07: a moved re-check keeps the observations but forbids zero-fill.
        for confirmed in (True,False):
            with self.subTest(confirmed=confirmed):
                adapter=self.adapter();adapter.max_pages=3;nav=Mock()
                nav.prepare.return_value=PreparedInventory('item','tech_notes',True,True)
                nav.verify_profile_order.return_value=True
                nav.advance.side_effect=lambda *_:ScrollResult(adapter.capture.wait_stable({},FastEvent()),3,(0,),False,True,'verified_tail_residual')
                nav.confirm_terminal.return_value=confirmed
                adapter.navigation=nav
                result=self.scan(adapter);entries=result[0]['payload']['entries']
                nav.confirm_terminal.assert_called_once()
                terminal=[e for e in result[0]['evidence'] if e['field']=='scroll_terminal']
                coverage=[e for e in result[0]['evidence'] if e['field']=='scan_coverage'][0]
                zero_filled=[e for e in entries if e['observed_slot'] is None]
                if confirmed:
                    self.assertEqual([('ok','verified_tail_residual')],[(e['status'],e['source']) for e in terminal])
                    self.assertTrue(zero_filled);self.assertEqual('ok',coverage['status'])
                else:
                    self.assertEqual([('partial','tail_recheck_moved')],[(e['status'],e['source']) for e in terminal])
                    self.assertEqual([],zero_filled);self.assertEqual('partial',coverage['status'])
                    self.assertTrue(result[0]['review_required'])

if __name__=='__main__':unittest.main()
