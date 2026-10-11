// 메타데이터 관리자 서비스(M2): 새 6 메서드를 strict DTO로 부르는 실제 서비스와, 백엔드 없이 여는 mock(오프라인) 서비스.
//
// - 실제: [ToolEnvelopeTransport](기본은 Python 도구 프로세스)로 exact 요청을 보내고 응답 envelope를
//   `metadata_manager_dto.dart`로 검사한다. 새 서비스 메서드는 Python 쪽에 이미 있는 6개뿐이다(XB M1 `1fbc4ddd`).
// - mock: 아무것도 부르지 않고 [MetadataManagerUnavailable]을 던진다. 화면은 이것을 오류가 아니라 "저장소 미연결 · 빈
//   상태"로 그린다(값을 지어내지 않는다).
// - [MockToolBackend]: mock 모드에서 ① 학생 탭의 기존 편집기가 빈 목록으로 열리게 하는 레거시 백엔드다.
import 'metadata_manager_dto.dart';
import 'tool_backend_client.dart';

/// 새 메서드를 부를 수 없다(mock 모드 · 전송 없음). 오류가 아니라 빈 상태로 그린다.
class MetadataManagerUnavailable implements Exception {
  const MetadataManagerUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 메타데이터 관리자 새 6 메서드.
abstract interface class MetadataManagerService {
  /// 백엔드 없이 연 상태의 표시 이름(예: "mock 모드"). 실제 서비스면 null.
  String? get offlineLabel;

  Future<StoreStatus> storeStatus();
  Future<StoreVersions> storeVersions();
  Future<StoreDiff> storeDiff(StoreVersionRef from, StoreVersionRef to);
  Future<SourceView> sourceView(String studentId);
  Future<AssetMapList> assetMapList();
  Future<AssetCheck> assetMapCheck(AssetCheckScope scope);
}

/// [transport]로 부르는 실제 서비스.
class ProtocolMetadataManagerService implements MetadataManagerService {
  const ProtocolMetadataManagerService(this.transport);

  final ToolEnvelopeTransport transport;

  @override
  String? get offlineLabel => null;

  Future<T> _call<T>(
    MetadataManagerRequest request,
    T Function(Object? result) parse,
  ) async {
    final message = await transport.send(request.toJson());
    return parseMetadataManagerResponse(message, parse);
  }

  @override
  Future<StoreStatus> storeStatus() => _call(
    const MetadataManagerRequest.storeStatus(),
    StoreStatus.fromJson,
  );

  @override
  Future<StoreVersions> storeVersions() => _call(
    const MetadataManagerRequest.storeVersions(),
    StoreVersions.fromJson,
  );

  @override
  Future<StoreDiff> storeDiff(StoreVersionRef from, StoreVersionRef to) async =>
      _call(
        MetadataManagerRequest.storeDiff(from: from, to: to),
        StoreDiff.fromJson,
      );

  @override
  Future<SourceView> sourceView(String studentId) async =>
      _call(MetadataManagerRequest.sourceView(studentId), SourceView.fromJson);

  @override
  Future<AssetMapList> assetMapList() => _call(
    const MetadataManagerRequest.assetMapList(),
    AssetMapList.fromJson,
  );

  @override
  Future<AssetCheck> assetMapCheck(AssetCheckScope scope) =>
      _call(MetadataManagerRequest.assetMapCheck(scope), AssetCheck.fromJson);
}

/// 아무것도 부르지 않는 서비스(mock 모드 · envelope 전송이 없는 백엔드).
class OfflineMetadataManagerService implements MetadataManagerService {
  const OfflineMetadataManagerService({
    required this.label,
    required this.reason,
  });

  /// mock 모드(`--mock`): 백엔드 없이 창을 연다.
  const OfflineMetadataManagerService.mock()
    : this(
        label: 'mock 모드',
        reason: 'mock 모드로 열어 Python 백엔드를 부르지 않았습니다.',
      );

  /// 레거시 백엔드만 있어 새 메서드를 보낼 수 없다.
  const OfflineMetadataManagerService.unsupported()
    : this(
        label: '새 메서드 연결 없음',
        reason: '이 백엔드는 새 메서드 요청(envelope 전송)을 지원하지 않습니다.',
      );

  final String label;
  final String reason;

  @override
  String? get offlineLabel => label;

  Future<T> _unavailable<T>() => Future.error(MetadataManagerUnavailable(reason));

  @override
  Future<StoreStatus> storeStatus() => _unavailable();

  @override
  Future<StoreVersions> storeVersions() => _unavailable();

  @override
  Future<StoreDiff> storeDiff(StoreVersionRef from, StoreVersionRef to) =>
      _unavailable();

  @override
  Future<SourceView> sourceView(String studentId) => _unavailable();

  @override
  Future<AssetMapList> assetMapList() => _unavailable();

  @override
  Future<AssetCheck> assetMapCheck(AssetCheckScope scope) => _unavailable();
}

/// [client]에 맞는 메타데이터 관리자 서비스: envelope 전송을 지원하면 실제, 아니면 연결 없음.
MetadataManagerService metadataManagerServiceFor(ToolBackend client) =>
    client is ToolEnvelopeTransport
    ? ProtocolMetadataManagerService(client as ToolEnvelopeTransport)
    : const OfflineMetadataManagerService.unsupported();

/// mock 모드의 레거시 백엔드: 학생 목록은 비어 있고, 그 밖의 작업은 쓸 수 없다고 알린다.
class MockToolBackend implements ToolBackend {
  const MockToolBackend();

  @override
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    if (method == 'metadata.list') {
      // 필드 목록이 비면 편집기가 계속 읽는 중으로 보인다. 기본 네 필드만 두고 학생은 비운다.
      return {
        'fields': [
          {'name': 'student_id', 'label': 'Student ID', 'type': 'text'},
          {'name': 'display_name', 'label': 'Display Name', 'type': 'text'},
          {'name': 'template_name', 'label': 'Template File', 'type': 'text'},
          {'name': 'group', 'label': 'Group', 'type': 'text'},
        ],
        'students': <Map<String, dynamic>>[],
        'total': 0,
      };
    }
    throw const ToolBackendException('mock 모드에서는 Python 백엔드 작업을 쓸 수 없습니다.');
  }
}
