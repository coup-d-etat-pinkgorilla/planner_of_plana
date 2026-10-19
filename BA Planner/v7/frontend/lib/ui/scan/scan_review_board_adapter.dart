// 학생 결과 검토 보드(FE8-g4a)의 바깥 일을 셸 소유 스캔 세션 컨트롤러로 잇는 어댑터(FE8-g4b, FD-144).
//
// - approve · commit: 컨트롤러 공개 2단계([ScanSessionController.approveStudentCandidate] ·
//   [ScanSessionController.commitApprovedStudentCandidate]) 그대로. 실패하면 던진다(보드가 그 학생에서 멈춘다).
// - revalidate: 지금 재검증(`revalidateStudentCandidate`, void) 뒤 그 후보의 revision이 올랐으면 새 후보, 아니면 null
//   (실패 글자는 컨트롤러 `candidateErrors`가 보드에 보인다).
// - hold · discard: 지금 공개 메서드 그대로.
import '../../services/scanner_service.dart';
import 'review/scan_student_review_board.dart';
import 'scan_session_controller.dart';

class ScanReviewBoardControllerActions
    implements ScanStudentReviewBoardActions {
  const ScanReviewBoardControllerActions(this.controller);

  final ScanSessionController controller;

  @override
  Future<ScannerCandidate> approve(ScannerCandidate candidate) =>
      controller.approveStudentCandidate(candidate);

  @override
  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  }) => controller.commitApprovedStudentCandidate(
    approved,
    expectedRepositoryRevision: expectedRepositoryRevision,
  );

  @override
  Future<ScannerCandidate?> revalidate(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
    Map<int, int> relationshipRanks,
    Set<String> confirmedFields,
  ) async {
    await controller.revalidateStudentCandidate(
      candidate,
      candidatePayload,
      relationshipRanks,
      confirmedFields,
    );
    final revised = controller.candidates[candidate.id];
    if (revised == null ||
        revised.sessionId != candidate.sessionId ||
        revised.generation != candidate.generation ||
        revised.revision == candidate.revision) {
      return null;
    }
    return revised;
  }

  @override
  Future<void> hold(ScannerCandidate candidate) =>
      controller.holdStudentCandidate(candidate);

  @override
  Future<void> discard(ScannerCandidate candidate) =>
      controller.discardStudentCandidate(candidate);
}
