import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'developer_tools/tool_backend_client.dart';

enum DeveloperTool { metadata, templateExtractor, gridInspector }

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final values = <String, String>{};
  for (final argument in arguments) {
    final split = argument.indexOf('=');
    if (argument.startsWith('--') && split > 2) {
      values[argument.substring(2, split)] = argument.substring(split + 1);
    }
  }
  const compiledTool = String.fromEnvironment('BA_PLANNER_DEVELOPER_TOOL');
  final toolName = values['tool'] ?? compiledTool;
  final tool = switch (toolName) {
    'student-metadata' => DeveloperTool.metadata,
    'student-template' => DeveloperTool.templateExtractor,
    'inventory-grid' => DeveloperTool.gridInspector,
    _ => DeveloperTool.metadata,
  };
  runApp(
    DeveloperToolApp(
      tool: tool,
      client: ToolBackendClient(
        backendDirectory: values['backend-dir'],
        pythonExecutable: values['python'],
      ),
    ),
  );
}

class DeveloperToolApp extends StatelessWidget {
  const DeveloperToolApp({super.key, required this.tool, required this.client});
  final DeveloperTool tool;
  final ToolBackendClient client;

  @override
  Widget build(BuildContext context) {
    final title = switch (tool) {
      DeveloperTool.metadata => 'BA Planner v7 · 학생 메타데이터 편집기',
      DeveloperTool.templateExtractor => 'BA Planner v7 · 학생 템플릿 추출기',
      DeveloperTool.gridInspector => 'BA Planner v7 · 인벤토리 그리드 매치 검사기',
    };
    final page = switch (tool) {
      DeveloperTool.metadata => MetadataEditorPage(client: client),
      DeveloperTool.templateExtractor => TemplateExtractorPage(client: client),
      DeveloperTool.gridInspector => GridInspectorPage(client: client),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: page,
      ),
    );
  }
}

mixin ToolPageState<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  Future<R?> runTool<R>(Future<R> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      return await action();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget statusStrip() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (busy) const LinearProgressIndicator(minHeight: 2),
      if (error != null)
        MaterialBanner(
          content: SelectableText(error!),
          actions: [
            TextButton(
              onPressed: () => setState(() => error = null),
              child: const Text('닫기'),
            ),
          ],
        ),
    ],
  );
}

class MetadataEditorPage extends StatefulWidget {
  const MetadataEditorPage({super.key, required this.client});
  final ToolBackendClient client;

  @override
  State<MetadataEditorPage> createState() => _MetadataEditorPageState();
}

class _MetadataEditorPageState extends State<MetadataEditorPage>
    with ToolPageState<MetadataEditorPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> fields = [];
  final controllers = <String, TextEditingController>{};
  String? selectedId;
  bool jpOnly = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    search.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await runTool(
      () => widget.client.call('metadata.list', {'query': search.text}),
    );
    if (result == null || !mounted) return;
    setState(() {
      fields = (result['fields'] as List)
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      students = (result['students'] as List)
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    });
  }

  Future<void> _select(String studentId) async {
    final result = await runTool(
      () => widget.client.call('metadata.get', {'student_id': studentId}),
    );
    if (result == null || !mounted) return;
    final metadata = (result['metadata'] as Map).cast<String, dynamic>();
    for (final field in fields) {
      final name = field['name'] as String;
      final value = name == 'student_id' ? studentId : metadata[name];
      final text = switch (field['type']) {
        'list' when value is List => value.join(', '),
        'json' when value != null => const JsonEncoder.withIndent(
          '  ',
        ).convert(value),
        _ => value?.toString() ?? '',
      };
      (controllers[name] ??= TextEditingController()).text = text;
    }
    setState(() {
      selectedId = studentId;
      jpOnly = result['jp_only'] == true;
    });
  }

  void _newStudent() {
    for (final field in fields) {
      (controllers[field['name']] ??= TextEditingController()).clear();
    }
    setState(() {
      selectedId = null;
      jpOnly = false;
    });
  }

  dynamic _parseField(Map<String, dynamic> field) {
    final text = controllers[field['name']]?.text.trim() ?? '';
    if (text.isEmpty) return null;
    return switch (field['type']) {
      'list' =>
        text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      'json' => jsonDecode(text),
      _ => text,
    };
  }

  Future<void> _save() async {
    final id = controllers['student_id']?.text.trim() ?? '';
    final metadata = <String, dynamic>{};
    try {
      for (final field in fields.where(
        (field) => field['name'] != 'student_id',
      )) {
        metadata[field['name']] = _parseField(field);
      }
    } catch (exception) {
      setState(() => error = 'JSON 필드 형식이 올바르지 않습니다: $exception');
      return;
    }
    final result = await runTool(
      () => widget.client.call('metadata.save', {
        'student_id': id,
        'metadata': metadata,
        'jp_only': jpOnly,
      }),
    );
    if (result != null) {
      await _refresh();
      await _select(id);
    }
  }

  Future<void> _delete() async {
    if (selectedId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text('$selectedId 메타데이터를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await runTool(
      () => widget.client.call('metadata.delete', {'student_id': selectedId}),
    );
    if (result != null) {
      _newStudent();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      statusStrip(),
      Expanded(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 390,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: search,
                      onSubmitted: (_) => _refresh(),
                      decoration: InputDecoration(
                        labelText: '학생 검색',
                        suffixIcon: IconButton(
                          onPressed: _refresh,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text('${students.length}명'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _newStudent,
                          icon: const Icon(Icons.add),
                          label: const Text('새 학생'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final row = students[index];
                        final id = row['student_id'] as String;
                        return ListTile(
                          selected: id == selectedId,
                          title: Text(row['display_name'] as String),
                          subtitle: Text('$id · ${row['group']}'),
                          trailing: row['jp_only'] == true
                              ? const Chip(label: Text('JP'))
                              : null,
                          onTap: () => _select(id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: fields.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              SwitchListTile(
                                value: jpOnly,
                                onChanged: (value) =>
                                    setState(() => jpOnly = value),
                                title: const Text('JP 전용 학생'),
                              ),
                              ...fields.map(
                                (field) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextField(
                                    controller: controllers[field['name']] ??=
                                        TextEditingController(),
                                    minLines: field['type'] == 'json' ? 3 : 1,
                                    maxLines: field['type'] == 'json' ? 8 : 1,
                                    readOnly:
                                        field['name'] == 'student_id' &&
                                        selectedId != null,
                                    decoration: InputDecoration(
                                      labelText: field['label'] as String,
                                      helperText: field['type'] == 'list'
                                          ? '쉼표로 구분'
                                          : field['type'] == 'json'
                                          ? 'JSON 형식'
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (selectedId != null)
                                TextButton.icon(
                                  onPressed: busy ? null : _delete,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('삭제'),
                                ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: busy ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('저장'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ],
  );
}

class TemplateExtractorPage extends StatefulWidget {
  const TemplateExtractorPage({super.key, required this.client});
  final ToolBackendClient client;

  @override
  State<TemplateExtractorPage> createState() => _TemplateExtractorPageState();
}

class _TemplateExtractorPageState extends State<TemplateExtractorPage>
    with ToolPageState<TemplateExtractorPage> {
  final studentId = TextEditingController();
  final crop = List.generate(4, (_) => TextEditingController());
  String? imagePath;
  String? previewPath;
  String? savedMessage;
  bool overwrite = false;

  @override
  void dispose() {
    studentId.dispose();
    for (final controller in crop) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (file == null) return;
    final result = await runTool(
      () => widget.client.call('template.preview', {'image_path': file.path}),
    );
    if (result == null || !mounted) return;
    final values = (result['crop'] as List)
        .map((value) => value.toString())
        .toList();
    for (var index = 0; index < 4; index++) {
      crop[index].text = values[index];
    }
    setState(() {
      imagePath = file.path;
      previewPath = result['preview_path'] as String;
      savedMessage = null;
      studentId.text = file.name
          .replaceFirst(
            RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
          .toLowerCase();
    });
  }

  Future<void> _save() async {
    if (imagePath == null) return;
    final box = crop
        .map((controller) => int.tryParse(controller.text))
        .toList();
    if (box.any((value) => value == null)) {
      setState(() => error = '크롭 좌표는 정수여야 합니다.');
      return;
    }
    final result = await runTool(
      () => widget.client.call('template.save', {
        'image_path': imagePath,
        'student_id': studentId.text.trim(),
        'crop': box,
        'overwrite': overwrite,
      }),
    );
    if (result != null && mounted) {
      setState(
        () => savedMessage =
            '저장: ${result['output_path']}\n메타데이터: ${result['metadata_path']}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      statusStrip(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _open,
              icon: const Icon(Icons.image_outlined),
              label: const Text('스크린샷 열기'),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: studentId,
                decoration: const InputDecoration(labelText: 'Student ID'),
              ),
            ),
            for (var index = 0; index < 4; index++)
              SizedBox(
                width: 105,
                child: TextField(
                  controller: crop[index],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: const ['Left', 'Top', 'Right', 'Bottom'][index],
                  ),
                ),
              ),
            FilterChip(
              label: const Text('덮어쓰기'),
              selected: overwrite,
              onSelected: (value) => setState(() => overwrite = value),
            ),
            FilledButton.icon(
              onPressed: busy || imagePath == null ? null : _save,
              icon: const Icon(Icons.content_cut),
              label: const Text('템플릿 저장'),
            ),
          ],
        ),
      ),
      if (savedMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SelectableText(savedMessage!),
        ),
      Expanded(
        child: previewPath == null
            ? const Center(child: Text('학생 상세 화면 스크린샷을 선택하세요.'))
            : InteractiveViewer(
                minScale: 0.1,
                maxScale: 6,
                child: Image.file(
                  File(previewPath!),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
      ),
    ],
  );
}

class GridInspectorPage extends StatefulWidget {
  const GridInspectorPage({super.key, required this.client});
  final ToolBackendClient client;

  @override
  State<GridInspectorPage> createState() => _GridInspectorPageState();
}

class _GridInspectorPageState extends State<GridInspectorPage>
    with ToolPageState<GridInspectorPage> {
  final threshold = TextEditingController(text: '0.80');
  final margin = TextEditingController(text: '0.03');
  String? imagePath;
  List<Map<String, dynamic>> slots = [];
  int templateCount = 0;

  @override
  void dispose() {
    threshold.dispose();
    margin.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (file == null) return;
    setState(() => imagePath = file.path);
    await _inspect();
  }

  Future<void> _inspect() async {
    if (imagePath == null) return;
    final result = await runTool(
      () => widget.client.call('inspector.inspect', {
        'image_path': imagePath,
        'threshold': double.tryParse(threshold.text) ?? 0.80,
        'margin': double.tryParse(margin.text) ?? 0.03,
      }),
    );
    if (result == null || !mounted) return;
    setState(() {
      templateCount = result['template_count'] as int;
      slots = (result['slots'] as List)
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      statusStrip(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _open,
              icon: const Icon(Icons.image_search),
              label: const Text('캡처 열기'),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: threshold,
                decoration: const InputDecoration(labelText: 'Score 기준'),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: margin,
                decoration: const InputDecoration(labelText: 'Margin 기준'),
              ),
            ),
            FilledButton.icon(
              onPressed: busy || imagePath == null ? null : _inspect,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 검사'),
            ),
            Text('템플릿 $templateCount개 · 슬롯 ${slots.length}개'),
          ],
        ),
      ),
      Expanded(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: imagePath == null
                  ? const Center(child: Text('인벤토리 캡처 이미지를 선택하세요.'))
                  : InteractiveViewer(
                      child: Image.file(File(imagePath!), fit: BoxFit.contain),
                    ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 2,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: slots.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = slots[index];
                  final empty = row['empty'] == true;
                  final confident = row['confident'] == true;
                  return ListTile(
                    leading: CircleAvatar(child: Text('${row['slot']}')),
                    title: Text(empty ? '빈 슬롯' : row['item_id'] as String),
                    subtitle: empty
                        ? null
                        : Text(
                            'score ${(row['score'] as num).toStringAsFixed(4)} · margin ${(row['margin'] as num).toStringAsFixed(4)}',
                          ),
                    trailing: empty
                        ? null
                        : Icon(
                            confident
                                ? Icons.check_circle
                                : Icons.warning_amber,
                            color: confident ? Colors.green : Colors.orange,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
