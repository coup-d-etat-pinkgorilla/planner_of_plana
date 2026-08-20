import 'dart:io';

import 'package:ba_planner_v7/developer_tools/tool_backend_client.dart';
import 'package:ba_planner_v7/developer_tools_main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MetadataClient implements ToolBackend {
  List<dynamic>? savedForms;
  String server = 'KR';
  List<String> mergePaths = ['hoshino_tank', 'hoshino_dealer'];

  @override
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    if (method == 'metadata.list') {
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
    }
    if (method == 'metadata.get') {
      return {
        'student_id': params['student_id'],
        'jp_only': false,
        'metadata': {
          'display_name': '호시노',
          'template_name': 'hoshino.png',
          'group': '호시노',
        },
      };
    }
    if (method == 'metadata.forms.get') {
      return {
        'student_id': params['student_id'],
        'forms': [
          {'label': '1', 'template_name': 'hoshino.png'},
          {'label': '2', 'template_name': 'hoshino_1.png'},
        ],
        'form_count': 2,
      };
    }
    if (method == 'metadata.forms.save') {
      savedForms = (params['forms'] as List).toList();
      return {
        'student_id': params['student_id'],
        'forms': savedForms,
        'form_count': savedForms!.length,
      };
    }
    if (method == 'metadata.debug.list') {
      return {
        'rows': [
          {
            'student_id': 'hoshino',
            'display_name': '호시노',
            'server': server,
            'group': '호시노',
            'variant': '—',
            'school': 'Abydos',
            'rarity': '3',
            'attack_type': 'Explosive',
            'defense_type': 'Heavy',
            'role': 'tanker',
            'position': 'front',
            'weapon_type': 'SG',
            'favorite_item_jp': 'yes',
            'favorite_item_kr': 'yes',
            'multi_form_count': 2,
            'portrait': true,
            'portrait_asset': null,
            'eleph': true,
            'eleph_asset': null,
            'match_found': 2,
            'match_total': 2,
          },
        ],
        'counts': {
          'all': 2,
          'kr': server == 'KR' ? 1 : 0,
          'jp': server == 'JP' ? 2 : 1,
        },
        'visible_count': 1,
      };
    }
    if (method == 'metadata.debug.get') {
      return {
        'student_id': 'hoshino',
        'display_name': '호시노',
        'template_name': 'hoshino.png',
        'server': server,
        'assets': {
          'portrait': true,
          'portrait_asset': null,
          'eleph': true,
          'eleph_asset': null,
          'match_found': 2,
          'match_total': 2,
        },
        'forms': [
          {'label': '1', 'template_name': 'hoshino.png', 'role': 'tanker'},
          {'label': '2', 'template_name': 'hoshino_1.png', 'role': 'dealer'},
        ],
        'form_count': 2,
        'fields': [
          {'name': 'student_id', 'label': 'Student ID', 'value': 'hoshino'},
          {'name': 'server', 'label': 'Server', 'value': server},
          {'name': 'school', 'label': 'School', 'value': 'Abydos'},
        ],
      };
    }
    if (method == 'metadata.server.set') {
      final previous = server;
      server = (params['server'] as String).toUpperCase();
      return {
        'student_id': params['student_id'],
        'previous_server': previous,
        'server': server,
        'changed': previous != server,
        'warnings': <String>[],
      };
    }
    if (method == 'metadata.merge_paths.list') {
      return {
        'rows': [
          {
            'student_id': 'hoshino',
            'display_name': '호시노',
            'template_name': 'hoshino.png',
            'paths': mergePaths,
            'path_count': mergePaths.length,
          },
        ],
        'rule_count': 1,
      };
    }
    if (method == 'metadata.merge_paths.save') {
      mergePaths = (params['paths'] as List)
          .map((value) => value.toString())
          .toList();
      return {
        'student_id': params['student_id'],
        'paths': mergePaths,
        'path_count': mergePaths.length,
      };
    }
    if (method == 'metadata.merge_paths.delete') {
      mergePaths = [];
      return {'student_id': params['student_id'], 'deleted': true};
    }
    if (method == 'metadata.items.analyze') {
      return {
        'source_label': 'v7 선택 계정 · 테스트',
        'inventory_path': 'C:/data/profile.json',
        'plan_path': null,
        'summary': {
          'catalog_count': 200,
          'snapshot_count': 3,
          'known_count': 2,
          'unknown_count': 1,
          'absent_count': 197,
          'missing_catalog_count': 0,
          'negative_count': 1,
          'zero_count': 1,
          'positive_count': 0,
        },
        'buckets': const <dynamic>[],
        'categories': [
          {
            'category': 'equipment',
            'catalog_count': 50,
            'snapshot_count': 2,
            'known_count': 2,
            'unknown_count': 0,
            'absent_count': 48,
            'coverage_percent': 4.0,
          },
        ],
        'rows': [
          {
            'resource_key': 'Equipment_Icon_Badge_Tier1',
            'item_id': 'Equipment_Icon_Badge_Tier1',
            'display_name': 'T1 배지',
            'category': 'equipment',
            'current_qty': 5,
            'plan_delta': -7,
            'adjusted_qty': -2,
            'status': 'negative',
            'index': 0,
            'icon_asset':
                'assets/item_icons/equipment/Equipment_Icon_Badge_Tier1.png',
          },
          {
            'resource_key': 'unknown-item',
            'item_id': null,
            'display_name': '미확인 아이템',
            'category': 'missing_catalog',
            'current_qty': null,
            'plan_delta': 0,
            'adjusted_qty': null,
            'status': 'unknown',
            'index': null,
            'icon_asset': null,
          },
        ],
      };
    }
    if (method == 'metadata.schaledb.single.preview') {
      return {
        'source_slug': 'hoshino',
        'student_id': 'hoshino',
        'exists': true,
        'matched_local_id': 'hoshino',
        'display_name': '호시노',
        'template_name': 'hoshino.png',
        'current': {
          'schaledb_id': 1,
          'favor_item_tags': <String>[],
          'favor_item_unique_tags': <String>[],
        },
        'incoming': {
          'schaledb_id': 10045,
          'favor_item_tags': ['aV'],
          'favor_item_unique_tags': ['Bf'],
        },
        'changed_fields': [
          'schaledb_id',
          'favor_item_tags',
          'favor_item_unique_tags',
        ],
        'special_gifts': [
          {
            'id': 5001,
            'name': 'Special Gift',
            'icon_asset': null,
            'exp_value': 20,
            'match_count': 2,
            'multiplier': 3,
            'points': 60,
          },
        ],
        'preferred_gifts': [
          {
            'id': 5000,
            'name': 'Wavecat Pillow',
            'icon_asset': null,
            'exp_value': 20,
            'match_count': 1,
            'multiplier': 2,
            'points': 40,
          },
        ],
        'gifts': const <dynamic>[],
        'gift_count': 52,
        'persisted_fields': const <String>[],
      };
    }
    if (method == 'metadata.schaledb.single.apply') {
      return {
        'student_id': 'hoshino',
        'updated_fields': ['schaledb_id'],
        'gift_count': 52,
      };
    }
    if (method == 'metadata.schaledb.preview') {
      return {
        'students': [
          {
            'student_id': 'hoshino',
            'display_name': '호시노',
            'template_name': 'hoshino.png',
            'jp_only': false,
            'current': {
              'schaledb_id': null,
              'favor_item_tags': [],
              'favor_item_unique_tags': [],
            },
            'incoming': {
              'schaledb_id': 10045,
              'favor_item_tags': ['aV'],
              'favor_item_unique_tags': ['Bf', 'de'],
            },
            'changed_fields': [
              'schaledb_id',
              'favor_item_tags',
              'favor_item_unique_tags',
            ],
            'special_gifts': [
              {
                'id': 5001,
                'name': 'Special Gift',
                'icon_asset': null,
                'exp_value': 20,
                'match_count': 2,
                'multiplier': 3,
                'points': 60,
              },
            ],
            'preferred_gifts': [
              {
                'id': 5000,
                'name': 'Wavecat Pillow',
                'icon_asset': null,
                'exp_value': 20,
                'match_count': 1,
                'multiplier': 2,
                'points': 40,
              },
            ],
          },
        ],
        'gifts': [
          {
            'id': 5000,
            'category': 'Favor',
            'tags': ['aV'],
            'exp_value': 20,
            'name': 'Wavecat Pillow',
            'icon_asset': null,
          },
        ],
        'missing_student_ids': <String>[],
        'changed_student_count': 1,
      };
    }
    throw StateError('Unexpected method: $method');
  }
}

void main() {
  final client = ToolBackendClient(
    backendDirectory: 'C:/not-used',
    pythonExecutable: 'python',
  );

  testWidgets('template extractor is a standalone app surface', (tester) async {
    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.templateExtractor, client: client),
    );
    expect(find.text('BA Planner v7 · 학생 템플릿 추출기'), findsOneWidget);
    expect(find.text('스크린샷 열기'), findsOneWidget);
    expect(find.text('템플릿 저장'), findsOneWidget);
  });

  testWidgets('grid inspector is a standalone app surface', (tester) async {
    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.gridInspector, client: client),
    );
    expect(find.text('BA Planner v7 · 인벤토리 그리드 매치 검사기'), findsOneWidget);
    expect(find.text('캡처 열기'), findsOneWidget);
    expect(find.text('다시 검사'), findsOneWidget);
  });

  for (final size in [const Size(1200, 800), const Size(700, 800)]) {
    testWidgets('metadata editor lays out at ${size.width} px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        DeveloperToolApp(
          tool: DeveloperTool.metadata,
          client: _MetadataClient(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('호시노'), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
    });
  }

  testWidgets(
    'metadata SchaleDB preview compares students and gifts visually',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        DeveloperToolApp(
          tool: DeveloperTool.metadata,
          client: _MetadataClient(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('SchaleDB 가져오기'));
      await tester.pump();
      await tester.tap(find.text('미리보기 불러오기'));
      await tester.pumpAndSettle();

      expect(find.text('학생별 선호'), findsOneWidget);
      expect(find.text('호시노'), findsOneWidget);
      expect(find.text('특별 선호'), findsOneWidget);
      expect(find.text('일반 선호'), findsOneWidget);
      expect(find.byTooltip('Special Gift · 60pt (×3)'), findsOneWidget);
      expect(find.byTooltip('Wavecat Pillow · 40pt (×2)'), findsOneWidget);
      expect(find.text('aV'), findsNothing);
      await tester.tap(find.text('선물 카탈로그'));
      await tester.pumpAndSettle();
      expect(find.text('Wavecat Pillow'), findsOneWidget);
      expect(find.text('선호 계산용 · 기본 20pt'), findsOneWidget);
      expect(find.text('ID 5000'), findsOneWidget);
    },
  );

  testWidgets('metadata editor duplicates drafts and saves multi-form JSON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final metadataClient = _MetadataClient();

    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.metadata, client: metadataClient),
    );
    await tester.pump();
    await tester.tap(find.text('호시노').first);
    await tester.pumpAndSettle();

    expect(find.text('다중 폼 오버라이드'), findsOneWidget);
    expect(find.text('2개 폼'), findsOneWidget);
    final formEditor = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == '폼 오버라이드 JSON 배열',
    );
    await tester.enterText(
      formEditor,
      '[{"label":"1","template_name":"hoshino.png"}]',
    );
    await tester.ensureVisible(find.text('폼 저장'));
    await tester.tap(find.text('폼 저장'));
    await tester.pumpAndSettle();
    expect(metadataClient.savedForms, hasLength(1));

    await tester.ensureVisible(find.text('복제하여 새 학생'));
    await tester.tap(find.text('복제하여 새 학생'));
    await tester.pump();
    final studentIdEditor = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Student ID',
      ),
    );
    expect(studentIdEditor.controller!.text, 'hoshino_copy');
    expect(studentIdEditor.readOnly, isFalse);
  });

  testWidgets(
    'metadata diagnostics shows server and asset status with details',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        DeveloperToolApp(
          tool: DeveloperTool.metadata,
          client: _MetadataClient(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('메타데이터 진단'));
      await tester.pumpAndSettle();

      expect(find.text('학생·ID·학교·속성 검색'), findsOneWidget);
      expect(find.text('인식 2/2'), findsWidgets);
      expect(find.text('초상'), findsWidgets);
      expect(find.text('엘레프'), findsWidgets);
      expect(find.text('다중 폼'), findsOneWidget);
      expect(find.text('전체 메타데이터'), findsOneWidget);
      expect(find.text('Abydos'), findsWidgets);
    },
  );

  testWidgets(
    'single SchaleDB import previews minimal fields and gift results',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        DeveloperToolApp(
          tool: DeveloperTool.metadata,
          client: _MetadataClient(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('SchaleDB 가져오기'));
      await tester.pump();
      await tester.tap(find.text('단일 학생'));
      await tester.pump();
      final sourceField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'SchaleDB URL / slug',
      );
      await tester.enterText(
        sourceField,
        'https://schaledb.com/student/hoshino',
      );
      await tester.tap(find.text('미리보기'));
      await tester.pumpAndSettle();

      expect(find.text('기존 학생'), findsOneWidget);
      expect(find.text('SchaleDB ID 변경'), findsOneWidget);
      expect(find.byTooltip('Special Gift · 60pt (×3)'), findsOneWidget);
      expect(find.byTooltip('Wavecat Pillow · 40pt (×2)'), findsOneWidget);
      expect(find.text('선물 52개'), findsOneWidget);
      expect(find.text('최소 7개 필드 저장'), findsOneWidget);
    },
  );

  testWidgets('SchaleDB merge paths show the primary and secondary slugs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final metadataClient = _MetadataClient();

    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.metadata, client: metadataClient),
    );
    await tester.pump();
    await tester.tap(find.text('SchaleDB 가져오기'));
    await tester.pump();
    await tester.tap(find.text('병합 경로'));
    await tester.pumpAndSettle();

    expect(find.text('기준 · hoshino_tank'), findsOneWidget);
    expect(find.text('보조 1 · hoshino_dealer'), findsOneWidget);
    await tester.tap(find.text('호시노').last);
    await tester.pump();
    final pathField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'SchaleDB slug 또는 URL',
    );
    await tester.enterText(
      pathField,
      'hoshino_tank\nhoshino_dealer\nhoshino_extra',
    );
    await tester.tap(find.text('규칙 저장'));
    await tester.pumpAndSettle();

    expect(metadataClient.mergePaths, hasLength(3));
    expect(find.text('보조 2 · hoshino_extra'), findsOneWidget);
  });

  testWidgets('item statistics separates unknown zero and planned shortage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.metadata, client: _MetadataClient()),
    );
    await tester.pump();
    await tester.tap(find.text('아이템 통계'));
    await tester.pumpAndSettle();

    expect(find.text('v7 선택 계정 · 테스트'), findsOneWidget);
    expect(find.text('수량 미확인'), findsOneWidget);
    expect(find.text('명시적 0'), findsOneWidget);
    expect(find.text('계획 반영 부족'), findsOneWidget);
    expect(find.text('T1 배지'), findsOneWidget);
    expect(find.text('현재 5 · 계획 -7 · 결과 -2'), findsOneWidget);
    expect(find.text('부족'), findsOneWidget);
    expect(find.textContaining('총 보유량'), findsNothing);
  });

  testWidgets('metadata diagnostics explicitly changes KR and JP state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final metadataClient = _MetadataClient();

    await tester.pumpWidget(
      DeveloperToolApp(tool: DeveloperTool.metadata, client: metadataClient),
    );
    await tester.pump();
    await tester.tap(find.text('메타데이터 진단'));
    await tester.pumpAndSettle();
    expect(find.text('JP 전용 지정'), findsOneWidget);

    await tester.tap(find.text('JP 전용 지정'));
    await tester.pumpAndSettle();
    expect(find.text('JP 전용 상태로 전환'), findsOneWidget);
    await tester.tap(find.text('전환'));
    await tester.pumpAndSettle();

    expect(metadataClient.server, 'JP');
    expect(find.text('KR로 전환'), findsOneWidget);
    expect(find.text('hoshino → JP'), findsOneWidget);
  });

  test('developer tool client prefers the backend virtual environment', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ba_planner_v7_developer_tool_backend_',
    );
    try {
      final python = File(
        '${directory.path}${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}'
        '${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
      );
      await python.parent.create(recursive: true);
      await python.writeAsBytes(const [0]);

      final resolved = ToolBackendClient(backendDirectory: directory.path);

      expect(resolved.pythonExecutable, python.absolute.path);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
