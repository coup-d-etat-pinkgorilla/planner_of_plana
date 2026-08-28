import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'repository_service.dart';
import 'scanner_service.dart';

const studentScanDiagnosticFormat = 'ba_planner_student_scan_diagnostic';
const studentScanDiagnosticVersion = 1;

const _jsonTypeGroup = XTypeGroup(
  label: 'BA Planner student scan diagnostic',
  extensions: <String>['json'],
  mimeTypes: <String>['application/json'],
);

abstract interface class StudentScanDiagnosticFileService {
  Future<String?> save({
    required String suggestedName,
    required String contents,
  });
}

class NativeStudentScanDiagnosticFileService
    implements StudentScanDiagnosticFileService {
  const NativeStudentScanDiagnosticFileService();

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[_jsonTypeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(contents)),
      mimeType: 'application/json',
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return location.path;
  }
}

Map<String, dynamic> buildStudentScanDiagnosticDocument({
  required ScannerSession session,
  required ScannerSessionSnapshot snapshot,
  required RepositoryState repositoryState,
  required DateTime generatedAt,
}) {
  if (session.kind != ScannerKind.student ||
      snapshot.kind != ScannerKind.student ||
      snapshot.sessionId != session.id ||
      snapshot.generation != session.generation) {
    throw const FormatException('Student scan diagnostic session mismatch');
  }
  if (snapshot.terminal != 'completed') {
    throw const FormatException(
      'Only completed student scan sessions can be exported',
    );
  }

  final candidates = snapshot.candidates
      .where((candidate) => candidate.kind == ScannerKind.student)
      .toList(growable: false);
  final candidateStudentIds = candidates
      .map((candidate) => candidate.payload['student_id'])
      .whereType<String>()
      .toSet();
  final confirmed =
      repositoryState.students
          .where((student) => candidateStudentIds.contains(student.studentId))
          .map((student) => student.toWire())
          .toList(growable: false)
        ..sort(
          (left, right) => (left['student_id'] as String).compareTo(
            right['student_id'] as String,
          ),
        );
  final statusCounts = <String, int>{};
  for (final candidate in candidates) {
    for (final evidence in candidate.evidence) {
      statusCounts.update(
        evidence.status,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  return {
    'format': studentScanDiagnosticFormat,
    'version': studentScanDiagnosticVersion,
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'privacy': const {
      'account_name_included': false,
      'window_title_included': false,
      'images_included': false,
    },
    'session': {
      'session_id': session.id,
      'generation': session.generation,
      'scan_kind': session.kind.wireName,
      'student_scan_mode': session.studentScanMode.name,
      'terminal': snapshot.terminal,
      'last_sequence': snapshot.lastSequence,
    },
    'summary': {
      'candidate_count': candidates.length,
      'review_required_count': candidates
          .where((candidate) => candidate.reviewRequired)
          .length,
      'approved_count': candidates
          .where((candidate) => candidate.approved)
          .length,
      'evidence_status_counts': {
        for (final key in statusCounts.keys.toList()..sort())
          key: statusCounts[key],
      },
    },
    'repository_context': {
      'revision': repositoryState.revision,
      'confirmed_students': confirmed,
    },
    'candidates': candidates.map(_candidateToWire).toList(growable: false),
    'events': snapshot.events.map(_eventToWire).toList(growable: false),
  };
}

String encodeStudentScanDiagnosticDocument(Map<String, dynamic> document) =>
    const JsonEncoder.withIndent('  ').convert(document);

String defaultStudentScanDiagnosticFileName(
  ScannerSession session,
  DateTime generatedAt,
) {
  final stamp = generatedAt.toUtc().toIso8601String().replaceAll(':', '-');
  return 'ba-planner-student-scan-$stamp-${session.studentScanMode.name}.json';
}

Map<String, dynamic> _candidateToWire(ScannerCandidate candidate) => {
  'candidate_id': candidate.id,
  'session_id': candidate.sessionId,
  'generation': candidate.generation,
  'revision': candidate.revision,
  'scan_kind': candidate.kind.wireName,
  'payload': candidate.payload,
  'evidence': candidate.evidence.map(_evidenceToWire).toList(growable: false),
  'review_required': candidate.reviewRequired,
  'approved': candidate.approved,
  'audit': candidate.audit,
};

Map<String, dynamic> _evidenceToWire(ScannerFieldEvidence evidence) => {
  'field': evidence.field,
  'status': evidence.status,
  'source': evidence.source,
  if (evidence.confidence != null) 'confidence': evidence.confidence,
  if (evidence.note.isNotEmpty) 'note': evidence.note,
  if (evidence.details != null) 'details': evidence.details,
};

Map<String, dynamic> _eventToWire(ScannerEvent event) => {
  'sequence': event.sequence,
  'event_kind': event.eventKind.name,
  'payload': event.payload,
};
