// 메타데이터 관리자 도구 창 테스트(M2): 등록표 · 탭 전환 · mock 빈 상태 · 계약 fixture로 채운 세 탭 · 오류 표시 · 옛 이름
// alias. 개발자 도구는 golden 범위 밖이라 위젯 테스트로 고정한다.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/developer_tools/metadata_manager_dto.dart';
import 'package:ba_planner_v7/developer_tools/metadata_manager_page.dart';
import 'package:ba_planner_v7/developer_tools/metadata_manager_service.dart';
import 'package:ba_planner_v7/developer_tools/tool_backend_client.dart';
import 'package:ba_planner_v7/developer_tools_main.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            '../contracts/fixtures/developer_tools_metadata_manager_m1_v1.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// 새 메서드 응답을 돌려주는 전송. 보낸 요청을 남긴다.
class _FakeTransport implements ToolEnvelopeTransport {
  _FakeTransport(this.responses);

  final Map<String, Object? Function(Map<String, Object?> request)> responses;
  final requests = <Map<String, Object?>>[];

  @override
  Future<Object?> send(Map<String, Object?> request) async {
    requests.add(request);
    final respond = responses[request['method']];
    if (respond == null) throw StateError('Unexpected method ${request['method']}');
    return jsonDecode(jsonEncode(respond(request)));
  }
}

/// ① 학생 탭 편집기용 레거시 백엔드(학생 한 명).
class _LegacyClient implements ToolBackend {
  @override
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    switch (method) {
      case 'metadata.list':
        return {
          'fields': [
            {'name': 'student_id', 'label': 'Student ID', 'type': 'text'},
            {'name': 'display_name', 'label': 'Display Name', 'type': 'text'},
            {'name': 'template_name', 'label': 'Template File', 'type': 'text'},
            {'name': 'group', 'label': 'Group', 'type': 'text'},
          ],
          'students': [
            {
              'student_id': 'hoshino',
              'display_name': '호시노',
              'group': '호시노',
              'template_name': 'hoshino.png',
              'jp_only': false,
            },
          ],
          'total': 1,
        };
      case 'metadata.get':
        return {
          'student_id': params['student_id'],
          'jp_only': false,
          'metadata': {
            'display_name': '호시노',
            'template_name': 'hoshino.png',
            'group': '호시노',
          },
        };
      case 'metadata.forms.get':
        return {
          'student_id': params['student_id'],
          'forms': <dynamic>[],
          'form_count': 0,
        };
    }
    throw StateError('Unexpected method: $method');
  }
}

Future<void> _pumpTool(
  WidgetTester tester,
  DeveloperToolServices services, {
  Size size = const Size(1600, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    DeveloperToolApp.services(toolId: 'metadata-manager', services: services),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, MetadataManagerTab tab) async {
  await tester.tap(find.text(metadataManagerTabLabel(tab)));
  await tester.pumpAndSettle();
}

void main() {
  final fixture = _fixture();
  final responses = {
    for (final item in fixture['responses'] as List)
      (item as Map)['method'] as String: item['message'],
  };

  _FakeTransport fixtureTransport({
    Map<String, Object? Function(Map<String, Object?> request)> overrides =
        const {},
  }) => _FakeTransport({
    for (final entry in responses.entries) entry.key: (_) => entry.value,
    ...overrides,
  });

  group('등록표', () {
    test('도구 id는 겹치지 않고, 옛 이름 · 모르는 이름은 메타데이터 관리자로 간다', () {
      final ids = developerTools.map((entry) => entry.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, [
        'metadata-manager',
        'student-template',
        'inventory-grid',
      ]);
      expect(developerToolFor('student-metadata').id, 'metadata-manager');
      expect(developerToolFor('metadata-manager').id, 'metadata-manager');
      expect(developerToolFor('inventory-grid').id, 'inventory-grid');
      expect(developerToolFor('nope').id, defaultDeveloperToolId);
      expect(developerToolFor(null).id, defaultDeveloperToolId);
      expect(developerToolFor('').id, defaultDeveloperToolId);
      for (final tool in DeveloperTool.values) {
        expect(developerToolFor(tool.id).matches(tool.id), isTrue);
      }
      expect(
        developerToolFor('student-template').title,
        'BA Planner v7 · 학생 템플릿 추출기',
      );
    });
  });

  testWidgets('mock 모드: 백엔드 없이 열리고 세 탭이 미연결 · 빈 상태다', (tester) async {
    await _pumpTool(tester, const DeveloperToolServices.mock());

    expect(find.text('BA Planner v7 · 메타데이터 관리자'), findsOneWidget);
    expect(find.byKey(const ValueKey('metadata-manager-offline')), findsOneWidget);
    expect(find.text('mock 모드'), findsOneWidget);
    for (final tab in MetadataManagerTab.values) {
      expect(find.text(metadataManagerTabLabel(tab)), findsOneWidget);
    }
    // ① 학생: 빈 편집기 + 학생을 고르라는 출처 패널(1400 이상이라 펼침).
    expect(
      find.byKey(const ValueKey('metadata-manager-source-empty')),
      findsOneWidget,
    );

    await _openTab(tester, MetadataManagerTab.sources);
    expect(
      find.byKey(const ValueKey('metadata-manager-status-error')),
      findsOneWidget,
    );
    expect(find.text('저장소 미연결'), findsNWidgets(2));
    expect(find.textContaining('mock 모드로 열어'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('metadata-manager-diff-unavailable')),
      findsOneWidget,
    );

    await _openTab(tester, MetadataManagerTab.assets);
    expect(find.text('실물 검증 아님(M4 필요)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('metadata-manager-assets-error')),
      findsOneWidget,
    );
    expect(find.text('빈 상태'), findsNWidgets(2));

    await _openTab(tester, MetadataManagerTab.updates);
    expect(find.text('M5에서 채웁니다.'), findsOneWidget);
    await _openTab(tester, MetadataManagerTab.release);
    expect(find.text('M6에서 채웁니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('계약 fixture로 세 탭을 채운다(exact 요청 envelope)', (tester) async {
    final transport = fixtureTransport();
    await _pumpTool(
      tester,
      DeveloperToolServices(
        client: _LegacyClient(),
        metadataManager: ProtocolMetadataManagerService(transport),
      ),
    );

    // ① 학생: 학생을 고르면 출처 패널이 metadata.source.view를 부른다. 미입증 출처는 "확인되지 않음".
    await tester.tap(find.text('호시노').first);
    await tester.pumpAndSettle();
    expect(transport.requests.last, {
      'version': 1,
      'method': 'metadata.source.view',
      'params': {'student_id': 'hoshino'},
    });
    expect(
      find.byKey(const ValueKey('metadata-manager-source-metadata.school')),
      findsOneWidget,
    );
    expect(find.text('값 없음'), findsOneWidget);
    expect(find.text('확인되지 않음'), findsNWidgets(3));
    expect(find.text('store_field_comparison'), findsOneWidget);

    // ② 출처.
    await _openTab(tester, MetadataManagerTab.sources);
    expect(
      find.byKey(const ValueKey('metadata-manager-store-connected')),
      findsOneWidget,
    );
    expect(find.text('TEST_ONLY_TEMP_STORE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('metadata-manager-missing-addressables-catalog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('metadata-manager-pin-jp')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('metadata-manager-version-jp-jp-test-a')),
      findsOneWidget,
    );
    expect(find.text('lock 고정'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('metadata-manager-diff-read')),
    );
    await tester.tap(find.byKey(const ValueKey('metadata-manager-diff-read')));
    await tester.pumpAndSettle();
    expect(transport.requests.last, {
      'version': 1,
      'method': 'store.diff',
      'params': {
        'from': {'server': 'jp', 'version_id': 'jp-test-a'},
        'to': {'server': 'jp', 'version_id': 'jp-test-b'},
      },
    });
    expect(
      find.byKey(const ValueKey('metadata-manager-diff-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('metadata-manager-diff-l1-GameAssembly.dll')),
      findsOneWidget,
    );
    expect(find.textContaining('NOT_COMPUTED'), findsOneWidget);

    // ③ 자산.
    await _openTab(tester, MetadataManagerTab.assets);
    expect(find.text('실물 검증 아님(M4 필요)'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'metadata-manager-asset-ui-frontend/assets/TEST_ONLY.txt',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('로컬 누락'), findsOneWidget);
    expect(find.text('1개 중 1개 표시 · 로컬 누락 1 · 수동 1'), findsOneWidget);
    for (final key in const [
      'metadata-manager-filter-renamed',
      'metadata-manager-filter-hash',
    ]) {
      expect(
        tester.widget<SkewToggleChip>(find.byKey(ValueKey(key))).onChanged,
        isNull,
      );
    }
    await tester.tap(find.byKey(const ValueKey('metadata-manager-filter-missing')));
    await tester.pumpAndSettle();
    expect(find.text('1개 중 1개 표시 · 로컬 누락 1 · 수동 1'), findsOneWidget);
    expect(
      transport.requests.where(
        (request) => request['method'] == 'asset_map.check',
      ),
      [
        {
          'version': 1,
          'method': 'asset_map.check',
          'params': {'scope': 'all'},
        },
      ],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('오류 표시: 서버 실패 · 계약 불일치 · 보고서 없음은 차이 0이 아니다', (tester) async {
    final oracles = fixture['diff_state_oracles'] as List;
    final transport = fixtureTransport(
      overrides: {
        'store.status': (_) => fixture['envelope_error'],
        'store.versions': (_) => {
          ...(responses['store.versions'] as Map),
          'extra': true,
        },
        'store.diff': (_) => oracles[1],
      },
    );
    await _pumpTool(
      tester,
      DeveloperToolServices(
        client: _LegacyClient(),
        metadataManager: ProtocolMetadataManagerService(transport),
      ),
    );
    await _openTab(tester, MetadataManagerTab.sources);

    expect(find.text('ClientDataStoreError: store_hash_mismatch: TEST_ONLY'), findsOneWidget);
    expect(find.text('읽기 실패'), findsOneWidget);
    expect(find.text('계약 불일치'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('metadata-manager-versions-error')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('store.diff missing은 "보고서 없음"으로 보인다', (tester) async {
    final oracles = fixture['diff_state_oracles'] as List;
    final transport = fixtureTransport(
      overrides: {'store.diff': (_) => oracles[1]},
    );
    await _pumpTool(
      tester,
      DeveloperToolServices(
        client: _LegacyClient(),
        metadataManager: ProtocolMetadataManagerService(transport),
      ),
    );
    await _openTab(tester, MetadataManagerTab.sources);
    await tester.ensureVisible(
      find.byKey(const ValueKey('metadata-manager-diff-read')),
    );
    await tester.tap(find.byKey(const ValueKey('metadata-manager-diff-read')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('metadata-manager-diff-missing')),
      findsOneWidget,
    );
    expect(find.textContaining('차이 0이 아닙니다'), findsOneWidget);
    expect(find.textContaining('L1 파일'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('옛 이름(student-metadata)은 같은 창 ① 학생 탭을 연다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.metadata, client: _LegacyClient()),
    );
    await tester.pumpAndSettle();

    expect(find.text('BA Planner v7 · 메타데이터 관리자'), findsOneWidget);
    expect(find.text('① 학생'), findsOneWidget);
    expect(find.text('호시노'), findsOneWidget);
    // 레거시 백엔드만 있으면 새 메서드는 부르지 않는다. 1400 미만이라 패널은 접혀 있다.
    expect(find.text('새 메서드 연결 없음'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('metadata-manager-source-open')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('metadata-manager-source-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호시노').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('metadata-manager-source-error')),
      findsOneWidget,
    );
    expect(find.textContaining('envelope 전송'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('메타데이터 관리자 서비스는 envelope 전송이 있을 때만 새 메서드를 부른다', () async {
    expect(
      metadataManagerServiceFor(_LegacyClient()).offlineLabel,
      '새 메서드 연결 없음',
    );
    expect(
      metadataManagerServiceFor(
        ToolBackendClient(backendDirectory: 'C:/not-used', pythonExecutable: 'python'),
      ),
      isA<ProtocolMetadataManagerService>(),
    );
    await expectLater(
      const OfflineMetadataManagerService.mock().storeStatus(),
      throwsA(isA<MetadataManagerUnavailable>()),
    );
    // DTO 예외 타입이 이 파일에서도 보이는지(계약 위반 문구).
    expect(
      const MetadataManagerProtocolException('x').toString(),
      contains('계약'),
    );
  });
}
