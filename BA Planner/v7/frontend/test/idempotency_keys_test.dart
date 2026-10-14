// tidy2 공용 idempotency key 생성기: 모양 `<prefix>-<µs>-<순번>`, 같은 시각에도 다른 key, 순번은 프로세스 전체에서 하나씩
// 오른다(FE9-b1 발견 4 — 인스턴스마다 순번이면 같은 µs의 두 인스턴스가 같은 key를 만든다).
import 'package:ba_planner_v7/services/idempotency_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixed = DateTime.utc(2026, 10, 14, 12);
  final micros = fixed.microsecondsSinceEpoch;

  int sequenceOf(String key) => int.parse(key.split('-').last);

  test('key shape is <prefix>-<µs>-<sequence>', () {
    final key = newIdempotencyKey('tactical-match-upsert', now: fixed);
    expect(key, matches(RegExp('^tactical-match-upsert-$micros-[0-9]+\$')));
  });

  test('the same instant still gives distinct keys in sequence', () {
    final keys = [
      for (var index = 0; index < 5; index++)
        newIdempotencyKey('presets-p1', now: fixed),
    ];
    expect(keys.toSet(), hasLength(keys.length));
    final numbers = keys.map(sequenceOf).toList();
    expect(numbers, [
      for (var index = 0; index < numbers.length; index++)
        numbers.first + index,
    ]);
  });

  test('one sequence is shared across prefixes and callers', () {
    final first = newIdempotencyKey('account-create', now: fixed);
    final second = newIdempotencyKey('tactical-match-upsert', now: fixed);
    final next = nextIdempotencySequence();
    expect(sequenceOf(second), sequenceOf(first) + 1);
    expect(next, sequenceOf(second) + 1);
  });

  test('without a clock the device clock is used', () {
    final before = DateTime.now().microsecondsSinceEpoch;
    final key = newIdempotencyKey('settings-create');
    final after = DateTime.now().microsecondsSinceEpoch;
    final stamp = int.parse(key.split('-')[2]);
    expect(stamp, inInclusiveRange(before, after));
  });
}
