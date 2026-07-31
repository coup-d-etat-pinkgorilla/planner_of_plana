import 'package:ba_planner_v7/developer_tools/tool_backend_client.dart';
import 'package:ba_planner_v7/developer_tools_main.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
