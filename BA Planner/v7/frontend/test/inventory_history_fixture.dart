// FE6-f 인벤토리 이력 검수 fixture 도우미(테스트 파일 아님).
//
// 검수 fixture(`inventory_fe6a_fixture.dart` · `inventory_fe6c_fixture.dart`)가 Mock 저장소에 넣을 현재 이력(FB-2a
// `current_history` v1)을 만든다. 시계는 고정이다([inventoryHistoryFixtureNow] = 2026-10-05 12:00 UTC, 시안 날짜).
// - 기준선은 legacy(첫 스캔 앞 상태 = 각 재화의 가장 오래된 값)이고, 스캔 회차(지금 기준 며칠 전)마다 scan profile별
//   세션 하나(`scan_kind = inventory`, `inventory_scan_profile` = 카탈로그 profile)를 1분 간격으로 쌓는다. 세션 승인
//   scope는 그 회차에 값을 준 재화뿐이다.
// - 마지막 상태는 fixture의 지금 수량과 같아야 한다(Mock 생성자가 이력 → 지금 재구성을 검사한다).
// mockdemo: 도우미는 검수 시나리오 Mock과 같이 쓰도록 `lib/services/design_review/inventory_history_data.dart`로 옮겼고 이
// 파일은 같은 이름을 그대로 내보낸다.
export 'package:ba_planner_v7/services/design_review/inventory_history_data.dart';
