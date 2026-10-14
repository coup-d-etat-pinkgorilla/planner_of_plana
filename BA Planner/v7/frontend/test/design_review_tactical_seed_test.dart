// tidy2(FE9-a 발견 8): design-review 전술 seed 덱의 칸 역할이 번들 학생 목록(`combat_class`)과 맞는지 — 스트라이커 칸 1~4는
// striker, 스페셜 칸 SP1 · SP2는 special. 화면 피커는 칸 역할로 학생을 거르므로 seed가 어긋나면 고를 수 없는 학생이 보인다.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_student_fixture.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed decks put strikers in 1-4 and specials in SP1 · SP2', () {
    final catalog = jsonDecode(
      File('assets/student_catalog.json').readAsStringSync(),
    ) as List;
    final combatClass = {
      for (final item in catalog.cast<Map<String, dynamic>>())
        item['student_id'] as String: item['combat_class'] as String?,
    };
    final mismatches = <String>[];
    void check(String where, TacticalDeckV2 deck) {
      for (final (role, slots) in [
        ('striker', deck.strikers),
        ('special', deck.specials),
      ]) {
        for (final slot in slots) {
          final id = slot.studentId;
          if (id == null) continue;
          if (combatClass[id] != role) {
            mismatches.add('$where $role#${slot.position}: $id');
          }
        }
      }
    }

    final matches = designReviewTacticalMatches();
    expect(matches, isNotEmpty);
    for (final match in matches) {
      check('${match.id} attack', match.attackDeck);
      check('${match.id} defense', match.defenseDeck);
    }
    expect(mismatches, isEmpty);
  });

  test('my-deck specials are owned in the default mock', () {
    // 내 덱은 보유 학생만 고른다(FE9-a). 공격 기록의 내 덱 = 공격 덱, 방어 기록의 내 덱 = 방어 덱.
    for (final match in designReviewTacticalMatches()) {
      final mine = match.kind == 'attack' ? match.attackDeck : match.defenseDeck;
      for (final slot in mine.specials) {
        final id = slot.studentId;
        if (id == null) continue;
        expect(mockOwnedStudentIds, contains(id), reason: '${match.id} $id');
      }
    }
  });
}
