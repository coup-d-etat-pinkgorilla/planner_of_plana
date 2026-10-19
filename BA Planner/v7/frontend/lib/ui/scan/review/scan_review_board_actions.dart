import '../../../services/scanner_service.dart';

/// 학생 결과 검토 보드가 바깥(스캔 세션 컨트롤러, FE8-g4b)에 맡기는 일(FE8-g4a).
///
/// 보드는 이 인터페이스만 부르고 서비스 · 세션 · idempotency key를 모른다. 형식은 FB-10 고정 선언(backend 로그
/// 2026-10-18 01:30)의 candidate review · revalidate · commit 그대로다.
/// - [approve]: `scanner.candidate.review`(approve = true). 새 candidate revision을 돌려준다. 실패하면 던진다.
/// - [commit]: `scanner.candidate.commit`. [expectedRepositoryRevision]은 보드가 앞 commit 응답 revision으로 잇는다
///   (FD-144 프론트 순차 일괄 적용). 응답의 repository revision을 돌려준다. 실패하면 던진다 — 보드는 그 학생에서
///   멈추고 나머지 후보를 그대로 둔다. 같은 의도의 재전송(같은 요청 · 같은 key)은 구현이 정한다.
/// - [revalidate]: `scanner.candidate.review`(approve = false, 학생 계산 재검증). 새 revision 후보를 돌려주고, 실패하면
///   null(오류 글자는 구현이 `ScanStudentReviewBoard.candidateErrors`로 보인다).
/// - [hold]: 보류(백엔드 호출 없음 — 지금 컨트롤러와 같다).
/// - [discard]: 폐기(review approve = false, 폐기 사유).
abstract interface class ScanStudentReviewBoardActions {
  Future<ScannerCandidate> approve(ScannerCandidate candidate);

  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  });

  Future<ScannerCandidate?> revalidate(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
    Map<int, int> relationshipRanks,
    Set<String> confirmedFields,
  );

  Future<void> hold(ScannerCandidate candidate);

  Future<void> discard(ScannerCandidate candidate);
}

/// 순차 적용 한 번의 결과.
class ScanReviewApplyRun {
  const ScanReviewApplyRun({
    required this.appliedIds,
    required this.remainingIds,
    required this.repositoryRevision,
    this.failed,
    this.error,
  });

  /// 적용에 성공한 후보 id(적용한 순서).
  final List<String> appliedIds;

  /// 적용하지 않고 남긴 후보 id(멈춘 후보 포함, 원래 순서).
  final List<String> remainingIds;

  /// 마지막으로 알게 된 repository revision(성공이 없으면 시작 revision).
  final int repositoryRevision;

  /// 멈춘 후보. 모두 성공했거나 보드가 사라져 멈췄으면 null.
  final ScannerCandidate? failed;
  final String? error;

  bool get stopped => failed != null;
}

/// FD-144 프론트 순차 적용: 후보마다 approve(이미 승인된 후보는 건너뜀) → commit. commit 응답 revision을 다음 후보의
/// expected로 쓰고, 어느 단계든 실패하면 그 후보에서 멈춰 나머지를 남긴다. [isActive]가 false가 되면(보드가 사라짐)
/// 다음 후보를 시작하지 않는다. [onStep]은 후보를 시작하기 전에 부른다(앞에서 끝난 수, 지금 후보).
Future<ScanReviewApplyRun> runScanReviewSequentialApply({
  required List<ScannerCandidate> candidates,
  required int startRevision,
  required ScanStudentReviewBoardActions actions,
  bool Function()? isActive,
  void Function(int done, ScannerCandidate candidate)? onStep,
}) async {
  var revision = startRevision;
  final applied = <String>[];
  for (var index = 0; index < candidates.length; index += 1) {
    final candidate = candidates[index];
    if (isActive != null && !isActive()) {
      return ScanReviewApplyRun(
        appliedIds: applied,
        remainingIds: [for (final item in candidates.skip(index)) item.id],
        repositoryRevision: revision,
      );
    }
    onStep?.call(index, candidate);
    try {
      final approved = candidate.approved
          ? candidate
          : await actions.approve(candidate);
      revision = await actions.commit(
        approved,
        expectedRepositoryRevision: revision,
      );
      applied.add(candidate.id);
    } catch (error) {
      return ScanReviewApplyRun(
        appliedIds: applied,
        remainingIds: [for (final item in candidates.skip(index)) item.id],
        repositoryRevision: revision,
        failed: candidate,
        error: '$error',
      );
    }
  }
  return ScanReviewApplyRun(
    appliedIds: applied,
    remainingIds: const [],
    repositoryRevision: revision,
  );
}
