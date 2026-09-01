from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from PIL import Image
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter
from core.scanner_session import ScannerError, ScanBatchResult
from core.student_form_recovery import StudentFormRecovery
from core.student_identity_recovery import StudentIdentity
from core.student_scan_recognizer import Observation
from test_student_panel_f2 import FastEvent


class FormUI:
    def __init__(self, form=1, ignored=False, wrong_student=False):
        self.form, self.ignored, self.wrong_student = form, ignored, wrong_student
        self.base = 'hoshino_battle'
        self.clicks = []
    def click(self, target, x, y):
        self.clicks.append((target, x, y))
        if self.wrong_student:
            self.base = 'mika'
        elif not self.ignored:
            self.form = 1 if x < .5 else 2
    def observe(self, target, cancel):
        if cancel.is_set(): raise ScannerError('cancelled', 'fixture')
        ref = self.base if self.form == 1 else self.base+'#2'
        return Image.new('RGB', (10,10)), StudentIdentity(ref, .95, .1)


class FormF8Tests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch('core.student_form_recovery.Event', FastEvent))
        self.regions = {f'style_form_{i}_button':dict(x1=x,x2=x+.1,y1=.1,y2=.2) for i,x in [(1,.1),(2,.8)]}
    def test_other_form_read_and_original_return(self):
        ui = FormUI(); recovery = StudentFormRecovery(ui, self.regions); refs = []
        recovery.collect({}, FastEvent(), 'hoshino_battle', ui.observe, lambda frame, identity: refs.append(identity.student_ref))
        self.assertEqual(['hoshino_battle#2'], refs)
        self.assertEqual(1, ui.form); self.assertEqual(2,len(ui.clicks))
    def test_original_form_two_is_not_replaced_with_default_one(self):
        ui = FormUI(form=2); recovery = StudentFormRecovery(ui, self.regions); refs = []
        recovery.collect({}, FastEvent(), 'hoshino_battle#2', ui.observe, lambda frame, identity: refs.append(identity.student_ref))
        self.assertEqual(['hoshino_battle'], refs); self.assertEqual(2,ui.form)
    def test_ignored_input_is_not_form_success(self):
        ui=FormUI(ignored=True); recovery=StudentFormRecovery(ui,self.regions); read=Mock()
        with self.assertRaises(ScannerError) as exc: recovery.collect({},FastEvent(),'hoshino_battle',ui.observe,read)
        self.assertEqual('form_unconfirmed',exc.exception.code)
        self.assertTrue(exc.exception.details['form_restored']); read.assert_not_called()
        self.assertEqual(1,len(ui.clicks))
    def test_wrong_student_never_receives_cleanup_form_click(self):
        ui=FormUI(wrong_student=True); recovery=StudentFormRecovery(ui,self.regions)
        with self.assertRaises(ScannerError) as exc: recovery.collect({},FastEvent(),'hoshino_battle',ui.observe,Mock())
        self.assertEqual('form_restore_failed',exc.exception.code); self.assertEqual(1,len(ui.clicks))
    def test_read_failure_still_restores(self):
        ui=FormUI(); recovery=StudentFormRecovery(ui,self.regions)
        with self.assertRaises(ScannerError) as exc:
            recovery.collect({},FastEvent(),'hoshino_battle',ui.observe,Mock(side_effect=ValueError('bad crop')))
        self.assertEqual('form_read_failed',exc.exception.code)
        self.assertTrue(exc.exception.details['form_restored']); self.assertEqual(1,ui.form)
    def test_cancel_uses_fresh_cleanup_token_and_restores(self):
        ui=FormUI(); recovery=StudentFormRecovery(ui,self.regions); cancel=FastEvent()
        with self.assertRaises(ScannerError) as exc:
            recovery.collect({},cancel,'hoshino_battle',ui.observe,lambda *_a:cancel.set())
        self.assertEqual('cancelled',exc.exception.code); self.assertEqual(1,ui.form)
        self.assertTrue(ui.clicks[-1][0]['_scanner_cleanup'])
        self.assertFalse(ui.clicks[-1][0]['_scanner_cancel'].is_set())
    def adapter(self):
        adapter=StudentMatcherAdapter(SimpleNamespace(),RecognitionAssetCatalog(),form_recovery=Mock())
        original=dict(payload=dict(version=1,student_id='hoshino_battle',values=dict(level=90,combat_hp=111),
            provenance=dict(level='fixture',combat_hp='fixture',student_id='student_texture_template')),
            evidence=[dict(field='student_id',status='ok'),dict(field='combat_hp',status='ok')],review_required=False,
            _answer_specimen={'private':'original'})
        self.enterContext(patch.object(adapter,'_scan_current',return_value=[original]))
        return adapter,original
    def test_other_form_has_own_combat_and_no_borrowed_answer_specimen(self):
        adapter,original=self.adapter()
        def collect(target,cancel,ref,observe,read):
            with Image.new('RGB',(1280,720)) as frame:read(frame,StudentIdentity('hoshino_battle#2',.94,.08))
        adapter.form_recovery.collect.side_effect=collect
        with patch.object(adapter.basic_recognizer,'read_combat',side_effect=[
            Observation(999,.9,'ok','other',''),Observation(22,.9,'ok','other',''),
            Observation(None,0,'uncertain','other',''),Observation(33,.9,'ok','other','')]):
            rows=adapter._scan_with_forms({},Event(),lambda *_a:None)
        self.assertEqual(111,original['payload']['values']['combat_hp'])
        self.assertEqual(999,rows[1]['payload']['values']['combat_hp'])
        self.assertNotIn('combat_def',rows[1]['payload']['values'])
        self.assertEqual(90,rows[1]['payload']['values']['level'])
        self.assertNotIn('_answer_specimen',rows[1]); self.assertTrue(rows[1]['review_required'])
    def test_already_seen_base_does_not_switch_forms_again(self):
        adapter,original=self.adapter()
        self.assertEqual([original],adapter._scan_with_forms({'_seen_students':('hoshino_battle',)},Event(),lambda *_a:None))
        adapter.form_recovery.collect.assert_not_called()
    def test_unverified_return_hands_completed_candidate_to_session(self):
        adapter,original=self.adapter()
        adapter.form_recovery.collect.side_effect=ScannerError('form_restore_failed','unverified')
        result=adapter({},Event(),lambda *_a:None)
        self.assertIsInstance(result,ScanBatchResult)
        self.assertEqual('failed',result.outcome);self.assertEqual([original],result.candidates)

    def test_full_navigation_deduplicates_base_not_form(self):
        adapter = object.__new__(StudentMatcherAdapter)
        adapter.capture = SimpleNamespace(click=Mock(), press_key=Mock(return_value=True))
        refs = iter(['hoshino_battle', 'mika', 'hoshino_battle#2'])
        def scan(target, cancel, progress):
            return [dict(payload=dict(student_id=next(refs)), evidence=[])]
        adapter._scan_with_forms = scan
        result = adapter({'student_scan_mode':'full'}, FastEvent(), lambda *_a:None)
        self.assertEqual('completed',result.outcome)
        self.assertTrue(result.coverage_complete)
        self.assertEqual(['hoshino_battle','mika'],[r['payload']['student_id'] for r in result.candidates])


if __name__=='__main__':unittest.main()
