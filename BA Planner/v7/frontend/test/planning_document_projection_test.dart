import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown inventory remains unknown in planning result previews', () {
    const resource = PlanConsumptionResourcePreview(
      id: 'credits',
      name: '크레딧',
      amount: 100,
      owned: 0,
      inventoryKnown: false,
      iconAsset: planCreditIconAsset,
      affectedStageKeys: {},
    );

    expect(resource.inventoryKnown, isFalse);
    expect(resource.isBottleneck, isFalse);
    expect(resource.ownedDisplay, '미확인');
    expect(resource.endingDisplay, '미확인');
    expect(resource.balanceDisplay, '보유량 미확인');
  });
}
