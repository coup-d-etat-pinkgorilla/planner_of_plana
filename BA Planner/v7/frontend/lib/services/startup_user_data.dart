// SU1(contracts/startup-user-data-v1): 사용자 데이터 이관이 실패해 백엔드가 제한된 시작 상태로 남았을 때의 전역 오류.
//
// 백엔드는 모든 신뢰된 요청에 같은 `user_data_migration_failed`를 돌려준다(method별 오류 집합보다 먼저).
// details는 정확히 `reason`(아래 enum) · `source_kept: true` · `restart_required: true`다. 모르는 키 · 다른 값 · 누락은
// 해독하지 않는다(프로토콜 오류). 재연결로는 풀리지 않고 원인을 해결한 뒤 앱을 다시 시작해야 한다.
import 'package:flutter/foundation.dart';

const userDataMigrationFailedCode = 'user_data_migration_failed';

/// 계약 `details.reason` 허용 목록(schema enum 순서).
enum UserDataMigrationReason {
  userDataBusy('user_data_busy'),
  userDataLinkNotMigrated('user_data_link_not_migrated'),
  userDataFolderInvalid('user_data_folder_invalid'),
  v7UserRootInvalid('v7_user_root_invalid'),
  v7DestinationUnrecognised('v7_destination_unrecognised'),
  legacyRepositoryRecoveryRequired('legacy_repository_recovery_required'),
  userDataChangedDuringMigration('user_data_changed_during_migration'),
  userDataIoError('user_data_io_error'),
  userDataMigrationFailed('user_data_migration_failed');

  const UserDataMigrationReason(this.wire);

  final String wire;

  static UserDataMigrationReason? fromWire(Object? value) {
    for (final reason in values) {
      if (reason.wire == value) return reason;
    }
    return null;
  }
}

/// 받은 시작 차단 오류. 한 번 잡히면 이 앱 실행 동안 풀리지 않는다(`restart_required`).
@immutable
class UserDataMigrationFailure {
  const UserDataMigrationFailure({required this.reason, required this.message});

  final UserDataMigrationReason reason;

  /// 백엔드 안내 문구(경로 · 파일명 · 예외 원문 없음). 화면은 reason별 앱 문구를 쓴다.
  final String message;

  /// 응답 `payload.error` 전체를 strict 해독한다. 키는 정확히 code · message · details(`retryable` 없음).
  static UserDataMigrationFailure? fromWireError(Map<String, dynamic> error) {
    const errorKeys = {'code', 'message', 'details'};
    const detailKeys = {'reason', 'source_kept', 'restart_required'};
    final message = error['message'];
    final details = error['details'];
    if (error.length != errorKeys.length ||
        !error.keys.toSet().containsAll(errorKeys) ||
        error['code'] != userDataMigrationFailedCode ||
        message is! String ||
        message.isEmpty ||
        details is! Map ||
        details.length != detailKeys.length ||
        !details.keys.toSet().containsAll(detailKeys) ||
        details['source_kept'] != true ||
        details['restart_required'] != true) {
      return null;
    }
    final reason = UserDataMigrationReason.fromWire(details['reason']);
    if (reason == null) return null;
    return UserDataMigrationFailure(reason: reason, message: message);
  }

  Map<String, dynamic> toWireDetails() => {
    'reason': reason.wire,
    'source_kept': true,
    'restart_required': true,
  };

  @override
  bool operator ==(Object other) =>
      other is UserDataMigrationFailure &&
      other.reason == reason &&
      other.message == message;

  @override
  int get hashCode => Object.hash(reason, message);
}
