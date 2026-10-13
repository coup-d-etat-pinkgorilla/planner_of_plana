// fb10c-dart: FB-10c 학생 무기 폴백 crop의 프론트 개인정보·수명.
// 기준: backend 로그 2026-10-13 18:02, debug/xb_fb10c_crop_lifecycle_20261013/artifacts/CF-CONNECTION.md,
// README "학생 스캔 진단 파일"(진단 파일은 스크린샷을 포함하지 않는다).
import 'dart:async';
import 'dart:convert';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_review_images.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/student_scan_diagnostic.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/widgets/scan_student_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트용 합성 1×1 PNG(base64). 실제 화면 캡처가 아니다.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
const _pngSignature = 'iVBORw0KGgo';

Map<String, dynamic> _cropDetails({Map<String, dynamic> extra = const {}}) => {
  'crop_png_base64': _pngBase64,
  'crop_source': 'basic_info',
  'crop_width': 1,
  'crop_height': 1,
  'delta': {'AttackPower': 0},
  ...extra,
};

Map<String, dynamic> _candidateWire(
  String id, {
  required String sessionId,
  int generation = 1,
  int revision = 1,
  String field = 'weapon_level_fallback',
  String studentId = 'aru',
  bool approved = false,
  Map<String, dynamic>? details,
}) => {
  'candidate_id': id,
  'session_id': sessionId,
  'generation': generation,
  'revision': revision,
  'scan_kind': 'student',
  'payload': {
    'version': 1,
    'student_id': studentId,
    'values': {'level': 90},
  },
  'evidence': [
    {
      'field': field,
      'status': 'ok',
      'source': 'weapon_panel_fallback',
      'confidence': 1.0,
      'note': 'synthetic fallback evidence',
      'details': details ?? _cropDetails(),
    },
    {
      'field': 'level',
      'status': 'ok',
      'source': 'synthetic',
      'confidence': 0.99,
    },
  ],
  'review_required': false,
  'approved': approved,
  'audit': <dynamic>[],
};

Map<String, dynamic> _eventWire(
  String sessionId,
  int sequence,
  ScannerEventKind kind,
  Map<String, dynamic> payload,
) => {
  'session_id': sessionId,
  'generation': 1,
  'sequence': sequence,
  'scan_kind': 'student',
  'event_kind': kind.name,
  ...payload,
};

/// 백엔드 `remove_student_crop_images`와 같이 `crop_png_base64`만 제자리에서 지운다(테스트 대역의 백엔드 쪽).
void _backendRemoveCrop(Object? value) {
  if (value is Map) {
    value.remove('crop_png_base64');
    value.values.forEach(_backendRemoveCrop);
  } else if (value is List) {
    value.forEach(_backendRemoveCrop);
  }
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

bool _candidateHasImage(ScannerCandidate candidate) =>
    candidate.evidence.any((item) => scannerValueHasReviewImage(item.details));

Map<String, dynamic>? _fallbackDetails(ScannerCandidate candidate) => candidate
    .evidence
    .firstWhere((item) => item.field.endsWith('_fallback'))
    .details;

RepositoryState _emptyRepository() => RepositoryState.fromWire({
  'profile_id': '0123456789abcdef01234567',
  'revision': 4,
  'students': [
    {
      'version': 1,
      'student_id': 'aru',
      'values': {'level': 80},
    },
  ],
  'inventory': {'version': 1, 'entries': <dynamic>[]},
  'goals': {'version': 1, 'goals': <dynamic>[]},
});

void main() {
  group('wire', () {
    test(
      'optional crop details pass through the candidate and snapshot DTOs',
      () {
        final candidate = ScannerCandidate.fromWire(
          _candidateWire('c1', sessionId: 's1'),
        );
        expect(_fallbackDetails(candidate), {
          'crop_png_base64': _pngBase64,
          'crop_source': 'basic_info',
          'crop_width': 1,
          'crop_height': 1,
          'delta': {'AttackPower': 0},
        });

        final snapshot = ScannerSessionSnapshot.fromWire({
          'session_id': 's1',
          'generation': 1,
          'scan_kind': 'student',
          'last_sequence': 2,
          'terminal': 'completed',
          'control_state': 'terminal',
          'reason': null,
          'events': [
            _eventWire('s1', 1, ScannerEventKind.candidate, {
              'candidate': _candidateWire('c1', sessionId: 's1'),
            }),
            _eventWire('s1', 2, ScannerEventKind.terminal, {
              'outcome': 'completed',
            }),
          ],
          'candidates': [_candidateWire('c1', sessionId: 's1')],
        });
        expect(_candidateHasImage(snapshot.candidates.single), isTrue);
        expect(
          scannerValueHasReviewImage(snapshot.events.first.payload),
          isTrue,
        );

        // 폴백이 아닌 행·crop 없는 후보는 예전 모양 그대로다.
        final plain = ScannerCandidate.fromWire(
          _candidateWire(
            'c2',
            sessionId: 's1',
            details: {
              'delta': {'MaxHP': 1},
            },
          ),
        );
        expect(_candidateHasImage(plain), isFalse);
        expect(
          identical(scannerCandidateWithoutReviewImages(plain), plain),
          isTrue,
        );
      },
    );
  });

  group('image rule', () {
    test('image keys are removed recursively and metadata stays', () {
      expect(isScannerReviewImageKey('crop_png_base64'), isTrue);
      expect(isScannerReviewImageKey('panel_crop_png_base64'), isTrue);
      expect(isScannerReviewImageKey('preview_png'), isTrue);
      expect(isScannerReviewImageKey('slot_image'), isTrue);
      expect(isScannerReviewImageKey('screenshot'), isTrue);
      for (final kept in [
        'crop_source',
        'crop_width',
        'crop_height',
        'delta',
        'expected',
        'image_count',
      ]) {
        expect(isScannerReviewImageKey(kept), isFalse, reason: kept);
      }

      final original = <String, dynamic>{
        'crop_png_base64': _pngBase64,
        'crop_source': 'basic_info',
        'crop_width': 8,
        'crop_height': 4,
        'nested': {
          'rows': [
            {'thumb_png_base64': _pngBase64, 'value': 3},
            'data:image/png;base64,$_pngBase64',
            _pngBase64,
            'plain text',
          ],
          'blob': _pngBase64,
          'preview_image': {'width': 1},
        },
      };
      final before = jsonEncode(original);
      final cleaned = scannerMapWithoutReviewImages(original);

      expect(jsonEncode(original), before, reason: '원래 Map은 바꾸지 않는다');
      expect(cleaned, {
        'crop_source': 'basic_info',
        'crop_width': 8,
        'crop_height': 4,
        'nested': {
          'rows': [
            {'value': 3},
            'plain text',
          ],
        },
      });
      expect(scannerValueHasReviewImage(cleaned), isFalse);
      expect(jsonEncode(cleaned), isNot(contains(_pngSignature)));
    });

    test(
      'candidate, event and recent copies release only the named candidate',
      () {
        final first = ScannerCandidate.fromWire(
          _candidateWire('c1', sessionId: 's1'),
        );
        final second = ScannerCandidate.fromWire(
          _candidateWire('c2', sessionId: 's1', field: 'weapon_star_fallback'),
        );
        final released = scannerCandidateWithoutReviewImages(first);
        expect(_candidateHasImage(released), isFalse);
        expect(_fallbackDetails(released), {
          'crop_source': 'basic_info',
          'crop_width': 1,
          'crop_height': 1,
          'delta': {'AttackPower': 0},
        });
        expect(released.revision, first.revision);
        expect(released.evidence[1], same(first.evidence[1]));
        expect(_candidateHasImage(first), isTrue, reason: '원래 후보는 그대로다');

        final event = ScannerEvent.fromPayload(
          _eventWire('s1', 1, ScannerEventKind.candidate, {
            'candidate': _candidateWire('c1', sessionId: 's1'),
          }),
        );
        expect(scannerEventWithoutCandidateImages(event, 'c2'), same(event));
        final cleanedEvent = scannerEventWithoutCandidateImages(event, 'c1');
        expect(scannerValueHasReviewImage(cleanedEvent.payload), isFalse);
        expect(cleanedEvent.sequence, 1);
        expect(
          (((cleanedEvent.payload['candidate'] as Map)['evidence'] as List)
                  .first
              as Map)['details'],
          containsPair('crop_width', 1),
        );

        final summary = ScannerRecentSummary(
          session: const ScannerSession(
            id: 's1',
            generation: 1,
            kind: ScannerKind.student,
          ),
          targetId: 't',
          targetTitle: 'Target',
          outcome: 'completed',
          phase: null,
          diagnostic: null,
          candidateCount: 2,
          reviewRequired: false,
          progressCurrent: null,
          progressTotal: null,
          messageKey: null,
          terminalError: null,
          candidates: [first, second],
        );
        final recent = scannerRecentWithoutCandidateImages(summary, 'c1');
        expect(_candidateHasImage(recent.candidates[0]), isFalse);
        expect(recent.candidates[1], same(second));
        expect(recent.candidateCount, 2);
        expect(
          scannerRecentWithoutCandidateImages(recent, 'c1'),
          same(recent),
          reason: '이미 지운 요약은 그대로 돌려준다',
        );
      },
    );
  });

  group('diagnostic', () {
    test(
      'candidate details and nested event candidates are exported without images',
      () {
        const session = ScannerSession(
          id: 's1',
          generation: 1,
          kind: ScannerKind.student,
          studentScanMode: StudentScanMode.full,
        );
        final firstWire = _candidateWire(
          'c1',
          sessionId: 's1',
          details: _cropDetails(
            extra: {
              'history': [
                {'panel_png_base64': _pngBase64, 'read': 7},
              ],
            },
          ),
        );
        final secondWire = _candidateWire(
          'c2',
          sessionId: 's1',
          field: 'weapon_star_fallback',
          studentId: 'hoshino',
        );
        final snapshot = ScannerSessionSnapshot.fromWire({
          'session_id': 's1',
          'generation': 1,
          'scan_kind': 'student',
          'last_sequence': 3,
          'terminal': 'completed',
          'control_state': 'terminal',
          'reason': null,
          'events': [
            _eventWire('s1', 1, ScannerEventKind.candidate, {
              'candidate': firstWire,
            }),
            _eventWire('s1', 2, ScannerEventKind.candidate, {
              'candidate': secondWire,
            }),
            _eventWire('s1', 3, ScannerEventKind.terminal, {
              'outcome': 'completed',
            }),
          ],
          'candidates': [firstWire, secondWire],
        });

        final document = buildStudentScanDiagnosticDocument(
          session: session,
          snapshot: snapshot,
          repositoryState: _emptyRepository(),
          generatedAt: DateTime.utc(2026, 10, 14),
        );
        final encoded = encodeStudentScanDiagnosticDocument(document);
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;

        expect(_pngSignature.allMatches(encoded), isEmpty);
        expect(encoded, isNot(contains('crop_png_base64')));
        expect(encoded, isNot(contains('panel_png_base64')));
        expect(scannerValueHasReviewImage(decoded), isFalse);
        expect(decoded['privacy'], {
          'account_name_included': false,
          'window_title_included': false,
          'images_included': false,
        });

        final candidates = (decoded['candidates'] as List).cast<Map>();
        final firstDetails =
            ((candidates[0]['evidence'] as List).first as Map)['details']
                as Map;
        expect(firstDetails, {
          'crop_source': 'basic_info',
          'crop_width': 1,
          'crop_height': 1,
          'delta': {'AttackPower': 0},
          'history': [
            {'read': 7},
          ],
        });
        for (final event in (decoded['events'] as List).cast<Map>().take(2)) {
          final candidate = (event['payload'] as Map)['candidate'] as Map;
          final details =
              ((candidate['evidence'] as List).first as Map)['details'] as Map;
          expect(details['crop_source'], 'basic_info');
          expect(details['crop_width'], 1);
          expect(details.containsKey('crop_png_base64'), isFalse);
        }
        expect(decoded['summary'], {
          'candidate_count': 2,
          'review_required_count': 0,
          'approved_count': 0,
          'evidence_status_counts': {'ok': 4},
        });

        // 진단은 받은 후보·이벤트 사본을 바꾸지 않는다(검토용 crop은 보류 동안 남는다).
        expect(_candidateHasImage(snapshot.candidates.first), isTrue);
        expect(
          scannerValueHasReviewImage(snapshot.events.first.payload),
          isTrue,
        );
      },
    );
  });

  group('scan page lifecycle', () {
    testWidgets(
      'hold and revalidate keep crops, discard and apply release only that candidate',
      (tester) async {
        final service = _CropScanService();
        final files = _RecordingDiagnosticFiles();
        addTearDown(service.dispose);
        final recent = <List<ScannerRecentSummary>>[];
        await _open(tester, service, recent.add, files);
        await _startCropScan(tester);

        expect(recent, hasLength(1), reason: 'terminal에서 최근 요약 1회');
        expect(recent.last.single.candidates.every(_candidateHasImage), isTrue);
        var shown = await _shownCandidates(tester);
        expect(shown.map((item) => item.id), ['crop-1', 'crop-2']);
        expect(shown.every(_candidateHasImage), isTrue);
        final workspace = await _workspace(tester);

        // 보류: 백엔드 호출 없이 crop 유지.
        await workspace.onHold(shown[0]);
        await tester.pump();
        shown = await _shownCandidates(tester);
        expect(shown.every(_candidateHasImage), isTrue);

        // 수정·재검증: 새 revision도 crop을 싣고 온다.
        await _revalidate(
          workspace,
          shown[0],
          Map<String, dynamic>.from(shown[0].payload),
        );
        await tester.pump();
        shown = await _shownCandidates(tester);
        expect(shown[0].revision, 2);
        expect(shown.every(_candidateHasImage), isTrue);
        expect(recent, hasLength(1), reason: '보류·재검증은 최근 요약을 바꾸지 않는다');

        // 적용 전에도 진단을 저장할 수 있다. 백엔드 snapshot에 crop이 있어도 파일에는 이미지가 없다.
        expect(service.backendHasImage('crop-1'), isTrue);
        final export = find.byKey(
          const ValueKey('scan-export-student-diagnostic'),
        );
        await _seek(tester, export);
        await tester.tap(export);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        final contents = files.contents!;
        expect(_pngSignature.allMatches(contents), isEmpty);
        expect(contents, isNot(contains('crop_png_base64')));
        expect(contents, contains('"crop_source": "basic_info"'));
        expect(
          (jsonDecode(contents) as Map)['privacy'],
          containsPair('images_included', false),
        );

        // 폐기: 그 후보만 지운다.
        await (await _workspace(tester)).onDiscard(shown[1]);
        await tester.pump();
        shown = await _shownCandidates(tester);
        expect(shown.map((item) => item.id), ['crop-1']);
        expect(_candidateHasImage(shown.single), isTrue);
        expect(recent, hasLength(2));
        final afterDiscard = recent.last.single.candidates;
        expect(_candidateHasImage(afterDiscard[0]), isTrue);
        expect(_candidateHasImage(afterDiscard[1]), isFalse);
        expect(
          _fallbackDetails(afterDiscard[1]),
          containsPair('crop_width', 1),
        );
        expect(service.backendHasImage('crop-2'), isFalse);
        expect(service.backendHasImage('crop-1'), isTrue);

        // 적용(승인 → commit 성공): 남은 후보의 crop도 지운다.
        await (await _workspace(tester)).onApply(shown.single);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(service.commits, 1);
        expect(await _notice(tester), contains('repository revision'));
        expect(recent.last.single.candidates.any(_candidateHasImage), isFalse);
        expect(
          recent.last.single.candidates.map((item) => item.id),
          ['crop-1', 'crop-2'],
          reason: '최근 요약의 후보 목록·개수는 그대로이고 이미지만 빠진다',
        );
        expect(service.backendHasImage('crop-1'), isFalse);
      },
    );

    testWidgets(
      'approval releases at once and a failed write keeps the other candidate crop',
      (tester) async {
        final service = _CropScanService()..loseNextCommit = true;
        addTearDown(service.dispose);
        final recent = <List<ScannerRecentSummary>>[];
        await _open(tester, service, recent.add, _RecordingDiagnosticFiles());
        await _startCropScan(tester);
        var shown = await _shownCandidates(tester);

        await (await _workspace(tester)).onApply(shown[0]);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        // 저장 결과를 모른다: 후보는 승인된 revision으로 남고(다시 적용 가능) crop은 승인 때 지워졌다.
        expect(await _notice(tester), contains('적용 결과를 확인하지 못했습니다'));
        shown = await _shownCandidates(tester);
        expect(shown.map((item) => item.id), ['crop-1', 'crop-2']);
        expect(shown[0].approved, isTrue);
        expect(_candidateHasImage(shown[0]), isFalse);
        expect(_candidateHasImage(shown[1]), isTrue);
        final summary = recent.last.single.candidates;
        expect(_candidateHasImage(summary[0]), isFalse);
        expect(_candidateHasImage(summary[1]), isTrue);

        // 같은 요청을 다시 보내 성공해도 다른 후보 crop은 그대로다.
        await (await _workspace(tester)).onApply(shown[0]);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(service.commits, 2);
        shown = await _shownCandidates(tester);
        expect(shown.map((item) => item.id), ['crop-2']);
        expect(_candidateHasImage(shown.single), isTrue);
        expect(_candidateHasImage(recent.last.single.candidates[1]), isTrue);
      },
    );
  });
}

Future<void> _open(
  WidgetTester tester,
  MockAppService service,
  ValueChanged<List<ScannerRecentSummary>> onRecentChanged,
  StudentScanDiagnosticFileService files,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScanPage(
          service: service,
          onCandidateHandoff: (_, _) {},
          onRecentChanged: onRecentChanged,
          studentScanDiagnosticFileService: files,
          now: () => DateTime.utc(2026, 10, 14, 9),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _startCropScan(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('scan-target')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('· mock-window').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('scan-start')));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

/// 스캔 페이지 목록을 맨 위에서부터 내려 [finder]가 만들어지게 한다(목록은 보이는 범위만 만든다).
Future<void> _seek(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('scan-page')),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  while (finder.evaluate().isEmpty &&
      position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      (position.pixels + 250).clamp(0.0, position.maxScrollExtent).toDouble(),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// 결과 안내 문구(`scan-student-candidate-notice`). 화면 밖일 수 있으므로 찾아서 읽는다.
Future<String> _notice(WidgetTester tester) async {
  final notice = find.byKey(const ValueKey('scan-student-candidate-notice'));
  await _seek(tester, notice);
  return tester.widget<Text>(notice).data!;
}

Future<ScanStudentReviewWorkspace> _workspace(WidgetTester tester) async {
  final finder = find.byType(ScanStudentReviewWorkspace);
  await _seek(tester, finder);
  return tester.widget<ScanStudentReviewWorkspace>(finder);
}

/// 검토 작업 공간의 "수정·재검증" 콜백을 부른다. 스캐너 미커밋 작업이 확인 필드 인자를 더했다(HEAD는 3개). 커밋
/// 트리와 작업 트리 모두에서 컴파일되도록 인자 수를 콜백 형태에 맞춘다.
Future<void> _revalidate(
  ScanStudentReviewWorkspace workspace,
  ScannerCandidate candidate,
  Map<String, dynamic> payload,
) async {
  final Function callback = workspace.onRevalidate;
  final withConfirmedFields =
      callback
          is Future<void> Function(
            ScannerCandidate,
            Map<String, dynamic>,
            Map<int, int>,
            Set<String>,
          );
  await (Function.apply(callback, [
        candidate,
        payload,
        const <int, int>{},
        if (withConfirmedFields) const <String>{},
      ])
      as Future<void>);
}

/// 지금 화면이 보관한 학생 후보(검토 작업 공간에 넘긴 목록).
Future<List<ScannerCandidate>> _shownCandidates(WidgetTester tester) async =>
    (await _workspace(tester)).candidates.toList()
      ..sort((left, right) => left.id.compareTo(right.id));

class _RecordingDiagnosticFiles implements StudentScanDiagnosticFileService {
  String? contents;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    this.contents = contents;
    return 'C:/fake/$suggestedName';
  }
}

/// crop을 실은 학생 후보 두 개를 내는 스캐너 대역. 수명 규칙은 백엔드(scanner_session.py
/// `_release_candidate_images`)와 같다: 승인·폐기 review와 commit 성공 때 그 후보와 retained event의 crop만 지운다.
class _CropScanService extends MockAppService {
  static const _sessionId = 'crop-session';

  final StreamController<ScannerEvent> _events = StreamController.broadcast();
  final Map<String, Map<String, dynamic>> _store = {};
  final List<Map<String, dynamic>> _history = [];
  bool loseNextCommit = false;
  int commits = 0;
  final Set<String> _committedKeys = {};

  bool backendHasImage(String candidateId) =>
      scannerValueHasReviewImage(_store[candidateId]) ||
      _history.any(
        (event) =>
            (event['candidate'] as Map?)?['candidate_id'] == candidateId &&
            scannerValueHasReviewImage(event),
      );

  @override
  Stream<ScannerEvent> get scannerEvents => _events.stream;

  void _emit(ScannerEventKind kind, Map<String, dynamic> payload) {
    final wire = _eventWire(_sessionId, _history.length + 1, kind, payload);
    _history.add(wire);
    _events.add(ScannerEvent.fromPayload(_deepCopy(wire)));
  }

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async {
    const session = ScannerSession(
      id: _sessionId,
      generation: 1,
      kind: ScannerKind.student,
    );
    _store['crop-1'] = _candidateWire('crop-1', sessionId: _sessionId);
    _store['crop-2'] = _candidateWire(
      'crop-2',
      sessionId: _sessionId,
      field: 'weapon_star_fallback',
      studentId: 'hoshino',
    );
    Timer(const Duration(milliseconds: 5), () {
      _emit(ScannerEventKind.phase, {'phase': 'capturing'});
      for (final id in ['crop-1', 'crop-2']) {
        _emit(ScannerEventKind.candidate, {
          'candidate': _deepCopy(_store[id]!),
        });
      }
      _emit(ScannerEventKind.terminal, {'outcome': 'completed'});
    });
    return session;
  }

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(
    ScannerSession session,
  ) async => ScannerSessionSnapshot.fromWire({
    'session_id': _sessionId,
    'generation': 1,
    'scan_kind': 'student',
    'last_sequence': _history.length,
    'terminal': 'completed',
    'control_state': 'terminal',
    'reason': null,
    'events': [for (final event in _history) _deepCopy(event)],
    'candidates': [for (final wire in _store.values) _deepCopy(wire)],
  });

  void _release(String candidateId) {
    _backendRemoveCrop(_store[candidateId]);
    for (final event in _history) {
      final candidate = event['candidate'];
      if (candidate is Map && candidate['candidate_id'] == candidateId) {
        _backendRemoveCrop(candidate);
      }
    }
  }

  @override
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
    Map<int, int>? relationshipRanks,
    Set<String>? confirmedFields,
  }) async {
    final wire = _store[candidate.id]!;
    if (wire['revision'] != candidate.revision) {
      throw StateError('candidate_revision_conflict');
    }
    if (approve ||
        reason == 'discarded_in_scan_page' ||
        reason == 'discarded_in_student_page') {
      _release(candidate.id);
    }
    wire['payload'] = _deepCopy(payload);
    wire['revision'] = candidate.revision + 1;
    wire['approved'] = approve;
    return ScannerCandidate.fromWire(_deepCopy(wire));
  }

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) async {
    commits += 1;
    if (loseNextCommit) {
      loseNextCommit = false;
      throw TimeoutException('synthetic lost write before the backend');
    }
    if (!_committedKeys.contains(idempotencyKey)) {
      await saveRepositoryGoals(
        profileId,
        const {'version': 1, 'goals': <dynamic>[]},
        expectedRepositoryRevision,
        'crop-commit-$idempotencyKey',
      );
      _committedKeys.add(idempotencyKey);
    }
    _release(candidate.id);
    return {
      'candidate_id': candidate.id,
      'candidate_revision': candidate.revision,
      'profile_id': profileId,
      'revision': expectedRepositoryRevision + 1,
    };
  }

  @override
  Future<void> dispose() async {
    await _events.close();
    await super.dispose();
  }
}
