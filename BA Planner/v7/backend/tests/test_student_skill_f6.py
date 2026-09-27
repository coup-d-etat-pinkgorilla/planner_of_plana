import hashlib
import json
from pathlib import Path
from threading import Event
import unittest
from unittest.mock import patch
from PIL import Image
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import SkillMenuCaptureAdapter, StudentMatcherAdapter, Match
from core.scanner_session import ScannerError
from core.student_panel_recovery import StudentPanelRecovery, StudentPanelRecognizer
from core.student_skill_recognizer import StudentSkillRecognizer, SKILL_REGIONS
from core.student_scan_recognizer import Observation
from core.student_candidate_validation import StudentCandidateValidator
from test_student_panel_f2 import ScriptedUI, FakeRecognizer, FastEvent
from test_student_weapon_s2w import StableBasicCapture

FIXTURES = Path(__file__).parent/'fixtures'


def obs(value,status=None,source='fixture'):
    return Observation(value,1 if value is not None else 0,status or ('ok' if value is not None else 'uncertain'),source,'')


class Menu:
    def __init__(self,cancel=None,error=None):
        self.opens=self.closes=0;self.cancel=cancel;self.error=error
        self.recovery=type('Recovery',(),{'state':'basic','recognizer':type('Classifier',(),{'classify':lambda self,frame:'basic'})()})()
    def capture(self,target,cancel):
        self.opens+=1
        if self.error: raise self.error
        if self.cancel: self.cancel.set()
        return Image.new('RGB',(8,8),'white')
    def close(self,target): self.closes+=1


class SkillF6Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.catalog=RecognitionAssetCatalog()
    def setUp(self):
        self.reader=StudentSkillRecognizer(self.catalog);self.addCleanup(self.reader.close)
    def frame(self,values,check='true',size=(1280,720)):
        frame=Image.new('RGB',size,'white')
        for name,label in [('check',check),*values.items()]:
            region=self.reader.regions['skill_all_view_check_region' if name=='check' else SKILL_REGIONS[name]]
            box=tuple(round(region[k]*s) for k,s in zip(('x1','y1','x2','y2'),(size[0],size[1],size[0],size[1])))
            with Image.open(self.catalog.resolve(f'templates/student_skill/{name}/{label}.png')) as source:
                with source.resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS) as crop: frame.paste(crop,box[:2])
        return frame
    def initial(self,star=3):
        return {'student_star':obs(star),**{f:obs(None) for f in SKILL_REGIONS}}
    def test_numeric_and_max_parity_at_two_sizes(self):
        spec=json.loads((FIXTURES/'student_skill_f6_v6_parity.json').read_text())
        for size in ((1280,720),(2560,1440)):
            for field,maximum in spec['maximum'].items():
                for value in range(1,maximum+1):
                    with self.subTest(field=field,value=value,size=size),self.frame({field:value},size=size) as frame:
                        self.assertEqual(value,self.reader.recognize_menu(frame,(field,))[field].value)
    def test_native1280_panel_values_check_and_return(self):
        root=FIXTURES/'student_skill_f6_live';panel=StudentPanelRecognizer(self.catalog);self.addCleanup(panel.close)
        for row in json.loads((root/'manifest.json').read_text())['assets']:
            path=root/row['file'];self.assertEqual(row['sha256'],hashlib.sha256(path.read_bytes()).hexdigest())
            with Image.open(path) as frame:
                self.assertEqual((1280,720),frame.size);self.assertEqual(row['state'],panel.classify(frame))
                if row['state']=='skill':
                    self.assertIs(row['check'],self.reader.read_check(frame).value)
                    if row['values'] is not None:
                        values=self.reader.recognize_menu(frame)
                        self.assertEqual(row['values'],[values[f].value for f in SKILL_REGIONS])
    def test_checkbox_true_false_and_unknown(self):
        for label,expected in [('true',True),('false',False)]:
            with self.frame({},label) as frame: self.assertIs(expected,self.reader.read_check(frame).value)
        for color in ('white','black',(120,120,120)):
            with Image.new('RGB',(1280,720),color) as frame: self.assertIsNone(self.reader.read_check(frame).value)
    def test_off_or_unknown_never_reads_values(self):
        with self.frame({},'false') as frame,patch.object(self.reader,'read_value',side_effect=AssertionError('read off')):
            self.assertTrue(all(v.value is None for v in self.reader.recognize_menu(frame).values()))
    def test_blank_and_missing_templates_uncertain(self):
        for color in ('white','black',(120,120,120)):
            with Image.new('RGB',(100,30),color) as crop: self.assertIsNone(self.reader.read_value(crop,'ex_skill').value)
        self.reader.templates['ex_skill']={}
        with Image.open(self.catalog.resolve('templates/student_skill/ex_skill/1.png')) as crop:
            self.assertIsNone(self.reader.read_value(crop,'ex_skill').value)
    def test_locked_template_not_numeric_or_skipped_without_star(self):
        for field in ('skill2','skill3'):
            with self.frame({field:'locked'}) as frame:
                result=self.reader.recognize_menu(frame,(field,))[field]
                self.assertIsNone(result.value);self.assertEqual('uncertain',result.status)
    def test_confirmed_star_gates_locked_fields_and_keeps_bank_lazy(self):
        for star,locked in [(1,('skill2','skill3')),(2,('skill3',))]:
            initial={f:obs(1) for f in ('ex_skill','skill1')}
            initial.update(self.initial(star));initial.update(ex_skill=obs(1),skill1=obs(1))
            if star==2: initial['skill2']=obs(1)
            menu=Menu();result=self.reader.resolve(initial,menu,{},Event())
            for field in locked: self.assertEqual('skipped',result[field].status)
            self.assertEqual(0,menu.opens)
        self.assertEqual({},self.reader.templates);self.assertIsNone(self.reader.check_templates)
    def test_unknown_or_conflicted_star_never_skips(self):
        for star in (obs(None),obs(1,'uncertain','panel_value_conflict')):
            initial=self.initial();initial['student_star']=star
            result=self.reader.resolve(initial,None,{},Event())
            self.assertFalse(any(v.status=='skipped' for v in result.values()))
    def test_basic_success_zero_clicks(self):
        initial={f:obs(1) for f in SKILL_REGIONS};initial['student_star']=obs(3)
        menu=Menu();self.reader.resolve(initial,menu,{},Event());self.assertEqual(0,menu.opens)
    def test_partial_failure_only_reads_missing_slots(self):
        initial=self.initial();initial['ex_skill']=obs(5);initial['skill1']=obs(9)
        menu=Menu()
        with patch.object(self.reader,'recognize_menu',return_value={'skill2':obs(7),'skill3':obs(8)}) as read:
            result=self.reader.resolve(initial,menu,{},Event())
        self.assertEqual(('skill2','skill3'),read.call_args.args[1]);self.assertEqual(5,result['ex_skill'].value)
        self.assertEqual((1,1),(menu.opens,menu.closes))
    def test_detail_failure_partial_and_no_retry(self):
        menu=Menu()
        with patch.object(self.reader,'recognize_menu',return_value={'ex_skill':obs(None)}) as read:
            result=self.reader.resolve(self.initial(),menu,{},Event())
        self.assertEqual(1,read.call_count);self.assertEqual('partial',result['skill_panel'].status)
    def test_safe_open_failure_partial(self):
        result=self.reader.resolve(self.initial(),Menu(error=ScannerError('panel_open_failed','ignored',details={'screen_state':'basic'})),{},Event())
        self.assertEqual('partial',result['skill_panel'].status)
    def test_cancel_prevents_read_and_closes(self):
        cancel=Event();menu=Menu(cancel=cancel)
        with patch.object(self.reader,'recognize_menu',side_effect=AssertionError('cancelled read')):
            with self.assertRaises(ScannerError): self.reader.resolve(self.initial(),menu,{},cancel)
        self.assertEqual(1,menu.closes)
    def test_restore_failure_propagates(self):
        menu=Menu()
        with patch.object(menu,'close',side_effect=ScannerError('panel_restore_failed','unsafe')):
            with self.assertRaises(ScannerError): self.reader.resolve(self.initial(),menu,{},Event())
    def test_conflicting_locked_value_is_retained_for_review(self):
        initial=self.initial(1);initial['skill2']=obs(7)
        result=self.reader.resolve(initial,None,{},Event())
        self.assertEqual(7,result['skill2'].value);self.assertEqual('panel_value_conflict',result['skill2'].source)
        validator=StudentCandidateValidator(None)
        evidence=validator({'student_id':'mika','values':{'student_star':1,'level':90,'bond_rank':1,'skill2':7},
                            'provenance':{'skill2':'panel_value_conflict'}},None)
        self.assertEqual('partial',evidence['status'])
    def adapter(self,states,checks,cancel=None,cancel_on=None):
        ui=ScriptedUI(states,cancel=cancel,cancel_on=cancel_on)
        recovery=StudentPanelRecovery(ui,None,recognizer=FakeRecognizer());self.addCleanup(recovery.close)
        adapter=SkillMenuCaptureAdapter(ui,self.catalog,recovery=recovery,recognizer=self.reader)
        self.enterContext(patch.object(self.reader,'read_check',side_effect=[obs(c) for c in checks]))
        self.enterContext(patch('core.student_panel_recovery.Event',FastEvent))
        return ui,recovery,adapter
    def test_show_all_on_never_toggled(self):
        ui,r,a=self.adapter(['basic','skill','skill','basic'],[True])
        a.capture({},FastEvent()).close();a.close({})
        self.assertEqual(2,len(ui.actions));self.assertEqual('basic',r.state)
    def test_show_all_off_click_once_recheck_then_return(self):
        ui,r,a=self.adapter(['basic','skill','skill','skill','basic'],[False,True])
        a.capture({},FastEvent()).close();a.close({})
        self.assertEqual(3,len(ui.actions));self.assertEqual(1,sum(t.get('input')=='enable_show_all' for t in r.trace))
    def test_unknown_checkbox_no_click_and_restores(self):
        ui,r,a=self.adapter(['basic','skill','skill','basic'],[None])
        with self.assertRaises(ScannerError): a.capture({},FastEvent())
        self.assertEqual(2,len(ui.actions));self.assertEqual('basic',r.state)
    def test_ignored_checkbox_no_retoggle_and_partial(self):
        ui,r,a=self.adapter(['basic','skill','skill','skill','basic'],[False,False])
        result=self.reader.resolve(self.initial(),a,{},FastEvent())
        self.assertEqual('partial',result['skill_panel'].status);self.assertEqual(3,len(ui.actions))
    def test_cancel_after_checkbox_recapture_restores_without_read(self):
        cancel=FastEvent();ui,r,a=self.adapter(['basic','skill','skill','skill','basic'],[False],cancel,3)
        with self.assertRaises(ScannerError): a.capture({},cancel)
        self.assertEqual('basic',r.state);self.assertEqual(3,len(ui.actions))
    def test_wrong_student_return_fails(self):
        ui,r,a=self.adapter(['basic','skill','other-student'],[True])
        a.capture({},FastEvent()).close()
        with self.assertRaises(ScannerError): a.close({})
    def test_matcher_resolves_skills_after_star_before_downstream(self):
        matcher=StudentMatcherAdapter(StableBasicCapture(),self.catalog,skill_menu=Menu())
        for r in (matcher.skill_recognizer,matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer): self.addCleanup(r.close)
        basic={**self.initial(3),'level':obs(1),'weapon_level':obs(None),'weapon_star':obs(None)}
        def potential(images,observations,*args):
            self.assertEqual(7,observations['skill2'].value);return {}
        with patch.object(matcher.matcher,'match',return_value=Match('mika',1,1)),patch.object(matcher.basic_recognizer,'recognize',return_value=basic),patch.object(matcher.weapon_recognizer,'read_state',return_value=obs('no_weapon_system')),patch.object(matcher.skill_recognizer,'recognize_menu',return_value={f:obs(5 if f=='ex_skill' else 7) for f in SKILL_REGIONS}),patch.object(matcher.potential_recognizer,'resolve',side_effect=potential),patch.object(matcher.equipment_recognizer,'recognize',return_value=({},())):
            result=matcher._scan_current({},Event(),lambda *a:None)[0]
        self.addCleanup(matcher._close_answer_specimens,[result]);self.assertEqual(7,result['payload']['values']['skill2'])


if __name__=='__main__': unittest.main()
