// 성장 계산기 계산 연결 (FE3-f1, FD-162·FD-172; FE3-f2b에서 FB-11a로 교체).
//
// - 서비스가 [PlanningStudentCalculationService]면 단일 학생 계산(`planning.student.calculate`, FB-11a)을
//   한 번 부른다(FD-162 (b)). 크레딧 합계·9범주 크레딧 내역·성장 재화 행을 한 번에 받는다.
// - 그 기능이 없는 서비스는 예전 임시 경로로 계산한다(FD-162 (a)). 계산기 목표로 1페이즈 1단계짜리 임시
//   문서를 만들어 `planning.document.calculate`([PlanningDocumentService.calculatePlanningDocument])로
//   계산한다. 이 호출은 받은 문서를 계산만 하고 저장하지 않으며 활성 계획도 건드리지 않는다. 문서 id는
//   저장 id가 아닌 고정 문자열이다. 이 경로에는 크레딧 내역이 없다([GrowthCalculatorCreditBreakdown.unavailable]).
// - 결과: 크레딧 합계와 성장 재화 행(전체 재화 행에서 크레딧 행을 뺀 것).
// - 데이터가 없는 값은 null이 아니라 명시 값이다(FD-172): 크레딧 보유 = 스캔 없음(FD-096 (c)),
//   재화 보유 = 확인/미확인, 계획 포함 = 저장된 활성 계획 문서 기준(FE4-h) 있음/없음/모름.
// - [GrowthCalculatorEngine]은 디바운스로 한 번만 부르고, 늦게 온 이전 요청 응답은 요청 번호로 버린다.
// - 인연 선물(FE3-g, FB-11b·FD-163~165): 서비스가 [PlanningStudentBondCalculationService]면 같은 호출에
//   `bond`(확정 인연 랭크, 모르면 null)를 함께 보내 성장 + 인연을 한 번에 받는다. 현재 인연은 `currentStudent`에
//   넣지 않고(`planningCurrentFields`에 없다), 모르는 현재 인연을 1로 채우지 않는다. 인연 선물은 성장 재화
//   목록·부족 종류 수에 합치지 않는다(FD-165). 그 입력을 인연 계산이 지원하지 않으면(`UnsupportedError`, 공유
//   fixture만 아는 mock) 성장만 계산하고 인연은 "계산할 수 없음"이다.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import 'growth_calculator_state.dart';
import 'planning_models.dart';
import 'repository_plan_snapshot.dart';

/// 목표를 바꾼 뒤 다시 계산할 때까지 기다리는 시간.
const growthCalculatorDebounce = Duration(milliseconds: 250);

/// 임시 문서의 id와 이름(저장하지 않는다).
const growthCalculatorDocumentId = 'growth-calculator';
const growthCalculatorPhaseId = 'growth-calculator-phase';
const growthCalculatorStageId = 'growth-calculator-stage';
const growthCalculatorDocumentName = '성장 계산기';
const growthCalculatorStageName = '계산기 목표';

/// 크레딧 resource key(백엔드 `_resource_requirements`).
const growthCalculatorCreditResourceKey = 'credits';

/// [studentId]의 [targets]로 만든 임시 1페이즈 1단계 문서.
PlanningDocument growthCalculatorDocument(
  String studentId,
  Map<String, int> targets,
) => PlanningDocument(
  id: growthCalculatorDocumentId,
  name: growthCalculatorDocumentName,
  kind: PlanningDocumentKind.scenario,
  phases: [
    PlanningDocumentPhase(
      id: growthCalculatorPhaseId,
      name: growthCalculatorDocumentName,
      stages: [
        PlanningDocumentStage(
          id: growthCalculatorStageId,
          studentId: studentId,
          name: growthCalculatorStageName,
          targets: targets,
        ),
      ],
    ),
  ],
);

String? _tierText(int tier) => tier > 0 ? 'T$tier' : null;

/// 직접 입력·미보유 학생의 현재값(19 key)을 `current_students` 항목으로 바꾼다. 인연은 현재 항목에
/// 없다(`planningCurrentFields`). 전용무기 ★가 있으면 장착 상태로 본다.
Map<String, dynamic> growthCalculatorCurrentStudentWire(
  String studentId,
  Map<String, int> current,
) => {
  'student_id': studentId,
  'level': current['level'],
  'student_star': current['student_star'],
  'weapon_state': current['weapon_star']! > 0
      ? 'weapon_equipped'
      : 'weapon_locked',
  'weapon_star': current['weapon_star'],
  'weapon_level': current['weapon_level'],
  'ex_skill': current['ex_skill'],
  'skill1': current['skill1'],
  'skill2': current['skill2'],
  'skill3': current['skill3'],
  'equip1': _tierText(current['equip1_tier']!),
  'equip2': _tierText(current['equip2_tier']!),
  'equip3': _tierText(current['equip3_tier']!),
  'equip4': _tierText(current['equip4_tier']!),
  'equip1_level': current['equip1_level'],
  'equip2_level': current['equip2_level'],
  'equip3_level': current['equip3_level'],
  'stat_hp': current['stat_hp'],
  'stat_atk': current['stat_atk'],
  'stat_heal': current['stat_heal'],
};

/// 빈 인벤토리(repository를 아직 못 읽었을 때). 보유는 모두 미확인이 된다.
const growthCalculatorEmptyInventory = <String, dynamic>{
  'version': 1,
  'entries': <Map<String, dynamic>>[],
};

/// 계획 포함 여부(FD-172). FE4-h부터 저장된 활성 계획 문서(`plan.get`) 기준이다. 그 학생 단계가 문서에 하나라도
/// 있으면 계획에 있다. goals v1은 보지 않는다.
enum GrowthCalculatorPlanMembership {
  inPlan,
  notInPlan,

  /// 활성 계획 문서를 아직 못 읽었다(또는 읽지 못했다).
  unknown,
}

GrowthCalculatorPlanMembership growthCalculatorPlanMembership(
  PlanningDocument? activePlan,
  String studentId,
) {
  if (activePlan == null) return GrowthCalculatorPlanMembership.unknown;
  return activePlanStudentIds(activePlan).contains(studentId)
      ? GrowthCalculatorPlanMembership.inPlan
      : GrowthCalculatorPlanMembership.notInPlan;
}

/// 계산 한 번의 입력.
@immutable
class GrowthCalculatorRequest {
  GrowthCalculatorRequest({
    required this.studentId,
    required Map<String, int> targets,
    required Map<String, dynamic> currentStudent,
    required Map<String, dynamic> inventory,
    required this.planMembership,
    this.currentBondRank,
  }) : targets = Map.unmodifiable(targets),
       currentStudent = Map.unmodifiable(currentStudent),
       inventory = Map.unmodifiable(inventory);

  /// 계산기 상태로 요청을 만든다.
  /// - 확정값 기준이고 repository에 그 학생 상태가 있으면 계획 탭과 같은
  ///   `confirmedStudentPlanningCurrent`를 보낸다.
  /// - 직접 입력이거나 미보유 학생이면 계산기 현재값으로 만든 항목을 보낸다.
  /// - 인벤토리는 repository 것을 쓰고, 없으면 빈 인벤토리다.
  /// - 계획 포함 여부는 [activePlan](저장된 활성 계획 문서) 기준이다. 없으면 모름이다.
  /// - 현재 인연([currentBondRank]): 확정값 기준이면 repository 학생 값에 `bond_rank`가 있을 때만 계산기의 확정
  ///   현재값(행·S3와 같은 값)이고, 없거나 미보유면 null이다. 직접 입력이면 계산기에 적은 현재 인연이다.
  ///   확정값을 모를 때 계산기 현재값(채운 값)을 쓰지 않는다.
  factory GrowthCalculatorRequest.fromState(
    GrowthCalculatorState state, {
    RepositoryState? repository,
    PlanningDocument? activePlan,
  }) {
    ConfirmedStudentState? confirmed;
    if (state.basis == GrowthCalculatorBasis.confirmed && repository != null) {
      for (final student in repository.students) {
        if (student.studentId == state.studentId) confirmed = student;
      }
    }
    final int? currentBondRank;
    if (state.basis == GrowthCalculatorBasis.direct) {
      currentBondRank = growthCalculatorBondRank(state.current['bond_rank']);
    } else if (confirmed?.values['bond_rank'] is int) {
      // 확정 인연이 있으면 계산기 행·S3와 같은 정규화된 현재값(성급 상한 적용)을 쓴다.
      currentBondRank = growthCalculatorBondRank(
        state.confirmedCurrent['bond_rank'],
      );
    } else {
      currentBondRank = null;
    }
    return GrowthCalculatorRequest(
      studentId: state.studentId,
      targets: state.targets,
      currentBondRank: currentBondRank,
      currentStudent: confirmed != null
          ? confirmedStudentPlanningCurrent(confirmed)
          : growthCalculatorCurrentStudentWire(state.studentId, state.current),
      inventory:
          repository?.inventory.toWire() ?? growthCalculatorEmptyInventory,
      planMembership: growthCalculatorPlanMembership(
        activePlan,
        state.studentId,
      ),
    );
  }

  final String studentId;
  final Map<String, int> targets;
  final Map<String, dynamic> currentStudent;
  final Map<String, dynamic> inventory;
  final GrowthCalculatorPlanMembership planMembership;

  /// 현재 인연 랭크. 모르면 null(1로 채우지 않는다).
  final int? currentBondRank;

  /// 목표 인연 랭크(계산기 목표 `bond_rank`).
  int? get targetBondRank => targets['bond_rank'];

  /// 인연 선물 계산 입력(FB-11b `bond`).
  StudentBondRequest get bondRequest =>
      StudentBondRequest(currentRank: currentBondRank);

  /// 이 요청의 임시 문서.
  PlanningDocument get document => growthCalculatorDocument(studentId, targets);
}

/// 인연 랭크로 쓸 수 있는 값(1~100 정수)만 남긴다. 그 밖은 모름(null)이다.
int? growthCalculatorBondRank(Object? value) =>
    value is int && value >= 1 && value <= 100 ? value : null;

/// 인연 선물 계산 결과(FE3-g). 성장 결과와 같은 호출에서 받는다.
sealed class GrowthCalculatorBond {
  const GrowthCalculatorBond();
}

/// 백엔드 인연 계산 결과(FB-11b `bond`).
final class GrowthCalculatorBondCalculated extends GrowthCalculatorBond {
  const GrowthCalculatorBondCalculated(this.result);

  final StudentBondResult result;
}

/// 이 연결(또는 이 입력)에서는 인연 선물을 계산할 수 없다.
final class GrowthCalculatorBondUnavailable extends GrowthCalculatorBond {
  const GrowthCalculatorBondUnavailable();
}

/// 보유량. 없는 값도 명시 상태로 둔다(FD-172).
sealed class GrowthCalculatorHolding {
  const GrowthCalculatorHolding();
}

/// 인벤토리에 수량이 있다.
final class GrowthCalculatorHoldingKnown extends GrowthCalculatorHolding {
  const GrowthCalculatorHoldingKnown(this.quantity);

  final int quantity;

  @override
  bool operator ==(Object other) =>
      other is GrowthCalculatorHoldingKnown && other.quantity == quantity;

  @override
  int get hashCode => quantity.hashCode;
}

/// 인벤토리에 수량 기록이 없다(미확인).
final class GrowthCalculatorHoldingUnknown extends GrowthCalculatorHolding {
  const GrowthCalculatorHoldingUnknown();

  @override
  bool operator ==(Object other) => other is GrowthCalculatorHoldingUnknown;

  @override
  int get hashCode => (GrowthCalculatorHoldingUnknown).hashCode;
}

/// 스캔 대상이 아니라 보유를 모른다(크레딧, FD-096 (c): "스캔 없음" 빗금, 부족 칩 숨김).
final class GrowthCalculatorHoldingNoScan extends GrowthCalculatorHolding {
  const GrowthCalculatorHoldingNoScan();

  @override
  bool operator ==(Object other) => other is GrowthCalculatorHoldingNoScan;

  @override
  int get hashCode => (GrowthCalculatorHoldingNoScan).hashCode;
}

/// 크레딧 범주별 내역(FD-162). 없으면 [unavailable](내역 막대를 숨긴다).
///
/// FB-11a의 9범주(`studentCreditCategories`) 값을 그대로 담는다. 화면에서 묶어 그릴 때도 범주를
/// 빠뜨리지 않도록 [amounts]의 합은 늘 [total]이다.
@immutable
class GrowthCalculatorCreditBreakdown {
  const GrowthCalculatorCreditBreakdown._(this._amounts);

  /// 범주별 크레딧. 음수는 받지 않는다.
  factory GrowthCalculatorCreditBreakdown.of(Map<String, int> amounts) {
    if (amounts.values.any((amount) => amount < 0)) {
      throw const FormatException('Negative credit breakdown amount');
    }
    return GrowthCalculatorCreditBreakdown._(Map.unmodifiable(amounts));
  }

  /// 내역이 없다(임시 문서 경로).
  static const unavailable = GrowthCalculatorCreditBreakdown._(null);

  final Map<String, int>? _amounts;

  bool get available => _amounts != null;

  /// 범주 → 크레딧. 없으면 빈 맵.
  Map<String, int> get amounts => _amounts ?? const {};

  /// 모든 범주의 합.
  int get total => amounts.values.fold(0, (sum, amount) => sum + amount);

  @override
  bool operator ==(Object other) =>
      other is GrowthCalculatorCreditBreakdown &&
      other.available == available &&
      mapEquals(other._amounts, _amounts);

  @override
  int get hashCode => available
      ? Object.hashAllUnordered(
          amounts.entries.map((entry) => Object.hash(entry.key, entry.value)),
        )
      : 0;
}

/// 성장 재화 한 행.
@immutable
class GrowthCalculatorResourceRow {
  const GrowthCalculatorResourceRow({
    required this.resourceKey,
    required this.itemId,
    required this.displayName,
    required this.category,
    required this.amount,
    required this.holding,
    required this.shortage,
  });

  final String resourceKey;

  /// 아이콘을 찾을 item id. 카탈로그에 없는 재화(`unresolved:…`)는 null이다.
  final String? itemId;
  final String displayName;
  final String category;

  /// 필요 수량(wire `required`).
  final int amount;
  final GrowthCalculatorHolding holding;

  /// 부족 수량. 보유가 미확인이면 0이다([isShort]는 false).
  final int shortage;

  bool get isShort => holding is GrowthCalculatorHoldingKnown && shortage > 0;

  factory GrowthCalculatorResourceRow.fromWire(Map<String, dynamic> value) {
    final resourceKey = value['resource_key'];
    final itemId = value['item_id'];
    final displayName = value['display_name'];
    final category = value['category'];
    final amount = value['required'];
    final owned = value['owned'];
    final shortage = value['shortage'];
    if (resourceKey is! String ||
        resourceKey.isEmpty ||
        (itemId != null && itemId is! String) ||
        displayName is! String ||
        category is! String ||
        amount is! int ||
        amount < 0 ||
        (owned != null && (owned is! int || owned < 0)) ||
        (shortage != null && (shortage is! int || shortage < 0))) {
      throw const FormatException('Invalid growth calculator resource row');
    }
    final holding = owned is int
        ? GrowthCalculatorHoldingKnown(owned)
        : const GrowthCalculatorHoldingUnknown();
    return GrowthCalculatorResourceRow(
      resourceKey: resourceKey,
      itemId: itemId as String?,
      displayName: displayName,
      category: category,
      amount: amount,
      holding: holding,
      shortage: owned is int
          ? (shortage as int? ?? (amount - owned).clamp(0, amount))
          : 0,
    );
  }
}

/// 계산 결과.
@immutable
class GrowthCalculatorResult {
  GrowthCalculatorResult({
    required this.studentId,
    required this.credits,
    required List<GrowthCalculatorResourceRow> resources,
    required this.planMembership,
    required List<String> warnings,
    this.creditBreakdown = GrowthCalculatorCreditBreakdown.unavailable,
    this.bond = const GrowthCalculatorBondUnavailable(),
    this.bondCurrentRank,
    this.bondTargetRank,
  }) : resources = List.unmodifiable(resources),
       warnings = List.unmodifiable(warnings);

  /// `planning.student.calculate` 결과(FB-11a)를 읽는다. 크레딧 행은 재화 목록에서 뺀다.
  factory GrowthCalculatorResult.fromStudentCalculation(
    StudentCalculationResult calculation, {
    required GrowthCalculatorRequest request,
  }) => GrowthCalculatorResult(
    studentId: request.studentId,
    credits: calculation.credits,
    resources: [
      for (final row in calculation.resources)
        if (row.resourceKey != growthCalculatorCreditResourceKey)
          GrowthCalculatorResourceRow.fromWire(row.toWire()),
    ],
    planMembership: request.planMembership,
    warnings: calculation.warnings,
    creditBreakdown: GrowthCalculatorCreditBreakdown.of(
      calculation.creditBreakdown,
    ),
    bond: switch (calculation.bond) {
      final bond? => GrowthCalculatorBondCalculated(bond),
      null => const GrowthCalculatorBondUnavailable(),
    },
    bondCurrentRank: request.currentBondRank,
    bondTargetRank: request.targetBondRank,
  );

  /// `planning.document.calculate` 응답의 projection을 읽는다.
  factory GrowthCalculatorResult.fromProjection(
    Map<String, dynamic> projection, {
    required GrowthCalculatorRequest request,
  }) {
    final overall = projection['overall'];
    final warnings = projection['warnings'] ?? const <Object?>[];
    if (overall is! Map || warnings is! List) {
      throw const FormatException('Invalid growth calculator projection');
    }
    final cost = overall['cost'] ?? const <String, Object?>{};
    final rawResources = overall['resources'] ?? const <Object?>[];
    if (cost is! Map || rawResources is! List) {
      throw const FormatException('Invalid growth calculator projection');
    }
    var creditRow = 0;
    final resources = <GrowthCalculatorResourceRow>[];
    for (final raw in rawResources) {
      if (raw is! Map) {
        throw const FormatException('Invalid growth calculator resource row');
      }
      final row = GrowthCalculatorResourceRow.fromWire(
        Map<String, dynamic>.from(raw),
      );
      if (row.resourceKey == growthCalculatorCreditResourceKey) {
        creditRow = row.amount;
      } else {
        resources.add(row);
      }
    }
    final costCredits = cost['credits'];
    if (costCredits != null && (costCredits is! int || costCredits < 0)) {
      throw const FormatException('Invalid growth calculator credits');
    }
    return GrowthCalculatorResult(
      studentId: request.studentId,
      credits: costCredits is int ? costCredits : creditRow,
      resources: resources,
      planMembership: request.planMembership,
      warnings: [
        for (final item in warnings)
          if (item is String) item,
      ],
      bondCurrentRank: request.currentBondRank,
      bondTargetRank: request.targetBondRank,
    );
  }

  final String studentId;

  /// 필요 크레딧 합계.
  final int credits;

  /// 크레딧 보유. 통화 스캔(FB-10)이 생기기 전에는 늘 스캔 없음이다.
  GrowthCalculatorHolding get creditHolding =>
      const GrowthCalculatorHoldingNoScan();

  /// 크레딧 범주별 내역. 임시 문서 경로에서는 없음이다.
  final GrowthCalculatorCreditBreakdown creditBreakdown;

  /// 성장 재화 행(백엔드 순서, 크레딧 행 제외).
  final List<GrowthCalculatorResourceRow> resources;
  final GrowthCalculatorPlanMembership planMembership;

  /// 성장 계산 백엔드 경고(예: 현재 상태가 없는 학생 단계 제외). 인연 경고는 [bond] 안에 있다.
  final List<String> warnings;

  /// 인연 선물 계산(FE3-g). 성장 재화 목록·[shortageTypeCount]에는 합치지 않는다(FD-165).
  final GrowthCalculatorBond bond;

  /// 이 결과를 계산할 때 보낸 현재 인연(모르면 null)과 목표 인연.
  final int? bondCurrentRank;
  final int? bondTargetRank;

  /// "부족 n종": 보유를 아는 재화 중 부족한 종류 수.
  int get shortageTypeCount => resources.where((row) => row.isShort).length;
}

/// [service]로 계산기를 쓸 수 있는가(단일 학생 계산 또는 문서 계산).
bool growthCalculatorSupports(Object service) =>
    service is PlanningStudentCalculationService ||
    service is PlanningStudentBondCalculationService ||
    service is PlanningDocumentService;

/// 디바운스 없이 한 번 계산한다. 단일 학생 계산(FB-11a)이 있으면 그것을 한 번 부르고, 없으면 임시 문서로
/// 계산한다. 둘 다 없으면 [UnsupportedError].
///
/// 인연 선물 계산(FB-11b)이 있으면 같은 한 번의 호출에 `bond`를 함께 보낸다. 그 입력을 인연 계산이 지원하지
/// 않으면(`UnsupportedError`) 성장만 계산한다(인연은 [GrowthCalculatorBondUnavailable]).
Future<GrowthCalculatorResult> calculateGrowthTargets(
  Object service,
  GrowthCalculatorRequest request,
) async {
  if (service case final PlanningStudentBondCalculationService bondService) {
    final StudentCalculationResult calculation;
    try {
      calculation = await bondService.calculateStudentWithBond(
        currentStudent: request.currentStudent,
        targets: request.targets,
        inventory: request.inventory,
        bond: request.bondRequest,
      );
    } on UnsupportedError {
      if (service case final PlanningStudentCalculationService growth) {
        return GrowthCalculatorResult.fromStudentCalculation(
          await growth.calculateStudent(
            currentStudent: request.currentStudent,
            targets: request.targets,
            inventory: request.inventory,
          ),
          request: request,
        );
      }
      rethrow;
    }
    return GrowthCalculatorResult.fromStudentCalculation(
      calculation,
      request: request,
    );
  }
  if (service case final PlanningStudentCalculationService growth) {
    final calculation = await growth.calculateStudent(
      currentStudent: request.currentStudent,
      targets: request.targets,
      inventory: request.inventory,
    );
    return GrowthCalculatorResult.fromStudentCalculation(
      calculation,
      request: request,
    );
  }
  if (service is PlanningDocumentService) {
    final projection = await service.calculatePlanningDocument(
      currentStudents: [request.currentStudent],
      inventory: request.inventory,
      document: request.document.toWire(),
    );
    return GrowthCalculatorResult.fromProjection(projection, request: request);
  }
  throw UnsupportedError('Growth calculation is unavailable');
}

/// 계산 상태.
sealed class GrowthCalculatorStatus {
  const GrowthCalculatorStatus();

  /// 마지막으로 받은 결과(새 계산을 기다리는 동안·실패 뒤에도 남는다). 아직 없으면 null.
  GrowthCalculatorResult? get lastResult;
}

/// 아직 계산을 부탁하지 않았다.
final class GrowthCalculatorIdle extends GrowthCalculatorStatus {
  const GrowthCalculatorIdle();

  @override
  GrowthCalculatorResult? get lastResult => null;
}

/// 디바운스를 기다리거나 응답을 기다린다.
final class GrowthCalculatorPending extends GrowthCalculatorStatus {
  const GrowthCalculatorPending({required this.requestNumber, this.lastResult});

  final int requestNumber;

  @override
  final GrowthCalculatorResult? lastResult;
}

/// 마지막 요청의 결과.
final class GrowthCalculatorReady extends GrowthCalculatorStatus {
  const GrowthCalculatorReady({
    required this.requestNumber,
    required this.result,
  });

  final int requestNumber;
  final GrowthCalculatorResult result;

  @override
  GrowthCalculatorResult get lastResult => result;
}

/// 마지막 요청이 실패했다.
final class GrowthCalculatorFailed extends GrowthCalculatorStatus {
  const GrowthCalculatorFailed({
    required this.requestNumber,
    required this.error,
    this.lastResult,
  });

  final int requestNumber;
  final Object error;

  @override
  final GrowthCalculatorResult? lastResult;
}

/// 디바운스 재계산기. [schedule]을 여러 번 불러도 [debounce] 동안 조용하면 마지막 요청만 한 번
/// 계산한다. 응답이 왔을 때 그 뒤에 새 요청이 있었으면(요청 번호가 다르면) 버린다.
///
/// [service]는 [growthCalculatorSupports]를 만족해야 한다([calculateGrowthTargets]).
class GrowthCalculatorEngine extends ChangeNotifier {
  GrowthCalculatorEngine({
    required Object service,
    this.debounce = growthCalculatorDebounce,
  }) : assert(growthCalculatorSupports(service)),
       _calculationService = service;

  final Object _calculationService;
  final Duration debounce;

  GrowthCalculatorStatus _status = const GrowthCalculatorIdle();
  GrowthCalculatorRequest? _pending;
  Timer? _timer;
  int _requestNumber = 0;
  bool _disposed = false;

  GrowthCalculatorStatus get status => _status;

  /// 마지막으로 부탁한 요청 번호(1부터).
  int get requestNumber => _requestNumber;

  /// [request]를 디바운스 뒤 계산한다. 앞서 기다리던 요청과 아직 오지 않은 응답은 버린다.
  void schedule(GrowthCalculatorRequest request) {
    if (_disposed) return;
    _requestNumber += 1;
    _pending = request;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_run()));
    _setStatus(
      GrowthCalculatorPending(
        requestNumber: _requestNumber,
        lastResult: _status.lastResult,
      ),
    );
  }

  /// 기다리던 요청과 아직 오지 않은 응답을 버린다. 마지막 결과는 남긴다.
  void cancel() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _requestNumber += 1;
    final last = _status.lastResult;
    _setStatus(
      last == null
          ? const GrowthCalculatorIdle()
          : GrowthCalculatorReady(requestNumber: _requestNumber, result: last),
    );
  }

  Future<void> _run() async {
    _timer = null;
    final request = _pending;
    _pending = null;
    if (request == null || _disposed) return;
    final number = _requestNumber;
    try {
      final result = await calculateGrowthTargets(_calculationService, request);
      if (_disposed || number != _requestNumber) return;
      _setStatus(GrowthCalculatorReady(requestNumber: number, result: result));
    } on Object catch (error) {
      if (_disposed || number != _requestNumber) return;
      _setStatus(
        GrowthCalculatorFailed(
          requestNumber: number,
          error: error,
          lastResult: _status.lastResult,
        ),
      );
    }
  }

  void _setStatus(GrowthCalculatorStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    super.dispose();
  }
}
