"""Synthetic F2 service/transport/cache tests: no actual installed assets."""
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from threading import Event
import unittest
from unittest.mock import patch

from core.application_protocol_v1 import ApplicationProtocolV1
from core.asset_preparation import AssetPreparationService, OperationGate, PreparationGuardedScanner
from core.asset_preparation_cache import digest, game_identity, validated_cache
from core.jsonl_multiplexer import JsonlMultiplexer
from core.recognition_asset_extract import AssetCache, ATLAS_SPRITES, FONTS, EXTRACTOR_VERSION
from core.recognition_synth import SynthUnavailable
from core.recognition_synth_provider import SynthProvider
from core.repository_store import JsonRepository
from core.scanner_session import ScannerError, ScannerSessionService
from core.stdio_server import serve
import core.recognition_asset_extract as extractor


def request(method, payload=None):
    return {'protocol':1,'type':'request','id':'r','method':method,'payload':payload or {}}


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='ba-f2-synthetic-')
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.game=self.root/'game'
        resources=extractor.resource_dir(self.game)
        (resources/'Catalog/Windows').mkdir(parents=True)
        (resources/'Catalog/Windows/catalog_Windows.bytes').write_bytes(b'CCDB\x01synthetic')
        for section in ('Catalog','Preload','GameData'):
            p=resources/section/'BundleRevision';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('123')
        self.rarity=self.root/'rarity.json';self.rarity.write_text('{}')
        self.gate=OperationGate()
        self.calls=0
        self.events=[]
        self.service=AssetPreparationService(storage_root=self.root/'repository',cache_root=self.root/'cache',
            rarity_path=self.rarity,gate=self.gate,game_finder=lambda:self.game,extractor=self.fake_extract)
        self.service.set_event_sink(self.events.append)
        self.addCleanup(self.service.close)

    def make_cache(self, missing=()):
        game=game_identity(self.game,'auto')
        root=self.service.cache_root/game['catalog_sha256'][:16]
        root.mkdir(parents=True,exist_ok=True)
        manifest={'extractor_version':EXTRACTOR_VERSION,'catalog_sha256':game['catalog_sha256'],
                  'bundle_revision':game['bundle_revision'],'rarity_sha256':digest(self.rarity),
                  'missing':list(missing),'icons':{},'sprites':{},'fonts':{},'reused_files':0}
        (root/'item-rarity.json').write_bytes(self.rarity.read_bytes())
        for section,names in (('icons',['synthetic']),('sprites',[*ATLAS_SPRITES,'Card_Item_Bg_C']),('fonts',FONTS)):
            for name in names:
                path=root/section/(name+'.synthetic');path.parent.mkdir(exist_ok=True);path.write_bytes(b'inert derived fixture')
                manifest[section][name]={'path':path.relative_to(root).as_posix(),'sha256':digest(path)}
        (root/'manifest.json').write_text(json.dumps(manifest),encoding='utf-8')
        return AssetCache(root,manifest)

    def fake_extract(self, game, root, rarity, progress, *, cancelled, force=False):
        self.calls+=1
        progress('icons',0,2);progress('icons',2,2)
        progress('sprites',1,None);progress('fonts',1,1)
        return self.make_cache()

    def test_status_folder_validation_revision_consensus_and_persistence(self):
        status=self.service.status()
        self.assertTrue(status['game_dir']['valid'])
        self.assertEqual(status['cache']['state'],'missing')
        self.assertIsNone(status['metadata']['jp_update_required'])
        self.service.set_game_dir(str(self.game))
        self.assertEqual(self.service.status()['game_dir']['source'],'user')
        self.assertEqual(json.loads(self.service.settings.read_text())['game_dir'],str(self.game.resolve()))
        p=extractor.resource_dir(self.game)/'Preload/BundleRevision';p.write_text('124')
        self.assertEqual(self.service.status()['game_dir']['reason'],'bundle_revision_mismatch')
        with self.assertRaises(ScannerError):self.service.start()
        self.service.set_game_dir(None)
        self.assertEqual(self.service.status()['game_dir']['source'],'auto')

    def test_invalid_folder_is_not_persisted(self):
        for path,reason in ((self.root/'absent','game_dir_not_found'),(self.root,'not_blue_archive')):
            with self.subTest(reason=reason),self.assertRaises(ScannerError) as raised:
                self.service.set_game_dir(str(path))
            self.assertEqual(raised.exception.details['reason'],reason)
        self.assertFalse(self.service.settings.exists())

    def test_start_progress_terminal_counts_and_shared_cache_no_reextract(self):
        first=self.service.start();self.service.wait()
        job=self.service.snapshot(**first)['job']
        self.assertEqual(job['state'],'succeeded')
        self.assertEqual(job['created'],1+len(ATLAS_SPRITES)+1+len(FONTS))
        self.assertEqual(job['created'],job['available'])
        self.assertEqual(self.service.status()['cache']['state'],'ready')
        self.assertEqual([e['payload']['sequence'] for e in self.events],list(range(1,len(self.events)+1)))
        self.assertEqual(self.events[-1]['payload']['event_kind'],'terminal')
        self.assertIsNone(next(e for e in self.events if e['payload']['stage']=='sprites')['payload']['total'])
        self.assertEqual(self.service.prepared_assets().root,self.make_cache().root)
        self.service.start();self.service.wait()
        self.assertEqual(self.calls,1)
        self.assertEqual(self.service.status()['job']['created'],0)
        self.assertEqual(self.service.status()['last_result']['sequence'],self.service.status()['job']['sequence'])

    def test_cancel_keeps_gate_until_worker_returns_and_preserves_old_cache(self):
        old=self.make_cache()
        (old.root/'manifest.json').write_text('{}')
        sentinel=(old.root/'icons/synthetic.synthetic').read_bytes()
        entered,release=Event(),Event()
        def blocked(*args,**kwargs):
            entered.set();release.wait(5)
            raise extractor.AssetExtractFailed('cancelled')
        self.service.extractor=blocked
        started=self.service.start();self.assertTrue(entered.wait(2))
        self.assertTrue(self.service.cancel(**started)['cancel_requested'])
        self.assertEqual(self.gate.owner(),'prepare')
        with self.assertRaises(ScannerError) as raised:self.service.start()
        self.assertEqual(raised.exception.code,'asset_prepare_busy')
        with self.assertRaises(ScannerError):self.service.set_game_dir(None)
        release.set();self.service.wait()
        self.assertEqual(self.service.snapshot(**started)['job']['state'],'cancelled')
        self.assertIsNone(self.gate.owner())
        self.assertEqual((old.root/'icons/synthetic.synthetic').read_bytes(),sentinel)

    def test_failed_partial_stale_and_corrupt_cache_states(self):
        cache=self.make_cache(missing=['optional-icon'])
        self.assertEqual(self.service.status()['cache']['state'],'partial')
        (cache.root/'icons/synthetic.synthetic').write_bytes(b'corrupt')
        self.assertEqual(self.service.status()['cache']['state'],'invalid')
        with self.assertRaises(SynthUnavailable):self.service.prepared_assets()
        self.make_cache()
        for section in ('Catalog','Preload','GameData'):
            (extractor.resource_dir(self.game)/section/'BundleRevision').write_text('124')
        self.assertEqual(self.service.status()['cache']['state'],'stale')
        self.service.extractor=lambda *args,**kwargs:(_ for _ in ()).throw(ValueError('sensitive local exception'))
        started=self.service.start();self.service.wait()
        self.assertEqual(self.service.snapshot(**started)['job']['reason_codes'],['asset_extract_failed'])
        self.assertNotIn('sensitive',json.dumps(self.events))

    def test_cache_traversal_and_changed_rarity_rejected(self):
        cache=self.make_cache()
        manifest=cache.manifest
        manifest['icons']['synthetic']['path']='../escape'
        (cache.root/'manifest.json').write_text(json.dumps(manifest))
        self.assertIsNone(validated_cache(cache.root,manifest['catalog_sha256'],self.rarity,'123'))
        self.make_cache();self.rarity.write_text('{"changed":true}')
        self.assertEqual(self.service.status()['cache']['state'],'stale')

    def test_scan_and_prepare_mutually_exclude_without_changing_scan_wire(self):
        block,release=Event(),Event()
        def matcher(*args):block.set();release.wait(5);return []
        raw=ScannerSessionService(target_provider=lambda:[{'target_id':'w1'}],student_matcher=matcher,
            inventory_matcher=matcher,repository=JsonRepository(self.root/'scanrepo'),asset_status=lambda:{'ready':True})
        guarded=PreparationGuardedScanner(raw,self.gate);self.addCleanup(guarded.close)
        scan=guarded.start('student','w1');self.assertTrue(block.wait(2))
        self.assertEqual(set(scan),{'session_id','generation','scan_kind','student_scan_mode'})
        with self.assertRaises(ScannerError) as raised:self.service.start()
        self.assertEqual(raised.exception.code,'scanner_busy')
        release.set();raw.wait(scan['session_id'])
        self.gate.acquire('prepare','fake')
        try:
            with self.assertRaises(ScannerError) as raised:guarded.start('student','w1')
            self.assertEqual(raised.exception.code,'asset_prepare_busy')
        finally:self.gate.release('fake')

    def test_start_response_before_fast_prepare_events_and_strict_payloads(self):
        protocol=ApplicationProtocolV1(storage_root=self.root/'repository',preparation_service=self.service)
        bad=protocol.handle(request('assets.prepare.start',{'extra':True}))
        self.assertEqual(bad['payload']['error']['code'],'invalid_payload')
        bad=protocol.handle(request('assets.prepare.cancel',{'job_id':'x','generation':True}))
        self.assertEqual(bad['payload']['error']['code'],'invalid_payload')
        output=io.StringIO()
        serve(io.StringIO(json.dumps(request('assets.prepare.start'))+'\n'),output,io.StringIO(),protocol=protocol)
        messages=[json.loads(s) for s in output.getvalue().splitlines()]
        self.assertEqual(messages[0]['method'],'assets.prepare.start')
        self.assertEqual(messages[0]['type'],'response')
        self.assertEqual(messages[-1]['payload']['event_kind'],'terminal')

    def test_synth_loader_never_extracts_or_latches_unprepared_state(self):
        cache=self.make_cache()
        loader=[None]
        def load():
            if loader[0] is None:raise SynthUnavailable('not prepared')
            return loader[0]
        provider=SynthProvider(self.root/'cache',self.root/'synth',self.rarity,assets_loader=load)
        with patch('core.recognition_synth_provider.extract') as hidden,patch('core.recognition_synth_provider.SynthCache') as synthetic:
            with self.assertRaises(SynthUnavailable):provider('tech_notes',(1280,720))
            loader[0]=cache
            provider('tech_notes',(1280,720));provider('tech_notes',(1280,720))
            hidden.assert_not_called();self.assertEqual(synthetic.return_value.templates.call_count,1)

    def test_cache_publish_failure_rolls_back_old_good_tree(self):
        target=self.root/'target';target.mkdir();(target/'old').write_text('old')
        staging=self.root/'staging';staging.mkdir();(staging/'new').write_text('new')
        original=extractor.os.replace
        def fail(src,dst):
            if Path(src)==staging:raise OSError('synthetic publish failure')
            return original(src,dst)
        with patch.object(extractor.os,'replace',side_effect=fail),self.assertRaises(OSError):
            extractor._publish_cache(staging,target)
        self.assertEqual((target/'old').read_text(),'old')
        self.assertTrue((staging/'new').exists())

    def test_partial_retry_rebuilds_and_unknown_saved_result_is_hidden(self):
        self.make_cache(missing=['optional'])
        started=self.service.start();self.service.wait()
        self.assertEqual(self.calls,1)
        self.assertEqual(self.service.snapshot(**started)['job']['state'],'succeeded')
        self.service.last_path.write_text('{"private":"must not be exposed"}')
        self.assertIsNone(self.service.status()['last_result'])

    def test_synthetic_jsonl_subprocess_status_and_start_no_native_client(self):
        backend=Path(__file__).resolve().parents[1]
        script='''import sys
from pathlib import Path
from core.application_protocol_v1 import ApplicationProtocolV1
from core.asset_preparation import AssetPreparationService,OperationGate
from core.stdio_server import serve
root=Path(sys.argv[1])
service=AssetPreparationService(storage_root=root/'process-repo',cache_root=root/'cache',
 rarity_path=root/'rarity.json',gate=OperationGate(),game_finder=lambda:root/'absent')
serve(protocol=ApplicationProtocolV1(storage_root=root/'process-repo',preparation_service=service))
'''
        messages=[request('assets.prepare.status'),request('assets.prepare.start')]
        p=subprocess.run([sys.executable,'-c',script,str(self.root)],cwd=backend,
                         input='\n'.join(json.dumps(m) for m in messages)+'\n',
                         text=True,encoding='utf-8',capture_output=True,timeout=10)
        self.assertEqual(p.returncode,0,p.stderr)
        output=[json.loads(s) for s in p.stdout.splitlines()]
        self.assertEqual(output[0]['payload']['game_dir']['valid'],False)
        self.assertEqual(output[1]['payload']['error']['code'],'invalid_game_dir')

    def test_schema_validates_actual_status_events_and_strict_negative_payloads(self):
        from jsonschema import Draft202012Validator
        contracts=Path(__file__).resolve().parents[2]/'contracts'
        schema=json.loads((contracts/'asset-preparation-v1.schema.json').read_text(encoding='utf-8'))
        Draft202012Validator.check_schema(schema)
        validator=Draft202012Validator(schema)
        protocol=ApplicationProtocolV1(storage_root=self.root/'repository',preparation_service=self.service)
        for method in ('assets.prepare.status','assets.prepare.start'):
            message=request(method);validator.validate(message)
            response=protocol.handle(message);validator.validate(response)
        self.service.wait()
        for event in self.events:validator.validate(event)
        validator.validate(protocol.handle(request('assets.prepare.status')))
        for message in (request('assets.prepare.start',{'extra':True}),
                        request('assets.prepare.cancel',{'job_id':'x','generation':True}),
                        request('assets.prepare.game_dir.set',{'path':5})):
            self.assertFalse(validator.is_valid(message))
        bad=json.loads(json.dumps(self.events[-1]));bad['payload']['created']=-1
        self.assertFalse(validator.is_valid(bad))

    def test_committed_synthetic_fixture_roundtrip(self):
        from jsonschema import Draft202012Validator
        contracts=Path(__file__).resolve().parents[2]/'contracts'
        validator=Draft202012Validator(json.loads((contracts/'asset-preparation-v1.schema.json').read_text(encoding='utf-8')))
        fixture=json.loads((contracts/'fixtures/asset_preparation_v1.json').read_text(encoding='utf-8'))
        for case in fixture['cases']:
            with self.subTest(case=case['id']):self.assertEqual(validator.is_valid(case['message']),case['valid'])

    def test_unavailable_runtime_error_satisfies_preparation_contract(self):
        from jsonschema import Draft202012Validator
        contracts = Path(__file__).resolve().parents[2] / 'contracts'
        validator = Draft202012Validator(json.loads(
            (contracts / 'asset-preparation-v1.schema.json').read_text(encoding='utf-8')))
        protocol = ApplicationProtocolV1(storage_root=self.root / 'no-preparation')
        response = protocol.handle(request('assets.prepare.status'))
        self.assertEqual(response['payload']['error']['details'], {})
        validator.validate(response)

    def test_terminal_snapshot_is_published_after_persistence_with_final_cursor(self):
        import core.asset_preparation as preparation
        original_write = preparation._atomic_json
        writing, releasing = [], []
        original_release = self.gate.release
        def write(path, value):
            if path == self.service.last_path:
                writing.append(self.service.snapshot(value['job_id'], value['generation'])['job'])
            original_write(path, value)
        def release(token):
            if self.service._job:
                releasing.append(self.service.snapshot(token, self.service._generation)['job'])
            original_release(token)
        with patch.object(preparation, '_atomic_json', side_effect=write), \
                patch.object(self.gate, 'release', side_effect=release):
            cursor = self.service.start()
            self.service.wait()
        self.assertEqual(writing[0]['state'], 'running')
        final = self.service.snapshot(**cursor)['job']
        self.assertEqual(releasing[-1], final)
        event = dict(self.events[-1]['payload'])
        event.pop('event_kind')
        self.assertEqual(event, final)
        self.assertEqual(self.service._last_result(), final)

    def test_terminal_persistence_failure_is_in_snapshot_and_event_before_gate_release(self):
        import core.asset_preparation as preparation
        original_write = preparation._atomic_json
        released = []
        original_release = self.gate.release
        def write(path, value):
            if path == self.service.last_path:
                raise OSError('synthetic disk failure')
            original_write(path, value)
        def release(token):
            released.append(self.service.snapshot(token, self.service._generation)['job'])
            original_release(token)
        with patch.object(preparation, '_atomic_json', side_effect=write), \
                patch.object(self.gate, 'release', side_effect=release):
            cursor = self.service.start()
            self.service.wait()
        final = self.service.snapshot(**cursor)['job']
        self.assertIn('result_not_saved', final['reason_codes'])
        self.assertEqual(released[-1], final)
        self.assertEqual(self.events[-1]['payload']['sequence'], final['sequence'])
        self.assertEqual(self.events[-1]['payload']['reason_codes'], final['reason_codes'])

    def test_discovery_opt_out_does_not_probe_steam_but_keeps_explicit_folders(self):
        with patch.dict(os.environ, {'BA_PLANNER_DISABLE_GAME_DISCOVERY': '1'}), \
                patch.object(extractor, '_steam_dir') as probe:
            self.assertIsNone(extractor.find_game_dir())
            probe.assert_not_called()
            service = AssetPreparationService(storage_root=self.root/'isolated-process-repo',
                cache_root=self.root/'isolated-cache', rarity_path=self.rarity, gate=OperationGate())
            try:
                self.assertFalse(service.status()['game_dir']['valid'])
                self.assertTrue(service.set_game_dir(str(self.game))['game_dir']['valid'])
                self.assertFalse(service.set_game_dir(None)['game_dir']['valid'])
            finally:
                service.close()

    def test_extractor_cancellation_cleans_staging_without_replacing_old_target(self):
        # Only the control flow is exercised; Unity data parsing is replaced with synthetic writers.
        cache=self.make_cache()
        (cache.root/'manifest.json').write_text('{}')
        old=(cache.root/'icons/synthetic.synthetic').read_bytes()
        cancelled=Event()
        def icons(*args):
            cancelled.set()
            extractor._check_cancel(cancelled.is_set)
        with patch.object(extractor,'AddressablesCatalog'),patch.object(extractor,'_extract_icons',side_effect=icons):
            with self.assertRaises(extractor.AssetExtractFailed):
                extractor.extract(self.game,self.service.cache_root,self.rarity,cancelled=cancelled.is_set)
        self.assertEqual((cache.root/'icons/synthetic.synthetic').read_bytes(),old)
        self.assertFalse(any(p.name.startswith('.staging-') for p in self.service.cache_root.iterdir()))


if __name__=='__main__':unittest.main()
