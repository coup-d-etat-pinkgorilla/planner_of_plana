import 'dart:collection';

import '../ui/models/planning_models.dart';

class PlanningAuthoringFormatException extends FormatException {
  const PlanningAuthoringFormatException(this.reason, String message)
    : super(message);
  final String reason;
}

Never _fail(String reason, String message) =>
    throw PlanningAuthoringFormatException(reason, message);

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    _fail('invalid_shape', 'Expected an authoring object');
  }
  return Map<String, dynamic>.from(raw);
}

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.length == keys.length && value.keys.toSet().containsAll(keys);

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    _fail('invalid_shape', 'Expected non-empty authoring text');
  }
  return value.trim();
}

List<dynamic> _array(Object? value) {
  if (value is! List) _fail('invalid_shape', 'Expected an authoring array');
  return value;
}

class PlanningStagePrerequisite {
  const PlanningStagePrerequisite({
    required this.stageId,
    required this.requiresStageId,
  });
  final String stageId;
  final String requiresStageId;
  Map<String, dynamic> toWire() => {
    'stage_id': stageId,
    'requires_stage_id': requiresStageId,
  };
}

/// Sidecar data. Calculation and goals consume only [PlanningDocument].
class PlanningAuthoring {
  PlanningAuthoring._({
    required List<PlanningStagePrerequisite> prerequisites,
    required List<PlanningDocumentStage> deferredStages,
    required List<String> studentOrder,
    required Map<String, List<String>> stageOrderByStudent,
    required Map<String, PlanningGoalMetadata> goalMetadata,
  }) : prerequisites = List.unmodifiable(prerequisites),
       deferredStages = List.unmodifiable(deferredStages),
       studentOrder = List.unmodifiable(studentOrder),
       stageOrderByStudent = Map.unmodifiable({
         for (final entry in stageOrderByStudent.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       goalMetadata = Map.unmodifiable(goalMetadata);

  final List<PlanningStagePrerequisite> prerequisites;
  final List<PlanningDocumentStage> deferredStages;
  final List<String> studentOrder;
  final Map<String, List<String>> stageOrderByStudent;
  final Map<String, PlanningGoalMetadata> goalMetadata;

  factory PlanningAuthoring.defaultForDocument(PlanningDocument document) {
    final order = <String, List<String>>{};
    for (final phase in document.phases) {
      for (final stage in phase.stages) {
        order.putIfAbsent(stage.studentId, () => []).add(stage.id);
      }
    }
    return PlanningAuthoring._(
      prerequisites: [],
      deferredStages: [],
      studentOrder: order.keys.toList(),
      stageOrderByStudent: order,
      goalMetadata: {},
    );
  }

  factory PlanningAuthoring.fromWire(Object? raw, PlanningDocument document) {
    // Validate public programmatic documents as well as parsed wire documents.
    document = PlanningDocument.fromWire(document.toWire());
    final value = _map(raw);
    if (!_exact(value, {
      'version',
      'prerequisites',
      'deferred_stages',
      'student_order',
      'stage_order_by_student',
      'goal_metadata',
    })) {
      _fail('invalid_shape', 'Authoring requires exactly six v1 keys');
    }
    if (value['version'] is! int || value['version'] != 1) {
      _fail('unsupported_version', 'Authoring version must be 1');
    }
    final students = _array(value['student_order']).map(_text).toList();
    if (students.toSet().length != students.length) {
      _fail('student_order', 'Selected student IDs must be unique');
    }
    final stages = <String, PlanningDocumentStage>{};
    final positions = <String, (int, int)>{};
    final placed = <String, List<String>>{};
    final deferred = <String, List<String>>{};
    for (var lane = 0; lane < document.phases.length; lane++) {
      final phase = document.phases[lane];
      for (var index = 0; index < phase.stages.length; index++) {
        final stage = phase.stages[index];
        stages[stage.id] = stage;
        positions[stage.id] = (lane, index);
        placed.putIfAbsent(stage.studentId, () => []).add(stage.id);
      }
    }
    final deferredStages = <PlanningDocumentStage>[];
    for (final rawStage in _array(value['deferred_stages'])) {
      final stageWire = _map(rawStage);
      if (!_exact(stageWire, {'stage_id', 'student_id', 'name', 'targets'})) {
        _fail('invalid_shape', 'Invalid deferred stage shape');
      }
      final id = _text(stageWire['stage_id']);
      final student = _text(stageWire['student_id']);
      final name = _text(stageWire['name']);
      if (stages.containsKey(id)) {
        _fail('stage_set', 'Duplicate global stage ID');
      }
      late PlanningDocumentStage stage;
      try {
        stage = PlanningDocumentStage.fromWire({
          ...stageWire,
          'stage_id': id,
          'student_id': student,
          'name': name,
        }, version: 2);
      } on FormatException catch (error) {
        _fail('targets', error.message.toString());
      } on TypeError {
        _fail('targets', 'Invalid nullable targets');
      }
      stages[id] = stage;
      positions[id] = (document.phases.length, deferredStages.length);
      deferred.putIfAbsent(student, () => []).add(id);
      deferredStages.add(stage);
    }
    final rawOrders = _map(value['stage_order_by_student']);
    if (!students.toSet().containsAll(stages.values.map((s) => s.studentId)) ||
        !_exact(rawOrders, students.toSet())) {
      _fail(
        'student_order',
        'Selected students and stage-order keys must match',
      );
    }
    final orders = <String, List<String>>{};
    final edges = <(String, String)>{};
    for (final student in students) {
      final rawIds = _array(rawOrders[student]);
      if (rawIds.any((id) => id is! String)) {
        _fail('invalid_shape', 'Stage order must contain string IDs');
      }
      final ids = rawIds.cast<String>().toList();
      final expected = [...?placed[student], ...?deferred[student]];
      if (ids.toSet().length != ids.length ||
          ids.length != expected.length ||
          !ids.toSet().containsAll(expected)) {
        _fail('stage_set', 'Student chain must cover exactly its own stages');
      }
      if (List.generate(
        ids.length,
        (i) => ids[i] == expected[i],
      ).contains(false)) {
        _fail(
          'stage_chain',
          'Placed prefix and deferred suffix must follow the chain',
        );
      }
      Map<String, int?>? previous;
      for (final id in ids) {
        final targets = stages[id]!.nullableTargets;
        if (previous != null) {
          for (final key in planningDocumentTargetKeys) {
            final before = previous[key];
            final after = targets[key];
            if (before != null && (after == null || after < before)) {
              _fail('target_regression', 'Target $key regresses at $id');
            }
          }
        }
        previous = targets;
      }
      orders[student] = ids;
      for (var i = 1; i < ids.length; i++) {
        edges.add((ids[i - 1], ids[i]));
      }
    }
    final rawMetadata = _map(value['goal_metadata']);
    if (!_exact(
      rawMetadata,
      students.toSet().difference(placed.keys.toSet()),
    )) {
      _fail(
        'goal_metadata',
        'Metadata must cover selected students absent from the document',
      );
    }
    final metadata = <String, PlanningGoalMetadata>{};
    for (final entry in rawMetadata.entries) {
      final meta = _map(entry.value);
      if (!_exact(meta, {'favorite', 'notes'}) ||
          meta['favorite'] is! bool ||
          meta['notes'] is! String) {
        _fail(
          'goal_metadata',
          'Metadata requires favorite bool and notes string',
        );
      }
      metadata[entry.key] = PlanningGoalMetadata(
        favorite: meta['favorite'] as bool,
        notes: meta['notes'] as String,
      );
    }
    final explicit = <(String, String)>{};
    for (final rawPair in _array(value['prerequisites'])) {
      final pair = _map(rawPair);
      if (!_exact(pair, {'stage_id', 'requires_stage_id'})) {
        _fail('invalid_shape', 'Prerequisite requires exactly two IDs');
      }
      final target = _text(pair['stage_id']);
      final source = _text(pair['requires_stage_id']);
      if (!stages.containsKey(source) || !stages.containsKey(target)) {
        _fail('stage_reference', 'Prerequisite refers to an absent stage');
      }
      if (source == target) {
        _fail('self_reference', 'A stage cannot require itself');
      }
      if (stages[source]!.studentId == stages[target]!.studentId) {
        _fail(
          'same_student_prerequisite',
          'The implicit chain owns same-student prerequisites',
        );
      }
      if (!explicit.add((source, target))) {
        _fail('duplicate_prerequisite', 'Duplicate direct prerequisite');
      }
    }
    edges.addAll(explicit);
    final successors = {for (final id in stages.keys) id: <String>[]};
    final indegree = {for (final id in stages.keys) id: 0};
    for (final edge in edges) {
      successors[edge.$1]!.add(edge.$2);
      indegree[edge.$2] = indegree[edge.$2]! + 1;
    }
    final queue = Queue<String>.from(
      stages.keys.where((id) => indegree[id] == 0),
    );
    var visited = 0;
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      visited++;
      for (final next in successors[id]!) {
        indegree[next] = indegree[next]! - 1;
        if (indegree[next] == 0) queue.add(next);
      }
    }
    if (visited != stages.length) {
      _fail('cycle', 'Implicit and direct prerequisites must form a DAG');
    }
    final orderedEdges = edges.toList()..sort(_edgeCompare);
    for (final edge in orderedEdges) {
      final source = positions[edge.$1]!;
      final target = positions[edge.$2]!;
      if (source.$1 > target.$1) {
        _fail('lane_order', 'Prerequisite is in a later lane');
      }
      if (source.$1 == target.$1 && source.$2 >= target.$2) {
        _fail('stage_order', 'Same-lane array must place prerequisites first');
      }
    }
    final pairs = explicit.toList()..sort(_edgeCompare);
    return PlanningAuthoring._(
      prerequisites: [
        for (final pair in pairs)
          PlanningStagePrerequisite(stageId: pair.$2, requiresStageId: pair.$1),
      ],
      deferredStages: deferredStages,
      studentOrder: students,
      stageOrderByStudent: orders,
      goalMetadata: metadata,
    );
  }

  static int _edgeCompare((String, String) a, (String, String) b) {
    final first = _textCompare(a.$1, b.$1);
    return first == 0 ? _textCompare(a.$2, b.$2) : first;
  }

  // Python sorts Unicode code points; String.compareTo compares UTF-16 units.
  static int _textCompare(String a, String b) {
    final left = a.runes.toList();
    final right = b.runes.toList();
    for (var i = 0; i < left.length && i < right.length; i++) {
      final difference = left[i].compareTo(right[i]);
      if (difference != 0) return difference;
    }
    return left.length.compareTo(right.length);
  }

  bool get hasContent => studentOrder.isNotEmpty || deferredStages.isNotEmpty;
  bool isDefaultForDocument(PlanningDocument document) => _deepEqual(
    toWire(),
    PlanningAuthoring.defaultForDocument(document).toWire(),
  );

  Map<String, dynamic> toWire() => {
    'version': 1,
    'prerequisites': prerequisites.map((p) => p.toWire()).toList(),
    'deferred_stages': deferredStages.map((s) => s.toWire()).toList(),
    'student_order': [...studentOrder],
    'stage_order_by_student': {
      for (final entry in stageOrderByStudent.entries)
        entry.key: [...entry.value],
    },
    'goal_metadata': {
      for (final entry in goalMetadata.entries) entry.key: entry.value.toWire(),
    },
  };
}

bool _deepEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _deepEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => _deepEqual(a[i], b[i])).every((v) => v);
  }
  return a == b;
}
