// FE6-a 인벤토리 검수 fixture(시안 Inventory "부족한 것 · 엘레프 선택"의 예시 값).
//
// `MockAppService` 기본값은 바꾸지 않는다(서비스 파일은 이 slice 범위 밖). 테스트와 golden이 이 대역을 쓴다.
// - 계정 `000000000000000000000001`(Mock 기본 Main, 선택됨), 학생 6명, 저장된 목표 6개(목표 v1 → Mock 활성 문서
//   한 페이즈 `v6-imported-plan`, 단계 `v6-<학생>-1`, 단계 이름 = notes).
// - 카탈로그: 엘레프 2 · 기술 노트 2 · BD 1 · 오파츠 1 · 활동 보고서 3 · 장비 2(강화석 · 헤어핀) + 재화 2(credits ·
//   엘리그마).
// - 부족 계산(`calculateShortages`)과 활성 문서 계산(`calculatePlanningDocument`)은 같은 표 [inventoryFixturePlan]에서
//   만든다. 위험도(FD-030 (b)): 리오 엘레프 1/450·1명 → 99.78(표시 100), 오파츠 3/40·2명 → 95.4999(95), 기술 노트
//   12/60·4명 → 91.07(91), 토키 엘레프 53/330·1명 → 83.94(84), BD 20/28·3명 → 55.05(55). 활동 보고서(상급)는 보유를
//   모른다(점수 —). 장비 헤어핀 0/55·2명 → 100(장비 모드).
// - 획득처: 카탈로그 품목은 FB-3 packaged v1처럼 빈 표(methods = [])다.
// - 학생 id · 엘레프 key는 실제 그림 id(`rio_battle` · `toki_battle`)다(FE6-e 발견 3, FE6-f에서 고침).
// - 이력(FE6-f, [inventoryFixtureScans]): 지금 = 2026-10-05 12:00 UTC([AppClockSource]), 스캔 회차 31 · 24 · 17 · 10
//   · 3일 전, profile별 세션. 시안 KPI "+3 지난 스캔 대비"(BD · 네브라 · 헤어핀이 지난 스캔 뒤 부족으로) · "−1"(네브라가 과잉
//   에서 빠짐) · "최근 감소 6종" · "마지막 스캔 3일 전", 리오 엘레프 스파크라인 0 · 0 · 1 · 1("순변화 +1 · 이전 스캔과 이상
//   없음"). 기술 노트(최상급)는 31 · 24 · 18 · 12(시안 18 · 15 · 12 · 12는 추세 규칙으로 "소진 예상"이 나오지 않아 바꿨다,
//   "순변화 −19 · 2주 뒤 소진 예상"). `owned`를 바꿔 만들면 이력은 넣지 않는다(지금 수량과 맞지 않으므로).
// mockdemo: 카탈로그 · 보유 · 계획 표 · 스캔 표 · 부족 계산은 검수 시나리오 Mock과 같이 쓰도록
// `lib/services/design_review/inventory_fe6a_data.dart`로 옮겼고 이 파일은 같은 이름을 그대로 내보낸다. 테스트 서비스만 여기 있다.
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/design_review/inventory_fe6a_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';

import 'inventory_history_fixture.dart';

export 'package:ba_planner_v7/services/design_review/inventory_fe6a_data.dart';

/// 검수 fixture 서비스. [plan]이 false면 목표 없이(부족 계산 없음) 시작한다. [history]가 false거나 [owned]를 바꾸면
/// 이력을 넣지 않는다.
class InventoryFixtureService extends MockAppService
    implements AppClockSource {
  InventoryFixtureService({
    bool plan = true,
    Map<String, String>? owned,
    bool? history,
  }) : super(
         repositoryStates: {
           inventoryFixtureProfileId: inventoryFixtureStateWire(
             revision: inventoryHistoryFixtureRevision,
             owned: owned ?? inventoryFixtureOwned,
             plan: plan,
           ),
         },
         historyClock: () => inventoryHistoryFixtureNow,
         repositoryHistories: {
           if (history ?? owned == null)
             inventoryFixtureProfileId: inventoryFixtureScanHistory(
               stateWire: (revision, owned) => inventoryFixtureStateWire(
                 revision: revision,
                 owned: owned,
                 plan: plan,
               ),
               current: owned ?? inventoryFixtureOwned,
               scans: inventoryFixtureScans,
             ),
         },
       );

  @override
  DateTime get clockNow => inventoryHistoryFixtureNow;

  int shortageCalls = 0;
  int documentCalls = 0;

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: inventoryFixtureRevision,
        items: inventoryFixtureCatalog,
      );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => [
    for (final entry in inventoryFixtureStudents.entries)
      StudentCatalogEntry(
        studentId: entry.key,
        displayName: entry.value,
        templateName: '${entry.key}.png',
        group: entry.key,
        variant: null,
        school: 'Gehenna',
        rarity: '3',
        attackType: 'Explosive',
        defenseType: 'Light',
        combatClass: 'Striker',
        role: 'Dealer',
        position: 'Back',
        searchTags: const [],
        krSearchTags: const [],
      ),
  ];

  @override
  Future<ResourceAcquisitionResult> getResourceAcquisition(
    String resourceKey,
  ) async {
    if (!inventoryFixtureCatalog.any((item) => item.resourceKey == resourceKey)) {
      return super.getResourceAcquisition(resourceKey);
    }
    return ResourceAcquisitionResult.fromWire({
      'resource_key': resourceKey,
      'methods': <dynamic>[],
      'acquisition_revision': mockEmptyResourceAcquisitionRevision,
    });
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async {
    shortageCalls += 1;
    return inventoryFixtureShortages(inventory);
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    documentCalls += 1;
    final remaining = <String, int?>{
      for (final key in inventoryFixturePlan.keys)
        key: inventoryFixtureOwnedQuantity(inventory, key),
    };
    final stageResults = <Map<String, dynamic>>[];
    for (final rawPhase in document['phases'] as List? ?? const []) {
      final phase = Map<String, dynamic>.from(rawPhase as Map);
      for (final rawStage in phase['stages'] as List? ?? const []) {
        final stage = Map<String, dynamic>.from(rawStage as Map);
        final student = stage['student_id'] as String;
        final resources = <Map<String, dynamic>>[];
        for (final entry in inventoryFixturePlan.entries) {
          final required = entry.value[student];
          if (required == null) continue;
          final before = remaining[entry.key];
          resources.add({
            'resource_key': entry.key,
            'item_id': entry.key == 'credits' ? null : entry.key,
            'display_name': inventoryFixtureItem(entry.key).displayName,
            'category': inventoryFixtureItem(entry.key).category,
            'required': required,
            'owned_at_entry': before,
            'shortage_at_entry': before == null
                ? null
                : (before >= required ? 0 : required - before),
          });
          if (before != null) {
            remaining[entry.key] = before >= required ? before - required : 0;
          }
        }
        stageResults.add({
          'stage_id': stage['stage_id'],
          'phase_id': phase['phase_id'],
          'student_id': student,
          'name': stage['name'],
          'cost': <String, dynamic>{},
          'resources': resources,
        });
      }
    }
    return {
      'document_id': document['document_id'],
      'kind': document['kind'],
      'stage_results': stageResults,
      'phase_results': <dynamic>[],
      'overall': {
        'cost': <String, dynamic>{'credits': 0},
        'resources': <dynamic>[],
      },
      'bottlenecks': <dynamic>[],
      'warnings': <dynamic>[],
    };
  }
}
