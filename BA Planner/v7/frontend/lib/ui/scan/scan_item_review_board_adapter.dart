// 아이템 결과 검토 보드(FE8-g5a)를 셸 소유 스캔 세션 컨트롤러로 잇는 어댑터와 값 연결(FE8-g5b, FD-146 · FD-153).
//
// - approveSubset · commit: 컨트롤러 공개 2단계([ScanSessionController.approveInventoryCandidateSubset] ·
//   [ScanSessionController.commitApprovedInventoryCandidate]) 그대로. 실패하면 던진다(보드가 그 종류에서 멈춘다).
// - assignIdentity · skipIdentity: 지금 미식별 지정 · 건너뛰기(`assignInventoryIdentity` · `skipInventoryIdentity`) 그대로.
// - 적용 · 지정은 후보(세션 · generation · id) 열쇠로만 한다. 종류(세션)마다 후보를 따로 두고 섞지 않는다.
// - 종류([scanItemReviewKindsFor]): 끝난 아이템 큐의 종류(칸 순서). 지금 큐 밖의 아이템 기록(앞선 큐 · 예전 화면 1종 시작)을
//   열었으면 그 기록 하나를 1종으로 본다. 후보는 컨트롤러 [ScanSessionController.itemReviewCandidates](최신 revision, 원 결과
//   payload — 부분 승인 review가 줄인 revision은 넣지 않는다).
import '../../services/scanner_service.dart';
import 'item_review/scan_item_review_board.dart';
import 'scan_header_progress.dart' show scanCandidateKey;
import 'scan_item_queue.dart';
import 'scan_session_controller.dart';

class ScanItemReviewBoardControllerActions
    implements ScanItemReviewBoardActions {
  const ScanItemReviewBoardControllerActions(this.controller);

  final ScanSessionController controller;

  @override
  Future<ScannerCandidate> approveSubset(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
  ) => controller.approveInventoryCandidateSubset(candidate, candidatePayload);

  @override
  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  }) => controller.commitApprovedInventoryCandidate(
    approved,
    expectedRepositoryRevision: expectedRepositoryRevision,
  );

  @override
  Future<void> assignIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
    String identity,
    bool persist,
  ) => controller.assignInventoryIdentity(candidate, slot, identity, persist);

  @override
  Future<void> skipIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
  ) => controller.skipInventoryIdentity(candidate, slot);
}

/// 아이템 결과 검토 보드의 종류(끝난 뒤에만, 큐 진행 중이면 빈 목록). 지금 보이는 세션이 끝난 아이템 큐의 종류면 그 큐, 큐 밖의
/// 아이템 기록이면 그 기록 1종이다. 학생 · 전술 로비 기록이 보이는데 그 기록에 남은 후보가 없고 끝난 아이템 큐에 남은 후보가 있으면
/// 그 큐다(FE8-g5b 규칙 4 — 보이는 기록에 남은 후보가 있으면 그 기록의 검토가 먼저다). [appliedElsewhere]는 다른 탭이 적용한
/// 후보([scanCandidateKey]).
List<ScanItemReviewKind> scanItemReviewKindsFor(
  ScanSessionController controller, {
  Set<String> appliedElsewhere = const {},
}) {
  final session = controller.session;
  if (controller.stage != ScanSessionStage.terminal ||
      controller.itemQueueRunning ||
      session == null) {
    return const [];
  }
  final queue = controller.itemQueue;
  final List<ScanQueueKind> kinds;
  if (session.kind != ScannerKind.inventory) {
    final ownPending = controller.candidates.values.any(
      (candidate) => !appliedElsewhere.contains(scanCandidateKey(candidate)),
    );
    if (ownPending || queue == null) return const [];
    kinds = queue.kinds;
  } else if (queue != null && queue.indexOf(session) != null) {
    kinds = queue.kinds;
  } else {
    final summary = controller.recent
        .where(
          (item) =>
              item.sessionId == session.id &&
              item.generation == session.generation,
        )
        .firstOrNull;
    final profile = controller.recentDetail(session)?.inventoryScanProfile;
    if (summary == null || profile == null) return const [];
    kinds = [
      ScanQueueKind(
        profile: profile,
        status: switch (summary.outcome) {
          'completed' => ScanQueueStatus.completed,
          'cancelled' => ScanQueueStatus.cancelled,
          _ => ScanQueueStatus.failed,
        },
        session: session,
        count: summary.progressCurrent,
        result: summary,
      ),
    ];
  }
  return [
    for (final kind in kinds)
      _reviewKind(controller, kind, appliedElsewhere: appliedElsewhere),
  ];
}

ScanItemReviewKind _reviewKind(
  ScanSessionController controller,
  ScanQueueKind kind, {
  required Set<String> appliedElsewhere,
}) {
  final result = controller.itemQueueResult(kind);
  return ScanItemReviewKind(
    queue: kind,
    result: result,
    candidates: controller.itemReviewCandidates(
      result,
      appliedElsewhere: appliedElsewhere,
    ),
    appliedElsewhere:
        result?.candidates.any(
          (candidate) =>
              controller.candidateResolution(candidate) == true ||
              appliedElsewhere.contains(scanCandidateKey(candidate)),
        ) ??
        false,
  );
}

/// 보드가 받는 미식별 슬롯 · identity 상태(후보 열쇠 · 슬롯 열쇠 [scanItemSlotKey]).
typedef ScanItemReviewSlotState = ({
  Map<String, List<ScannerUnresolvedSlot>> slots,
  Set<String> busy,
  Map<String, String> errors,
  Set<String> skipped,
  Map<String, String> candidateErrors,
});

/// [kinds] 후보의 미식별 슬롯 · 지정 중 · 오류 · 건너뜀(컨트롤러 값 그대로, 지금 보이는 세션이 아닌 종류 포함).
ScanItemReviewSlotState scanItemReviewSlotStateFor(
  ScanSessionController controller,
  List<ScanItemReviewKind> kinds,
) {
  final slots = <String, List<ScannerUnresolvedSlot>>{};
  final busy = <String>{};
  final errors = <String, String>{};
  final skipped = <String>{};
  final candidateErrors = <String, String>{};
  for (final kind in kinds) {
    for (final candidate in kind.candidates) {
      final key = scanCandidateKey(candidate);
      final error = controller.unresolvedErrorOf(candidate);
      if (error != null) candidateErrors[key] = error;
      final unresolved = controller.unresolvedSlotsOf(candidate);
      if (unresolved == null) continue;
      slots[key] = unresolved;
      for (final slot in unresolved) {
        final slotKey = scanItemSlotKey(candidate, slot.slot);
        if (controller.identityBusyOf(candidate, slot.slot)) busy.add(slotKey);
        if (controller.identitySkippedOf(candidate, slot.slot)) {
          skipped.add(slotKey);
        }
        final failure = controller.identityErrorOf(candidate, slot.slot);
        if (failure != null) errors[slotKey] = failure;
      }
    }
  }
  return (
    slots: slots,
    busy: busy,
    errors: errors,
    skipped: skipped,
    candidateErrors: candidateErrors,
  );
}

/// 보드 후보들이 읽은 아이템의 정규 resource key(마지막 스캔 글자를 읽을 대상, FD-147).
Set<String> scanItemReviewResourceKeys(List<ScanItemReviewKind> kinds) => {
  for (final kind in kinds)
    for (final candidate in kind.candidates)
      if (candidate.payload['entries'] case final List entries)
        for (final entry in entries)
          if (entry is Map) ?scanItemEntryKey(Map<String, dynamic>.from(entry)),
};
