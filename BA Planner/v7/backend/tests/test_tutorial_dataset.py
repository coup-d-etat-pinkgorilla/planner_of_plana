import unittest
from core.tutorial_dataset import tutorial_dataset, PLANNING_STUDENTS
from core.repository_dto import ConfirmedStudent, InventorySnapshot
from core.planning_document import planning_document_from_wire


class TutorialDatasetTests(unittest.TestCase):
    def test_student_mix_and_all_seven_planning_students_are_available_after_review(self):
        data = tutorial_dataset()
        examples = data['student_examples']
        self.assertEqual({kind: sum(row['classification'] == kind for row in examples)
                          for kind in ('changed','new','review')}, {'changed':6,'new':1,'review':2})
        available = {row['student_id'] for row in data['previous_students']}
        for row in examples:
            ConfirmedStudent.from_dict(row['student'])
            if not row['review_required']:
                available.add(row['student']['student_id'])
        self.assertTrue(set(PLANNING_STUDENTS) <= available)
        self.assertEqual(sum(row['fallback_capture_required'] for row in examples), 1)

    def test_two_inventory_profiles_reach_56_only_after_two_known_reviews(self):
        groups = tutorial_dataset()['inventory_examples']
        self.assertEqual(set(groups), {'tech_notes','tactical_bd'})
        self.assertEqual(sum(row['suggested_approval'] for rows in groups.values() for row in rows), 54)
        known_reviews = [row for rows in groups.values() for row in rows
                         if row['review_required'] and row['entry']['quantity'] is not None]
        self.assertEqual([row['entry']['quantity'] for row in known_reviews], ['46', '47'])
        self.assertEqual(sum(row['entry']['quantity'] is None for rows in groups.values() for row in rows), 4)
        for rows in groups.values():
            InventorySnapshot.from_dict({'version':1,'entries':[row['entry'] for row in rows]})

    def test_comparison_scenario_and_stage_order_follow_script_and_are_independent(self):
        data = tutorial_dataset()
        example = planning_document_from_wire(data['example_scenario'])
        self.assertEqual(example.name, '비나 대비 · 한 번에 MAX')
        self.assertEqual([tuple(stage.student_id for stage in phase.stages) for phase in example.phases],
                         [('kanna_swimsuit','maki','mika'),
                          ('shiroko_swimsuit','himari_battle','neru_school_uniform'), ('akane',)])
        self.assertEqual(data['plan_instructions']['first_priority'], ['kanna_swimsuit','maki','mika'])
        self.assertEqual(data['plan_instructions']['maki_stage2']['skill2'], 7)
        data['student_examples'].clear()
        self.assertEqual(len(tutorial_dataset()['student_examples']), 9)

    def test_previous_inventory_produces_five_unchanged_and_five_positive_deltas(self):
        data = tutorial_dataset()
        self.assertEqual(data['content_revision'], 2)
        previous = data['previous_inventory']
        current = data['inventory_examples']['tech_notes']
        self.assertEqual(len(previous), 10)
        self.assertEqual([int(current[i]['entry']['quantity']) - int(row['quantity'])
                          for i,row in enumerate(previous)], [0]*5 + [5]*5)


if __name__ == '__main__':
    unittest.main()
