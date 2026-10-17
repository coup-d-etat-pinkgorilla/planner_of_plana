// FE9-c: 전술대항전 기록 화면 S2 로비 스캔(시안 Tactical S2 · 방어 이력 플라이아웃, G §1, FD-127 · FD-128).
//
// - 규칙: 후보 저장 전 막음(검토 필요 · 순위 없음), 자동 채움(공개 칸 `visible_lobby` · 2~4번 중복 지움), 카드(이름 · 순위 · 족보 줄 ·
//   내 전적), 방어 이력 구간 · 변경 주기, 링크 결과 · 오류 글자.
// - 배치: 기준 콘텐츠 캔버스에서 카드 3장 · 플라이아웃이 시안 rect ±2px, 1280×720에서 넘침 0 · 플라이아웃이 창 안.
// - 흐름(셸): 미연결 "지금 스캔" → 창 선택 패널, S2에서 시작 → 후보 → commit(revision · 시즌) → 카드 → 선택(select + 자동 채움)
//   → 저장 → link(auto) → 연결 글자, 링크 실패는 기록을 남기고 S2 글자, commit 실패 · 검토 필요 후보, 스캔 탭에서 시작한 로비
//   스캔은 인계(`_handoffCandidate`)할 때만 저장, 처리한 후보는 검토 대기에서 빠진다, 셸 `onOpenStudents`(FE8-g2 발견 2).
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/tactical_lobby_scanner_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_records_controller.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_header_progress.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_lobby_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_records_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tactical_lobby_fe9c_fixture.dart';

const _header = 184.0;

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

String _card(int index) => 'tactical-lobby-card-scan-1-candidate-$index';

void _expectRect(
  WidgetTester tester,
  String key,
  double x,
  double y,
  double width,
  double height, {
  double tolerance = 2,
}) {
  final rect = tester.getRect(_key(key));
  expect(rect.left, closeTo(x, tolerance), reason: '$key left');
  expect(rect.top, closeTo(y - _header, tolerance), reason: '$key top');
  expect(rect.width, closeTo(width, tolerance), reason: '$key width');
  expect(rect.height, closeTo(height, tolerance), reason: '$key height');
}

ScannerCandidate _candidate(Map<String, dynamic> payload) => ScannerCandidate(
  id: 'lobby-candidate-1',
  sessionId: 'fe9c-session-1',
  generation: 1,
  revision: 1,
  kind: ScannerKind.tacticalLobby,
  payload: payload,
  evidence: const [],
  reviewRequired: false,
  approved: false,
  audit: const [],
);

/// 시험 대역에 seed 기록 7개와 로비 스캔 하나를 넣는다(화면 밖에서 — revision 7 → 8).
Future<Fe9cLobbyService> _seededWithLobby() async {
  final service = Fe9cLobbyService();
  await fe9cSeedRecords(service);
  await service.commitTacticalLobby(
    profileId: fe9cProfileId,
    candidatePayload: fe9cLobbyPayload(),
    season: '10',
    map: '',
    identityBindings: const {},
    expectedRevision: 7,
    idempotencyKey: 'fe9c-direct-commit',
  );
  return service;
}

/// 화면 단독(셸 없이 — 스캔 버튼은 흐림). 기준 콘텐츠 캔버스 크기.
Future<void> _pumpPage(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(2560, 1208),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TacticalPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 이벤트 → 알림 → 저장(microtask) → 다시 읽기 → 다시 그리기가 끝날 만큼 프레임을 넘긴다(스캔 화면의 끝없는 막대 때문에
/// pumpAndSettle을 쓰지 않는다).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

TacticalPage _page(WidgetTester tester) =>
    tester.widget<TacticalPage>(find.byType(TacticalPage, skipOffstage: false));

ScanTabPage _scanTab(WidgetTester tester) =>
    tester.widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false));

/// 셸을 띄우고 seed를 넣은 계정으로 전술대항전 탭을 연다. [connect]면 게임 창을 연결한다.
Future<void> _openShell(
  WidgetTester tester,
  Fe9cLobbyService service, {
  bool connect = true,
  Size size = const Size(2560, 1392),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await fe9cSeedRecords(service);
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  if (connect) {
    _scanTab(tester).connectedTarget!.connect(fe9cReadyTarget);
    await tester.pumpAndSettle();
  }
  await tester.tap(_key('top-tab-pvp'));
  await tester.pumpAndSettle();
}

/// S2 "지금 스캔"으로 시작해 후보 · 끝을 낸다.
Future<void> _scanFromLobby(
  WidgetTester tester,
  Fe9cLobbyService service, {
  Map<String, dynamic>? payload,
}) async {
  await tester.tap(_key('tactical-lobby-scan'));
  await _settle(tester);
  expect(service.calls, contains('start:tacticalLobby'));
  service.emitLobbyCandidate(payload: payload);
  service.emitTerminal();
  await _settle(tester);
}

void main() {
  group('lobby rules', () {
    test('candidate blocker refuses review and missing ranks', () {
      TacticalLobbyScanCandidate decode(Map<String, dynamic> payload) =>
          TacticalLobbyScanCandidate.fromScannerCandidate(_candidate(payload));
      expect(tacticalLobbyCandidateBlocker(decode(fe9cLobbyPayload())), isNull);
      expect(
        tacticalLobbyCandidateBlocker(
          decode(fe9cLobbyPayload(reviewStatus: 'review_required')),
        ),
        tacticalLobbyReviewText,
      );
      expect(
        tacticalLobbyCandidateBlocker(
          decode(fe9cLobbyPayload(currentRank: null)),
        ),
        tacticalLobbyReviewText,
      );
      expect(
        tacticalLobbyCandidateBlocker(
          decode(
            fe9cLobbyPayload(
              rows: [
                fe9cLobbyRows[0],
                (name: '무명', rank: null, first: null, sp1: null, sp2: null),
                fe9cLobbyRows[2],
              ],
            ),
          ),
        ),
        tacticalLobbyReviewText,
      );
    });

    test('cards, history and auto fill follow the observed lobby', () async {
      final service = await _seededWithLobby();
      addTearDown(service.dispose);
      final state = await service.loadTacticalEvidenceState(fe9cProfileId);
      expect(state.revision, 8);
      final controller = TacticalRecordsController(service);
      addTearDown(controller.dispose);
      await controller.load(fe9cProfileId);
      final scan = tacticalLobbyLatestScan(state)!;
      final cards = tacticalLobbyCards(
        state: state,
        scan: scan,
        jokbo: controller.jokbo,
        matches: controller.matches,
        now: service.clockNow,
      );
      expect(
        [for (final card in cards) card.title],
        ['게헨나 선도부 · 23위', '아비도스 대책위원회 · 31위', '트리니티 정의실현부 · 27위'],
      );
      expect(cards[0].identityId, designReviewTacticalOpponentA);
      expect(cards[1].identityId, designReviewTacticalOpponentB);
      expect(
        [for (final card in cards) card.recordText],
        ['1승 1패', '1승 0패', '기록 없음'],
      );
      expect(
        [for (final card in cards) card.recordTone],
        [
          TacticalLobbyRecordTone.info,
          TacticalLobbyRecordTone.ok,
          TacticalLobbyRecordTone.none,
        ],
      );
      // 게헨나 공개 칸(히나 | 히비키 · 아코)의 족보 둘 중 패가 적은 아비도스 족보, 마지막 승리 10/2(KST) → 3일 전.
      expect(cards[0].jokboText, startsWith('족보 '));
      expect(cards[0].jokboText, endsWith(' · 3일 전 검증'));
      expect(cards[1].jokboText, '족보 없음');
      expect(cards[0].signature, 'hina|hibiki|ako');
      expect(tacticalLobbySelectedId(cards, null), isNull);

      // 아비도스: 10/2 기록(히나 공개 칸) → 10/5 로비(아루로 바뀜) = 두 구간, 시작 간격 약 3.85일.
      final history = tacticalLobbyHistory(
        card: cards[1],
        state: state,
        matches: controller.matches,
      );
      expect(history.title, '아비도스 대책위원회 · 31위 · 최근 방어 덱 2종');
      expect(
        [for (final row in history.rows) row.period],
        ['10/5 ~ 현재', '10/2 ~ 10/2'],
      );
      expect(history.rows.first.current, isTrue);
      expect(history.rows.first.recordText, '기록 없음');
      expect(history.rows.last.recordText, '1승 0패');
      expect(tacticalLobbySignature(history.rows.last.deck), 'hina|hibiki|ako');
      expect(history.cycleText, '변경 주기 평균 4일');
      // 게헨나: 기록 둘(10/3 · 10/4)과 로비가 같은 공개 칸 = 한 구간, 그 구간에서 가장 많이 아는 덱(기록 덱).
      final gehenna = tacticalLobbyHistory(
        card: cards[0],
        state: state,
        matches: controller.matches,
      );
      expect(gehenna.rows.single.period, '10/3 ~ 현재');
      expect(gehenna.rows.single.recordText, '1승 1패');
      expect(
        tacticalDeckSlots(
          gehenna.rows.single.deck,
        ).map((slot) => slot.studentId),
        ['hina', 'iori', 'aru', 'haruka', 'hibiki', 'ako'],
      );
      expect(gehenna.cycleText, '변경 주기 평균 —');

      // 자동 채움: 공개 칸 3개 = 로비 관측, 2~4번에 같은 학생이 있으면 모름으로, 내 덱 · 결과는 그대로.
      final base = TacticalRecordDraft.blank(season: '10').copyWith(
        kind: 'defense',
        opponentDeck: tacticalDeckWithSlot(tacticalUnknownDeck(), 2, 'hina'),
        myDeck: tacticalDeckWithSlot(tacticalUnknownDeck(), 0, 'hoshino'),
      );
      final filled = tacticalDraftWithLobby(base, cards[0]);
      expect(filled.kind, 'attack');
      expect(filled.opponentName, '게헨나 선도부');
      expect(filled.opponentIdentityId, designReviewTacticalOpponentA);
      final slots = tacticalDeckSlots(filled.opponentDeck);
      expect(
        [for (final slot in slots) slot.studentId],
        ['hina', null, null, null, 'hibiki', 'ako'],
      );
      expect(
        [
          for (final index in [0, 4, 5]) slots[index].state,
        ],
        ['visible_lobby', 'visible_lobby', 'visible_lobby'],
      );
      expect(slots[0].source, 'lobby_scan');
      expect(tacticalDeckSlots(filled.myDeck).first.studentId, 'hoshino');
      expect(filled.season, '10');
    });

    test('link results and lobby errors read as section text', () {
      TacticalLinkResult link(String status, [int? count]) =>
          TacticalLinkResult(
            revision: 1,
            status: status,
            candidateId: null,
            matchId: 'm',
            candidateCount: count,
          );
      expect(
        tacticalLobbyLinkNotice(link('automatic')).text,
        tacticalLobbyLinkedText,
      );
      expect(
        tacticalLobbyLinkNotice(link('automatic')).tone,
        TacticalLobbyTone.ok,
      );
      expect(
        tacticalLobbyLinkNotice(link('unresolved', 0)).text,
        tacticalLobbyUnresolvedText,
      );
      expect(
        tacticalLobbyLinkNotice(link('ambiguous', 2)).text,
        tacticalLobbyAmbiguousText(2),
      );
      expect(
        tacticalLobbyErrorText(
          TacticalLobbyAction.link,
          const TacticalRecordsError('link_conflict', ''),
        ),
        contains('기록은 저장했습니다'),
      );
      expect(
        tacticalLobbyErrorText(
          TacticalLobbyAction.commit,
          const TacticalRecordsError('revision_conflict', ''),
        ),
        tacticalRecordsErrorMessages['revision_conflict'],
      );
      expect(
        tacticalLobbyErrorText(
          TacticalLobbyAction.commit,
          const TacticalRecordsError('something_new', ''),
        ),
        '로비 스캔을 저장하지 못했습니다.',
      );
    });
  });

  group('lobby layout', () {
    testWidgets('cards and flyout sit on the prototype rects', (tester) async {
      final service = await _seededWithLobby();
      addTearDown(service.dispose);
      await _pumpPage(tester, service);
      expect(
        _text(tester, 'tactical-lobby-caption'),
        tacticalLobbyCountCaption(3),
      );
      _expectRect(
        tester,
        'tactical-slot-lobby-title',
        838.1,
        229.2,
        1052.9,
        36,
      );
      _expectRect(
        tester,
        'tactical-slot-lobby-card-0',
        817.0,
        281.2,
        356.5,
        104,
      );
      _expectRect(
        tester,
        'tactical-slot-lobby-card-1',
        1171.2,
        281.2,
        356.5,
        104,
      );
      _expectRect(
        tester,
        'tactical-slot-lobby-card-2',
        1525.3,
        281.2,
        356.5,
        104,
      );
      expect(_text(tester, 'tactical-lobby-card-title-0'), '게헨나 선도부 · 23위');
      // FD-127: 방어 승률 · 30일 수치는 없다.
      expect(find.textContaining('방어 승률'), findsNothing);
      // 화면 단독에는 셸 스캔 세션이 없어 "지금 스캔"이 흐리다.
      expect(
        tester.widget<TonalButton>(_key('tactical-lobby-scan')).onPressed,
        isNull,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(_key(_card(1))));
      await tester.pump();
      // 시안 `.fly.dl`: 카드 왼쪽 · 카드 아래 12 · 폭 540(두 줄 = 181.6).
      _expectRect(tester, 'tactical-lobby-flyout', 1171.2, 397.2, 540, 181.6);
      expect(
        _text(tester, 'tactical-lobby-flyout-title'),
        '아비도스 대책위원회 · 31위 · 최근 방어 덱 2종',
      );
      expect(_key('tactical-lobby-flyout-row-1'), findsOneWidget);
      expect(_text(tester, 'tactical-lobby-flyout-cycle'), '변경 주기 평균 4일');
      // 아비도스 공개 시그니처(아루)의 최근 30일 공격 기록이 없어 "상대 카드 열기"가 없다.
      expect(_key('tactical-lobby-flyout-open'), findsNothing);
      // 카드 → 플라이아웃으로 옮겨도 닫히지 않고, 둘 다 벗어나면 잠깐 뒤 닫힌다.
      await gesture.moveTo(tester.getCenter(_key('tactical-lobby-flyout')));
      await tester.pump(tacticalLobbyHoverExitDelay * 2);
      expect(_key('tactical-lobby-flyout'), findsOneWidget);
      await gesture.moveTo(const Offset(5, 1150));
      await tester.pump(tacticalLobbyHoverExitDelay * 2);
      expect(_key('tactical-lobby-flyout'), findsNothing);
      // 게헨나 카드는 최근 30일 공격 기록이 있어 분석 상대 카드로 갈 수 있다.
      await gesture.moveTo(tester.getCenter(_key(_card(0))));
      await tester.pump();
      expect(_key('tactical-lobby-flyout-open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280x720 keeps cards and flyout inside', (tester) async {
      final service = await _seededWithLobby();
      addTearDown(service.dispose);
      await _pumpPage(tester, service, size: const Size(1280, 720));
      expect(tester.takeException(), isNull);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      for (var index = 0; index < 3; index++) {
        await gesture.moveTo(tester.getCenter(_key(_card(index))));
        await tester.pump();
        final rect = tester.getRect(_key('tactical-lobby-flyout'));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(1280));
        expect(rect.bottom, lessThanOrEqualTo(720));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('default mock shows the empty lobby state', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await _pumpPage(tester, service);
      expect(_text(tester, 'tactical-lobby-message'), tacticalLobbyEmptyText);
      expect(_text(tester, 'tactical-lobby-caption'), tacticalLobbyCaption);
      expect(
        tester.widget<TonalButton>(_key('tactical-lobby-scan')).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('lobby flow in the shell', () {
    testWidgets('not connected: scan opens the window picker', (tester) async {
      final service = Fe9cLobbyService();
      addTearDown(service.dispose);
      await _openShell(tester, service, connect: false);
      expect(_text(tester, 'tactical-lobby-message'), tacticalLobbyEmptyText);
      await tester.tap(_key('tactical-lobby-scan'));
      await tester.pumpAndSettle();
      expect(_key('tactical-connect-panel'), findsOneWidget);
      expect(service.calls, isNot(contains('start:tacticalLobby')));
      await tester.tap(_key('home-connect-panel-cancel'));
      await tester.pumpAndSettle();
      expect(_key('tactical-connect-panel'), findsNothing);
      expect(_text(tester, 'tactical-lobby-caption'), tacticalLobbyConnectText);
      // 다시 열어 창을 쓰면 연결되고 패널이 닫힌다.
      await tester.tap(_key('tactical-lobby-scan'));
      await tester.pumpAndSettle();
      _page(tester).connectedTarget!.connect(fe9cReadyTarget);
      await tester.pumpAndSettle();
      expect(_key('tactical-connect-panel'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scan → commit → cards → select → save → automatic link', (
      tester,
    ) async {
      final service = Fe9cLobbyService();
      addTearDown(service.dispose);
      await _openShell(tester, service);
      await _scanFromLobby(tester, service);
      expect(service.calls, contains('commit:7:10'));
      expect(
        _text(tester, 'tactical-lobby-caption'),
        tacticalLobbySavedText(3),
      );
      expect(_key(_card(0)), findsOneWidget);
      expect(_key('tactical-lobby-card-record-0'), findsOneWidget);
      // 처리한 후보는 검토 대기에서 빠진다(셸 점 · 스캔 탭 고르기), 전술 탭에 있어 완료 토스트도 없다.
      final scan = _scanTab(tester).controller;
      expect(
        ScanHeaderStatus.of(
          scan,
          appliedElsewhere: _page(tester).scanAppliedElsewhere,
        ).activity,
        ScanHeaderActivity.idle,
      );
      expect(_key('scan-end-toast'), findsNothing);

      await tester.tap(_key(_card(0)));
      await _settle(tester);
      expect(service.calls, contains('select:scan-1-candidate-0:8'));
      expect(
        service.lobbyCandidate('scan-1-candidate-0')!['selected_at'],
        '2026-10-05T12:00:00Z',
      );
      expect(_text(tester, 'tactical-editor-header'), '새 공격 기록');
      expect(
        tester
            .widget<TextField>(_key('tactical-opponent-name'))
            .controller!
            .text,
        '게헨나 선도부',
      );
      expect(_text(tester, 'tactical-jokbo-target-blank'), '2 · 3 · 4번 빈칸');
      expect(
        _text(tester, 'tactical-lobby-caption'),
        tacticalLobbyFilledText('게헨나 선도부'),
      );

      await tester.tap(_key('tactical-save'));
      await _settle(tester);
      final link = service.calls.where((call) => call.startsWith('link:'));
      expect(link, hasLength(1));
      expect(link.single, endsWith(':auto:10'));
      expect(_text(tester, 'tactical-lobby-caption'), tacticalLobbyLinkedText);
      expect(
        service.lobbyCandidate('scan-1-candidate-0')!['link_status'],
        'automatic',
      );
      // 저장한 기록이 골라졌고, S3 문구는 링크와 무관하다.
      expect(_text(tester, 'tactical-editor-header'), startsWith('공격 기록 · '));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed link keeps the saved record', (tester) async {
      final service = Fe9cLobbyService();
      addTearDown(service.dispose);
      await _openShell(tester, service);
      await _scanFromLobby(tester, service);
      await tester.tap(_key(_card(2)));
      await _settle(tester);
      service.failLink = 'link_conflict';
      await tester.tap(_key('tactical-save'));
      await _settle(tester);
      expect(
        _text(tester, 'tactical-lobby-caption'),
        tacticalLobbyErrorText(
          TacticalLobbyAction.link,
          const TacticalRecordsError('link_conflict', ''),
        ),
      );
      final state = await service.loadTacticalEvidenceState(fe9cProfileId);
      expect(
        state.matches.where(
          (match) => match.opponentDisplayName == '트리니티 정의실현부',
        ),
        hasLength(1),
      );
      expect(_text(tester, 'tactical-editor-header'), startsWith('공격 기록 · '));
      expect(tester.takeException(), isNull);
    });

    testWidgets('commit errors and review candidates stay in S2', (
      tester,
    ) async {
      final service = Fe9cLobbyService();
      addTearDown(service.dispose);
      await _openShell(tester, service);
      service.failCommit = 'identity_ambiguous';
      await _scanFromLobby(tester, service);
      expect(
        _text(tester, 'tactical-lobby-caption'),
        tacticalLobbyErrorText(
          TacticalLobbyAction.commit,
          const TacticalRecordsError('identity_ambiguous', ''),
        ),
      );
      expect(_text(tester, 'tactical-lobby-message'), tacticalLobbyEmptyText);
      // 처리한 후보라 다시 스캔할 수 있다(검토 대기가 아니다).
      await _scanFromLobby(
        tester,
        service,
        payload: fe9cLobbyPayload(reviewStatus: 'review_required'),
      );
      expect(
        service.calls.where((call) => call.startsWith('commit:')),
        hasLength(1),
      );
      expect(_text(tester, 'tactical-lobby-caption'), tacticalLobbyReviewText);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lobby scan from the scan tab saves only on handoff', (
      tester,
    ) async {
      final service = Fe9cLobbyService();
      addTearDown(service.dispose);
      await _openShell(tester, service);
      await tester.tap(_key('top-tab-scan'));
      await tester.pumpAndSettle();
      final scan = _scanTab(tester).controller;
      scan.selectKind(ScannerKind.tacticalLobby);
      await scan.start();
      await _settle(tester);
      service.emitLobbyCandidate();
      service.emitTerminal();
      await _settle(tester);
      expect(scan.stage, ScanSessionStage.terminal);
      expect(
        service.calls.where((call) => call.startsWith('commit:')),
        isEmpty,
      );
      final review = _key('scan-review-lobby-candidate-1');
      expect(review, findsOneWidget);
      await tester.tap(review);
      await _settle(tester);
      expect(service.calls, contains('commit:7:10'));
      expect(_key(_card(1)), findsOneWidget);
      expect(
        ScanHeaderStatus.of(
          scan,
          appliedElsewhere: _page(tester).scanAppliedElsewhere,
        ).activity,
        ScanHeaderActivity.idle,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scan tab hands the shell an open-students callback', (
      tester,
    ) async {
      final service = Fe9cLobbyService();
      addTearDown(service.dispose);
      await _openShell(tester, service, connect: false);
      final open = _scanTab(tester).onOpenStudents;
      expect(open, isNotNull);
      open!();
      await tester.pumpAndSettle();
      expect(_key('student-page'), findsOneWidget);
    });
  });
}
