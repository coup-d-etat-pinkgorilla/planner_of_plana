from copy import deepcopy
import json
import os
from pathlib import Path
from queue import Queue
import subprocess
import sys
import tempfile
from threading import Thread
import unittest

from tests.inventory_e2e_backend import fixture_root, build_fixture_application, InventoryFixtureProtocol

BACKEND = Path(__file__).resolve().parents[1]
FIXTURE = json.loads((BACKEND/'tests/fixtures/inventory_process_fb10b_v1.json').read_text(encoding='utf-8'))
A,B,C,D = [row['key'] for row in FIXTURE['candidate_entries']]


class ProcessDriver:
    def __init__(self, root):
        self.process = subprocess.Popen([sys.executable,'-m','tests.inventory_e2e_backend'], cwd=BACKEND,
            env={**os.environ,'BA_PLANNER_STORAGE_ROOT':str(root)}, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8')
        self.queue=Queue();self.events=[];self.number=0
        def read():
            for line in self.process.stdout:self.queue.put(json.loads(line))
            self.queue.put(None)
        self.reader=Thread(target=read,daemon=True);self.reader.start()

    def receive(self):
        result=self.queue.get(timeout=15)
        if result is None:raise AssertionError(self.process.stderr.read())
        return result

    def rpc(self, method, payload):
        self.number+=1;identifier=str(self.number)
        self.process.stdin.write(json.dumps({'protocol':1,'id':identifier,'type':'request','method':method,'payload':payload})+'\n');self.process.stdin.flush()
        while True:
            message=self.receive()
            if message.get('type')=='event':self.events.append(message);continue
            assert message['id']==identifier and message['method']==method,message
            return message['payload']

    def terminal(self, session):
        def done(event):return event['payload'].get('session_id')==session['session_id'] and event['payload'].get('event_kind')=='terminal'
        if any(done(e) for e in self.events):return
        while True:
            event=self.receive();assert event['type']=='event',event;self.events.append(event)
            if done(event):return

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:self.process.kill();self.process.wait();raise
        error=self.process.stderr.read()
        self.process.stdout.close();self.process.stderr.close();self.reader.join(timeout=1)
        assert self.process.returncode==0,error


class InventoryProcessFixtureTests(unittest.TestCase):
    def temporary(self):
        tmp=tempfile.TemporaryDirectory(prefix='ba_planner_inventory_e2e_');self.addCleanup(tmp.cleanup)
        return Path(tmp.name)

    def driver(self, root):
        driver=ProcessDriver(root);self.addCleanup(lambda:driver.close() if driver.process.stdout and not driver.process.stdout.closed else None)
        return driver

    def test_process_partial_review_restart_scope_replay_and_other_profile_preserved(self):
        root=self.temporary();driver=self.driver(root)
        pids=[]
        for key in ('main','other'):
            pid=driver.rpc('repository.profile.create',{'display_name':key,'idempotency_key':key})['profile']['profile_id'];pids.append(pid)
            self.assertEqual(driver.rpc('repository.inventory.update',{'profile_id':pid,'inventory':{'version':1,'entries':FIXTURE['initial_entries']},'expected_revision':0,'idempotency_key':'seed'}),{'revision':1})
        pid,other=pids;other_before=driver.rpc('repository.state.get',{'profile_id':other})
        session=driver.rpc('scanner.session.start',{'scan_kind':'inventory','target_id':'fb10b-e2e-target','profile_id':pid,'inventory_scan_profile':'tech_notes'})
        driver.terminal(session)
        snapshot=driver.rpc('scanner.session.snapshot',{'session_id':session['session_id'],'generation':session['generation']})
        candidate=snapshot['candidates'][0]
        reviewed=driver.rpc('scanner.candidate.review',{'session_id':session['session_id'],'generation':session['generation'],
            'candidate_id':candidate['candidate_id'],'expected_candidate_revision':candidate['revision'],
            'candidate_payload':{'version':1,'catalog_revision':candidate['payload']['catalog_revision'],'entries':[FIXTURE['candidate_entries'][0]]},
            'approve':True,'reason':'shared_inventory_fixture_partial'})['candidate']
        response=driver.rpc('scanner.candidate.commit',{'session_id':session['session_id'],'generation':session['generation'],
            'candidate_id':reviewed['candidate_id'],'candidate_revision':reviewed['revision'],'profile_id':pid,
            'expected_repository_revision':1,'idempotency_key':'scan'})
        self.assertEqual(response['revision'],2);driver.close()
        restarted=self.driver(root)
        self.assertEqual(restarted.rpc('repository.inventory.review.get',{'profile_id':pid})['needs_review_keys'],[B,C,D])
        state=restarted.rpc('repository.state.get',{'profile_id':pid});inventory=state['inventory']
        self.assertEqual({e['key']:e['quantity'] for e in inventory['entries']},{A:'7',B:'9',C:'7'})
        request={'profile_id':pid,'inventory':inventory,'expected_revision':2,'idempotency_key':'ack','applied_resource_keys':[B]}
        self.assertEqual(restarted.rpc('repository.inventory.update',request),{'revision':3})
        self.assertEqual(restarted.rpc('repository.inventory.review.get',{'profile_id':pid})['needs_review_keys'],[C,D])
        changed={**request,'applied_resource_keys':[C]}
        self.assertEqual(restarted.rpc('repository.inventory.update',changed)['error']['code'],'idempotency_conflict')
        absent={**request,'expected_revision':3,'idempotency_key':'absent','applied_resource_keys':[D]}
        self.assertEqual(restarted.rpc('repository.inventory.update',absent)['error']['details']['reason'],'scan_scope_mismatch')
        self.assertEqual(restarted.rpc('repository.state.get',{'profile_id':other}),other_before)
        restarted.close();third=self.driver(root)
        self.assertEqual(third.rpc('repository.inventory.update',request),{'revision':3})
        self.assertEqual(third.rpc('repository.inventory.review.get',{'profile_id':pid})['needs_review_keys'],[C,D])

    def test_completed_receipt_after_delete_is_historical_success_without_profile_restore(self):
        from core.repository_store import RepositoryError
        root=fixture_root(str(self.temporary()));app=build_fixture_application(root);self.addCleanup(app.close)
        repo=app.repository.repository
        pid=repo.create_profile('Receipt','receipt-profile')['profile']['profile_id']
        service=app.scanner_service
        session=service.start('inventory','fb10b-e2e-target',pid,inventory_scan_profile='tech_notes');service.wait(session['session_id'])
        candidate=service.snapshot(session['session_id'],session['generation'])['candidates'][0]
        request={'session_id':session['session_id'],'generation':session['generation'],'candidate_id':candidate['candidate_id'],
            'candidate_revision':candidate['revision'],'profile_id':pid,'expected_repository_revision':0,'idempotency_key':'scan'}
        success=service.commit(**request)
        receipt=service._current_commits[(session['session_id'],'scan')]
        self.assertIsNone(receipt.request)
        self.assertEqual(set(json.loads(receipt.response_json)),{'candidate_id','candidate_revision','profile_id','revision'})
        repo.delete_profile(pid,success['revision'],'delete')
        before={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()}
        self.assertEqual(service.commit(**request),success)
        self.assertEqual({p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()},before)
        with self.assertRaises(RepositoryError) as caught:service.commit(**{**request,'idempotency_key':'new'})
        self.assertEqual(caught.exception.code,'profile_not_found')
        self.assertFalse(repo._profile_path(pid).exists())

    def test_fixture_rejects_default_outside_and_unmarked_nonempty_roots(self):
        with self.assertRaises(ValueError):fixture_root(None)
        with self.assertRaises(ValueError):fixture_root(str(BACKEND))
        root=self.temporary();(root/'keep.txt').write_bytes(b'keep')
        with self.assertRaises(ValueError):fixture_root(str(root))
        self.assertEqual(list(root.iterdir()),[root/'keep.txt'])
        self.assertEqual((root/'keep.txt').read_bytes(),b'keep')
        owned=self.temporary();fixture_root(str(owned))
        marker=owned/'.inventory-e2e-fixture.v1.json';data=json.loads(marker.read_text(encoding='utf-8'))
        data['version']=True;marker.write_text(json.dumps(data),encoding='utf-8')
        before=marker.read_bytes()
        with self.assertRaises(ValueError):build_fixture_application(owned)
        self.assertEqual(marker.read_bytes(),before)

    def test_test_entry_blocks_tool_migration_and_planning_methods(self):
        root=fixture_root(str(self.temporary()));app=build_fixture_application(root)
        handler=InventoryFixtureProtocol(app);self.addCleanup(handler.close)
        for method in ('developer_tools.student_metadata.apply','repository.migration.preview','planning.student.get'):
            result=handler.handle({'protocol':1,'id':'blocked','type':'request','method':method,'payload':{}})
            self.assertEqual(result['payload']['error']['code'],'unknown_method')
        self.assertEqual({p.name for p in root.iterdir()},{'.inventory-e2e-fixture.v1.json'})


if __name__=='__main__':unittest.main()
