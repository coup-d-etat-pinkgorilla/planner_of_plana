import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'F12 production Dart to Python scanner probe',
    () async {
      if (Platform.environment['BA_F12_LIVE'] != '1') {
        return;
      }
      final kind = ScannerKindWire.fromWire(
        Platform.environment['BA_F12_KIND'] ?? 'student',
      );
      final mode = StudentScanMode.values.byName(
        Platform.environment['BA_F12_MODE'] ?? 'single',
      );
      final inventoryScanProfile =
          Platform.environment['BA_F12_INVENTORY_PROFILE'];
      final outputPath = Platform.environment['BA_F12_OUTPUT'];
      if (outputPath == null || outputPath.isEmpty) {
        throw StateError('BA_F12_OUTPUT is required');
      }
      final maxSeconds = int.parse(
        Platform.environment['BA_F12_TIMEOUT_SECONDS'] ?? '240',
      );
      final cancelAfter = int.parse(
        Platform.environment['BA_F12_CANCEL_AFTER_CANDIDATES'] ?? '0',
      );
      final cancelAfterSeconds = int.parse(
        Platform.environment['BA_F12_CANCEL_AFTER_SECONDS'] ?? '0',
      );
      final backend = Directory.current.parent.uri
          .resolve('backend')
          .toFilePath();
      final config = BackendProcessConfig.resolve(backendDirectory: backend);
      final service = ProcessAppService.fromConfig(config);
      final stopwatch = Stopwatch()..start();
      final events = <({ScannerEvent event, int receivedMs})>[];
      final errors = <String>[];
      final started = DateTime.now().toUtc();
      final subscription = service.scannerEvents.listen(
        (event) => events.add((
          event: event,
          receivedMs: stopwatch.elapsedMilliseconds,
        )),
        onError: (Object error) => errors.add('$error'),
      );
      ScannerSession? session;
      ScannerSessionSnapshot? snapshot;
      Map<String, dynamic>? cancelResult;
      try {
        await service.reconnect();
        final readiness = await service.scannerReadiness();
        final targets = await service.listScannerTargets();
        final targetId = Platform.environment['BA_F12_TARGET_ID'];
        final target = targets.firstWhere(
          (item) => targetId == null
              ? item.status == ScannerTargetStatus.ready
              : item.id == targetId,
        );
        session = await service.startScannerSession(
          kind,
          target.id,
          profileId: Platform.environment['BA_F12_PROFILE_ID'],
          studentScanMode: mode,
          inventoryScanProfile: inventoryScanProfile == null
              ? null
              : InventoryScanProfile.fromWire(inventoryScanProfile),
        );
        final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
        while (DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          final own = events
              .where((item) => item.event.sessionId == session!.id)
              .toList();
          final candidates = own
              .where(
                (item) => item.event.eventKind == ScannerEventKind.candidate,
              )
              .length;
          if (cancelAfter > 0 &&
              candidates >= cancelAfter &&
              cancelResult == null) {
            cancelResult = await service.cancelScannerSession(session);
          }
          if (cancelAfterSeconds > 0 &&
              stopwatch.elapsed >= Duration(seconds: cancelAfterSeconds) &&
              cancelResult == null) {
            cancelResult = await service.cancelScannerSession(session);
          }
          if (own.any(
            (item) => item.event.eventKind == ScannerEventKind.terminal,
          )) {
            break;
          }
        }
        snapshot = await service.scannerSnapshot(session);
        if (snapshot.terminal == null) {
          cancelResult ??= await service.cancelScannerSession(session);
          await Future<void>.delayed(const Duration(seconds: 1));
          snapshot = await service.scannerSnapshot(session);
        }
        final finished = DateTime.now().toUtc();
        final own = events
            .where((item) => item.event.sessionId == session!.id)
            .toList();
        final report = <String, dynamic>{
          'schema_version': 1,
          'evidence_partition': 'new_f12_native_scan',
          'mutations': {'review': 0, 'revalidate': 0, 'commit': 0},
          'started_at_utc': started.toIso8601String(),
          'finished_at_utc': finished.toIso8601String(),
          'elapsed_ms': finished.difference(started).inMilliseconds,
          'kind': kind.wireName,
          'student_scan_mode': mode.name,
          'target': {
            'id': target.id,
            'title': target.title,
            'status': target.status.name,
            'foreground': target.foreground,
          },
          'readiness': readiness,
          'session': {'id': session.id, 'generation': session.generation},
          'cancel_result': cancelResult,
          'errors': errors,
          'events': own
              .map(
                (item) => {
                  'received_ms': item.receivedMs,
                  'sequence': item.event.sequence,
                  'event_kind': item.event.eventKind.name,
                  'payload': item.event.payload,
                },
              )
              .toList(),
          'snapshot': {
            'terminal': snapshot.terminal,
            'last_sequence': snapshot.lastSequence,
            'candidate_count': snapshot.candidates.length,
            'candidates': snapshot.candidates
                .map(
                  (candidate) => {
                    'id': candidate.id,
                    'revision': candidate.revision,
                    'review_required': candidate.reviewRequired,
                    'approved': candidate.approved,
                    'payload': candidate.payload,
                    'evidence': candidate.evidence
                        .map(
                          (item) => {
                            'field': item.field,
                            'status': item.status,
                            'source': item.source,
                            'confidence': item.confidence,
                            'note': item.note,
                            'details': item.details,
                          },
                        )
                        .toList(),
                  },
                )
                .toList(),
          },
        };
        final output = File(outputPath);
        output.parent.createSync(recursive: true);
        output.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n',
        );
        expect(errors, isEmpty);
        expect(snapshot.terminal, anyOf('completed', 'cancelled'));
      } finally {
        await subscription.cancel();
        await service.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
