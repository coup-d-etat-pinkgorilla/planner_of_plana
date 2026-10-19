// v7 개발자 도구 진입점(`flutter run -t lib/developer_tools_main.dart`, 배포본 앱과 별도 창).
//
// `--tool=<id>`(또는 컴파일 상수 `BA_PLANNER_DEVELOPER_TOOL`)로 도구를 고른다. 도구 목록은
// `developer_tools/tool_registry.dart`의 등록표다(M2부터). 화면 코드는 `developer_tools/` 아래에 있다.
// - `--mock`(또는 `--mock=true`, 컴파일 상수 `BA_PLANNER_DEVELOPER_TOOL_MOCK=true`): Python 백엔드 없이 연다.
// - `--backend-dir=<경로>` · `--python=<실행 파일>`: 기존과 같다.
import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'developer_tools/metadata_manager_service.dart';
import 'developer_tools/tool_backend_client.dart';
import 'developer_tools/tool_registry.dart';

export 'developer_tools/legacy_tool_pages.dart';
export 'developer_tools/tool_registry.dart'
    show
        DeveloperToolEntry,
        DeveloperToolServices,
        defaultDeveloperToolId,
        developerToolFor,
        developerTools;

/// 옛 도구 선택값(테스트 · 기존 호출 호환). 새 도구는 등록표 항목만 더하고 [DeveloperToolApp.services]로 연다.
enum DeveloperTool {
  /// 옛 학생 메타데이터 편집기 = 메타데이터 관리자 ① 학생 탭(한 릴리스 동안 alias).
  metadata('student-metadata'),
  templateExtractor('student-template'),
  gridInspector('inventory-grid'),
  metadataManager('metadata-manager');

  const DeveloperTool(this.id);

  /// 등록표 id 또는 옛 이름.
  final String id;
}

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final values = <String, String>{};
  for (final argument in arguments) {
    final split = argument.indexOf('=');
    if (argument.startsWith('--') && split > 2) {
      values[argument.substring(2, split)] = argument.substring(split + 1);
    } else if (argument == '--mock') {
      values['mock'] = 'true';
    }
  }
  const compiledTool = String.fromEnvironment('BA_PLANNER_DEVELOPER_TOOL');
  const compiledMock = bool.fromEnvironment('BA_PLANNER_DEVELOPER_TOOL_MOCK');
  final mock =
      compiledMock || values['mock'] == 'true' || values['mock'] == '1';
  runApp(
    DeveloperToolApp.services(
      toolId: values['tool'] ?? compiledTool,
      services: mock
          ? const DeveloperToolServices.mock()
          : DeveloperToolServices.forClient(
              ToolBackendClient(
                backendDirectory: values['backend-dir'],
                pythonExecutable: values['python'],
              ),
            ),
    ),
  );
}

class DeveloperToolApp extends StatelessWidget {
  /// 옛 호출: [tool]과 기존 백엔드 [client]. [metadataManager]가 없으면 [client]가 envelope 전송을 지원할 때만 새
  /// 메서드를 부른다.
  DeveloperToolApp({
    super.key,
    required DeveloperTool tool,
    required ToolBackend client,
    MetadataManagerService? metadataManager,
  }) : toolId = tool.id,
       services = DeveloperToolServices(
         client: client,
         metadataManager: metadataManager ?? metadataManagerServiceFor(client),
       );

  /// 등록표 id(또는 옛 이름)와 백엔드로 연다.
  const DeveloperToolApp.services({
    super.key,
    required this.toolId,
    required this.services,
  });

  final String toolId;
  final DeveloperToolServices services;

  @override
  Widget build(BuildContext context) {
    final entry = developerToolFor(toolId);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: entry.title,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        appBar: AppBar(title: Text(entry.title)),
        body: entry.builder(services),
      ),
    );
  }
}
