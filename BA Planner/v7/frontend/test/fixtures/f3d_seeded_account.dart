// F3d: 빈 상태 안내가 기존 시험 화면을 가리지 않게 하는 시험용 계정 데이터.
//
// 기본 `MockAppService()`는 빈 계정이라 F3d부터 스캔 · 학생 · 인벤토리 · 계획 · 통계 · 전술 탭이 빈 상태 안내를 보인다.
// 안내 뒤의 지금 화면을 시험하는 파일은 여기의 최소 데이터로 "하나라도 있음"을 만든다(사용자 결정 2026-10-21: 기존 시험을
// 고친다). 값은 화면 단언에 닿지 않는 것만 고른다.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_student_fixture.dart';
import 'package:ba_planner_v7/services/repository_service.dart';

/// 기본 Mock 계정 id.
const f3dDefaultProfileId = '000000000000000000000001';

/// 시험용 첫 스캔 시각(UTC).
final f3dSeededScanAt = DateTime.utc(2026, 10, 1, 12);

/// 스캔 기록 0회 판단(FB-2b `scan_latest` by_kind 0건)만 비껴 간다: 실제 이력에 종류별 스캔이 하나도 없으면 학생 스캔
/// 1건(수량 변화 없음)을 더해 답한다. 실제 스캔을 적용한 뒤에는 실제 값 그대로다. 계정 상태 · revision은 바꾸지 않는다.
mixin F3dScannedHistory on MockAppService {
  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async {
    final result = await super.loadRepositoryHistoryScanLatest(request);
    final wire = result.toWire();
    final byKind = wire['by_kind'];
    if (byKind is! List || byKind.isNotEmpty) return result;
    final at = historyUtcTimestamp(f3dSeededScanAt);
    return RepositoryHistoryScanLatestResult.fromWireFor(request, {
      ...wire,
      'history_sequence': 1,
      'last_scan_at': at,
      'by_kind': [
        {
          'sequence': 1,
          'recorded_at': at,
          'session_id': 'f3d-seeded-scan',
          'scan_kind': 'student',
          'inventory_scan_profile': null,
        },
      ],
    });
  }
}

/// [F3dScannedHistory]를 단 기본 Mock(생성자 인자는 그대로 넘긴다).
class F3dScannedMockAppService extends MockAppService with F3dScannedHistory {
  F3dScannedMockAppService({
    super.initialState,
    super.scannerScenario,
    super.fullStudentCatalog,
    super.scannerTargets,
    super.scannerReadiness,
    super.profiles,
    super.repositoryStates,
    super.historyClock,
    super.repositoryHistories,
  });
}

/// [mockOwnedStudentIds]의 확정 학생 wire(기본 Mock 전체 카탈로그 값과 같다).
Map<String, dynamic> f3dConfirmedStudentWire(String studentId) =>
    buildMockOwnedStudents().firstWhere(
      (student) => student['student_id'] == studentId,
    );

/// 기본 Mock 계정에 확정 학생 [studentIds]만 있는 계정 상태(인벤토리 · 목표 없음, revision 0).
Map<String, Map<String, dynamic>> f3dOwnedStudentStates(
  List<String> studentIds, {
  String profileId = f3dDefaultProfileId,
}) => {
  profileId: {
    'profile_id': profileId,
    'revision': 0,
    'students': [for (final id in studentIds) f3dConfirmedStudentWire(id)],
    'inventory': {'version': 1, 'entries': <dynamic>[]},
    'goals': {'version': 1, 'goals': <dynamic>[]},
  },
};

/// 계정 상태 [currentWire]로 끝나는 이력: 그 직전 revision의 같은 내용을 legacy 기준선으로 두고 학생 스캔 1건(수량 변화
/// 없음)을 더한다. 통계 스냅샷이 1개가 된다. revision은 1 이상이어야 한다.
RepositoryCurrentHistory f3dOneScanHistory(
  Map<String, dynamic> currentWire, {
  DateTime? at,
  String studentId = 'aru',
}) {
  final current = RepositoryState.fromWire(currentWire);
  final before = RepositoryState.fromWire({
    ...currentWire,
    'revision': current.revision - 1,
  });
  return RepositoryCurrentHistory.empty(legacy: before).appendScan(
    before,
    current,
    at ?? f3dSeededScanAt,
    rawScanKind: 'student',
    rawInventoryScanProfile: null,
    scanContext: const {
      'session_id': 'f3d-seeded-scan',
      'generation': 1,
      'candidate_id': 'f3d-seeded-candidate',
      'candidate_revision': 0,
    },
    studentIds: [studentId],
    resourceKeys: const [],
  );
}
