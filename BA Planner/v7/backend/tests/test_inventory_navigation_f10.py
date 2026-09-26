import json
import hashlib
from pathlib import Path
from threading import Event
import unittest
from unittest.mock import Mock
from PIL import Image

from core.inventory_detail_recovery import InventoryDetailRecognizer
from core.inventory_catalog import CATALOG
from core.inventory_navigation import ALLOWED_CONTROLS, CATEGORY_BOXES, InventoryNavigation, PageMove, PreparedInventory
from core import recognition_thresholds as rt
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError


class FakeCapture:
    def __init__(self):self.clicks=[];self.scrolls=[];self.frame=Image.new('RGB',(1280,720),'#789abc')
    def click(self,target,x,y):self.clicks.append((round(x,4),round(y,4),target.get('_scanner_cleanup',False)))
    def scroll(self,target,delta):self.scrolls.append(delta)
    def wait_stable(self,target,cancel,timeout=2):
        if cancel.is_set():raise ScannerError('cancelled','fixture')
        return self.frame.copy()


class Detail:
    def __init__(self,source='item'):self.source=source;self.regions={'sources':{source:{'grid_slots':[]}}}
    def classify(self,frame):return self.source


def bare(source='item'):
    nav=object.__new__(InventoryNavigation);nav.capture=FakeCapture();nav.catalog=None;nav.detail_recognizer=Detail(source)
    nav.regions={'filter_title':dict(x1=0,y1=0,x2=.1,y2=.1),'controls':{}}
    names=['filtermenu_button','eq_filtermenu_button','filter_tab','filter_reset_button','note_filter','sort_tab',
           'filter_confirm_button','eq_filter_confirm_button','sort_rule_check','eq_sort_rule_check','filter_cancel_button']
    for i,name in enumerate(names):nav.regions['controls'][name]=dict(x1=i/20,y1=.1,x2=i/20+.02,y2=.12)
    nav.regions['scroll_track']=dict(x=.975,start_y=.75,end_y=[.65,.58])
    nav.templates={};nav.images={};nav.trace=[]
    nav.tab_active=lambda _frame,_tab:True
    nav.category_state=lambda _frame,name:('selected' if name=='note_filter' else 'empty') if 'note_filter' in [row.get('input') for row in nav.trace] else 'all'
    return nav


class PreparationTests(unittest.TestCase):
    def test_parity_contract_is_frozen_before_implementation(self):
        value=json.loads((Path(__file__).parent/'fixtures/inventory_navigation_f10_v6_parity.json').read_text())
        self.assertEqual(2,value['contracts']['filter_open']['max_attempts'])
        self.assertFalse(value['contracts']['coverage']['cancel_or_partial_or_scroll_failure_zero_fill'])

    def test_present_profile_has_the_v6_natural_order_for_all_templates(self):
        rows=[row for row in CATALOG if row.profile_id=='presents']
        self.assertEqual(75,len(rows))
        self.assertEqual('Item_Icon_Favor_0',rows[0].item_id)
        self.assertEqual('Item_Icon_Favor_SSR_GL_20',rows[-1].item_id)
        nav=bare();self.assertTrue(nav.verify_profile_order('presents',[row.item_id for row in rows]))

    def test_item_prepare_orders_filter_then_verified_sort_then_confirm(self):
        nav=bare();nav.menu_ready=lambda *_:True;scores=iter([.8]);nav.score=lambda *_:next(scores)
        result=nav.prepare({'inventory_scan_profile':'tech_notes'},Event(),nav.capture.frame)
        self.assertEqual(PreparedInventory('item','tech_notes',True,True),result)
        names=[row['input'] for row in nav.trace if 'input' in row]
        self.assertEqual(['filtermenu_button','filter_tab','filter_reset_button','note_filter','sort_tab','filter_confirm_button'],names)

    def test_sort_radio_is_clicked_only_after_it_is_observed_off(self):
        # C2 X09: the radio lives on the sort tab; an already selected radio is never clicked.
        nav=bare();nav.menu_ready=lambda *_:True;scores=iter([.3,.8]);nav.score=lambda *_:next(scores)
        nav.prepare({'inventory_scan_profile':'tech_notes'},Event(),nav.capture.frame)
        names=[row['input'] for row in nav.trace if 'input' in row]
        self.assertEqual(['filtermenu_button','filter_tab','filter_reset_button','note_filter','sort_tab','sort_rule_check','filter_confirm_button'],names)
        observed=[row['observe'] for row in nav.trace if 'observe' in row]
        self.assertEqual(['filter_tab','category','category','sort_tab','sort_rule_check','sort_rule_check'],observed)

    def test_only_allowlisted_controls_can_be_clicked(self):
        nav=bare()
        for name in ('coin_filter','other_filter','collectible_filter'):
            with self.subTest(name=name),self.assertRaises(ScannerError) as exc:nav.click({},Event(),name)
            self.assertEqual('control_not_allowed',exc.exception.code)
        self.assertEqual([],nav.capture.clicks)
        real=InventoryNavigation(FakeCapture(),RecognitionAssetCatalog(),Detail())
        self.assertLessEqual(ALLOWED_CONTROLS,set(real.regions['controls'])|set(real.regions))

    def test_filter_open_retries_once_and_exhausts_without_later_inputs(self):
        nav=bare();ready=iter([False]*3+[True]);nav.menu_ready=lambda *_:next(ready)
        with nav.open_menu({},Event(),'item'):pass
        self.assertEqual(2,len(nav.capture.clicks))
        nav=bare();nav.menu_ready=lambda *_:False
        with self.assertRaises(ScannerError) as exc:nav.open_menu({},Event(),'item')
        self.assertEqual('inventory_filter_unconfirmed',exc.exception.code);self.assertEqual(2,len(nav.capture.clicks))

    def test_sort_repairs_at_most_twice_and_requires_post_click_match(self):
        nav=bare();scores=iter([.2,.3,.8]);nav.score=lambda *_:next(scores)
        self.assertTrue(nav.ensure_sort({},Event(),'item','tech_notes'))
        self.assertEqual(2,len(nav.capture.clicks))
        nav=bare();nav.score=lambda *_:.2
        with self.assertRaises(ScannerError) as exc:nav.ensure_sort({},Event(),'item','tech_notes')
        self.assertEqual('inventory_sort_unconfirmed',exc.exception.code);self.assertEqual(2,len(nav.capture.clicks))

    def test_account_profile_is_never_used_as_inventory_scan_profile(self):
        nav=bare();nav.menu_ready=lambda *_:True;nav.score=lambda *_:.8
        with self.assertRaises(ScannerError) as exc:nav.prepare({'profile_id':'account-a'},Event(),nav.capture.frame)
        self.assertEqual('inventory_profile_required',exc.exception.code);self.assertEqual([],nav.capture.clicks)


def sig(label):
    values=[float(hashlib.sha256(f'{label}:{i}'.encode()).digest()[0]&1==1) for i in range(256)]
    norm=sum(v*v for v in values)**.5
    return tuple(v/norm for v in values)


class ShiftNavigation(InventoryNavigation):
    """advance() with scripted settled frames and measured (shift, residual) pairs."""
    def __init__(self,shifts):
        self.capture=FakeCapture();self.shifts=iter(shifts);self.trace=[]
        self.regions={'scroll_track':dict(x=.975,start_y=.75,end_y=[.65,.58])}
    def settled_after(self,target,cancel,source):return self.capture.frame.copy(),None
    def measure_shift(self,before,after,source):return next(self.shifts)


class ScrollTests(unittest.TestCase):
    def test_measured_shift_moves_the_page(self):
        nav=ShiftNavigation([(110/720,2.0)]);result=nav.advance({},Event(),nav.capture.frame,'item')
        self.assertAlmostEqual(110/720,result.shift);self.assertFalse(result.terminal)
        self.assertEqual('verified_pixel_shift',result.reason);self.assertEqual([-240],nav.capture.scrolls)

    def test_no_motion_retries_once_then_is_verified_terminal(self):
        nav=ShiftNavigation([(0.0,0.0),(0.002,0.5)]);result=nav.advance({},Event(),nav.capture.frame,'item')
        self.assertTrue(result.terminal);self.assertEqual('verified_no_motion',result.reason)
        self.assertEqual([-240,-360],nav.capture.scrolls)

    def test_unmatched_shift_is_failure_not_terminal(self):
        nav=ShiftNavigation([(.1,rt.value('inventory.shift.max_residual')+1)])
        with self.assertRaises(ScannerError) as exc:nav.advance({},Event(),nav.capture.frame,'item')
        self.assertEqual('inventory_scroll_unverified',exc.exception.code)

    def test_page_slots_follow_the_measured_offset(self):
        nav=InventoryNavigation(FakeCapture(),RecognitionAssetCatalog(),InventoryDetailRecognizer(RecognitionAssetCatalog()))
        for source,count in (('item',20),('equipment',25)):
            base=nav.detail_recognizer.regions['sources'][source]['grid_slots']
            self.assertEqual({i:slot for i,slot in enumerate(base)},nav.page_slots(source,0.0))
            self.assertEqual(count,len(base))
        moved=nav.page_slots('item',110/720)
        # Row 1 now sits ~1px under the list top: its selection border would be clipped, so it is not readable.
        self.assertEqual(list(range(10,25)),sorted(moved))
        self.assertEqual(list(range(5,25)),sorted(nav.page_slots('item',110/720,readable=False)))
        base=nav.detail_recognizer.regions['sources']['item']['grid_slots'];pitch=base[5]['cy']-base[0]['cy']
        self.assertAlmostEqual(base[0]['y1']+2*pitch-110/720,moved[10]['y1'],places=9)

    def test_tab_switch_is_verified_before_tab_specific_clicks(self):
        # C5 live: the menu reopened on the sort tab, the filter-tab click was lost, and the
        # reset click landed on a sort radio. Tabs are now observed active before any tab click.
        nav=InventoryNavigation(FakeCapture(),RecognitionAssetCatalog(),Detail())
        root=Path(__file__).resolve().parents[2]/'debug'
        for frame_path,filter_active in (('scanner_c5_live/safety/01-menu.png',False),('scanner_c5_live/category/02-note-clicked.png',True)):
            with self.subTest(frame=frame_path),Image.open(root/frame_path) as frame:
                self.assertEqual(filter_active,nav.tab_active(frame,'filter_tab'))
                self.assertEqual(not filter_active,nav.tab_active(frame,'sort_tab'))
        nav=bare();nav.menu_ready=lambda *_:True;nav.tab_active=lambda _f,tab:tab=='sort_tab'
        with self.assertRaises(ScannerError) as exc:nav.prepare({'inventory_scan_profile':'tech_notes'},Event(),nav.capture.frame)
        self.assertEqual('inventory_tab_unconfirmed',exc.exception.code)
        clicks=[row['input'] for row in nav.trace if 'input' in row]
        self.assertEqual(['filtermenu_button','filter_tab','filter_tab','filter_cancel_button'],clicks)

    def test_category_boxes_read_live_1280_states(self):
        # C5 (C2-1): selected cyan / empty / grey 'all' after reset, from the live client.
        nav=InventoryNavigation(FakeCapture(),RecognitionAssetCatalog(),Detail())
        root=Path(__file__).resolve().parents[2]/'debug/scanner_c5_live/category'
        expected={'00-filter-tab':'note','01-after-reset':None,'02-note-clicked':'note'}
        for name,selected in expected.items():
            with self.subTest(frame=name),Image.open(root/f'{name}.png') as frame:
                states={box:nav.category_state(frame,box) for box in CATEGORY_BOXES}
                if selected is None:self.assertEqual({'all'},set(states.values()))
                else:
                    self.assertEqual('selected',states['note_filter'])
                    self.assertEqual({'empty'},{v for k,v in states.items() if k!='note_filter'})

    def test_category_must_be_the_only_selected_box(self):
        cases=(({'note_filter':'selected'},'empty',True),
               ({'note_filter':'selected','presents_filter':'selected'},'empty',False),
               ({},'all',False),
               ({'note_filter':None},'empty',False))
        for overrides,default,ok in cases:
            with self.subTest(overrides=overrides,default=default):
                nav=bare();observed=[]
                def state(_f,name,o=overrides,d=default):
                    # Before the category click every box shows the reset ('all') state.
                    return 'all' if 'note_filter' not in [row.get('input') for row in nav.trace] else o.get(name,d)
                nav.category_state=state
                if ok:self.assertTrue(nav.ensure_category({},Event(),'tech_notes'))
                else:
                    with self.assertRaises(ScannerError) as exc:nav.ensure_category({},Event(),'tech_notes')
                    self.assertEqual('inventory_category_unconfirmed',exc.exception.code)
                clicks=[row['input'] for row in nav.trace if 'input' in row]
                self.assertEqual(['filter_reset_button','note_filter'],clicks)

    def test_category_click_waits_for_reset_and_failure_cancels_menu(self):
        nav=bare();nav.menu_ready=lambda *_:True;nav.score=lambda *_:.8
        nav.category_state=lambda *_:'selected'  # never shows the reset
        with self.assertRaises(ScannerError) as exc:nav.prepare({'inventory_scan_profile':'tech_notes'},Event(),nav.capture.frame)
        self.assertEqual('inventory_category_unconfirmed',exc.exception.code)
        clicks=[row['input'] for row in nav.trace if 'input' in row]
        self.assertEqual(['filtermenu_button','filter_tab','filter_reset_button','filter_cancel_button'],clicks)
        self.assertTrue(nav.capture.clicks[-1][2])

    def test_drag_uses_the_scroll_track_outside_every_grid_slot(self):
        # C2 X08: the drag starts in the list padding, so a drag read as a tap selects nothing.
        drags=[];nav=ShiftNavigation([(0.0,0.0),(0.0,0.0)])
        nav.capture.drag_scroll=lambda target,start,end:drags.append((start,end))
        nav.advance({},Event(),nav.capture.frame,'item')
        self.assertEqual([((.975,.75),(.975,.65)),((.975,.75),(.975,.58))],drags)
        real=RecognitionAssetCatalog().region_for_purpose('inventory','inventory-navigation-regions')['scroll_track']
        slots=InventoryDetailRecognizer(RecognitionAssetCatalog()).regions['sources']
        for source in ('item','equipment'):
            for slot in slots[source]['grid_slots']:
                self.assertTrue(real['x']>slot['x2'] or real['x']<slot['x1'],(source,slot))

    def test_profile_order_requires_membership_monotonicity_and_unique_ids(self):
        nav=bare();a='Item_Icon_SkillBook_Hyakkiyako_0';b='Item_Icon_SkillBook_Hyakkiyako_1'
        self.assertTrue(nav.verify_profile_order('tech_notes',[a,b]))
        self.assertFalse(nav.verify_profile_order('tech_notes',[b,a]))
        self.assertFalse(nav.verify_profile_order('tech_notes',[a,a]))
        self.assertFalse(nav.verify_profile_order('tech_notes',[a,'foreign']))


class NativeNavigationFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=Path(__file__).parent/'fixtures/inventory_navigation_f10_live'
        cls.manifest=json.loads((cls.root/'manifest.json').read_text())
        cls.detail=InventoryDetailRecognizer(RecognitionAssetCatalog())
        cls.nav=object.__new__(InventoryNavigation);cls.nav.detail_recognizer=cls.detail

    @classmethod
    def tearDownClass(cls):cls.detail.close()

    def test_native_pairs_measure_exact_pixel_shifts(self):
        # C5 (X20, C2-2): the measured shift replaces F10's histogram overlap. The F10 pair rejected as
        # an ambiguous overlap and the sub-row tail both measure cleanly on the live 1280 frames.
        nav=InventoryNavigation(FakeCapture(),RecognitionAssetCatalog(),self.detail)
        expected={('item-page0.png','item-page1.png'):112,('item-pre-tail.png','item-tail.png'):31,
                  ('equipment-page0.png','equipment-page1.png'):110,('equipment-page1.png','equipment-page2.png'):112,
                  ('equipment-page2.png','equipment-variable-drag.png'):110}
        live=Path(__file__).resolve().parents[2]/'debug/scanner_c2_live'
        cases=[(self.root/pair['before'],self.root/pair['after'],pair['source_kind'],expected[(pair['before'],pair['after'])]) for pair in self.manifest['pairs']]
        cases+=[(live/'tech-notes-full/frame-16.png',live/'tech-notes-full/frame-19.png','item',29),
                (live/'presents-full-2/frame-31.png',live/'presents-full-2/frame-34.png','item',110),
                (live/'equipment-full/frame-16.png',live/'equipment-full/frame-19.png','equipment',112),
                (live/'tech-notes-full/frame-19.png',live/'tech-notes-full/frame-19.png','item',0)]
        for before_path,after_path,source,pixels in cases:
            with self.subTest(after=after_path.name),Image.open(before_path) as before,Image.open(after_path) as after:
                shift,residual=nav.measure_shift(before.convert('RGB'),after.convert('RGB'),source)
                self.assertLessEqual(abs(round(shift*720)-pixels),1)
                self.assertLessEqual(residual,rt.value('inventory.shift.max_residual'))

    def test_fixture_hashes_are_immutable(self):
        for asset in self.manifest['assets']:
            self.assertEqual(asset['sha256'],hashlib.sha256((self.root/asset['file']).read_bytes()).hexdigest())


class AssetTests(unittest.TestCase):
    def test_f10_assets_are_versioned_and_ready(self):
        catalog=RecognitionAssetCatalog();status=catalog.verify()
        self.assertTrue(status['ready']);self.assertEqual(3051,status['asset_count'])
        self.assertEqual(4,len(catalog.assets('inventory','inventory-navigation-template')))
        regions=catalog.region_for_purpose('inventory','inventory-navigation-regions')
        self.assertIn('presents_filter',regions['controls'])


if __name__=='__main__':unittest.main()
