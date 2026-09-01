import json
import hashlib
from pathlib import Path
from threading import Event
import unittest
from unittest.mock import Mock
from PIL import Image

from core.inventory_detail_recovery import InventoryDetailRecognizer
from core.inventory_catalog import CATALOG
from core.inventory_navigation import InventoryNavigation, PreparedInventory, ScrollResult
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
           'filter_confirm_button','eq_filter_confirm_button','sort_rule_check','eq_sort_rule_check']
    for i,name in enumerate(names):nav.regions['controls'][name]=dict(x1=i/20,y1=.1,x2=i/20+.02,y2=.12)
    nav.templates={};nav.images={};nav.trace=[]
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
        self.assertEqual(['filtermenu_button','filter_tab','sort_rule_check','sort_tab','filter_confirm_button'],names)

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


class SignatureNavigation(InventoryNavigation):
    def __init__(self,before,afters):
        self.capture=FakeCapture();self.before=before;self.afters=iter(afters);self.trace=[]
    def signatures(self,frame,source):return self.before
    def settled_after(self,target,cancel,source):return self.capture.frame.copy(),next(self.afters)


class ScrollTests(unittest.TestCase):
    def test_row_overlap_recovers_three_rows_and_scans_only_new_two(self):
        before=[sig(i) for i in range(25)];after=before[10:]+[sig(i) for i in range(30,40)]
        nav=SignatureNavigation(before,[after]);result=nav.advance({},Event(),nav.capture.frame,'item')
        self.assertEqual(3,result.overlap_rows);self.assertEqual(tuple(range(15,25)),result.slot_indices)
        self.assertFalse(result.terminal);self.assertEqual([-240],nav.capture.scrolls)

    def test_no_motion_retries_once_then_is_verified_terminal(self):
        before=[sig(i) for i in range(25)];nav=SignatureNavigation(before,[before,before])
        result=nav.advance({},Event(),nav.capture.frame,'item')
        self.assertTrue(result.terminal);self.assertEqual('verified_no_motion',result.reason)
        self.assertEqual([-240,-360],nav.capture.scrolls)

    def test_ambiguous_overlap_is_failure_not_terminal(self):
        before=[sig(i) for i in range(25)];unknown=[sig(i) for i in range(60,85)]
        nav=SignatureNavigation(before,[unknown])
        with self.assertRaises(ScannerError) as exc:nav.advance({},Event(),nav.capture.frame,'item')
        self.assertEqual('inventory_scroll_unverified',exc.exception.code)

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

    def test_reviewed_native_pairs_preserve_overlap_and_safe_decisions(self):
        for pair in self.manifest['pairs']:
            with self.subTest(pair=pair['after']), Image.open(self.root/pair['before']) as before, Image.open(self.root/pair['after']) as after:
                overlap=self.nav.overlap(self.nav.signatures(before,pair['source_kind']),
                                         self.nav.signatures(after,pair['source_kind']))
                self.assertIsNotNone(overlap);rows,score,margin=overlap
                self.assertEqual(pair['overlap_rows'],rows)
                if pair['decision']=='verified_row_overlap':
                    threshold=.025 if pair['source_kind']=='equipment' else .03
                    self.assertGreaterEqual(score,.94);self.assertGreaterEqual(margin,threshold)
                elif pair['decision']=='verified_tail_residual':
                    self.assertGreaterEqual(score,.88);self.assertLess(score,.94);self.assertGreaterEqual(margin,.03)
                else:
                    self.assertLess(margin,.025)

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
