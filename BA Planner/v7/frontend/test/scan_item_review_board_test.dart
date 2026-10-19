// FE8-g5a: 아이템 결과 검토 보드(시안 Scan-Item-Review, FD-146 · FD-153) 단독 시험.
// 칸 상태 규칙 · subset payload(순수), 종류 전환, 칸 승인 · 건너뛰기 · 직접 고치기, 부분 적용 성공 / 중간 실패(그 종류에서 멈춤 ·
// 반환 revision 잇기 · 원 칸 보존), 읽지 못한 칸 제외, 미식별 칸 마운트(기존 `ScanInventoryIdentityReview`), 1280×720 넘침 0,
// 보드가 사라진 뒤 응답. 바깥 일은 가짜 actions(`test/fixtures/scan_item_review_board_fixture.dart`)가 받는다.
import 'dart:async';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/scan/item_review/scan_item_review_board.dart';
import 'package:ba_planner_v7/ui/scan/scan_header_progress.dart';
import 'package:ba_planner_v7/ui/widgets/scan_inventory_identity_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/scan_item_review_board_fixture.dart';

Future<(FakeScanItemReviewActions, GlobalKey<ScanItemReviewBoardHarnessState>)>
_pumpBoard(
  WidgetTester tester, {
  Size size = const Size(2560, 1392),
  int? revision = scanItemFixtureRevision,
  Map<String, List<ScannerUnresolvedSlot>> unresolved = const {},
  FakeScanItemReviewActions? actions,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = actions ?? FakeScanItemReviewActions();
  final key = GlobalKey<ScanItemReviewBoardHarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: ScanItemReviewBoardHarness(
          key: key,
          actions: fake,
          repositoryRevision: revision,
          unresolved: unresolved,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, key);
}

Finder _key(String value) => find.byKey(ValueKey(value));

String _text(WidgetTester tester, String key) =>
    switch (tester.widget(_key(key))) {
      Text(:final data) => data ?? '',
      BaChip(:final label) => label,
      TonalButton(:final label) => label,
      final widget => throw StateError('no text: $key ($widget)'),
    };

bool _enabled(WidgetTester tester, String key) {
  final widget = tester.widget(_key(key));
  return switch (widget) {
    TonalButton(:final onPressed) => onPressed != null,
    RailButton(:final onPressed) => onPressed != null,
    KitPressable(:final onPressed) => onPressed != null,
    _ => throw StateError('not a button: $key'),
  };
}

String _count(WidgetTester tester, ScanItemFilter filter) =>
    _text(tester, 'scan-item-count-${filter.name}');

String _cell(ScannerCandidate candidate, String key) =>
    'scan-item-cell-${scanItemFixtureCellId(candidate, key)}';

/// 타일 값 줄의 글자를 이어 붙인다(`96→112+16`).
String _cellValue(WidgetTester tester, ScannerCandidate candidate, String key) {
  final value = find.byKey(
    ValueKey('scan-item-cell-value-${scanItemFixtureCellId(candidate, key)}'),
  );
  return [
    for (final element
        in find.descendant(of: value, matching: find.byType(Text)).evaluate())
      (element.widget as Text).data ?? '',
  ].join();
}

void main() {
  final tech = scanItemFixtureTechCandidate();
  final bd = scanItemFixtureBdCandidate();
  final techMillennium = scanItemFixtureTechKey('Millennium', 4);
  final techTrinity = scanItemFixtureTechKey('Trinity', 4);
  final bdRedWinter = scanItemFixtureBdKey('RedWinter', 4);
  final bdAbydos = scanItemFixtureBdKey('Abydos', 4);

  group('칸 규칙(순수)', () {
    final catalog = {
      for (final entry in scanItemFixtureCatalog()) entry.resourceKey: entry,
    };
    final stored = scanItemStoredQuantities(scanItemFixtureInventory());

    List<ScanItemCell> cells() => [
      for (final kind in scanItemFixtureKinds())
        for (final candidate in kind.candidates)
          ...scanItemCellsFor(
            kind: kind,
            candidate: candidate,
            base: candidate,
            stored: stored,
            catalogByKey: catalog,
          ),
    ];

    test('2종 52칸: 확인 필요 2 · 바뀐 수량 5 · 그대로 45, 상태는 근거 · 수량 · 이전값 순서', () {
      final list = cells();
      expect(scanItemCounts(list), {
        ScanItemFilter.all: 52,
        ScanItemFilter.needsReview: 2,
        ScanItemFilter.changed: 5,
        ScanItemFilter.unchanged: 45,
      });
      final byKey = {for (final cell in list) cell.resourceKey: cell};
      final millennium = byKey[techMillennium]!;
      expect(millennium.state, ScanItemCellState.needsReview);
      expect(millennium.previous, 96);
      expect(millennium.scanned, 112);
      expect(millennium.name, '밀레니엄');
      expect(millennium.evidenceFor('quantity')!.confidence, 0.58);
      expect(byKey[bdRedWinter]!.state, ScanItemCellState.unread);
      expect(byKey[bdRedWinter]!.scanned, isNull);
      expect(byKey[techTrinity]!.state, ScanItemCellState.changed);
      expect(
        byKey[scanItemFixtureTechKey('Gehenna', 4)]!.state,
        ScanItemCellState.unchanged,
      );
      // 이전값이 없으면 바뀐 것으로 보고 '—'로 둔다(0으로 채우지 않는다).
      expect(
        scanItemCellStateFor(
          unidentified: false,
          scanned: 3,
          previous: null,
          evidence: const [],
        ),
        ScanItemCellState.changed,
      );
      expect(
        scanItemCellStateFor(
          unidentified: true,
          scanned: null,
          previous: null,
          evidence: const [],
        ),
        ScanItemCellState.unidentified,
      );
    });

    test('티어 묶음과 접은 요약은 시안 글자 그대로', () {
      final kinds = scanItemFixtureKinds();
      final list = cells();
      final techCells = [
        for (final cell in list)
          if (cell.kind.profile == InventoryScanProfile.techNotes) cell,
      ];
      final groups = scanItemTierGroups(techCells);
      expect([for (final group in groups) group.tier], [4, 3, 2, 1]);
      expect(
        scanItemGroupTitle(kinds.first, 4, groups.first.cells.length),
        '기술 노트 · 최상급 7칸',
      );
      expect(
        [for (final cell in groups.first.cells) cell.name],
        ['밀레니엄', '게헨나', '트리니티', '아비도스', '백귀야행', '붉은겨울', '발키리'],
      );
      expect(
        scanItemCollapsedNote(kinds.first, groups.skip(1).toList()),
        '초급 · 일반 · 상급 21칸은 바뀐 칸 없음 · 펼치기',
      );
      final bdGroups = scanItemTierGroups([
        for (final cell in list)
          if (cell.kind.profile == InventoryScanProfile.tacticalBd) cell,
      ]);
      expect(
        scanItemCollapsedNote(kinds.last, bdGroups.skip(1).toList()),
        '초급 · 일반 · 상급 18칸 · 1칸 바뀜 · 펼치기',
      );
    });

    test('subset payload: 승인 칸 줄만 · 고친 수량은 문자열 · 다른 키 그대로 · 0칸이면 null', () {
      final list = [
        for (final cell in cells())
          if (cell.candidate.id == tech.id) cell,
      ];
      final approved = [
        for (final cell in list)
          if (cell.approvedByDefault) cell,
      ];
      final trinity = approved.firstWhere(
        (cell) => cell.resourceKey == techTrinity,
      );
      final payload = scanItemSubsetPayload(
        payload: tech.payload,
        approved: approved,
        quantities: {trinity.id: 100},
      )!;
      final entries = (payload['entries'] as List).cast<Map>();
      expect(entries, hasLength(27));
      expect(entries.any((entry) => entry['key'] == techMillennium), isFalse);
      expect(
        entries.firstWhere((entry) => entry['key'] == techTrinity)['quantity'],
        '100',
      );
      expect(payload['catalog_revision'], tech.payload['catalog_revision']);
      expect(payload['version'], 1);
      expect(
        scanItemSubsetPayload(
          payload: tech.payload,
          approved: const [],
          quantities: const {},
        ),
        isNull,
      );
      expect(
        scanItemApplySubtitle(review: 2, skipped: 0),
        '확인 필요 2칸은 빼고 적용합니다',
      );
      expect(
        scanItemApplySubtitle(review: 1, skipped: 1),
        '확인 필요 1칸 · 건너뛴 1칸은 빼고 적용합니다',
      );
    });
  });

  group('보드', () {
    testWidgets('첫 화면: 2종 탭 · 분류 수 · 접은 티어 · 확인 필요 칸 선택 · 주 버튼', (
      tester,
    ) async {
      await _pumpBoard(tester);
      expect(_count(tester, ScanItemFilter.all), '52');
      expect(_count(tester, ScanItemFilter.needsReview), '2');
      expect(_count(tester, ScanItemFilter.changed), '5');
      expect(_count(tester, ScanItemFilter.unchanged), '45');
      expect(_text(tester, 'scan-item-scope'), '기술 노트 · 전술 교육 BD · 방금');
      expect(_text(tester, 'scan-item-kind-all'), '모든 종류 · 2종');
      expect(_text(tester, 'scan-item-kind-tech_notes'), '기술 노트 · 확인 1');
      expect(_text(tester, 'scan-item-kind-tactical_bd'), '전술 교육 BD · 확인 1');
      expect(find.text('기술 노트 · 최상급 7칸'), findsOneWidget);
      expect(find.text('초급 · 일반 · 상급 21칸은 바뀐 칸 없음 · 펼치기'), findsOneWidget);
      expect(find.text('전술 교육 BD · 최상급 6칸'), findsOneWidget);
      expect(find.text('초급 · 일반 · 상급 18칸 · 1칸 바뀜 · 펼치기'), findsOneWidget);
      expect(_cellValue(tester, tech, techMillennium), '96→112+16');
      expect(
        _cellValue(tester, tech, scanItemFixtureTechKey('Gehenna', 4)),
        '140',
      );
      expect(_cellValue(tester, bd, bdRedWinter), '읽지 못함');
      expect(_text(tester, 'scan-item-inspector-title'), '기술 노트 · 밀레니엄 (최상급)');
      expect(_text(tester, 'scan-item-inspector-chip'), '확인 필요');
      expect(_text(tester, 'scan-item-inspector-previous'), '96');
      expect(find.text('3일 전 스캔'), findsOneWidget);
      expect(_text(tester, 'scan-item-inspector-reading'), '112');
      expect(
        _text(tester, 'scan-item-inspector-reading-note'),
        '신뢰도 0.58 · 1과 7 구분 낮음',
      );
      expect(_text(tester, 'scan-item-inspector-required'), '254');
      expect(_text(tester, 'scan-item-inspector-shortage'), '158 → 142');
      expect(
        _text(tester, 'scan-item-inspector-location'),
        '인벤토리 · 기술 노트 탭 · 1번째 칸',
      );
      expect(_text(tester, 'scan-item-approve-title'), '112로 승인');
      expect(_text(tester, 'scan-item-apply-title'), '승인한 50칸 인벤토리에 적용');
      expect(_text(tester, 'scan-item-apply-subtitle'), '확인 필요 2칸은 빼고 적용합니다');
      expect(_enabled(tester, 'scan-item-apply'), isTrue);
      // 접은 티어 펼치기 → 소제목이 생기고 `접기`.
      await tester.tap(_key('scan-item-expand-tech_notes'));
      await tester.pumpAndSettle();
      expect(find.text('접기'), findsOneWidget);
      expect(find.text('기술 노트 · 상급 7칸'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('종류 전환: 그 종류의 칸 · 숫자 · 적용 범위만', (tester) async {
      await _pumpBoard(tester);
      await tester.tap(_key('scan-item-kind-tactical_bd'));
      await tester.pumpAndSettle();
      expect(_count(tester, ScanItemFilter.all), '24');
      expect(_count(tester, ScanItemFilter.needsReview), '1');
      expect(_count(tester, ScanItemFilter.changed), '3');
      expect(_count(tester, ScanItemFilter.unchanged), '20');
      expect(find.text('기술 노트 · 최상급 7칸'), findsNothing);
      expect(
        _text(tester, 'scan-item-inspector-title'),
        '전술 교육 BD · 붉은겨울 (최상급)',
      );
      expect(_text(tester, 'scan-item-inspector-chip'), '읽지 못함');
      expect(_text(tester, 'scan-item-approve-title'), '수량을 입력하면 승인할 수 있습니다');
      expect(_enabled(tester, 'scan-item-approve'), isFalse);
      expect(_text(tester, 'scan-item-apply-title'), '승인한 23칸 인벤토리에 적용');
      expect(_text(tester, 'scan-item-apply-subtitle'), '확인 필요 1칸은 빼고 적용합니다');
      // 분류 버튼은 종류 안에서 거른다.
      await tester.tap(_key('scan-item-filter-changed'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(_cell(bd, bdAbydos))), findsOneWidget);
      expect(find.byKey(ValueKey(_cell(bd, bdRedWinter))), findsNothing);
      expect(find.text('전술 교육 BD · 상급 1칸'), findsOneWidget);
      await tester.tap(_key('scan-item-kind-all'));
      await tester.pumpAndSettle();
      expect(_count(tester, ScanItemFilter.all), '52');
      expect(tester.takeException(), isNull);
    });

    testWidgets('칸 승인 · 건너뛰기 · 직접 고치기', (tester) async {
      await _pumpBoard(tester);
      // 확인 필요 칸을 그대로 승인 → 다음 확인 필요(BD 붉은겨울)로.
      await tester.tap(_key('scan-item-approve'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-item-apply-title'), '승인한 51칸 인벤토리에 적용');
      expect(_text(tester, 'scan-item-apply-subtitle'), '확인 필요 1칸은 빼고 적용합니다');
      expect(
        _text(tester, 'scan-item-inspector-title'),
        '전술 교육 BD · 붉은겨울 (최상급)',
      );
      // 읽지 못한 칸에 수량을 입력하면 승인 칸이 된다.
      await tester.enterText(_key('scan-item-quantity-input'), '30');
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-item-apply-title'), '승인한 52칸 인벤토리에 적용');
      expect(_text(tester, 'scan-item-apply-subtitle'), '빼는 칸 없이 적용합니다');
      expect(_cellValue(tester, bd, bdRedWinter), '25→30+5');
      // 바뀐 칸 건너뛰기 → 승인에서 빠지고 타일에 `건너뜀`.
      await tester.tap(find.byKey(ValueKey(_cell(tech, techTrinity))));
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-item-inspector-title'), '기술 노트 · 트리니티 (최상급)');
      expect(_text(tester, 'scan-item-approve-title'), '승인한 칸입니다 · 102');
      await tester.tap(_key('scan-item-skip'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-item-apply-title'), '승인한 51칸 인벤토리에 적용');
      expect(_text(tester, 'scan-item-apply-subtitle'), '건너뛴 1칸은 빼고 적용합니다');
      expect(_cellValue(tester, tech, techTrinity), '102 · 건너뜀');
      // +/− 는 고친 값을 만든다.
      await tester.tap(find.byKey(ValueKey(_cell(tech, techTrinity))));
      await tester.pumpAndSettle();
      await tester.tap(_key('scan-item-quantity-plus'));
      await tester.pumpAndSettle();
      expect(_cellValue(tester, tech, techTrinity), '88→103+15');
      expect(_text(tester, 'scan-item-apply-title'), '승인한 52칸 인벤토리에 적용');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '부분 적용 성공: 종류 순차 review(승인 칸) → commit, revision 잇기, 읽지 못한 · 확인 필요 칸 제외',
      (tester) async {
        final (actions, _) = await _pumpBoard(tester);
        await tester.tap(_key('scan-item-apply'));
        await tester.pumpAndSettle();
        expect(actions.calls, [
          'review:cand-tech:1',
          'commit:cand-tech:2:70',
          'review:cand-bd:1',
          'commit:cand-bd:2:71',
        ]);
        final techEntries =
            (actions.subsetPayloads[scanCandidateKey(tech)]!['entries'] as List)
                .cast<Map>();
        final bdEntries =
            (actions.subsetPayloads[scanCandidateKey(bd)]!['entries'] as List)
                .cast<Map>();
        expect(techEntries, hasLength(27));
        expect(bdEntries, hasLength(23));
        expect(
          techEntries.any((entry) => entry['key'] == techMillennium),
          isFalse,
        );
        expect(bdEntries.any((entry) => entry['key'] == bdRedWinter), isFalse);
        expect(
          bdEntries.every((entry) => entry['quantity'] is String),
          isTrue,
          reason: '읽지 못한 칸(null)은 subset에 없다',
        );
        expect(
          actions.subsetPayloads[scanCandidateKey(bd)]!['catalog_revision'],
          bd.payload['catalog_revision'],
        );
        expect(_text(tester, 'scan-item-apply-note'), '2종류 · 50칸을 적용했습니다');
        expect(_text(tester, 'scan-item-kind-tech_notes'), '기술 노트 · 확정');
        expect(_text(tester, 'scan-item-kind-tactical_bd'), '전술 교육 BD · 확정');
        expect(_count(tester, ScanItemFilter.all), '0');
        expect(_enabled(tester, 'scan-item-apply'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('중간 실패: 그 종류에서 멈추고 원 칸을 그대로 두며, 다시 적용은 이어진 revision으로', (
      tester,
    ) async {
      final actions = FakeScanItemReviewActions()..failCommitIds.add('cand-bd');
      await _pumpBoard(tester, actions: actions);
      await tester.tap(_key('scan-item-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'review:cand-tech:1',
        'commit:cand-tech:2:70',
        'review:cand-bd:1',
        'commit:cand-bd:2:71',
      ]);
      expect(
        _text(tester, 'scan-item-apply-note'),
        '전술 교육 BD에서 멈췄습니다: Bad state: repository revision conflict · 적용 1종류 · '
        '남은 1종류는 그대로 둡니다',
      );
      expect(_text(tester, 'scan-item-kind-tech_notes'), '기술 노트 · 확정');
      expect(_text(tester, 'scan-item-kind-tactical_bd'), '전술 교육 BD · 적용 실패');
      // 부분 승인 review가 줄인 payload(23칸)가 아니라 원 24칸 · 읽지 못한 칸이 그대로 보인다.
      expect(_count(tester, ScanItemFilter.all), '24');
      expect(_count(tester, ScanItemFilter.needsReview), '1');
      expect(find.byKey(ValueKey(_cell(bd, bdRedWinter))), findsOneWidget);
      expect(_text(tester, 'scan-item-apply-title'), '승인한 23칸 인벤토리에 적용');
      actions.failCommitIds.clear();
      actions.calls.clear();
      await tester.tap(_key('scan-item-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['review:cand-bd:2', 'commit:cand-bd:3:71']);
      expect(
        (actions.subsetPayloads[scanCandidateKey(bd)]!['entries'] as List),
        hasLength(23),
      );
      expect(_text(tester, 'scan-item-apply-note'), '1종류 · 23칸을 적용했습니다');
      expect(tester.takeException(), isNull);
    });

    testWidgets('repository revision을 모르면 적용하지 않는다', (tester) async {
      final (actions, _) = await _pumpBoard(tester, revision: null);
      expect(_enabled(tester, 'scan-item-apply'), isFalse);
      expect(actions.calls, isEmpty);
    });

    testWidgets('미식별 칸: 확인 필요에 들고, 고르면 기존 identity 검토를 그 자리에 마운트', (
      tester,
    ) async {
      final slot = scanItemFixtureUnresolvedSlot();
      final (actions, _) = await _pumpBoard(
        tester,
        unresolved: {
          scanCandidateKey(bd): [slot],
        },
      );
      expect(_count(tester, ScanItemFilter.needsReview), '3');
      await tester.tap(_key('scan-item-kind-tactical_bd'));
      await tester.pumpAndSettle();
      await tester.tap(_key('scan-item-filter-needsReview'));
      await tester.pumpAndSettle();
      final cellKey = 'scan-item-cell-${scanCandidateKey(bd)}#s:${slot.slot}';
      expect(find.byKey(ValueKey(cellKey)), findsOneWidget);
      expect(find.text('전술 교육 BD · 1칸'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(cellKey)));
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-item-inspector-chip'), '미식별');
      expect(find.byType(ScanInventoryIdentityReview), findsOneWidget);
      expect(_key('scan-item-inspector-grid-note'), findsNothing);
      expect(_text(tester, 'scan-item-approve-title'), '아이템을 먼저 지정합니다');
      expect(_enabled(tester, 'scan-item-approve'), isFalse);
      // 미식별 칸은 적용 대상이 아니다.
      expect(_text(tester, 'scan-item-apply-subtitle'), '확인 필요 2칸은 빼고 적용합니다');
      await tester.tap(find.byType(ChoiceChip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이번 세션만'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'assign:cand-bd:30:${scanItemFixtureBdKey('Valkyrie', 4)}:false',
      ]);
      // 지정 뒤 새 revision: 슬롯은 사라지고 수량 null 칸(읽지 못함)이 생긴다.
      expect(find.byType(ScanInventoryIdentityReview), findsNothing);
      expect(_count(tester, ScanItemFilter.all), '25');
      expect(_count(tester, ScanItemFilter.needsReview), '2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('미식별 칸 건너뛰기는 기존 콜백 그대로', (tester) async {
      final slot = scanItemFixtureUnresolvedSlot();
      final (actions, _) = await _pumpBoard(
        tester,
        unresolved: {
          scanCandidateKey(bd): [slot],
        },
      );
      await tester.tap(_key('scan-item-kind-tactical_bd'));
      await tester.pumpAndSettle();
      await tester.tap(_key('scan-item-filter-needsReview'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey('scan-item-cell-${scanCandidateKey(bd)}#s:${slot.slot}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['skip:cand-bd:30']);
      expect(_key('scan-item-identity-skipped'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} 넘침 0(목록 · 검사기 · 미식별 칸)',
        (tester) async {
          final slot = scanItemFixtureUnresolvedSlot();
          await _pumpBoard(
            tester,
            size: size,
            unresolved: {
              scanCandidateKey(bd): [slot],
            },
          );
          expect(tester.takeException(), isNull);
          expect(_text(tester, 'scan-item-apply-title'), '승인한 50칸 인벤토리에 적용');
          await tester.tap(_key('scan-item-expand-tech_notes'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(_key('scan-item-kind-tactical_bd'));
          await tester.pumpAndSettle();
          await tester.tap(_key('scan-item-filter-needsReview'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(
              ValueKey('scan-item-cell-${scanCandidateKey(bd)}#s:${slot.slot}'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ScanInventoryIdentityReview), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('보드가 사라지면 다음 종류를 시작하지 않고 setState도 하지 않는다', (tester) async {
      final actions = FakeScanItemReviewActions()
        ..commitGate = Completer<void>();
      await _pumpBoard(tester, actions: actions);
      await tester.tap(_key('scan-item-apply'));
      await tester.pump();
      expect(_text(tester, 'scan-item-apply-subtitle'), '적용 중 · 0 / 2종류');
      expect(_enabled(tester, 'scan-item-apply'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      actions.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(actions.calls, ['review:cand-tech:1', 'commit:cand-tech:2:70']);
      expect(tester.takeException(), isNull);
    });
  });
}
