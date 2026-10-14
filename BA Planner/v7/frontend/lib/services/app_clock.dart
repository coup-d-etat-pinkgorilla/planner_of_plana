// 화면 공용 "지금" 시계 계약(tidy1, mockdemo 발견 5 · FE8-c 발견 2).
//
// 서비스가 이 interface를 구현하면 화면은 기기 시계 대신 서비스가 주는 시각을 "지금"으로 쓴다(검수 시나리오 · 테스트의 고정
// 시계). 구현하지 않으면 기기 시계다. 인벤토리 이력 집계(FE6-f)와 계정 메타 "마지막 스캔"(FE8-c)이 읽는다.
// 원래 `ui/inventory/inventory_controller.dart`의 `InventoryClockSource`였다. 검수 시나리오(`services/`)가 `ui/`를 import하지
// 않게 서비스 쪽으로 옮겼다.

/// "지금"을 주는 서비스(검수 fixture · 테스트가 고정 시각을 준다).
abstract interface class AppClockSource {
  DateTime get clockNow;
}

/// [service]가 [AppClockSource]면 그 시각, 아니면 기기 시계다.
DateTime appClockNow(Object? service) => switch (service) {
  final AppClockSource source => source.clockNow,
  _ => DateTime.now(),
};
