// 메타데이터 관리자 새 6 메서드 strict DTO 테스트(M2). 계약 fixture
// `contracts/fixtures/developer_tools_metadata_manager_m1_v1.json`(XB M1 `1fbc4ddd`)의 양성 · 음성 예와, fixture를 한 곳씩
// 바꾼 계약 위반 응답을 쓴다.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/developer_tools/metadata_manager_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            '../contracts/fixtures/developer_tools_metadata_manager_m1_v1.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// JSON 깊은 복사.
dynamic _copy(Object? value) => jsonDecode(jsonEncode(value));

final _parsers = <String, Object Function(Object? result)>{
  MetadataManagerMethod.storeStatus: StoreStatus.fromJson,
  MetadataManagerMethod.storeVersions: StoreVersions.fromJson,
  MetadataManagerMethod.storeDiff: StoreDiff.fromJson,
  MetadataManagerMethod.sourceView: SourceView.fromJson,
  MetadataManagerMethod.assetMapList: AssetMapList.fromJson,
  MetadataManagerMethod.assetMapCheck: AssetCheck.fromJson,
};

Matcher get _protocol => throwsA(isA<MetadataManagerProtocolException>());

void main() {
  final fixture = _fixture();
  final responses = {
    for (final item in fixture['responses'] as List)
      (item as Map)['method'] as String: item['message'] as Map<String, dynamic>,
  };

  /// [method] fixture 응답을 복사해 [edit]로 고친 뒤 읽는다.
  Object parseEdited(String method, void Function(dynamic message) edit) {
    final message = _copy(responses[method]);
    edit(message);
    return parseMetadataManagerResponse(message, _parsers[method]!);
  }

  group('양성(계약 fixture)', () {
    test('요청 6개를 읽고 같은 envelope로 다시 쓴다', () {
      final requests = fixture['requests'] as List;
      expect(requests, hasLength(6));
      for (final item in requests) {
        final raw = (item as Map)['request'];
        final request = MetadataManagerRequest.fromJson(raw);
        expect(request.method, item['method']);
        expect(request.toJson(), raw, reason: item['method'] as String);
      }
    });

    test('서비스가 만드는 요청이 fixture 요청과 같다', () {
      final requests = {
        for (final item in fixture['requests'] as List)
          (item as Map)['method'] as String: item['request'],
      };
      expect(
        const MetadataManagerRequest.storeStatus().toJson(),
        requests[MetadataManagerMethod.storeStatus],
      );
      expect(
        const MetadataManagerRequest.storeVersions().toJson(),
        requests[MetadataManagerMethod.storeVersions],
      );
      expect(
        MetadataManagerRequest.storeDiff(
          from: const StoreVersionRef(
            server: StoreServer.jp,
            versionId: 'jp-test-a',
          ),
          to: const StoreVersionRef(
            server: StoreServer.jp,
            versionId: 'jp-test-b',
          ),
        ).toJson(),
        requests[MetadataManagerMethod.storeDiff],
      );
      expect(
        MetadataManagerRequest.sourceView('test_student').toJson(),
        requests[MetadataManagerMethod.sourceView],
      );
      expect(
        const MetadataManagerRequest.assetMapList().toJson(),
        requests[MetadataManagerMethod.assetMapList],
      );
      expect(
        MetadataManagerRequest.assetMapCheck(AssetCheckScope.all).toJson(),
        requests[MetadataManagerMethod.assetMapCheck],
      );
    });

    test('store.status: 연결 · lock 고정 버전 · extract · 빠진 kind', () {
      final status = parseMetadataManagerResponse(
        responses[MetadataManagerMethod.storeStatus],
        StoreStatus.fromJson,
      );
      expect(status.connected, isTrue);
      expect(status.storeRoot, 'TEST_ONLY_TEMP_STORE');
      final pin = status.pins[StoreServer.jp]!;
      expect(pin.versionId, 'jp-test-a');
      expect(pin.clientVersion, 'TEST_ONLY');
      expect(pin.bundleRevision, isNull);
      expect(pin.files.keys, ['GameAssembly.dll']);
      expect(status.extracts.single.kind, 'exceldb-json');
      expect(status.extracts.single.files.keys, ['CharacterExcel.json']);
      expect(status.missingKinds, ['addressables-catalog']);
    });

    test('store.versions: 고정 표시 · manifest 해시', () {
      final versions = parseMetadataManagerResponse(
        responses[MetadataManagerMethod.storeVersions],
        StoreVersions.fromJson,
      );
      expect(versions.state, StoreConnection.connected);
      expect(versions.versions.map((version) => version.versionId), [
        'jp-test-a',
        'jp-test-b',
      ]);
      expect(versions.versions.first.pinned, isTrue);
      expect(versions.versions.last.pinned, isFalse);
      expect(
        versions.versions.last.ref,
        const StoreVersionRef(server: StoreServer.jp, versionId: 'jp-test-b'),
      );
    });

    test('store.diff: 상태 3종(미연결 · 없음 · 있음). 없음 · 미연결은 보고서 없이 not_verified다', () {
      final states = [
        for (final oracle in fixture['diff_state_oracles'] as List)
          parseMetadataManagerResponse(oracle, StoreDiff.fromJson),
      ];
      expect(states.map((diff) => diff.state), [
        StoreDiffState.disconnected,
        StoreDiffState.missing,
        StoreDiffState.available,
      ]);
      expect(states[0].report, isNull);
      expect(states[1].report, isNull);
      final report = states[2].report!;
      expect(report.levelOneFiles, {'GameAssembly.dll': StoreFileChange.same});
      expect(report.levelTwoExtracts['exceldb-json']!.keys, [
        'CharacterExcel.json',
      ]);
      expect(report.levelThreeBehavior, startsWith('NOT_COMPUTED'));
      expect(states[2].coverage, contains('existing-report-only'));
    });

    test('metadata.source.view: 미입증 출처를 그대로 담는다', () {
      final view = parseMetadataManagerResponse(
        responses[MetadataManagerMethod.sourceView],
        SourceView.fromJson,
      );
      expect(view.studentId, 'test_student');
      final field = view.fields.single;
      expect(field.field, 'metadata.school');
      expect(field.value, isNull);
      expect(field.valueState, SourceValueState.unknown);
      expect(field.sourceKnown, isFalse);
      expect(view.unavailableGroups, [
        'statistics_association',
        'store_field_comparison',
      ]);
      // fixture의 미입증 필드 예도 같은 DTO로 읽힌다.
      final unknown = SourceField.fromJson(
        fixture['unknown_existing_provenance'],
        'unknown_existing_provenance',
      );
      expect(unknown.valueState, SourceValueState.unknown);
    });

    test('asset_map.list · asset_map.check: M0 초안 · 로컬 구조만', () {
      final list = parseMetadataManagerResponse(
        responses[MetadataManagerMethod.assetMapList],
        AssetMapList.fromJson,
      );
      final asset = list.assets.single;
      expect(asset.plannerPath, 'frontend/assets/TEST_ONLY.txt');
      expect(asset.source, AssetMappingSource.manual);
      expect(asset.addressKey, isNull);
      expect(asset.clientKind, StoreServer.steam);
      final check = parseMetadataManagerResponse(
        responses[MetadataManagerMethod.assetMapCheck],
        AssetCheck.fromJson,
      );
      expect(check.scope, AssetCheckScope.all);
      expect(check.rows.single.localFile, AssetLocalFile.missing);
      expect(check.rows.single.mapping, AssetMappingSource.manual);
    });

    test('ok: false는 서버 실패(type · message)다', () {
      expect(
        () => parseMetadataManagerResponse(
          fixture['envelope_error'],
          StoreStatus.fromJson,
        ),
        throwsA(
          isA<MetadataManagerRemoteError>()
              .having((error) => error.type, 'type', 'ClientDataStoreError')
              .having(
                (error) => error.message,
                'message',
                'store_hash_mismatch: TEST_ONLY',
              ),
        ),
      );
    });
  });

  group('음성 요청(계약 fixture negative_requests)', () {
    final negatives = [
      for (final item in fixture['negative_requests'] as List)
        Map<String, dynamic>.from(item as Map),
    ];

    test('계약 모양이 아닌 요청은 읽지 않는다', () {
      // params null · version_id 경로 탈출 · student_id 경로 탈출.
      for (final index in [0, 2, 3]) {
        expect(
          () => MetadataManagerRequest.fromJson(negatives[index]['request']),
          _protocol,
          reason: negatives[index]['expected'] as String,
        );
      }
    });

    test('섞인 버전은 계약 모양으로는 맞고 서버가 거절한다(store_mixed_version)', () {
      final mixed = negatives[1];
      expect(mixed['expected'], contains('store_mixed_version'));
      final request = MetadataManagerRequest.fromJson(mixed['request']);
      expect(request.toJson(), mixed['request']);
    });

    test('서비스 요청 생성도 계약 모양을 지킨다', () {
      expect(() => MetadataManagerRequest.sourceView('../escape'), _protocol);
      expect(() => MetadataManagerRequest.sourceView(''), _protocol);
      expect(
        () => MetadataManagerRequest.storeDiff(
          from: const StoreVersionRef(
            server: StoreServer.jp,
            versionId: 'jp-test-a',
          ),
          to: const StoreVersionRef(
            server: StoreServer.jp,
            versionId: '../escape',
          ),
        ),
        _protocol,
      );
      expect(
        () => MetadataManagerRequest.fromJson({
          'version': 1,
          'method': 'store.status',
          'params': <String, dynamic>{},
          'extra': true,
        }),
        _protocol,
      );
      expect(
        () => MetadataManagerRequest.fromJson({
          'version': 1,
          'method': 'metadata.list',
          'params': <String, dynamic>{},
        }),
        _protocol,
      );
      expect(
        () => MetadataManagerRequest.fromJson({
          'version': 1,
          'method': 'asset_map.check',
          'params': {'scope': 'everything'},
        }),
        _protocol,
      );
    });
  });

  group('음성 응답(계약 위반)', () {
    test('envelope: 키 더함 · 빠짐 · 버전 · ok 타입 · 성공과 오류 섞임', () {
      expect(
        () => parseEdited(MetadataManagerMethod.storeStatus, (message) {
          message['extra'] = 1;
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeStatus, (message) {
          message.remove('version');
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeStatus, (message) {
          message['version'] = 2;
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeStatus, (message) {
          message['version'] = true;
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeStatus, (message) {
          message['ok'] = 'true';
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeStatus, (message) {
          message['error'] = {'type': 'X', 'message': 'Y'};
        }),
        _protocol,
      );
      expect(
        () => parseMetadataManagerResponse({
          'version': 1,
          'ok': false,
          'error': {'type': 'X'},
        }, StoreStatus.fromJson),
        _protocol,
      );
      expect(
        () => parseMetadataManagerResponse([1, 2], StoreStatus.fromJson),
        _protocol,
      );
    });

    test('store.status: 상태 enum · 검증 const · 빈 pins · 해시 모양 · 모르는 서버', () {
      final edits = <void Function(dynamic result)>[
        (result) => result['state'] = 'unknown',
        (result) => result['verification'] = 'verified',
        (result) => result['pins'] = <String, dynamic>{},
        (result) => result['pins']['jp']['files']['GameAssembly.dll'] = 'ABC',
        (result) => result['pins']['jp']['files'] = <String, dynamic>{},
        (result) => result['pins']['kr'] = result['pins']['jp'],
        (result) => result['extracts'][0]['server'] = 'kr',
        (result) => result['extracts'][0]['provenance_sha256'] = '0' * 63,
        (result) => result['missing_kinds'] = [1],
        (result) => result['pins']['jp'].remove('bundle_revision'),
      ];
      for (final (index, edit) in edits.indexed) {
        expect(
          () => parseEdited(
            MetadataManagerMethod.storeStatus,
            (message) => edit(message['result']),
          ),
          _protocol,
          reason: 'edit $index',
        );
      }
    });

    test('store.versions: 미연결인데 목록 있음 · manifest 검증 const', () {
      expect(
        () => parseEdited(MetadataManagerMethod.storeVersions, (message) {
          message['result']['state'] = 'disconnected';
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeVersions, (message) {
          message['result']['versions'][0]['verification'] = 'full';
        }),
        _protocol,
      );
      expect(
        () => parseEdited(MetadataManagerMethod.storeVersions, (message) {
          message['result']['versions'][0]['pinned'] = 'yes';
        }),
        _protocol,
      );
    });

    test('store.diff: 상태와 보고서 · 검증 짝이 다르면 거절(없음을 차이 0으로 만들지 않는다)', () {
      final edits = <void Function(dynamic result)>[
        (result) => result['report'] = null,
        (result) => result['verification'] = 'not_verified',
        (result) => result['state'] = 'missing',
        (result) => result['report']['schema'] = 'other',
        (result) => result['report']['level1_files']['GameAssembly.dll'] = 'x',
        (result) => result['report']['generated_utc'] = 'yesterday',
        (result) => result['from']['version_id'] = '../escape',
      ];
      for (final (index, edit) in edits.indexed) {
        expect(
          () => parseEdited(
            MetadataManagerMethod.storeDiff,
            (message) => edit(message['result']),
          ),
          _protocol,
          reason: 'edit $index',
        );
      }
      final missingWithReport = _copy(
        (fixture['diff_state_oracles'] as List)[1],
      );
      missingWithReport['result']['report'] = _copy(
        responses[MetadataManagerMethod.storeDiff]!['result']['report'],
      );
      expect(
        () => parseMetadataManagerResponse(missingWithReport, StoreDiff.fromJson),
        _protocol,
      );
    });

    test('metadata.source.view: 출처 · 비교를 지어낸 응답은 거절', () {
      final edits = <void Function(dynamic field)>[
        (field) => field['provenance'] = {'kind': 'exceldb-json'},
        (field) => field['comparisons'] = [
          {'source': 'store'},
        ],
        (field) => field['source_state'] = 'known',
        (field) => field['value_state'] = 'guessed',
      ];
      for (final (index, edit) in edits.indexed) {
        expect(
          () => parseEdited(
            MetadataManagerMethod.sourceView,
            (message) => edit(message['result']['fields'][0]),
          ),
          _protocol,
          reason: 'edit $index',
        );
      }
      expect(
        () => parseEdited(MetadataManagerMethod.sourceView, (message) {
          message['result']['comparison_state'] = 'verified';
        }),
        _protocol,
      );
    });

    test('asset_map.list: manual에 주소 키 · catalog에 번들 없음 · 경로 탈출 · 상태 const', () {
      final edits = <void Function(dynamic result)>[
        (result) => result['assets'][0]['addressKey'] = 'key',
        (result) => result['assets'][0]['source'] = 'catalog',
        (result) {
          result['assets'][0]
            ..['source'] = 'catalog'
            ..['addressKey'] = 'key'
            ..['bundle'] = 'dir/file.bundle';
        },
        (result) => result['assets'][0]['plannerPath'] = '../escape.png',
        (result) => result['assets'][0]['plannerPath'] = r'C:\abs.png',
        (result) => result['assets'][0]['plannerPath'] = 'frontend/a\nb.png',
        (result) => result['assets'][0]['note'] = '',
        (result) => result['inventory_status'] = 'M1',
        (result) => result['verification'] = 'verified',
      ];
      for (final (index, edit) in edits.indexed) {
        expect(
          () => parseEdited(
            MetadataManagerMethod.assetMapList,
            (message) => edit(message['result']),
          ),
          _protocol,
          reason: 'edit $index',
        );
      }
      // catalog 매핑(주소 키 · 번들 있음)은 받는다.
      final catalog = parseEdited(MetadataManagerMethod.assetMapList, (message) {
        message['result']['assets'][0]
          ..['source'] = 'catalog'
          ..['addressKey'] = 'Assets/_MX/UI/test.png'
          ..['bundle'] = 'ui-test.bundle';
      }) as AssetMapList;
      expect(catalog.assets.single.source, AssetMappingSource.catalog);
    });

    test('asset_map.check: 실물 검증을 주장하는 응답은 거절', () {
      final edits = <void Function(dynamic result)>[
        (result) => result['physical_validation'] = 'done',
        (result) => result['source_verification'] = 'physical',
        (result) => result['rows'][0]['physical_state'] = 'ok',
        (result) => result['rows'][0]['structure_state'] = 'invalid',
        (result) => result['rows'][0]['local_file_state'] = 'unknown',
        (result) => result['scope'] = 'everything',
      ];
      for (final (index, edit) in edits.indexed) {
        expect(
          () => parseEdited(
            MetadataManagerMethod.assetMapCheck,
            (message) => edit(message['result']),
          ),
          _protocol,
          reason: 'edit $index',
        );
      }
    });
  });
}
