// fb10c-dart process E2E: 실제 Python 백엔드가 학생 무기 폴백 crop을 보내고(XB FB-10c 생산·세션 경계 연결·
// 수명 함수 그대로), Dart가 그것을 받아 진단에서 빼고, 폐기·승인·commit 뒤 백엔드 사본도 지워지는지 본다.
// 실제 게임·화면 캡처 없음: 합성 PIL 이미지 2장을 XB `weapon_fallback_review_details`로 인코딩한다.
// 저장소는 임시 폴더(끝에 지움). 디코드한 이미지는 메모리에서 PNG 시그니처만 확인하고 파일로 저장하지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_review_images.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/student_scan_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

/// 공용 E2E 진입점(`tests.scanner_e2e_backend`)의 학생 matcher는 crop을 내지 않는다. 이 테스트만의 진입점은
/// 실제 `ScannerSessionService`·`ApplicationProtocolV1`·`JsonRepository`에 폴백 행 2개를 내는 matcher만 붙인다.
const _backendScript = r'''
import sys
from pathlib import Path
from types import SimpleNamespace

from PIL import Image

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository
from core.runtime_paths import resolve_repository_root
from core.scanner_session import ScannerSessionService
from core.stdio_server import serve
from core.student_fallback_evidence import weapon_fallback_review_details


def _row(candidate_id, student_id, field, crop_key, size):
    evidence = [{
        "field": field,
        "status": "ok",
        "source": "weapon_panel_fallback",
        "confidence": 1.0,
        "note": "fb10c-dart synthetic fallback",
    }]
    crops = SimpleNamespace(images={crop_key: Image.new("RGB", size, (200, 40, 40))})
    return {
        "candidate_id": candidate_id,
        "payload": {
            "version": 1,
            "student_id": student_id,
            "values": {"level": 90},
            "provenance": {"level": "fb10c-dart-e2e"},
        },
        "evidence": evidence,
        "review_required": False,
        "_answer_specimen": {
            "fallback_review_details": weapon_fallback_review_details(evidence, crops),
        },
    }


def _student_matcher(_target, _cancel, progress):
    progress(1, 1, "fb10c_dart_e2e")
    return [
        _row("crop-1", "shiroko", "weapon_level_fallback", "basic_weapon_level_digits_quad", (6, 3)),
        _row("crop-2", "hoshino", "weapon_star_fallback", "basic_weapon_star_region", (5, 2)),
    ]


def main():
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    storage_root = resolve_repository_root()
    service = ScannerSessionService(
        target_provider=lambda: [{
            "target_id": "fb10c-dart-target",
            "title": "FB10c Dart Fixture",
            "status": "ready",
            "foreground": False,
        }],
        student_matcher=_student_matcher,
        inventory_matcher=lambda *_args: [],
        repository=JsonRepository(storage_root),
        asset_status=lambda: {
            "ready": True,
            "manifest_version": 1,
            "asset_count": 16,
            "missing": [],
            "corrupt": [],
        },
    )
    serve(protocol=ApplicationProtocolV1(
        storage_root=Path(storage_root),
        scanner_service=service,
    ))


main()
''';

const _pngSignature = 'iVBORw0KGgo';

Map<String, dynamic>? _fallbackDetails(ScannerCandidate candidate) => candidate
    .evidence
    .firstWhere((item) => item.field.endsWith('_fallback'))
    .details;

bool _hasImage(ScannerCandidate candidate) =>
    scannerValueHasReviewImage(_fallbackDetails(candidate));

bool _eventHasImage(ScannerSessionSnapshot snapshot, String candidateId) =>
    snapshot.events.any(
      (event) =>
          (event.payload['candidate'] as Map?)?['candidate_id'] ==
              candidateId &&
          scannerValueHasReviewImage(event.payload),
    );

ScannerCandidate _candidate(ScannerSessionSnapshot snapshot, String id) =>
    snapshot.candidates.singleWhere((item) => item.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real backend crop is accepted, kept out of diagnostics and released on discard and apply',
    () async {
      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_fb10c_e2e_',
      );
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final virtualEnvironmentPython = File(
        '${backendDirectory.path}${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}'
        '${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
      );
      final executable = virtualEnvironmentPython.existsSync()
          ? virtualEnvironmentPython.absolute.path
          : Platform.isWindows
          ? 'py'
          : 'python3';
      final usesPyLauncher =
          executable.split(RegExp(r'[/\\]')).last.toLowerCase() == 'py';
      final config = BackendProcessConfig(
        executable: executable,
        arguments: [
          if (Platform.isWindows && usesPyLauncher) '-3.11',
          '-c',
          _backendScript,
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storageRoot.path,
          'BA_PLANNER_ASSET_DIR': backendDirectory.absolute.path,
        },
      );
      final startedProcesses = <BackendProcessHandle>[];
      final service = ProcessAppService(
        PlanningProtocolClient(() async {
          final process = await startBackendProcess(config);
          startedProcesses.add(process);
          return process;
        }, defaultTimeout: const Duration(seconds: 10)),
      );
      final errors = <Object>[];
      final subscription = service.scannerEvents.listen(
        (_) {},
        onError: errors.add,
      );

      var completed = false;
      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'FB10c Dart E2E',
          'fb10c-dart-e2e-profile',
          avatarStudentId: 'airi',
        );
        final target = (await service.listScannerTargets()).single;
        final session = await service.startScannerSession(
          ScannerKind.student,
          target.id,
          profileId: profile.id,
        );
        await service.scannerEvents
            .firstWhere(
              (event) =>
                  event.sessionId == session.id &&
                  event.eventKind == ScannerEventKind.terminal,
            )
            .timeout(const Duration(seconds: 10));

        // 1. wire: 실제 응답이 검사기·DTO를 지나 optional 4키를 그대로 싣는다.
        var snapshot = await service.scannerSnapshot(session);
        expect(snapshot.terminal, 'completed');
        expect(snapshot.candidates.map((item) => item.id).toSet(), {
          'crop-1',
          'crop-2',
        });
        final level = _fallbackDetails(_candidate(snapshot, 'crop-1'))!;
        expect(level.keys.toSet(), {
          'crop_png_base64',
          'crop_source',
          'crop_width',
          'crop_height',
        });
        expect(level['crop_source'], 'basic_info');
        expect([level['crop_width'], level['crop_height']], [6, 3]);
        final bytes = base64Decode(level['crop_png_base64'] as String);
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final star = _fallbackDetails(_candidate(snapshot, 'crop-2'))!;
        expect([star['crop_width'], star['crop_height']], [5, 2]);
        expect(_eventHasImage(snapshot, 'crop-1'), isTrue);
        expect(_eventHasImage(snapshot, 'crop-2'), isTrue);

        // 2. 진단: 백엔드가 crop을 들고 있는 동안에도 파일에는 이미지가 없다.
        String diagnostic(
          ScannerSessionSnapshot value,
          RepositoryState state,
        ) => encodeStudentScanDiagnosticDocument(
          buildStudentScanDiagnosticDocument(
            session: session,
            snapshot: value,
            repositoryState: state,
            generatedAt: DateTime.utc(2026, 10, 14),
          ),
        );
        final before = diagnostic(
          snapshot,
          await service.loadRepositoryState(profile.id),
        );
        expect(_pngSignature.allMatches(before), isEmpty);
        expect(before, isNot(contains('crop_png_base64')));
        expect('"crop_source": "basic_info"'.allMatches(before), hasLength(4));
        expect(
          (jsonDecode(before) as Map)['privacy'],
          containsPair('images_included', false),
        );

        // 3. 수정·재검증은 crop을 유지한다.
        final first = _candidate(snapshot, 'crop-1');
        final revised = await service.reviewScannerCandidate(
          session,
          first,
          first.payload,
          approve: false,
          reason: 'edited_and_revalidated_in_scan_page',
        );
        expect(revised.revision, first.revision + 1);
        expect(_hasImage(revised), isTrue);

        // 4. 폐기: 그 후보와 그 후보의 이벤트 사본만 지운다.
        final second = _candidate(snapshot, 'crop-2');
        final discarded = await service.reviewScannerCandidate(
          session,
          second,
          second.payload,
          approve: false,
          reason: 'discarded_in_scan_page',
        );
        expect(_hasImage(discarded), isFalse);
        expect(_fallbackDetails(discarded), {
          'crop_source': 'basic_info',
          'crop_width': 5,
          'crop_height': 2,
        });
        snapshot = await service.scannerSnapshot(session);
        expect(_hasImage(_candidate(snapshot, 'crop-2')), isFalse);
        expect(_eventHasImage(snapshot, 'crop-2'), isFalse);
        expect(_hasImage(_candidate(snapshot, 'crop-1')), isTrue);
        expect(_eventHasImage(snapshot, 'crop-1'), isTrue);

        // 5. 승인 → commit: 남은 후보도 지운다. 저장소 파일에는 crop이 없다.
        final approved = await service.reviewScannerCandidate(
          session,
          revised,
          revised.payload,
          approve: true,
          reason: 'applied_in_scan_page',
        );
        expect(approved.approved, isTrue);
        expect(_hasImage(approved), isFalse);
        final committed = await service.commitScannerCandidate(
          session,
          approved,
          profileId: profile.id,
          expectedRepositoryRevision: profile.revision,
          idempotencyKey: 'fb10c-dart-e2e-commit',
        );
        expect(committed['revision'], profile.revision + 1);
        snapshot = await service.scannerSnapshot(session);
        expect(snapshot.candidates.any(_hasImage), isFalse);
        expect(
          snapshot.events.any(
            (event) => scannerValueHasReviewImage(event.payload),
          ),
          isFalse,
        );
        final repository = await service.loadRepositoryState(profile.id);
        expect(
          repository.students
              .singleWhere((item) => item.studentId == 'shiroko')
              .values['level'],
          90,
        );
        final after = diagnostic(snapshot, repository);
        expect(_pngSignature.allMatches(after), isEmpty);
        for (final file
            in storageRoot.listSync(recursive: true).whereType<File>()) {
          final text = latin1.decode(file.readAsBytesSync());
          expect(text, isNot(contains('crop_png_base64')), reason: file.path);
          expect(text, isNot(contains(_pngSignature)), reason: file.path);
        }
        expect(errors, isEmpty);
        completed = true;
      } finally {
        await subscription.cancel();
        await service.dispose();
        final exitCodes = <int>[];
        for (final process in startedProcesses) {
          exitCodes.add(
            await process.exitCode.timeout(const Duration(seconds: 5)),
          );
        }
        if (storageRoot.existsSync()) {
          await storageRoot.delete(recursive: true);
        }
        expect(storageRoot.existsSync(), isFalse);
        if (completed) {
          expect(startedProcesses, hasLength(1));
          expect(exitCodes, everyElement(0));
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
