"""Reviewed local student/form to JP character identity; no provider aliases."""
from functools import lru_cache
import json
from pathlib import Path
import re

DEFAULT_PATH = Path(__file__).resolve().parents[1] / 'data/metadata/v1/client-character-refs.json'


@lru_cache(maxsize=4)
def load_refs(path=DEFAULT_PATH):
    value = json.loads(Path(path).read_text(encoding='utf-8'))
    if (not isinstance(value, dict) or set(value) != {'schemaVersion', 'students', 'provenance'}
            or type(value['schemaVersion']) is not int or value['schemaVersion'] != 1
            or not isinstance(value['students'], dict) or not isinstance(value['provenance'], dict)):
        raise ValueError('invalid client character references')
    result = {}
    for sid, forms in value['students'].items():
        if (not isinstance(sid, str) or not re.fullmatch('[a-z0-9_]+', sid)
                or not isinstance(forms, list) or not forms
                or any(type(number) is not int or number < 1 for number in forms)):
            raise ValueError('invalid client character/form identity')
        result[sid] = tuple(forms)
    return result


def character_id(student_id, form_index=1, *, path=DEFAULT_PATH):
    forms = load_refs(path).get(student_id)
    if forms is None:
        return None
    if type(form_index) is not int or not 1 <= form_index <= len(forms):
        raise ValueError('form identity must use a normalized positive index')
    return forms[form_index - 1]
