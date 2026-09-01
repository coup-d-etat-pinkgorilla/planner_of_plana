import json
import hashlib
from pathlib import Path
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from PIL import Image, ImageDraw

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import EquipmentMenuCaptureAdapter, StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.student_equipment_recovery import EquipmentControlRecognizer, favorite_dot_state, resolve_equipment_menu
from core.student_equipment_recognizer import StudentEquipmentRecognizer, EquipmentMenuRecognizer
from core.student_panel_recovery import StudentPanelRecovery, StudentPanelRecognizer
from core.student_scan_recognizer import Observation, StudentBasicCropSet, ratio_crop
from test_student_panel_f2 import ScriptedUI, FakeRecognizer, FastEvent


def obs(value, status=None, source='fixture'):
    return Observation(value, 1 if value is not None else 0, status or ('ok' if value is not None else 'uncertain'), source, '')


class Menu:
    def __init__(self, cancel=None, error=None):
        self.opens = self.retries = self.closes = 0
        self.cancel, self.error = cancel, error
        self.recovery = SimpleNamespace(state='basic')
    def capture_equipment_menu(self, target, cancel):
        self.opens += 1
        if self.cancel: self.cancel.set()
        return Image.new('RGB', (8,8), 'white')
    def recapture_equipment_menu(self, target, cancel):
        self.retries += 1
        if self.error: raise self.error
        return Image.new('RGB', (8,8), 'white')
    def close_equipment_menu(self, target): self.closes += 1


class EquipmentF7Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.catalog = RecognitionAssetCatalog()
    def setUp(self):
        self.controls = EquipmentControlRecognizer(self.catalog)
        self.addCleanup(self.controls.close)
    def frame(self, label, size=(1280,720)):
        frame = Image.new('RGB', size, 'white')
        region = self.controls.regions['equipment_all_view_check_region']
        box = tuple(round(region[k]*s) for k,s in zip(('x1','y1','x2','y2'), size*2))
        with Image.open(self.catalog.resolve(f'templates/student_equipment/f7/{label}.png')) as source:
            with source.resize((box[2]-box[0],box[3]-box[1]), Image.Resampling.LANCZOS) as crop: frame.paste(crop,box[:2])
        return frame
    def test_fixed_check_states_at_two_resolutions(self):
        for size in ((1280,720),(2560,1440)):
            for label, expected in [('true',True),('false',False)]:
                with self.subTest(size=size,label=label), self.frame(label,size) as frame:
                    self.assertIs(expected,self.controls.read_check(frame).value)
    def test_blank_check_is_unknown(self):
        for color in ('white','black','gray'):
            with Image.new('RGB',(1280,720),color) as frame:
                self.assertIsNone(self.controls.read_check(frame).value)
    def test_growth_color_distinguishes_same_button_text(self):
        for label, expected in [('possible',True),('impossible',False)]:
            with Image.open(self.catalog.resolve(f'templates/student_equipment/f7/{label}.png')) as crop:
                self.assertIs(expected,self.controls.read_growth(crop).value)
        for color in ('white','black','gray',(90,220,255)):
            with Image.new('RGB',(100,30),color) as crop: self.assertIsNone(self.controls.read_growth(crop).value)
    def test_missing_control_bank_never_implies_off(self):
        self.controls.templates = {'unrelated':Image.new('RGB',(2,2))}
        with self.frame('true') as frame: self.assertIsNone(self.controls.read_check(frame).value)
    def adapter(self, states, checks, **kwargs):
        ui = ScriptedUI(states,**kwargs)
        recovery = StudentPanelRecovery(ui,None,recognizer=FakeRecognizer())
        self.addCleanup(recovery.close)
        adapter = EquipmentMenuCaptureAdapter(ui,self.catalog,recovery=recovery,controls=self.controls)
        self.enterContext(patch.object(self.controls,'read_check',side_effect=[obs(v) for v in checks]))
        self.enterContext(patch('core.student_panel_recovery.Event',FastEvent))
        return ui,recovery,adapter
    def test_on_no_toggle(self):
        ui,r,a = self.adapter(['basic','equipment','equipment','basic'],[True])
        a.capture_equipment_menu({},FastEvent()).close();a.close_equipment_menu({})
        self.assertEqual(2,len(ui.actions));self.assertEqual('basic',r.state)
    def test_off_rechecked_before_single_toggle(self):
        ui,r,a = self.adapter(['basic']+['equipment']*4+['basic'],[False,False,True])
        a.capture_equipment_menu({},FastEvent()).close();a.close_equipment_menu({})
        self.assertEqual(3,len(ui.actions));self.assertEqual('basic',r.state)
        self.assertEqual(1,sum(t.get('input')=='enable_show_all' for t in r.trace))
    def test_delayed_on_recheck_does_not_click(self):
        ui,r,a = self.adapter(['basic']+['equipment']*3+['basic'],[False,True])
        a.capture_equipment_menu({},FastEvent()).close();a.close_equipment_menu({})
        self.assertEqual(2,len(ui.actions))
    def test_unknown_no_toggle_restores(self):
        ui,r,a = self.adapter(['basic','equipment','equipment','basic'],[None])
        with self.assertRaises(ScannerError): a.capture_equipment_menu({},FastEvent())
        self.assertEqual(2,len(ui.actions));self.assertEqual('basic',r.state)
    def test_ignored_check_safe_partial_without_numeric_read(self):
        ui,r,a = self.adapter(['basic']+['equipment']*4+['basic'],[False,False,False])
        reader = SimpleNamespace(recognize=Mock(side_effect=AssertionError('off frame read')))
        result = resolve_equipment_menu(a,reader,{},FastEvent(),{},(1,))
        self.assertEqual('partial',result['equipment_panel'].status);reader.recognize.assert_not_called()
        self.assertEqual(3,len(ui.actions))
    def test_cancel_during_recheck_no_toggle(self):
        cancel=FastEvent()
        ui,r,a=self.adapter(['basic']+['equipment']*3+['basic'],[False],cancel=cancel,cancel_on=3)
        with self.assertRaises(ScannerError): a.capture_equipment_menu({},cancel)
        self.assertEqual(2,len(ui.actions));self.assertEqual('basic',r.state)
    def test_retry_rechecks_without_retoggling(self):
        ui,r,a=self.adapter(['basic']+['equipment']*3+['basic'],[True,False])
        a.capture_equipment_menu({},FastEvent()).close()
        with self.assertRaises(ScannerError): a.recapture_equipment_menu({},FastEvent())
        a.close_equipment_menu({});self.assertEqual(2,len(ui.actions))
    def run_reads(self, reads, slots=(1,2,3), initial=None, menu=None):
        menu=menu or Menu();reader=SimpleNamespace(recognize=Mock(side_effect=reads))
        result=resolve_equipment_menu(menu,reader,{},Event(),initial or {},slots)
        return result,menu,reader
    def test_all_missing_retry_once_then_recovery(self):
        first={f'equip{i}':obs(None) for i in (1,2,3)}
        second={f'equip{i}':obs('T10') for i in (1,2,3)}
        second.update({f'equip{i}_level':obs(70) for i in (1,2,3)})
        result,m,reader=self.run_reads([first,second])
        self.assertEqual((1,1,1),(m.opens,m.retries,m.closes));self.assertEqual(70,result['equip3_level'].value)
        self.assertEqual(2,reader.recognize.call_count)
    def test_permanent_missing_is_bounded(self):
        result,m,_=self.run_reads([{},{}]);self.assertEqual(1,m.retries)
        self.assertEqual('partial',result['equipment_panel'].status)
    def test_partial_tier_success_no_extra_capture(self):
        result,m,_=self.run_reads([{'equip1':obs('T9')}]);self.assertEqual(0,m.retries)
        self.assertEqual('T9',result['equip1'].value)
    def test_known_basic_tier_prevents_retry_and_is_preserved(self):
        result,m,_=self.run_reads([{}],initial={'equip2':obs('T10')})
        self.assertEqual(0,m.retries);self.assertEqual('T10',result['equip2'].value)
    def test_favorite_only_never_retries_or_invents_level(self):
        result,m,_=self.run_reads([{'equip4':obs('T2')}],slots=(4,))
        self.assertEqual(0,m.retries);self.assertEqual({'equip4'},set(result))
    def test_empty_and_locked_levels_are_resolved_skips(self):
        for state in ('empty','level_locked'):
            result,m,_=self.run_reads([{'equip1':obs(state),'equip1_level':obs(None,'skipped')}],slots=(1,))
            self.assertEqual(0,m.retries);self.assertNotIn('equipment_panel',result)
    def test_unverified_return_is_fatal(self):
        menu=Menu(error=ScannerError('capture_failed','fixture'));menu.recovery.state='unknown'
        with self.assertRaises(ScannerError): self.run_reads([{}],menu=menu)
        self.assertEqual(1,menu.closes)
    def test_cancel_before_read_closes_and_does_not_retry(self):
        cancel=Event();menu=Menu(cancel=cancel);reader=SimpleNamespace(recognize=Mock())
        with self.assertRaises(ScannerError): resolve_equipment_menu(menu,reader,{},cancel,{},(1,))
        self.assertEqual((0,1),(menu.retries,menu.closes));reader.recognize.assert_not_called()
    def test_retry_failure_keeps_basic_and_safe_partial(self):
        menu=Menu(error=ScannerError('capture_failed','fixture'))
        result,m,_=self.run_reads([{}],initial={'equip1_level':obs(70)},menu=menu)
        self.assertEqual(70,result['equip1_level'].value);self.assertEqual('partial',result['equipment_panel'].status)
    def test_conflict_sticky_no_retry(self):
        result,m,_=self.run_reads([{'equip1':obs('T9')}],slots=(1,),initial={'equip1':obs('T10')})
        self.assertEqual(0,m.retries);self.assertEqual('panel_value_conflict',result['equip1'].source)
    @staticmethod
    def corner(size=20):
        crop=Image.new('RGB',(size,size),'white')
        ImageDraw.Draw(crop).rounded_rectangle((-size,round(size*.15),round(size*.70),size*2),
            radius=round(size*.55),fill=(100,91,91))
        return crop
    def test_dot_absence_requires_corner_not_uniform_surface(self):
        self.assertIsNone(favorite_dot_state(None,StudentEquipmentRecognizer.empty_dot))
        for color,expected in [('white',None),('black',None),('gray',None),((255,185,24),True)]:
            with Image.new('RGB',(20,20),color) as crop:
                self.assertIs(expected,favorite_dot_state(crop,StudentEquipmentRecognizer.empty_dot))
        for size in (13,25):
            with self.corner(size) as crop:
                self.assertIs(False,favorite_dot_state(crop,StudentEquipmentRecognizer.empty_dot))
    def test_partial_or_occluded_dot_is_unknown(self):
        with self.corner() as crop:
            ImageDraw.Draw(crop).rectangle((9,7,10,9),fill=(255,185,24))
            self.assertIsNone(favorite_dot_state(crop,StudentEquipmentRecognizer.empty_dot))
        with self.corner() as crop:
            ImageDraw.Draw(crop).rectangle((0,0,19,3),fill='gray')
            self.assertIsNone(favorite_dot_state(crop,StudentEquipmentRecognizer.empty_dot))
    def test_lock_requires_both_positive_inactive_and_dot_absence(self):
        reader=StudentEquipmentRecognizer(self.catalog);self.addCleanup(reader.close)
        self.enterContext(patch('core.student_equipment_recognizer.student_meta.favorite_item_enabled',return_value=True))
        self.enterContext(patch('core.student_equipment_recognizer.student_meta.equipment_slots',return_value=()))
        for color,active,expected in [('corner',False,'love_locked'),('corner',None,None),('white',False,None),('black',False,None)]:
            with (self.corner() if color=='corner' else Image.new('RGB',(20,20),color)) as frame:
                crops=StudentBasicCropSet.from_frame(frame,{'basic_favorite_empty_dot_region':dict(x1=0,y1=0,x2=1,y2=1)})
            try:
                result,_=reader.recognize(crops,student_ref='serika_new_year',student_level=1,favorite_growth_active=active)
                self.assertEqual(expected,result['equip4'].value)
            finally: crops.close()
    def test_legacy_t10_decision_does_not_enable_current_bank(self):
        spec=json.loads((Path(__file__).parent/'fixtures/student_equipment_f7_v6_parity.json').read_text())
        self.assertEqual('disabled_pending_D2_independent_image_validation',spec['current_bank_t10_promotion'])
    def test_native_controls_normal_t10_and_same_student_return(self):
        root=Path(__file__).parent/'fixtures/student_equipment_f7_live'
        panel=StudentPanelRecognizer(self.catalog);self.addCleanup(panel.close)
        reader=EquipmentMenuRecognizer(self.catalog)
        spec=json.loads((root/'manifest.json').read_text())
        for row in spec['assets']:
            path=root/row['file'];self.assertEqual(row['sha256'],hashlib.sha256(path.read_bytes()).hexdigest())
            with Image.open(path) as frame:
                self.assertEqual((1280,720),frame.size);self.assertEqual(row['state'],panel.classify(frame))
                if row['state']=='equipment':
                    self.assertIs(row['check'],self.controls.read_check(frame).value)
                    if row['check']:
                        result=reader.recognize(frame,(1,2,3))
                        self.assertEqual(spec['expected']['tiers'],[result[f'equip{i}'].value for i in (1,2,3)])
                        self.assertEqual(spec['expected']['levels'],[result[f'equip{i}_level'].value for i in (1,2,3)])
                        self.assertTrue(all(v.source!='level70_implies_t10' for v in result.values()))
                else:
                    with ratio_crop(frame,self.controls.regions['equipment_button']) as crop:
                        self.assertIs(True,self.controls.read_growth(crop).value)
    def test_reviewed_favorite_locked_empty_t1_t2_at_native_resolutions(self):
        root=Path(__file__).parent/'fixtures/student_equipment_f7_favorite'
        reader=StudentEquipmentRecognizer(self.catalog);self.addCleanup(reader.close)
        self.enterContext(patch('core.student_equipment_recognizer.student_meta.equipment_slots',return_value=()))
        for row in json.loads((root/'manifest.json').read_text())['assets']:
            path=root/row['file']
            self.assertEqual(row['sha256'],hashlib.sha256(path.read_bytes()).hexdigest())
            with Image.open(path) as frame:
                crops=StudentBasicCropSet.from_frame(frame,self.catalog.region('student'))
                with ratio_crop(frame,self.controls.regions['equipment_button']) as crop:
                    growth=self.controls.read_growth(crop)
            try:
                with self.subTest(file=row['file']):
                    self.assertIs(row['growth'],growth.value)
                    self.assertIs(row['dot'],favorite_dot_state(crops.images['basic_favorite_empty_dot_region'],reader.empty_dot))
                    result,unresolved=reader.recognize(crops,student_ref=row['student'],student_level=row['level'],favorite_growth_active=growth.value)
                    self.assertEqual(row['favorite'],result['equip4'].value);self.assertNotIn(4,unresolved)
            finally:crops.close()
    def test_production_basic_miyu_love_lock_without_any_input_port(self):
        path=Path(__file__).parent/'fixtures/student_equipment_f7_favorite/miyu-1280.png'
        capture=SimpleNamespace(wait_stable=lambda *_args: Image.open(path).convert('RGB'))
        matcher=StudentMatcherAdapter(capture,self.catalog)
        for reader in (matcher.equipment_controls,matcher.equipment_recognizer,matcher.skill_recognizer,
                       matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer):
            self.addCleanup(reader.close)
        rows=matcher._scan_current({},Event(),lambda *_args:None);self.addCleanup(matcher._close_answer_specimens,rows)
        self.assertEqual('miyu',rows[0]['payload']['student_id'])
        self.assertEqual('love_locked',rows[0]['payload']['values']['equip4'])
        self.assertEqual('favorite_growth_lock',rows[0]['payload']['provenance']['equip4'])


if __name__=='__main__': unittest.main()
