import '../../services/planning_protocol_client.dart'
    show BackendRemoteException;
import '../../services/scanner_service.dart';
import '../widgets/account_section_cluster.dart' show repositoryErrorCode;

/// `repository_busy`(재시도 가능)일 때 같은 요청을 다시 보내기 전의 대기 시간. 지수 backoff 최대 3회
/// (tactic 로그 2026-10-10 01:20 ②). 처음 시도까지 합쳐 4번 보낸다.
const List<Duration> scanRepositoryBusyRetryDelays = [
  Duration(milliseconds: 200),
  Duration(milliseconds: 400),
  Duration(milliseconds: 800),
];

/// [action]을 부르고, `repository_busy`면 [delays]대로 기다렸다가 **같은 [action]**을 다시 부른다.
/// 재시도가 끝나도 busy면 마지막 오류를 그대로 던진다. 다른 오류는 바로 던진다.
Future<T> retryRepositoryBusy<T>(
  Future<T> Function() action, {
  List<Duration> delays = scanRepositoryBusyRetryDelays,
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await action();
    } catch (error) {
      if (attempt >= delays.length ||
          repositoryErrorCode(error) != 'repository_busy') {
        rethrow;
      }
      await Future<void>.delayed(delays[attempt]);
    }
  }
}

/// 스캔 결과 적용(`scanner.candidate.commit`)이 실패한 까닭.
enum ScanApplyFailure {
  /// 응답을 받지 못해 저장됐는지 모른다(연결 끊김·시간 초과·응답 형식 오류). 같은 요청을 다시 보낼 수 있다.
  unknownOutcome,

  /// 재시도를 다 써도 저장소가 바빴다. 저장되지 않았고, 같은 요청을 나중에 다시 보낼 수 있다.
  busy,

  /// expected revision이 낡았다. 저장되지 않았다. 현재값을 다시 읽고 새 적용 의도로 다시 한다.
  revisionConflict,

  /// 백엔드가 요청을 거절했다(후보 revision 충돌, 검토 필요, 세션 없음 등). 저장되지 않았다.
  rejected,
}

/// [error]를 [ScanApplyFailure]로 나눈다. 백엔드 오류는 `BackendRemoteException`, mock 오류는
/// `StateError(code)`로 온다. 둘 다 아니면 응답을 받지 못한 것으로 본다.
ScanApplyFailure classifyScanApplyFailure(Object error) {
  if (error is! BackendRemoteException && error is! StateError) {
    return ScanApplyFailure.unknownOutcome;
  }
  return switch (repositoryErrorCode(error)) {
    'repository_busy' => ScanApplyFailure.busy,
    'revision_conflict' => ScanApplyFailure.revisionConflict,
    _ => ScanApplyFailure.rejected,
  };
}

/// 한 번의 "적용" 의도. 최초 승인 candidate·profile·expected revision·idempotency key를 고정한다
/// (XB S-FB2b 메모 2026-10-10 15:30). 같은 의도의 재시도는 이 값을 그대로 다시 보낸다: review를 다시 부르지
/// 않고, 그사이 다시 읽은 state revision으로 expected를 바꾸지 않는다. 새 의도는 새 key다.
class ScanPendingApply {
  const ScanPendingApply({
    required this.session,
    required this.candidate,
    required this.profileId,
    required this.expectedRepositoryRevision,
    required this.idempotencyKey,
  });

  final ScannerSession session;
  final ScannerCandidate candidate;
  final String profileId;
  final int expectedRepositoryRevision;
  final String idempotencyKey;

  /// 같은 세션·같은 후보 revision·같은 profile에서 다시 누른 "적용"이면 이 의도의 재시도다.
  bool isRetryOf(
    ScannerSession session,
    ScannerCandidate candidate,
    String profileId,
  ) =>
      this.session.id == session.id &&
      this.session.generation == session.generation &&
      this.candidate.id == candidate.id &&
      this.candidate.revision == candidate.revision &&
      this.profileId == profileId;
}

/// 후보 하나의 pending apply 자리. 세션 generation이 다르면 다른 자리다.
String scanPendingApplySlot(ScannerSession session, String candidateId) =>
    '${session.id}:${session.generation}:$candidateId';
