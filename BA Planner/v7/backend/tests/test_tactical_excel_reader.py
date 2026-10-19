from dataclasses import replace
from datetime import datetime
import hashlib
import os
from pathlib import Path
import unittest
import tempfile
import zipfile

import openpyxl
from core.tactical_excel_reader import ReaderLimits, SourceReadError, read_source

ART = Path(__file__).resolve().parent
CASES = None

class BoundedReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        global CASES
        cls.temporary = tempfile.TemporaryDirectory(prefix='ba_fb7_reader_')
        CASES = Path(cls.temporary.name)
        cls.xlsx = CASES / 'source.xlsx'
        book = openpyxl.Workbook()
        sheet = book.active
        sheet.title = 'Combat'
        sheet.append(['Date', 'Opponent', 'Student', 'Attempts'])
        sheet.append([datetime(2026, 10, 10, 12, 30), 'Rival A', '무장리오', '=SUM(1,1)'])
        sheet.append([None, 'Rival B', None, 2])
        book.create_sheet('Other').append(['other sheet'])
        book.save(cls.xlsx)
        book.close()
        cls.csv = CASES / 'source.csv'
        cls.csv.write_bytes('날짜,상대,메모\n2026-10-10,A,"쉼표,\"\"인용\"\"\n다음줄"\n'.encode('utf-8-sig'))
        cls.pins = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (cls.xlsx, cls.csv)}

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def reason(self, expected, path, **kwargs):
        with self.assertRaises(SourceReadError) as raised:
            read_source(path, **kwargs)
        self.assertEqual(expected, raised.exception.reason)

    def mutated_zip(self, name, replacements=None, additions=None):
        target = CASES / name
        with zipfile.ZipFile(self.xlsx) as original, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as changed:
            for entry in original.infolist():
                changed.writestr(entry.filename, (replacements or {}).get(entry.filename, original.read(entry.filename)))
            for path, data in (additions or {}).items():
                changed.writestr(path, data)
        return target

    def test_xlsx_preserves_raw_date_unknown_blank_formula_and_fingerprint(self):
        doc = read_source(self.xlsx)
        self.assertEqual(('Combat', 'Other'), doc.sheet_names)
        self.assertEqual('Combat', doc.selected_sheet)
        self.assertEqual(self.pins[self.xlsx.name], doc.fingerprint)
        self.assertEqual(datetime(2026, 10, 10, 12, 30), doc.rows[1][0].value)
        self.assertEqual('무장리오', doc.rows[1][2].value)
        self.assertEqual('=SUM(1,1)', doc.rows[1][3].formula)
        self.assertIsNone(doc.rows[1][3].cached_value)
        self.assertIsNone(doc.rows[2][2].value)
        self.assertEqual(2, doc.rows[2][3].value)

    def test_explicit_sheet_and_missing_sheet(self):
        self.assertEqual('other sheet', read_source(self.xlsx, sheet_name='Other').rows[0][0].value)
        self.reason('sheet_not_found', self.xlsx, sheet_name='missing')

    def test_utf8_bom_quoting_and_explicit_tab(self):
        doc = read_source(self.csv)
        self.assertEqual('날짜', doc.rows[0][0].value)
        self.assertEqual('쉼표,"인용"\n다음줄', doc.rows[1][2].value)
        tab = CASES / 'tab.csv'
        tab.write_text('date\topponent\n2026-10-10\tA\n', encoding='utf-8')
        self.assertEqual('A', read_source(tab, delimiter='\t').rows[1][1].value)
        self.reason('delimiter_unsupported', self.csv, delimiter=';')

    def test_source_change_creates_new_fingerprint_and_source_reads_never_write(self):
        changed = CASES / 'changed.csv'
        changed.write_bytes(self.csv.read_bytes())
        before = read_source(changed).fingerprint
        changed.write_bytes(changed.read_bytes() + b'2026-10-11,B,note\n')
        self.assertNotEqual(before, read_source(changed).fingerprint)
        for path in (self.xlsx, self.csv):
            self.assertEqual(self.pins[path.name], hashlib.sha256(path.read_bytes()).hexdigest())

    def test_format_encoding_and_malformed_sources(self):
        for suffix in ('.xls', '.xlsm'):
            self.reason('format_unsupported', CASES / ('unsupported' + suffix))
        invalid_csv = CASES / 'invalid-encoding.csv'
        invalid_csv.write_bytes(b'\xff\xfe\x00')
        self.reason('csv_encoding_unsupported', invalid_csv)
        invalid_zip = CASES / 'not-a-zip.xlsx'
        invalid_zip.write_bytes(b'not an OOXML workbook')
        self.reason('invalid_workbook', invalid_zip)

    def test_file_row_column_sheet_and_cell_limits(self):
        limits = ReaderLimits()
        self.reason('file_limit_exceeded', self.xlsx, limits=replace(limits, file_bytes=10))
        self.reason('row_limit_exceeded', self.xlsx, limits=replace(limits, rows=2))
        self.reason('column_limit_exceeded', self.xlsx, limits=replace(limits, columns=3))
        self.reason('sheet_limit_exceeded', self.xlsx, limits=replace(limits, sheets=1))
        self.reason('cell_limit_exceeded', self.csv, limits=replace(limits, cell_utf8_bytes=3))

    def test_zip_member_size_path_and_macro_limits(self):
        limits = ReaderLimits()
        self.reason('zip_member_limit_exceeded', self.xlsx, limits=replace(limits, zip_members=1))
        self.reason('zip_size_limit_exceeded', self.xlsx, limits=replace(limits, zip_uncompressed_bytes=10))
        self.reason('invalid_zip_path', self.mutated_zip('traversal.xlsx', additions={'../outside.txt': b'not extracted'}))
        self.reason('macro_workbook_unsupported', self.mutated_zip('macro.xlsx', additions={'xl/vbaProject.bin': b'fake macro'}))
        self.assertFalse((ART / 'outside.txt').exists())

    def test_unsafe_xml_and_malformed_xml_fail_closed(self):
        entity = b'<!DOCTYPE worksheet [<!ENTITY sample "untrusted">]><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>&sample;</t></is></c></row></sheetData></worksheet>'
        self.reason('unsafe_xml', self.mutated_zip('entity.xlsx', replacements={'xl/worksheets/sheet1.xml': entity}))
        self.reason('invalid_workbook', self.mutated_zip('malformed.xlsx', replacements={'xl/worksheets/sheet1.xml': b'<worksheet>'}))

if __name__ == '__main__':
    unittest.main(verbosity=2)
