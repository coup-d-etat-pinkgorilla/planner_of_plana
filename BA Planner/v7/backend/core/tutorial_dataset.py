"""FD-183 fixed synthetic tutorial content. Never reads a real profile/client."""
from copy import deepcopy

from core import student_meta
from core.inventory_catalog import CATALOG, CATALOG_REVISION
from core.planning_document import TARGET_MAXIMUMS, planning_document_from_wire
from core.repository_dto import ConfirmedStudent, InventorySnapshot

DATASET_VERSION = 'tutorial-v1'
CONTENT_REVISION = 2
PLANNING_STUDENTS = ('kanna_swimsuit', 'akane', 'maki', 'mika', 'himari_battle',
                     'shiroko_swimsuit', 'neru_school_uniform')
PRIORITIES = (('kanna_swimsuit', 'maki', 'mika'),
              ('shiroko_swimsuit', 'himari_battle'), ('akane',))


def _student(sid, level):
    return ConfirmedStudent.from_dict({'version': 1, 'student_id': sid,
        'values': {'level': level, 'student_star': 3, 'bond_rank': 10,
                   'ex_skill': 3, 'skill1': 4, 'skill2': 4, 'skill3': 4},
        'provenance': {'source': 'tutorial-synthetic-v1'}}).to_dict()


def _stage(sid, index):
    targets = dict(TARGET_MAXIMUMS)
    # Available favorite-item tiers remain per-student; zero means no target.
    targets['equip4_tier'] = 0
    return {'stage_id': f'tutorial-max-{sid}', 'student_id': sid,
            'name': '한 번에 MAX', 'targets': targets}


def tutorial_dataset():
    if not set(PLANNING_STUDENTS) <= set(student_meta.STUDENTS):
        raise ValueError('tutorial students are missing from the packaged catalog')
    previous = [_student(sid, 60 + index) for index, sid in enumerate(PLANNING_STUDENTS[:-1])]
    changed = [_student(sid, 70 + index) for index, sid in enumerate(PLANNING_STUDENTS[:-1])]
    new = [_student(PLANNING_STUDENTS[-1], 60)]
    review = [_student('yuuka', 70), _student('hina', 70)]
    student_examples = [
        {'classification': kind, 'student': row, 'review_required': kind == 'review',
         'fallback_capture_required': kind == 'review' and row['student_id'] == 'yuuka'}
        for kind, values in (('changed', changed), ('new', new), ('review', review)) for row in values]
    inventory = {}
    for profile in ('tech_notes', 'tactical_bd'):
        rows = [row for row in CATALOG if row.profile_id == profile][:30]
        if len(rows) != 30:
            raise ValueError('tutorial inventory needs 30 known resources per profile')
        examples = []
        for index, row in enumerate(rows):
            known = index < 28
            review_required = not known or (profile == 'tech_notes' and index in (26, 27))
            approved = known and not review_required
            quantity = str(20 + index) if known else None
            entry = {'key': row.resource_key, 'item_id': row.item_id, 'name': row.display_name,
                     'profile_id': profile, 'index': row.order_index, 'observed_slot': index,
                     'quantity': quantity}
            examples.append({'entry': entry, 'review_required': review_required,
                             'synthetic': True, 'suggested_approval': approved})
        inventory[profile] = examples
        InventorySnapshot.from_dict({'version': 1, 'catalog_revision': CATALOG_REVISION,
                                      'entries': [example['entry'] for example in examples]})
    previous_inventory = []
    for index, row in enumerate(inventory['tech_notes'][:10]):
        entry = deepcopy(row['entry'])
        entry.pop('observed_slot')
        if index >= 5:
            entry['quantity'] = str(int(entry['quantity']) - 5)
        previous_inventory.append(entry)
    InventorySnapshot.from_dict({'version': 1, 'catalog_revision': CATALOG_REVISION,
                                 'entries': previous_inventory})
    example_priorities = (PRIORITIES[0], (*PRIORITIES[1], 'neru_school_uniform'), PRIORITIES[2])
    example = {'version': 1, 'document_id': 'tutorial-binah-max', 'kind': 'scenario',
               'name': '비나 대비 · 한 번에 MAX',
               'phases': [{'phase_id': f'tutorial-phase-{index + 1}', 'name': f'{index + 1}순위',
                           'stages': [_stage(sid, index) for sid in students]}
                          for index, students in enumerate(example_priorities)]}
    planning_document_from_wire(example)
    return deepcopy({'dataset_version': DATASET_VERSION, 'content_revision': CONTENT_REVISION,
        'synthetic': True,
        'virtual_target_id': 'tutorial:1280x720', 'planning_students': list(PLANNING_STUDENTS),
        'previous_students': previous, 'previous_inventory': previous_inventory,
        'student_examples': student_examples,
        'inventory_examples': inventory, 'example_scenario': example,
        'previous_scan': {'session_id': 'tutorial-previous-scan-v1',
                          'provenance': 'synthetic previous scan; persist through the normal history writer'},
        'plan_instructions': {'first_priority': list(PRIORITIES[0]),
            'second_priority': list(PRIORITIES[1]), 'third_priority': list(PRIORITIES[2]),
            'later': ['neru_school_uniform', 'maki#stage2'],
            'maki_stage1': {'ex_skill':5,'skill1':10,'skill2':1,'skill3':1},
            'maki_stage2': {'ex_skill':5,'skill1':10,'skill2':7,'skill3':7}},
        'limits': ['Data helper only: practice ownership, crash recovery, virtual session replay and RPC are not implemented here.',
                   '54 initially approved slots; review two known tech-note quantities to reach 56; four unknowns stay null.',
                   'No fake comparison costs or native accuracy claims; use the real plan/history calculation.']})
