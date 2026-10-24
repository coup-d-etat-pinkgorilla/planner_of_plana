from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
from unittest.mock import patch

from core.client_character_refs import character_id, load_refs
from core import student_meta
from core.student_stats_catalog import student_stat_record
from tools import developer_tools


class RetiredProviderTests(unittest.TestCase):
    def test_retired_methods_are_unknown_and_never_mutate_metadata(self):
        baseline = developer_tools.CANONICAL_METADATA_PATH.read_bytes()
        methods = ['metadata.schaledb.preview', 'metadata.schaledb.apply',
            'metadata.schaledb.single.preview', 'metadata.schaledb.single.apply',
            'metadata.merge_paths.list', 'metadata.merge_paths.save', 'metadata.merge_paths.delete']
        for method in methods:
            with self.subTest(method=method), self.assertRaisesRegex(ValueError, 'unknown method'):
                developer_tools.dispatch({'version': 1, 'method': method, 'params': {}})
        self.assertEqual(developer_tools.CANONICAL_METADATA_PATH.read_bytes(), baseline)

    def test_http_provider_adapter_and_slug_rules_are_not_runtime_modules(self):
        for module in ('schaledb_provider', 'schaledb_metadata_adapter', 'schale_merge_paths', 'schale_skill_material_map'):
            with self.subTest(module=module):
                self.assertIsNone(importlib.util.find_spec('core.' + module))

    def test_all_student_forms_resolve_from_explicit_character_references(self):
        mapping = load_refs()
        count = 0
        for sid in student_meta.all_ids():
            self.assertEqual(len(mapping[sid]), len(student_meta.form_indexes(sid)))
            for index in student_meta.form_indexes(sid):
                self.assertEqual(student_stat_record(sid, index).schaledb_id, character_id(sid, index))
                count += 1
        self.assertEqual(count, 267)
        self.assertNotEqual(character_id('hoshino_battle', 1), character_id('hoshino_battle', 2))

    def test_ref_schema_rejects_bool_ids_and_form_bounds(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'refs.json'
            for version, identities in ((True, {'local':[1]}), (1, {'local':[True]}), (1, {'local':[]})):
                path.write_text(json.dumps({'schemaVersion':version,'students':identities,'provenance':{}}))
                load_refs.cache_clear()
                with self.assertRaises(ValueError): load_refs(path)
        for index in (True, 0, 3):
            with self.subTest(index=index), self.assertRaises(ValueError):
                character_id('hoshino_battle', index)


if __name__ == '__main__':
    unittest.main()
