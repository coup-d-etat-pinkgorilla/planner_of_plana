import 'package:ba_planner_v7/ui/models/plan_scenario_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // FE5-f1: 옛 홈 미리보기(`PlanConsumptionResourcePreview`)를 지우고 같은 의미를 Detail 홈 재화 줄(FE5-d)로 옮겼다.
  test('unknown inventory remains unknown in planning result previews', () {
    final resource = PlanDetailResourceTile(
      resourceKey: 'credits',
      name: '크레딧',
      category: 'credits',
      required: 100,
    );

    expect(resource.owned, isNull);
    expect(resource.exit, isNull);
    expect(resource.shortage, isNull);
    expect(resource.fraction, isNull);
    expect(resource.percent, isNull);
    expect(resource.satisfied, isFalse);
  });
}
