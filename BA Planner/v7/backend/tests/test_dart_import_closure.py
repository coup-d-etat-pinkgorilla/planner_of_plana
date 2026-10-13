from pathlib import Path
import tempfile
import unittest

from tests.dart_import_closure import dart_directive_uris, dart_local_source_closure


class DartImportClosureTests(unittest.TestCase):
    def test_real_inventory_comment_cannot_supply_quoted_ui_label(self):
        source = '''// all sources: scan / manual / import together
// "previous scan" is a UI label, not a dependency.
import 'dart:math' as math;
const title = "import 'missing.dart';";
'''
        self.assertEqual(dart_directive_uris(source), ('dart:math',))

    def test_nested_comments_doc_comments_and_uri_slashes(self):
        source = '''/* import 'fake.dart'; /* export 'other.dart'; */ */
/// import 'third.dart';
import 'package:app/path.dart'; // export 'fake.dart';
export 'https://example.invalid/path.dart';
class Thing {}
'''
        self.assertEqual(dart_directive_uris(source), ('package:app/path.dart', 'https://example.invalid/path.dart'))

    def test_library_annotation_multiline_conditional_values_are_not_uris(self):
        source = '''@Example('import fake;')
library;
import 'base.dart'
  if (dart.library.io == 'true') 'io.dart'
  if (dart.library.js_interop) 'web.dart' deferred as selected;
export 'api.dart' show API;
void main() {}
'''
        self.assertEqual(dart_directive_uris(source), ('base.dart', 'io.dart', 'web.dart', 'api.dart'))

    def test_raw_and_unicode_escaped_uris_are_recognized(self):
        source = r'''import r'package:app/raw.dart';
export '\u0064eveloper_tools/tool.dart';
export '\u{0061}pi.dart';
'''
        self.assertEqual(dart_directive_uris(source), ('package:app/raw.dart', 'developer_tools/tool.dart', 'api.dart'))

    def test_body_multiline_strings_cannot_add_edges(self):
        source = "import 'real.dart';\nconst data = r'''\nimport 'fake.dart';\nexport 'other.dart';\n''';"
        self.assertEqual(dart_directive_uris(source), ('real.dart',))

    def test_annotation_string_parentheses_do_not_end_annotation(self):
        source = "@Example(')', '(') library; import 'real.dart';"
        self.assertEqual(dart_directive_uris(source), ('real.dart',))

    def test_semicolon_in_literal_uri_is_not_statement_terminator(self):
        self.assertEqual(dart_directive_uris("import ';';"), (';',))

    def test_parts_are_followed_and_part_of_does_not_add_parent_edge(self):
        self.assertEqual(dart_directive_uris("library thing; part 'piece.dart'; class Thing {}"), ('piece.dart',))
        self.assertEqual(dart_directive_uris("part of 'parent.dart'; class Piece {}"), ())

    def test_closure_keeps_indirect_and_conditional_developer_edges(self):
        with tempfile.TemporaryDirectory(prefix='ba_planner_dart_closure_') as directory:
            lib = Path(directory)
            (lib / 'developer_tools').mkdir()
            (lib / 'main.dart').write_text("import 'base.dart' if (dart.library.io == 'true') 'developer_tools/entry.dart';", encoding='utf-8')
            (lib / 'base.dart').write_text("export 'package:app/api.dart';", encoding='utf-8')
            (lib / 'api.dart').write_text('const api = 1;', encoding='utf-8')
            (lib / 'developer_tools/entry.dart').write_text("export '../developer_tools_main.dart';", encoding='utf-8')
            (lib / 'developer_tools_main.dart').write_text('void main() {}', encoding='utf-8')
            closure = dart_local_source_closure(lib, 'app')
            self.assertEqual(len(closure), 5)
            self.assertIn((lib / 'developer_tools/entry.dart').resolve(), closure)
            self.assertIn((lib / 'developer_tools_main.dart').resolve(), closure)

    def test_missing_and_escaping_local_sources_remain_errors(self):
        with tempfile.TemporaryDirectory(prefix='ba_planner_dart_closure_') as directory:
            lib = Path(directory)
            for uri in ('missing.dart', '../outside.dart'):
                with self.subTest(uri=uri):
                    (lib / 'main.dart').write_text(f"import '{uri}';", encoding='utf-8')
                    with self.assertRaises(ValueError):
                        dart_local_source_closure(lib, 'app')

    def test_malformed_comments_and_interpolated_uris_fail_closed(self):
        for source in ("/* broken", "import 'oops.dart'", "import '${dynamic}.dart';"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                dart_directive_uris(source)


if __name__ == '__main__':
    unittest.main()
