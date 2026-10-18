import '../../../services/scanner_service.dart';
import '../scan_header_progress.dart' show scanCandidateKey;

/// 아이템 결과 검토 보드가 바깥(스캔 세션 컨트롤러, FE8-g5b)에 맡기는 일(FE8-g5a).
///
/// 보드는 이 인터페이스만 부르고 서비스 · 세션 · idempotency key를 모른다. 형식은 FB-10 고정 선언(backend 로그
/// 2026-10-18 01:30)의 candidate review · commit · unresolved identity 그대로다.
/// - [approveSubset]: `scanner.candidate.review`(approve = true, `candidate_payload` = 승인한 칸만 남긴 payload, FD-146 ·
///   FB10b). 새 candidate revision을 돌려준다. 실패하면 던진다.
/// - [commit]: `scanner.candidate.commit`. [expectedRepositoryRevision]은 보드가 앞 commit 응답 revision으로 잇는다(종류
///   순차). 응답의 repository revision을 돌려준다. 실패하면 던진다 — 보드는 그 종류에서 멈추고 나머지 종류를 그대로 둔다.
///   같은 의도의 재전송(같은 요청 전체 · 같은 key)은 구현이 정한다.
/// - [assignIdentity] · [skipIdentity]: 기존 `ScanInventoryIdentityReview` 콜백 그대로(지금 컨트롤러
///   `assignInventoryIdentity` · `skipInventoryIdentity`). 새 revision 후보 · 슬롯은 바깥이 위젯 인자로 다시 넘긴다.
abstract interface class ScanItemReviewBoardActions {
  Future<ScannerCandidate> approveSubset(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
  );

  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  });

  Future<void> assignIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
    String identity,
    bool persist,
  );

  Future<void> skipIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
  );
}

/// 부분 적용할 후보 하나(승인한 칸으로 줄인 payload).
class ScanItemApplyTarget {
  const ScanItemApplyTarget({
    required this.candidate,
    required this.payload,
    required this.cellCount,
  });

  final ScannerCandidate candidate;
  final Map<String, dynamic> payload;

  /// 적용할 칸 수(글자용).
  final int cellCount;

  String get key => scanCandidateKey(candidate);
}

/// 종류 순차 부분 적용 한 번의 결과.
class ScanItemApplyRun {
  const ScanItemApplyRun({
    required this.appliedKeys,
    required this.remainingKeys,
    required this.repositoryRevision,
    this.failed,
    this.error,
  });

  /// 적용에 성공한 후보 열쇠(적용한 순서).
  final List<String> appliedKeys;

  /// 적용하지 않고 남긴 후보 열쇠(멈춘 후보 포함, 원래 순서).
  final List<String> remainingKeys;

  /// 마지막으로 알게 된 repository revision(성공이 없으면 시작 revision).
  final int repositoryRevision;

  /// 멈춘 후보. 모두 성공했거나 보드가 사라져 멈췄으면 null.
  final ScanItemApplyTarget? failed;
  final String? error;

  bool get stopped => failed != null;
}

/// FD-146 부분 적용(종류 순차): 후보마다 [ScanItemReviewBoardActions.approveSubset](승인 칸 payload) → commit. commit 응답
/// revision을 다음 후보의 expected로 쓰고, 어느 단계든 실패하면 그 후보에서 멈춰 나머지를 남긴다. [isActive]가 false가 되면
/// (보드가 사라짐) 다음 후보를 시작하지 않는다. [onStep]은 후보를 시작하기 전에 부른다(앞에서 끝난 수, 지금 대상).
Future<ScanItemApplyRun> runScanItemPartialApply({
  required List<ScanItemApplyTarget> targets,
  required int startRevision,
  required ScanItemReviewBoardActions actions,
  bool Function()? isActive,
  void Function(int done, ScanItemApplyTarget target)? onStep,
}) async {
  var revision = startRevision;
  final applied = <String>[];
  for (var index = 0; index < targets.length; index += 1) {
    final target = targets[index];
    if (isActive != null && !isActive()) {
      return ScanItemApplyRun(
        appliedKeys: applied,
        remainingKeys: [for (final item in targets.skip(index)) item.key],
        repositoryRevision: revision,
      );
    }
    onStep?.call(index, target);
    try {
      final approved = await actions.approveSubset(
        target.candidate,
        target.payload,
      );
      revision = await actions.commit(
        approved,
        expectedRepositoryRevision: revision,
      );
      applied.add(target.key);
    } catch (error) {
      return ScanItemApplyRun(
        appliedKeys: applied,
        remainingKeys: [for (final item in targets.skip(index)) item.key],
        repositoryRevision: revision,
        failed: target,
        error: '$error',
      );
    }
  }
  return ScanItemApplyRun(
    appliedKeys: applied,
    remainingKeys: const [],
    repositoryRevision: revision,
  );
}
