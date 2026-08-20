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
  final ToolBackend client;

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
  final ToolBackend client;

  @override
  State<MetadataEditorPage> createState() => _MetadataEditorPageState();
}

class _MetadataEditorPageState extends State<MetadataEditorPage>
    with ToolPageState<MetadataEditorPage> {
  final search = TextEditingController();
  final syncSearch = TextEditingController();
  final singleSchaleSource = TextEditingController();
  final singleSchaleStudentId = TextEditingController();
  final mergeStudentId = TextEditingController();
  final mergePaths = TextEditingController();
  final itemInventoryPath = TextEditingController();
  final itemPlanPath = TextEditingController();
  final itemSearch = TextEditingController();
  final debugSearch = TextEditingController();
  final multiFormController = TextEditingController();
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> fields = [];
  List<Map<String, dynamic>> schaleStudents = [];
  List<Map<String, dynamic>> schaleGifts = [];
  List<Map<String, dynamic>> mergePathRules = [];
  List<Map<String, dynamic>> itemRows = [];
  List<Map<String, dynamic>> itemCategories = [];
  List<Map<String, dynamic>> debugStudents = [];
  Map<String, dynamic>? debugDetail;
  Map<String, dynamic>? singleSchalePreview;
  Map<String, dynamic> debugCounts = const {'all': 0, 'kr': 0, 'jp': 0};
  List<String> missingSchaleStudents = [];
  final controllers = <String, TextEditingController>{};
  String? selectedId;
  bool jpOnly = false;
  int metadataSurface = 0;
  String debugServer = 'all';
  int schaleMode = 0;
  String? selectedMergeRuleId;
  Map<String, dynamic>? itemSummary;
  String itemSourceLabel = '';
  String itemStatusFilter = 'all';
  String itemSort = 'shortage';
  String? selectedDebugId;
  int changedSchaleStudents = 0;
  int multiFormCount = 0;
  String? syncMessage;
  String? multiFormMessage;
  String? singleSchaleMessage;
  String? mergePathMessage;
  String? debugMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    search.dispose();
    syncSearch.dispose();
    singleSchaleSource.dispose();
    singleSchaleStudentId.dispose();
    mergeStudentId.dispose();
    mergePaths.dispose();
    itemInventoryPath.dispose();
    itemPlanPath.dispose();
    itemSearch.dispose();
    debugSearch.dispose();
    multiFormController.dispose();
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

  Future<void> _loadMetadataDebug({String? selectStudentId}) async {
    final result = await runTool(
      () => widget.client.call('metadata.debug.list', {
        'query': debugSearch.text,
        'server': debugServer,
      }),
    );
    if (result == null || !mounted) return;
    final rows = (result['rows'] as List)
        .cast<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
    final counts = (result['counts'] as Map).cast<String, dynamic>();
    final preferred = selectStudentId ?? selectedDebugId;
    final nextId = rows.any((row) => row['student_id'] == preferred)
        ? preferred
        : rows.isEmpty
        ? null
        : rows.first['student_id'] as String;
    setState(() {
      debugStudents = rows;
      debugCounts = counts;
      selectedDebugId = nextId;
      if (nextId == null) debugDetail = null;
    });
    if (nextId != null) await _selectMetadataDebug(nextId);
  }

  Future<void> _selectMetadataDebug(String studentId) async {
    final result = await runTool(
      () => widget.client.call('metadata.debug.get', {'student_id': studentId}),
    );
    if (result == null || !mounted) return;
    setState(() {
      selectedDebugId = studentId;
      debugDetail = result;
    });
  }

  Future<void> _setMetadataServer(String server) async {
    final detail = debugDetail;
    if (detail == null) return;
    final studentId = detail['student_id'] as String;
    final targetLabel = server == 'jp' ? 'JP 전용' : 'KR';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$targetLabel 상태로 전환'),
        content: Text(
          '${detail['display_name']} ($studentId)의 서버 상태를 $targetLabel로 변경할까요?\n학생 메타데이터 본문은 변경하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('전환'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await runTool(
      () => widget.client.call('metadata.server.set', {
        'student_id': studentId,
        'server': server,
      }),
    );
    if (result == null || !mounted) return;
    final warnings = (result['warnings'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    setState(() {
      debugMessage =
          '$studentId → ${result['server']}${warnings.isEmpty ? '' : ' · ${warnings.join(' ')}'}';
      if (selectedId == studentId) jpOnly = server == 'jp';
    });
    await _refresh();
    await _loadMetadataDebug(selectStudentId: studentId);
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
    await _loadMultiForms(studentId);
  }

  void _newStudent() {
    for (final field in fields) {
      (controllers[field['name']] ??= TextEditingController()).clear();
    }
    setState(() {
      selectedId = null;
      jpOnly = false;
      multiFormCount = 0;
      multiFormMessage = null;
    });
    multiFormController.clear();
  }

  Future<void> _loadMultiForms(String studentId) async {
    final result = await runTool(
      () => widget.client.call('metadata.forms.get', {'student_id': studentId}),
    );
    if (result == null || !mounted) return;
    final forms = (result['forms'] as List? ?? const []);
    multiFormController.text = forms.isEmpty
        ? ''
        : const JsonEncoder.withIndent('  ').convert(forms);
    setState(() {
      multiFormCount = result['form_count'] as int? ?? forms.length;
      multiFormMessage = null;
    });
  }

  void _seedMultiForms() {
    final templateName = controllers['template_name']?.text.trim() ?? '';
    final studentId = controllers['student_id']?.text.trim() ?? '';
    if (studentId.isEmpty) {
      setState(() => error = '다중 폼을 만들려면 Student ID가 필요합니다.');
      return;
    }
    final firstTemplate = templateName.isEmpty
        ? '$studentId.png'
        : templateName;
    final dot = firstTemplate.lastIndexOf('.');
    final secondTemplate = dot > 0
        ? '${firstTemplate.substring(0, dot)}_1${firstTemplate.substring(dot)}'
        : '${firstTemplate}_1.png';
    final forms = [
      {'label': '1', 'template_name': firstTemplate},
      {'label': '2', 'template_name': secondTemplate},
    ];
    multiFormController.text = const JsonEncoder.withIndent(
      '  ',
    ).convert(forms);
    setState(() => multiFormMessage = '2개 폼 초안을 만들었습니다. 저장 전 내용을 확인하세요.');
  }

  void _duplicateCurrent() {
    final currentId = controllers['student_id']?.text.trim() ?? '';
    if (selectedId == null || currentId.isEmpty) return;
    (controllers['student_id'] ??= TextEditingController()).text =
        '${currentId}_copy';
    final hadMultiForms = multiFormCount > 0;
    setState(() {
      selectedId = null;
      multiFormCount = 0;
      multiFormMessage = '원본 값을 복제한 새 학생 초안입니다.';
    });
    if (hadMultiForms) _seedMultiForms();
  }

  Future<void> _saveMultiForms() async {
    final studentId = controllers['student_id']?.text.trim() ?? '';
    if (studentId.isEmpty || selectedId != studentId) {
      setState(() => error = '먼저 학생 메타데이터를 저장한 뒤 다중 폼을 저장하세요.');
      return;
    }
    late final List<dynamic> forms;
    try {
      final text = multiFormController.text.trim();
      final decoded = text.isEmpty ? <dynamic>[] : jsonDecode(text);
      if (decoded is! List) {
        throw const FormatException('최상위 값은 JSON 배열이어야 합니다.');
      }
      forms = decoded;
    } catch (exception) {
      setState(() => error = '다중 폼 JSON 형식이 올바르지 않습니다: $exception');
      return;
    }
    final result = await runTool(
      () => widget.client.call('metadata.forms.save', {
        'student_id': studentId,
        'forms': forms,
      }),
    );
    if (result == null || !mounted) return;
    setState(() {
      multiFormCount = result['form_count'] as int? ?? forms.length;
      multiFormMessage = multiFormCount == 0
          ? '다중 폼 오버라이드를 제거했습니다.'
          : '다중 폼 $multiFormCount개를 저장했습니다.';
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
      'integer' => int.parse(text),
      _ => text,
    };
  }

  Future<void> _loadSchalePreview() async {
    final result = await runTool(
      () => widget.client.call('metadata.schaledb.preview'),
    );
    if (result == null || !mounted) return;
    setState(() {
      schaleStudents = (result['students'] as List)
          .cast<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      schaleGifts = (result['gifts'] as List)
          .cast<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      missingSchaleStudents = (result['missing_student_ids'] as List)
          .map((value) => value.toString())
          .toList();
      changedSchaleStudents = result['changed_student_count'] as int;
      syncMessage = null;
    });
  }

  Future<void> _applySchalePreview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최소 인연 데이터 적용'),
        content: Text(
          '학생 $changedSchaleStudents명의 변경 필드와 선물 ${schaleGifts.length}개를 저장합니다. '
          '학생 스탯 필드는 가져오지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await runTool(
      () => widget.client.call('metadata.schaledb.apply'),
    );
    if (result == null || !mounted) return;
    setState(() {
      syncMessage =
          '학생 ${result['updated_students']}명 · 선물 ${result['gift_count']}개 저장 완료';
    });
    await _refresh();
    await _loadSchalePreview();
  }

  Future<void> _loadSingleSchalePreview() async {
    final result = await runTool(
      () => widget.client.call('metadata.schaledb.single.preview', {
        'source': singleSchaleSource.text,
        'student_id': singleSchaleStudentId.text,
      }),
    );
    if (result == null || !mounted) return;
    setState(() {
      singleSchalePreview = result;
      singleSchaleSource.text = result['source_slug'] as String;
      singleSchaleStudentId.text = result['student_id'] as String;
      singleSchaleMessage = null;
    });
  }

  void _useSelectedForSingleImport() {
    final studentId = selectedId;
    if (studentId == null) {
      setState(() => error = '보유 메타데이터에서 학생을 먼저 선택하세요.');
      return;
    }
    singleSchaleSource.text = studentId;
    singleSchaleStudentId.text = studentId;
    _loadSingleSchalePreview();
  }

  Future<void> _loadSinglePreviewIntoEditor() async {
    final preview = singleSchalePreview;
    if (preview == null) return;
    final studentId = preview['student_id'] as String;
    if (preview['exists'] == true) {
      await _select(studentId);
    } else {
      _newStudent();
      (controllers['student_id'] ??= TextEditingController()).text = studentId;
    }
    final incoming = (preview['incoming'] as Map).cast<String, dynamic>();
    (controllers['schaledb_id'] ??= TextEditingController()).text =
        '${incoming['schaledb_id']}';
    (controllers['favor_item_tags'] ??= TextEditingController()).text =
        (incoming['favor_item_tags'] as List).join(', ');
    (controllers['favor_item_unique_tags'] ??= TextEditingController()).text =
        (incoming['favor_item_unique_tags'] as List).join(', ');
    if (!mounted) return;
    setState(() {
      metadataSurface = 0;
      singleSchaleMessage = preview['exists'] == true
          ? '최소 필드를 편집기에 반영했습니다.'
          : '신규 학생 초안을 만들었습니다. 필수 로컬 메타데이터를 입력한 뒤 저장하세요.';
    });
  }

  Future<void> _applySingleSchalePreview() async {
    final preview = singleSchalePreview;
    if (preview == null || preview['exists'] != true) return;
    final changed = (preview['changed_fields'] as List).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단일 학생 최소 필드 저장'),
        content: Text(
          '${preview['display_name']}의 학생 필드 $changed개와 선물 ${preview['gift_count']}개를 저장합니다. '
          '학생·인연 스탯 필드는 가져오지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await runTool(
      () => widget.client.call('metadata.schaledb.single.apply', {
        'source': singleSchaleSource.text,
        'student_id': singleSchaleStudentId.text,
      }),
    );
    if (result == null || !mounted) return;
    setState(
      () => singleSchaleMessage =
          '${result['student_id']} · 학생 ${result['updated_fields'].length}개 필드, 선물 ${result['gift_count']}개 저장 완료',
    );
    await _refresh();
    await _loadSingleSchalePreview();
  }

  Future<void> _loadMergePaths({String? selectStudentId}) async {
    final result = await runTool(
      () => widget.client.call('metadata.merge_paths.list'),
    );
    if (result == null || !mounted) return;
    final rows = (result['rows'] as List? ?? const [])
        .cast<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
    setState(() => mergePathRules = rows);
    final wanted = selectStudentId ?? selectedMergeRuleId;
    Map<String, dynamic>? match;
    for (final row in rows) {
      if (row['student_id'] == wanted) {
        match = row;
        break;
      }
    }
    if (match != null) _selectMergeRule(match);
  }

  void _selectMergeRule(Map<String, dynamic> row) {
    mergeStudentId.text = row['student_id'] as String;
    mergePaths.text = (row['paths'] as List).join('\n');
    setState(() {
      selectedMergeRuleId = row['student_id'] as String;
      mergePathMessage = null;
    });
  }

  void _useSelectedForMergeRule() {
    final studentId = selectedId;
    if (studentId == null) {
      setState(() => error = '보유 메타데이터에서 학생을 먼저 선택하세요.');
      return;
    }
    Map<String, dynamic>? existing;
    for (final row in mergePathRules) {
      if (row['student_id'] == studentId) {
        existing = row;
        break;
      }
    }
    if (existing != null) {
      _selectMergeRule(existing);
      return;
    }
    mergeStudentId.text = studentId;
    mergePaths.clear();
    setState(() {
      selectedMergeRuleId = null;
      mergePathMessage = '$studentId의 SchaleDB slug를 기준 경로부터 줄마다 입력하세요.';
    });
  }

  Future<void> _saveMergePaths() async {
    final paths = mergePaths.text
        .split(RegExp(r'[\s,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (mergeStudentId.text.trim().isEmpty || paths.length < 2) {
      setState(() => error = '로컬 Student ID와 서로 다른 SchaleDB 경로 2개 이상이 필요합니다.');
      return;
    }
    final result = await runTool(
      () => widget.client.call('metadata.merge_paths.save', {
        'student_id': mergeStudentId.text.trim(),
        'paths': paths,
      }),
    );
    if (result == null || !mounted) return;
    setState(
      () => mergePathMessage =
          '${result['student_id']} · ${result['path_count']}개 경로 저장 완료',
    );
    await _loadMergePaths(selectStudentId: result['student_id'] as String);
  }

  Future<void> _deleteMergePaths() async {
    final studentId = selectedMergeRuleId;
    if (studentId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('병합 경로 삭제'),
        content: Text('$studentId의 다중 경로 규칙을 삭제할까요?'),
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
      () => widget.client.call('metadata.merge_paths.delete', {
        'student_id': studentId,
      }),
    );
    if (result == null || !mounted) return;
    mergeStudentId.clear();
    mergePaths.clear();
    setState(() {
      selectedMergeRuleId = null;
      mergePathMessage = '$studentId 규칙을 삭제했습니다.';
    });
    await _loadMergePaths();
  }

  Future<void> _pickItemJson(TextEditingController controller) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) return;
    controller.text = file.path;
    await _loadItemAnalysis();
  }

  Future<void> _loadItemAnalysis() async {
    final result = await runTool(
      () => widget.client.call('metadata.items.analyze', {
        'inventory_path': itemInventoryPath.text.trim(),
        'plan_path': itemPlanPath.text.trim(),
      }),
    );
    if (result == null || !mounted) return;
    setState(() {
      itemRows = (result['rows'] as List? ?? const [])
          .cast<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      itemCategories = (result['categories'] as List? ?? const [])
          .cast<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      itemSummary = (result['summary'] as Map).cast<String, dynamic>();
      itemSourceLabel = result['source_label'] as String? ?? '';
    });
  }

  List<Map<String, dynamic>> get _visibleItemRows {
    final query = itemSearch.text.trim().toLowerCase();
    final rows = itemRows.where((row) {
      final statusMatches =
          itemStatusFilter == 'all' || row['status'] == itemStatusFilter;
      final text =
          '${row['display_name']} ${row['resource_key']} ${row['category']}'
              .toLowerCase();
      return statusMatches && (query.isEmpty || text.contains(query));
    }).toList();
    int nullableNumber(Map<String, dynamic> row, String key) =>
        row[key] as int? ?? -1;
    rows.sort((left, right) {
      final primary = switch (itemSort) {
        'adjusted_asc' => nullableNumber(
          left,
          'adjusted_qty',
        ).compareTo(nullableNumber(right, 'adjusted_qty')),
        'adjusted_desc' => nullableNumber(
          right,
          'adjusted_qty',
        ).compareTo(nullableNumber(left, 'adjusted_qty')),
        'name' => (left['display_name'] as String).toLowerCase().compareTo(
          (right['display_name'] as String).toLowerCase(),
        ),
        _ => _itemStatusRank(
          left['status'] as String,
        ).compareTo(_itemStatusRank(right['status'] as String)),
      };
      return primary != 0
          ? primary
          : (left['display_name'] as String).toLowerCase().compareTo(
              (right['display_name'] as String).toLowerCase(),
            );
    });
    return rows;
  }

  int _itemStatusRank(String status) => switch (status) {
    'negative' => 0,
    'zero' => 1,
    'unknown' => 2,
    'absent' => 3,
    _ => 4,
  };

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

  Widget _studentListPane() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: search,
          onSubmitted: (_) => _refresh(),
          decoration: InputDecoration(
            labelText: '학생 검색',
            suffixIcon: IconButton(
              onPressed: busy ? null : _refresh,
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
              onPressed: busy ? null : _newStudent,
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
              onTap: busy ? null : () => _select(id),
            );
          },
        ),
      ),
    ],
  );

  Widget _multiFormEditor() => Card(
    child: ExpansionTile(
      key: ValueKey('multi-forms:$selectedId:$multiFormCount'),
      initiallyExpanded: multiFormCount > 0,
      leading: const Icon(Icons.layers_outlined, color: AppColors.primary),
      title: const Text('다중 폼 오버라이드'),
      subtitle: Text(
        multiFormCount == 0 ? '단일 폼' : '$multiFormCount개 폼',
        style: const TextStyle(color: AppColors.textMuted),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '폼별 템플릿과 전투 분류값만 덮어씁니다. 기본 학생 메타데이터는 유지됩니다.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: multiFormController,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: '폼 오버라이드 JSON 배열',
            helperText: '각 항목에는 template_name이 필요합니다.',
            alignLabelWithHint: true,
          ),
        ),
        if (multiFormMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              multiFormMessage!,
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _seedMultiForms,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('2개 폼 초안'),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () {
                      multiFormController.clear();
                      setState(
                        () => multiFormMessage = '빈 배열로 저장하면 오버라이드가 제거됩니다.',
                      );
                    },
              icon: const Icon(Icons.clear_all),
              label: const Text('편집기 비우기'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : _saveMultiForms,
              icon: const Icon(Icons.save_outlined),
              label: const Text('폼 저장'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _editorPane() => fields.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    value: jpOnly,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => jpOnly = value),
                    title: const Text('JP 전용 학생'),
                  ),
                  _multiFormEditor(),
                  const SizedBox(height: 12),
                  ...fields.map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[field['name']] ??=
                            TextEditingController(),
                        minLines: field['type'] == 'json' ? 3 : 1,
                        maxLines: field['type'] == 'json' ? 8 : 1,
                        readOnly:
                            field['name'] == 'student_id' && selectedId != null,
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
                      onPressed: busy ? null : _duplicateCurrent,
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('복제하여 새 학생'),
                    ),
                  if (selectedId != null) const SizedBox(width: 8),
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
        );

  List<Map<String, dynamic>> get _filteredSchaleStudents {
    final query = syncSearch.text.trim().toLowerCase();
    if (query.isEmpty) return schaleStudents;
    return schaleStudents.where((row) {
      Iterable<String> giftNames(Object? raw) sync* {
        if (raw is! List) return;
        for (final gift in raw) {
          if (gift is Map && gift['name'] != null) {
            yield gift['name'].toString();
          }
        }
      }

      final text = [
        row['student_id'],
        row['display_name'],
        ...giftNames(row['special_gifts']),
        ...giftNames(row['preferred_gifts']),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Widget _portrait(String templateName) => Container(
    width: 88,
    height: 72,
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      'assets/student_portraits/$templateName',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, _, _) => const Icon(Icons.person_outline, size: 38),
    ),
  );

  Widget _giftAffinityStrip(
    String label,
    Object? raw, {
    required Color color,
    required int maxVisible,
  }) {
    final gifts = raw is List
        ? raw
              .whereType<Map>()
              .map((gift) => gift.cast<String, dynamic>())
              .toList()
        : <Map<String, dynamic>>[];
    final visible = gifts.take(maxVisible).toList();
    final hiddenCount = gifts.length - visible.length;
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${gifts.length}개',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (visible.isEmpty)
            const Expanded(
              child: Text(
                '해당 선물 없음',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  for (final gift in visible)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Tooltip(
                        message:
                            '${gift['name']} · ${gift['points']}pt (×${gift['multiplier']})',
                        child: SizedBox(
                          width: 46,
                          height: 54,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                bottom: 7,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: gift['icon_asset'] == null
                                      ? Icon(
                                          Icons.card_giftcard,
                                          color: color,
                                          size: 30,
                                        )
                                      : Image.asset(
                                          gift['icon_asset'] as String,
                                          fit: BoxFit.contain,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${gift['points']}pt',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (hiddenCount > 0)
                    Text(
                      '+$hiddenCount',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _schaleStudentCard(Map<String, dynamic> row) {
    final incoming = (row['incoming'] as Map).cast<String, dynamic>();
    final changed = (row['changed_fields'] as List).isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _portrait(row['template_name'] as String),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['display_name'] as String,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${row['student_id']} · SchaleDB ${incoming['schaledb_id']}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(changed ? Icons.sync : Icons.check, size: 15),
                  label: Text(changed ? '변경' : '동일'),
                  backgroundColor:
                      (changed ? AppColors.warning : AppColors.success)
                          .withValues(alpha: 0.15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _giftAffinityStrip(
              '특별 선호',
              row['special_gifts'],
              color: const Color(0xffd982e5),
              maxVisible: 4,
            ),
            const SizedBox(height: 8),
            _giftAffinityStrip(
              '일반 선호',
              row['preferred_gifts'],
              color: AppColors.primary,
              maxVisible: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _giftCard(Map<String, dynamic> gift) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 72,
            child: gift['icon_asset'] == null
                ? const Icon(
                    Icons.card_giftcard,
                    size: 46,
                    color: AppColors.textMuted,
                  )
                : Image.asset(
                    gift['icon_asset'] as String,
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            gift['name'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 2),
          Text(
            '선호 계산용 · 기본 ${gift['exp_value']}pt',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          Text(
            'ID ${gift['id']}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _bulkSchaleSyncPane() {
    if (schaleStudents.isEmpty && busy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (schaleStudents.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_download_outlined,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SchaleDB 최소 인연 데이터',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '학생 3개 필드와 선물 4개 필드만 불러옵니다. 저장 전 학생별 선호 선물과 예상 포인트를 아이콘으로 확인할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: busy ? null : _loadSchalePreview,
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('미리보기 불러오기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final visibleStudents = _filteredSchaleStudents;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _SummaryBadge(
                  icon: Icons.people_alt_outlined,
                  label: '학생',
                  value: '${schaleStudents.length}',
                ),
                const SizedBox(width: 8),
                _SummaryBadge(
                  icon: Icons.sync,
                  label: '변경',
                  value: '$changedSchaleStudents',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _SummaryBadge(
                  icon: Icons.card_giftcard,
                  label: '선물',
                  value: '${schaleGifts.length}',
                  color: const Color(0xfff2b3ef),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: busy ? null : _loadSchalePreview,
                  icon: const Icon(Icons.refresh),
                  label: const Text('새로고침'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: busy ? null : _applySchalePreview,
                  icon: const Icon(Icons.download_done),
                  label: const Text('7개 필드 적용'),
                ),
              ],
            ),
          ),
          if (syncMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  syncMessage!,
                  style: const TextStyle(color: AppColors.success),
                ),
              ),
            ),
          const TabBar(
            tabs: [
              Tab(text: '학생별 선호'),
              Tab(text: '선물 카탈로그'),
              Tab(text: '매칭 누락'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: syncSearch,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: '학생·ID·선물 이름 검색',
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 520,
                              mainAxisExtent: 268,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: visibleStudents.length,
                        itemBuilder: (_, index) =>
                            _schaleStudentCard(visibleStudents[index]),
                      ),
                    ),
                  ],
                ),
                GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: schaleGifts.length,
                  itemBuilder: (_, index) => _giftCard(schaleGifts[index]),
                ),
                missingSchaleStudents.isEmpty
                    ? const Center(
                        child: Text(
                          '모든 현재 학생이 SchaleDB 데이터와 연결되었습니다.',
                          style: TextStyle(color: AppColors.success),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            '자동 매칭되지 않은 현재 학생',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final id in missingSchaleStudents)
                            ListTile(
                              leading: const Icon(
                                Icons.link_off,
                                color: AppColors.warning,
                              ),
                              title: Text(id),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _singleSchalePane() {
    final preview = singleSchalePreview;
    const fieldLabels = {
      'schaledb_id': 'SchaleDB ID',
      'favor_item_tags': '일반 선호 태그',
      'favor_item_unique_tags': '고유 선호 태그',
    };
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '단일 학생 최소 필드 가져오기',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'SchaleDB URL 또는 slug를 입력합니다. 학생 3개 필드와 선물 4개 필드 외에는 가져오지 않습니다.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 430,
                      child: TextField(
                        controller: singleSchaleSource,
                        onSubmitted: (_) => _loadSingleSchalePreview(),
                        decoration: const InputDecoration(
                          labelText: 'SchaleDB URL / slug',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: singleSchaleStudentId,
                        decoration: const InputDecoration(
                          labelText: '로컬 Student ID (선택)',
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _useSelectedForSingleImport,
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('선택 학생 사용'),
                    ),
                    FilledButton.icon(
                      onPressed: busy ? null : _loadSingleSchalePreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('미리보기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (singleSchaleMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              singleSchaleMessage!,
              style: const TextStyle(color: AppColors.success),
            ),
          ),
        if (preview == null)
          const Padding(
            padding: EdgeInsets.only(top: 70),
            child: Center(
              child: Text(
                'URL 또는 slug를 입력해 저장 전 결과를 확인하세요.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _portrait(preview['template_name'] as String),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preview['display_name'] as String,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${preview['student_id']} · ${preview['source_slug']}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              preview['exists'] == true
                                  ? Icons.edit_outlined
                                  : Icons.add,
                              size: 16,
                            ),
                            label: Text(
                              preview['exists'] == true ? '기존 학생' : '신규 초안',
                            ),
                            backgroundColor:
                                (preview['exists'] == true
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withValues(alpha: 0.14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final name
                              in (preview['changed_fields'] as List))
                            Chip(
                              avatar: const Icon(Icons.sync, size: 15),
                              label: Text('${fieldLabels[name] ?? name} 변경'),
                              backgroundColor: AppColors.warning.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          if ((preview['changed_fields'] as List).isEmpty)
                            const Chip(
                              avatar: Icon(Icons.check, size: 15),
                              label: Text('학생 필드 동일'),
                            ),
                          Chip(
                            avatar: const Icon(Icons.card_giftcard, size: 15),
                            label: Text('선물 ${preview['gift_count']}개'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _giftAffinityStrip(
                        '특별 선호',
                        preview['special_gifts'],
                        color: const Color(0xffd982e5),
                        maxVisible: 4,
                      ),
                      const SizedBox(height: 8),
                      _giftAffinityStrip(
                        '일반 선호',
                        preview['preferred_gifts'],
                        color: AppColors.primary,
                        maxVisible: 6,
                      ),
                      const SizedBox(height: 12),
                      if (preview['exists'] != true)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            '신규 학생은 필수 로컬 필드가 없으므로 직접 저장할 수 없습니다. 편집기에 반영한 뒤 이름·템플릿·그룹을 입력하세요.',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : _loadSinglePreviewIntoEditor,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('편집기에 반영'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: busy || preview['exists'] != true
                                ? null
                                : _applySingleSchalePreview,
                            icon: const Icon(Icons.download_done),
                            label: const Text('최소 7개 필드 저장'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mergePathsPane() => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.24),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.merge_type, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '한 로컬 학생에 SchaleDB 경로를 2개 이상 연결합니다. 첫 번째 경로가 최소 인연 필드의 기준이고, 나머지는 같은 학생으로 찾기 위한 보조 경로입니다.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: mergeStudentId,
                decoration: const InputDecoration(
                  labelText: '로컬 Student ID',
                  helperText: '보유 메타데이터의 학생 ID',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 7,
              child: TextField(
                controller: mergePaths,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'SchaleDB slug 또는 URL',
                  helperText: '첫 줄: 기준 경로 · 이후 줄: 보조 경로',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _useSelectedForMergeRule,
                  icon: const Icon(Icons.person_pin_outlined),
                  label: const Text('선택 학생 사용'),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: busy ? null : _saveMergePaths,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('규칙 저장'),
                ),
              ],
            ),
          ],
        ),
        if (mergePathMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              mergePathMessage!,
              style: const TextStyle(color: AppColors.success),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: mergePathRules.isEmpty
              ? Center(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _loadMergePaths,
                    icon: const Icon(Icons.refresh),
                    label: const Text('병합 규칙 불러오기'),
                  ),
                )
              : ListView.separated(
                  itemCount: mergePathRules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = mergePathRules[index];
                    final paths = (row['paths'] as List)
                        .map((value) => value.toString())
                        .toList();
                    final selected = selectedMergeRuleId == row['student_id'];
                    return Card(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: busy ? null : () => _selectMergeRule(row),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _portrait(row['template_name'] as String? ?? ''),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row['display_name'] as String,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      row['student_id'] as String,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 6,
                                      children: [
                                        for (
                                          var pathIndex = 0;
                                          pathIndex < paths.length;
                                          pathIndex++
                                        )
                                          Chip(
                                            avatar: Icon(
                                              pathIndex == 0
                                                  ? Icons.flag_outlined
                                                  : Icons.call_merge,
                                              size: 15,
                                            ),
                                            label: Text(
                                              '${pathIndex == 0 ? '기준' : '보조 $pathIndex'} · ${paths[pathIndex]}',
                                            ),
                                            backgroundColor:
                                                (pathIndex == 0
                                                        ? AppColors.primary
                                                        : AppColors
                                                              .surfaceRaised)
                                                    .withValues(
                                                      alpha: pathIndex == 0
                                                          ? 0.16
                                                          : 0.7,
                                                    ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                IconButton(
                                  tooltip: '규칙 삭제',
                                  onPressed: busy ? null : _deleteMergePaths,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget _schaleSyncPane() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.groups_outlined),
              label: Text('전체 동기화'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.person_search_outlined),
              label: Text('단일 학생'),
            ),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.merge_type),
              label: Text('병합 경로'),
            ),
          ],
          selected: {schaleMode},
          onSelectionChanged: busy
              ? null
              : (value) {
                  final next = value.first;
                  setState(() => schaleMode = next);
                  if (next == 2 && mergePathRules.isEmpty) _loadMergePaths();
                },
        ),
      ),
      Expanded(
        child: switch (schaleMode) {
          1 => _singleSchalePane(),
          2 => _mergePathsPane(),
          _ => _bulkSchaleSyncPane(),
        },
      ),
    ],
  );

  Widget _debugAssetBadge(
    IconData icon,
    String label,
    bool available, {
    String? asset,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: (available ? AppColors.success : AppColors.warning).withValues(
        alpha: 0.12,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (asset == null)
          Icon(
            icon,
            size: 16,
            color: available ? AppColors.success : AppColors.warning,
          )
        else
          SizedBox(
            width: 22,
            height: 22,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(icon, size: 16),
            ),
          ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _debugStudentCard(Map<String, dynamic> row) {
    final selected = selectedDebugId == row['student_id'];
    final matchFound = row['match_found'] as int? ?? 0;
    final matchTotal = row['match_total'] as int? ?? 0;
    return Card(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy
            ? null
            : () => _selectMetadataDebug(row['student_id'] as String),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _portrait(
                row['portrait_asset'] == null
                    ? ''
                    : (row['portrait_asset'] as String).split('/').last,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row['display_name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(row['server'] as String),
                          backgroundColor:
                              (row['server'] == 'JP'
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withValues(alpha: 0.14),
                        ),
                      ],
                    ),
                    Text(
                      '${row['student_id']} · ${row['school']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _debugAssetBadge(
                          Icons.center_focus_strong,
                          '인식 $matchFound/$matchTotal',
                          matchFound == matchTotal,
                        ),
                        _debugAssetBadge(
                          Icons.face_outlined,
                          '초상',
                          row['portrait'] == true,
                        ),
                        _debugAssetBadge(
                          Icons.hexagon_outlined,
                          '엘레프',
                          row['eleph'] == true,
                          asset: row['eleph_asset'] as String?,
                        ),
                        if ((row['multi_form_count'] as int? ?? 0) > 0)
                          _debugAssetBadge(
                            Icons.layers_outlined,
                            '폼 ${row['multi_form_count']}',
                            true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugDetailPane() {
    final detail = debugDetail;
    if (detail == null) {
      return const Center(
        child: Text(
          '조건에 맞는 학생이 없습니다.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    final assets = (detail['assets'] as Map).cast<String, dynamic>();
    final fields = (detail['fields'] as List).cast<Map>();
    final forms = (detail['forms'] as List? ?? const []).cast<Map>();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _portrait(detail['template_name'] as String),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail['display_name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        detail['student_id'] as String,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _debugAssetBadge(
                            Icons.center_focus_strong,
                            '인식 ${assets['match_found']}/${assets['match_total']}',
                            assets['match_found'] == assets['match_total'],
                          ),
                          _debugAssetBadge(
                            Icons.face_outlined,
                            '초상',
                            assets['portrait'] == true,
                          ),
                          _debugAssetBadge(
                            Icons.hexagon_outlined,
                            '엘레프',
                            assets['eleph'] == true,
                            asset: assets['eleph_asset'] as String?,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: detail['server'] == 'JP'
                            ? FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _setMetadataServer('kr'),
                                icon: const Icon(Icons.public),
                                label: const Text('KR로 전환'),
                              )
                            : OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _setMetadataServer('jp'),
                                icon: const Icon(Icons.language),
                                label: const Text('JP 전용 지정'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (forms.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              '다중 폼',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final form in forms)
                Container(
                  constraints: const BoxConstraints(minWidth: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '폼 ${form['label']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${form['template_name']}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (form['role'] != null)
                        Text(
                          '${form['attack_type'] ?? '—'} · ${form['defense_type'] ?? '—'} · ${form['role']}',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(
            '전체 메타데이터',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                ListTile(
                  dense: true,
                  title: Text(
                    '${fields[index]['label']}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  subtitle: SelectableText(
                    '${fields[index]['value']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (index < fields.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _metadataDebugPane() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          children: [
            _SummaryBadge(
              icon: Icons.people_outline,
              label: '전체',
              value: '${debugCounts['all'] ?? 0}',
            ),
            const SizedBox(width: 7),
            _SummaryBadge(
              icon: Icons.public,
              label: 'KR',
              value: '${debugCounts['kr'] ?? 0}',
              color: AppColors.success,
            ),
            const SizedBox(width: 7),
            _SummaryBadge(
              icon: Icons.language,
              label: 'JP',
              value: '${debugCounts['jp'] ?? 0}',
              color: AppColors.warning,
            ),
            const Spacer(),
            IconButton(
              onPressed: busy ? null : _loadMetadataDebug,
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: debugSearch,
                onSubmitted: (_) => _loadMetadataDebug(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: '학생·ID·학교·속성 검색',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: debugServer,
                decoration: const InputDecoration(labelText: '서버'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'kr', child: Text('KR')),
                  DropdownMenuItem(value: 'jp', child: Text('JP 전용')),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => debugServer = value);
                        _loadMetadataDebug();
                      },
              ),
            ),
          ],
        ),
      ),
      if (debugMessage != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              debugMessage!,
              style: const TextStyle(color: AppColors.success),
            ),
          ),
        ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final list = ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              itemCount: debugStudents.length,
              itemBuilder: (_, index) =>
                  _debugStudentCard(debugStudents[index]),
            );
            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  SizedBox(width: 520, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(child: _debugDetailPane()),
                ],
              );
            }
            return Column(
              children: [
                Flexible(child: list),
                const Divider(height: 1),
                Flexible(child: _debugDetailPane()),
              ],
            );
          },
        ),
      ),
    ],
  );

  String _itemCategoryLabel(String value) => switch (value) {
    'equipment' => '장비',
    'activity_report' => '활동 보고서',
    'tech_notes' => '기술 노트',
    'tactical_bd' => '전술 교육 BD',
    'oopart' => '오파츠',
    'workbook' => '능력 해방 교본',
    'student_eleph' => '학생 엘레프',
    'missing_catalog' => '카탈로그 미등록',
    _ => value,
  };

  (String, Color, IconData) _itemStatusStyle(String status) => switch (status) {
    'negative' => ('부족', AppColors.danger, Icons.trending_down),
    'zero' => ('0', AppColors.warning, Icons.remove_circle_outline),
    'positive' => ('보유', AppColors.success, Icons.check_circle_outline),
    'unknown' => ('미확인', AppColors.textMuted, Icons.help_outline),
    _ => ('스냅샷 없음', AppColors.textMuted, Icons.visibility_off_outlined),
  };

  Widget _itemKpi(String label, Object value, IconData icon, Color color) =>
      Container(
        width: 155,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _itemCategoryCard(Map<String, dynamic> row) {
    final catalog = row['catalog_count'] as int? ?? 0;
    final snapshot = row['snapshot_count'] as int? ?? 0;
    final coverage = catalog == 0 ? 0.0 : snapshot / catalog;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _itemCategoryLabel(row['category'] as String),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: coverage.clamp(0.0, 1.0),
              minHeight: 5,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 7),
            Text(
              '스냅샷 $snapshot/$catalog · 확인 ${row['known_count']} · 미확인 ${row['unknown_count']} · 부재 ${row['absent_count']}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemAnalysisCard(Map<String, dynamic> row) {
    final style = _itemStatusStyle(row['status'] as String);
    final current = row['current_qty'] as int?;
    final adjusted = row['adjusted_qty'] as int?;
    final delta = row['plan_delta'] as int? ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                image: const DecorationImage(
                  image: AssetImage('assets/item_backgrounds/square.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: row['icon_asset'] == null
                  ? const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.textMuted,
                    )
                  : Image.asset(
                      row['icon_asset'] as String,
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['display_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_itemCategoryLabel(row['category'] as String)} · ${row['resource_key']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    current == null
                        ? '현재 미확인${delta == 0 ? '' : ' · 계획 ${delta > 0 ? '+' : ''}$delta (계산 보류)'}'
                        : '현재 $current${delta == 0 ? '' : ' · 계획 ${delta > 0 ? '+' : ''}$delta'} · 결과 $adjusted',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: Icon(style.$3, size: 16, color: style.$2),
              label: Text(style.$1),
              backgroundColor: style.$2.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemAnalysisPane() {
    final summary = itemSummary;
    if (summary == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: busy ? null : _loadItemAnalysis,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('선택 계정 아이템 통계 불러오기'),
        ),
      );
    }
    final visible = _visibleItemRows;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 390,
                child: TextField(
                  controller: itemInventoryPath,
                  decoration: InputDecoration(
                    labelText: '인벤토리 또는 v7 프로필 JSON',
                    helperText: itemSourceLabel,
                    suffixIcon: IconButton(
                      tooltip: 'JSON 선택',
                      onPressed: busy
                          ? null
                          : () => _pickItemJson(itemInventoryPath),
                      icon: const Icon(Icons.folder_open),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 390,
                child: TextField(
                  controller: itemPlanPath,
                  decoration: InputDecoration(
                    labelText: '계획 증감 JSON (선택)',
                    helperText: '항목별 delta만 읽으며 원본은 수정하지 않음',
                    suffixIcon: IconButton(
                      tooltip: '계획 JSON 선택',
                      onPressed: busy
                          ? null
                          : () => _pickItemJson(itemPlanPath),
                      icon: const Icon(Icons.folder_open),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: busy ? null : _loadItemAnalysis,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 분석'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _itemKpi(
                '카탈로그',
                summary['catalog_count']!,
                Icons.category_outlined,
                AppColors.primary,
              ),
              _itemKpi(
                '스냅샷',
                summary['snapshot_count']!,
                Icons.inventory_2_outlined,
                AppColors.primary,
              ),
              _itemKpi(
                '수량 확인',
                summary['known_count']!,
                Icons.visibility_outlined,
                AppColors.success,
              ),
              _itemKpi(
                '수량 미확인',
                summary['unknown_count']!,
                Icons.help_outline,
                AppColors.textMuted,
              ),
              _itemKpi(
                '명시적 0',
                summary['zero_count']!,
                Icons.remove_circle_outline,
                AppColors.warning,
              ),
              _itemKpi(
                '계획 반영 부족',
                summary['negative_count']!,
                Icons.trending_down,
                AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: '아이템 이름·ID·분류 검색',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: itemStatusFilter,
                  decoration: const InputDecoration(labelText: '상태'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('전체')),
                    DropdownMenuItem(value: 'negative', child: Text('부족')),
                    DropdownMenuItem(value: 'zero', child: Text('0')),
                    DropdownMenuItem(value: 'positive', child: Text('보유')),
                    DropdownMenuItem(value: 'unknown', child: Text('미확인')),
                    DropdownMenuItem(value: 'absent', child: Text('스냅샷 없음')),
                  ],
                  onChanged: (value) =>
                      setState(() => itemStatusFilter = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 175,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: itemSort,
                  decoration: const InputDecoration(labelText: '정렬'),
                  items: const [
                    DropdownMenuItem(value: 'shortage', child: Text('부족 우선')),
                    DropdownMenuItem(
                      value: 'adjusted_asc',
                      child: Text('결과 오름차순'),
                    ),
                    DropdownMenuItem(
                      value: 'adjusted_desc',
                      child: Text('결과 내림차순'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('이름순')),
                  ],
                  onChanged: (value) =>
                      setState(() => itemSort = value ?? 'shortage'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final categories = ListView.builder(
                  scrollDirection: constraints.maxWidth >= 900
                      ? Axis.vertical
                      : Axis.horizontal,
                  itemCount: itemCategories.length,
                  itemBuilder: (_, index) => SizedBox(
                    width: constraints.maxWidth >= 900 ? null : 280,
                    child: _itemCategoryCard(itemCategories[index]),
                  ),
                );
                final items = visible.isEmpty
                    ? const Center(child: Text('조건에 맞는 아이템이 없습니다.'))
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, index) =>
                            _itemAnalysisCard(visible[index]),
                      );
                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: [
                      SizedBox(width: 310, child: categories),
                      const VerticalDivider(width: 12),
                      Expanded(child: items),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(height: 125, child: categories),
                    const Divider(height: 10),
                    Expanded(child: items),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      statusStrip(),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.edit_note),
                label: Text('보유 메타데이터'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.sync_alt),
                label: Text('SchaleDB 가져오기'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.fact_check_outlined),
                label: Text('메타데이터 진단'),
              ),
              ButtonSegment(
                value: 3,
                icon: Icon(Icons.analytics_outlined),
                label: Text('아이템 통계'),
              ),
            ],
            selected: {metadataSurface},
            onSelectionChanged: busy
                ? null
                : (value) {
                    final next = value.first;
                    setState(() => metadataSurface = next);
                    if (next == 2 && debugStudents.isEmpty) {
                      _loadMetadataDebug();
                    }
                    if (next == 3 && itemSummary == null) _loadItemAnalysis();
                  },
          ),
        ),
      ),
      Expanded(
        child: switch (metadataSurface) {
          1 => _schaleSyncPane(),
          2 => _metadataDebugPane(),
          3 => _itemAnalysisPane(),
          _ => LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 390, child: _studentListPane()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _editorPane()),
                  ],
                );
              }
              return Column(
                children: [
                  Flexible(flex: 2, child: _studentListPane()),
                  const Divider(height: 1),
                  Expanded(flex: 3, child: _editorPane()),
                ],
              );
            },
          ),
        },
      ),
    ],
  );
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Text('$label ', style: const TextStyle(color: AppColors.textMuted)),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class TemplateExtractorPage extends StatefulWidget {
  const TemplateExtractorPage({super.key, required this.client});
  final ToolBackend client;

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
  final ToolBackend client;

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
