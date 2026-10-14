// FE8-c: 계정 편집 패널(시안 Title-Accounts 편집 패널)과 같은 패널의 초상 고르기 확장(시안 Title-Accounts-Portrait).
//
// 기준 viewport 2560×1392에서 Studio 문서 값이 시안 px 값과 같은지(패널 ±1px, 안쪽 요소 ±2px), 펼침·접힘 전이,
// 닫기 = 버림 · 저장 = 편집 중인 값에 반영 · 편집기 저장 = 저장소 호출, 메타 줄의 "마지막 스캔"(FD-041)을 본다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_scrollbar.dart';
import 'package:ba_planner_v7/ui/kit/info_popover.dart';
import 'package:ba_planner_v7/ui/studio/account_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _referenceSize = Size(2560, 1392);
const _mainId = '0000000000000000000000f1';

/// 검수 fixture의 지금(지역 시각 2026-10-13 12:00)과 마지막 스캔(지역 시각 어제 21:40).
final _fixtureNow = DateTime(2026, 10, 13, 12);
final _fixtureLastScan = DateTime(2026, 10, 12, 21, 40);

/// 마지막 스캔이 있는 계정 하나(초상 [avatar]). 요약은 기록 없음 요약에 scan 적용 1건을 더한 값이다.
class _LastScanService extends MockAppService implements AppClockSource {
  _LastScanService({
    String avatar = 'airi',
    this.lastScan,
    this.failSummary = false,
  }) : super(
         profiles: [
           RepositoryProfile(
             id: _mainId,
             displayName: '거모이는존재한다 (v7 UI 테스트)',
             avatarStudentId: avatar,
             revision: 0,
             selected: true,
           ),
         ],
       );

  final DateTime? lastScan;
  final bool failSummary;
  int summaryCalls = 0;
  final updates = <({String name, String avatar, int revision})>[];

  @override
  DateTime get clockNow => _fixtureNow;

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async {
    summaryCalls += 1;
    if (failSummary) throw StateError('repository_busy');
    final result = await super.loadRepositoryHistorySummary(profileIds);
    final at = lastScan;
    if (at == null) return result;
    return RepositoryHistorySummaryResult.fromWire({
      'profiles': [
        for (final summary in result.profiles)
          {
            ...summary.toWire(),
            'history_sequence': 1,
            'last_scan_at': historyUtcTimestamp(at),
            'total_event_count': 1,
            'retained_event_count': 1,
            'total_counts': {...summary.totalCounts, 'scan': 1},
            'retained_counts': {...summary.retainedCounts, 'scan': 1},
            'total_scan_session_count': 1,
            'retained_scan_session_count': 1,
          },
      ],
    });
  }

  @override
  Future<int> updateProfile(
    String profileId,
    String displayName,
    String avatarStudentId,
    int expectedRevision,
    String idempotencyKey,
  ) {
    updates.add((
      name: displayName,
      avatar: avatarStudentId,
      revision: expectedRevision,
    ));
    return super.updateProfile(
      profileId,
      displayName,
      avatarStudentId,
      expectedRevision,
      idempotencyKey,
    );
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _openEditor(
  WidgetTester tester,
  MockAppService service, {
  Size size = _referenceSize,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('title-settings')));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('account-edit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('account-edit')));
  await tester.pumpAndSettle();
}

InkWell _ink(WidgetTester tester, String key) => tester.widget<InkWell>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(InkWell),
  ),
);

AccountPathOutlinePainter _outline(WidgetTester tester, String key) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as AccountPathOutlinePainter;

Rect _panelBounds(WidgetTester tester) => tester
    .widget<LiftedPathShadow>(
      find.byKey(const ValueKey('account-editor-section-shadow')),
    )
    .path
    .getBounds();

void _expectRect(Rect actual, Rect expected, double tolerance, String reason) {
  expect(
    actual.left,
    closeTo(expected.left, tolerance),
    reason: '$reason left',
  );
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$reason top');
  expect(
    actual.width,
    closeTo(expected.width, tolerance),
    reason: '$reason width',
  );
  expect(
    actual.height,
    closeTo(expected.height, tolerance),
    reason: '$reason height',
  );
}

/// Studio 요소 rect(평행사변형은 사선 포함 bounds).
Rect _box(String id, {bool slanted = true}) {
  final rect = accountEditorRect(_referenceSize, id, id, 0);
  return slanted ? accountEditorBounds(rect) : rect;
}

void main() {
  test('Studio document places the panel and its pairs at the artboard px', () {
    // 시안 path bounds(2560×1392). 패널 ±1px, 안쪽 요소 ±2px.
    _expectRect(
      _box('container-20'),
      const Rect.fromLTWH(1010, 470, 1000, 262),
      1,
      'collapsed panel',
    );
    _expectRect(
      _box('container-21'),
      const Rect.fromLTWH(1010, 270, 1000, 850),
      1,
      'expanded panel',
    );
    const collapsed = {
      'container-4': Rect.fromLTWH(1068.81, 501.76, 176, 142.48),
      'container-3': Rect.fromLTWH(1058.3, 660, 158.6, 44),
      'feature-8': Rect.fromLTWH(1310.8, 530, 569.9, 56),
      'container-6': Rect.fromLTWH(1691.3, 662, 118, 50),
      'container-7': Rect.fromLTWH(1819.3, 662, 118, 50),
    };
    const expanded = {
      'container-22': Rect.fromLTWH(1172.49, 301.76, 176, 142.48),
      'container-23': Rect.fromLTWH(1162, 460, 158.6, 44),
      'feature-11': Rect.fromLTWH(1414.5, 330, 535.1, 56),
      'container-8': Rect.fromLTWH(1057.6, 570, 859.5, 450),
      'container-9': Rect.fromLTWH(1587.6, 1050, 118, 50),
      'container-10': Rect.fromLTWH(1715.6, 1050, 118, 50),
    };
    for (final entry in {...collapsed, ...expanded}.entries) {
      _expectRect(_box(entry.key), entry.value, 2, entry.key);
    }
    // 글자 칸은 시안 글자 왼쪽 위(계정명 .ihdr, 메타 줄 .mut, 초상 고르기 머리).
    const textOrigins = {
      'feature-4': Offset(1331, 506),
      'feature-9': Offset(1311, 598),
      'feature-10': Offset(1434, 306),
      'feature-12': Offset(1414, 398),
      'feature-13': Offset(1152, 530),
    };
    for (final entry in textOrigins.entries) {
      final rect = _box(entry.key, slanted: false);
      expect(rect.left, closeTo(entry.value.dx, 2), reason: entry.key);
      expect(rect.top, closeTo(entry.value.dy, 2), reason: entry.key);
    }
    // 섹션 1·4는 grid에 맞춘 감싸는 rect다(패널은 컨테이너 20·21).
    Rect section(String id) => sectionCanvasElementRect(
      _referenceSize,
      accountStudioDocument.elements.singleWhere((item) => item.id == id),
    );
    expect(section('element-1').contains(const Offset(1010, 470)), isTrue);
    expect(section('element-4').contains(const Offset(1010, 270)), isTrue);
    expect(section('element-4').bottom, greaterThanOrEqualTo(1120));
    // "초상 변경"과 stucard 중심을 잇는 선은 80°다(시안에서도 같다).
    final change = accountEditorChangeRect(
      accountEditorRect(_referenceSize, 'container-3', 'container-3', 0),
      _box('container-4'),
    );
    _expectRect(
      accountEditorBounds(change),
      collapsed['container-3']!,
      2,
      'aligned change',
    );
  });

  test('portrait grid metrics and scrollbar rail follow the artboard', () {
    final metrics = accountPortraitGridMetrics(const Size(859.5, 450), 267);
    expect(metrics.scale, closeTo(1, 1e-9));
    expect(metrics.cell.width, closeTo(112, 0.01));
    expect(metrics.cell.height, closeTo(90.67, 0.01));
    expect(metrics.columnGap, closeTo(14, 0.01));
    expect(metrics.rowGap, closeTo(17.33, 0.01));
    expect(metrics.rows, 45);
    expect(
      metrics.padding.left + portraitGridTrajectoryOffset(63, 450),
      closeTo(77.98, 0.05),
    );
    expect(metrics.padding.top, closeTo(17.67, 0.01));
    // 4행이 보인다(17.67 + 4 × 90.67 + 3 × 17.33 = 432.3 ≤ 450).
    expect(
      metrics.padding.top + 4 * metrics.cell.height + 3 * metrics.rowGap,
      lessThanOrEqualTo(450),
    );
    // 시안 레일: (899.4, 310) → (823.5, 740)(패널 원점 1010,270 기준, viewport 원점 1057.6,570).
    final top = accountPortraitScrollbarTrackPoint(const Size(859.5, 450), 10);
    final bottom = accountPortraitScrollbarTrackPoint(
      const Size(859.5, 450),
      440,
    );
    expect(top.dx + 1057.6 - 1010, closeTo(899.4, 0.3));
    expect(bottom.dx + 1057.6 - 1010, closeTo(823.5, 0.3));
  });

  test('last scan text uses local calendar days and dashes when unknown', () {
    String text(DateTime? at) => accountLastScanText(
      at == null ? null : historyUtcTimestamp(at),
      _fixtureNow,
    );
    expect(text(_fixtureLastScan), '어제 21:40');
    expect(text(DateTime(2026, 10, 13, 8, 5)), '오늘 08:05');
    expect(text(DateTime(2026, 10, 10, 23, 59)), '3일 전');
    expect(text(DateTime(2026, 10, 14, 9, 0)), '10/14 09:00');
    expect(text(null), '—');
    expect(accountLastScanText('not a time', _fixtureNow), '—');
    expect(
      accountEditorMetaText(owned: 217, total: 265, lastScan: '어제 21:40'),
      '보유 217 / 265 · 마지막 스캔 어제 21:40',
    );
    expect(
      accountEditorMetaText(owned: null, total: 0, lastScan: '—'),
      '보유 — / — · 마지막 스캔 —',
    );
  });

  testWidgets('collapsed editor panel matches Title-Accounts', (tester) async {
    final service = _LastScanService(lastScan: _fixtureLastScan);
    addTearDown(service.dispose);
    await _openEditor(tester, service);

    // 부유 패널 1000×262(채움 .95, lifted shadow). 둥근 모서리라 path bounds는 3px 안이다.
    _expectRect(
      _panelBounds(tester),
      const Rect.fromLTWH(1010, 470, 1000, 262),
      3,
      'panel',
    );
    final surface = find.byKey(const ValueKey('account-editor-base-surface'));
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(of: surface, matching: find.byType(ColoredBox)),
          )
          .color,
      accountEditorPanelFill,
    );
    expect(accountEditorPanelFill, const Color.fromRGBO(29, 42, 58, 0.95));
    _expectRect(
      tester.getRect(find.byKey(const ValueKey('account-editor-portrait'))),
      const Rect.fromLTWH(1068.81, 501.76, 176, 142.48),
      2,
      'stucard',
    );
    _expectRect(
      tester.getRect(find.byKey(const ValueKey('account-name-input-path'))),
      const Rect.fromLTWH(1310.8, 530, 569.9, 56),
      2,
      'input',
    );

    // 문구: 계정명 · 초상 변경 · 뒤로 · 저장, 해요체 입력 안내 없음(~습니다체).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-editor-label')),
        matching: find.text('계정명'),
      ),
      findsOneWidget,
    );
    for (final entry in const {
      'account-change-portrait': '초상 변경',
      'account-editor-back': '뒤로',
      'account-editor-save': '저장',
    }.entries) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(entry.key)),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
        reason: entry.key,
      );
    }
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('account-name-input')),
    );
    expect(input.decoration!.hintText, '계정명을 입력하십시오');
    expect(input.controller!.text, '거모이는존재한다 (v7 UI 테스트)');

    // 메타 줄: 보유 n / 전체 · 마지막 스캔 어제 21:40(이력 요약 한 번).
    final owned = (await service.loadRepositoryState(_mainId)).students.length;
    final total = (await service.listStudents()).length;
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('account-editor-meta')))
          .data,
      '보유 $owned / $total · 마지막 스캔 어제 21:40',
    );
    expect(service.summaryCalls, 1);
    final meta = tester.getRect(
      find.byKey(const ValueKey('account-editor-meta-box')),
    );
    expect(meta.left, closeTo(1311, 2));
    expect(meta.top, closeTo(598, 2));

    // 입력 외곽선: 평소 rgba(56,81,107,.9) 1.6, 포커스 #f2b3ef 2.4. 채움 .55.
    var outline = _outline(tester, 'account-name-input-outline');
    expect(outline.color, accountEditorInputIdleOutline);
    expect(outline.strokeWidth, accountEditorInputIdleOutlineWidth);
    await tester.tap(find.byKey(const ValueKey('account-name-input')));
    await tester.pump();
    outline = _outline(tester, 'account-name-input-outline');
    expect(outline.color, accountPressedOutline);
    expect(outline.strokeWidth, accountEditorInputFocusOutlineWidth);
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(const ValueKey('account-name-input-surface')),
              matching: find.byType(ColoredBox),
            ),
          )
          .color,
      accountEditorInputFill,
    );

    // 버튼 외곽선: 초상 변경·뒤로 .72 1.8, 저장 분홍 .9 1.8.
    expect(
      _outline(tester, 'account-change-portrait-outline').color,
      accountRailOutline,
    );
    expect(
      _outline(tester, 'account-editor-back-outline').color,
      accountRailOutline,
    );
    final save = _outline(tester, 'account-editor-save-outline');
    expect(save.color, accountEditorSaveOutline);
    expect(save.strokeWidth, 1.8);
    expect(find.byKey(const ValueKey('account-portrait-grid')), findsNothing);
    expect(find.byKey(const ValueKey('account-picker-close')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait change expands the same panel into the 6-column grid', (
    tester,
  ) async {
    final service = _LastScanService(lastScan: _fixtureLastScan);
    addTearDown(service.dispose);
    await _openEditor(tester, service);

    await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
    // 펼치는 중간에도 넘침·예외가 없다.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'frame $frame');
    }
    await tester.pumpAndSettle();

    _expectRect(
      _panelBounds(tester),
      const Rect.fromLTWH(1010, 270, 1000, 850),
      3,
      'expanded panel',
    );
    _expectRect(
      tester.getRect(find.byKey(const ValueKey('account-editor-portrait'))),
      const Rect.fromLTWH(1172.49, 301.76, 176, 142.48),
      2,
      'stucard',
    );
    _expectRect(
      tester.getRect(find.byKey(const ValueKey('account-name-input-path'))),
      const Rect.fromLTWH(1414.5, 330, 535.1, 56),
      2,
      'input',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-change-portrait')),
        matching: find.text('고르는 중'),
      ),
      findsOneWidget,
    );
    final picking = _outline(tester, 'account-change-portrait-outline');
    expect(picking.color, accountPressedOutline);
    expect(picking.strokeWidth, accountPressedOutlineWidth);
    // 펼침에는 편집기 뒤로가 없고 닫기·저장만 있다.
    expect(find.byKey(const ValueKey('account-editor-back')), findsNothing);
    expect(find.text('닫기'), findsOneWidget);
    _expectRect(
      tester.getRect(find.byKey(const ValueKey('account-picker-close'))),
      const Rect.fromLTWH(1587.6, 1050, 118, 50),
      2,
      'close',
    );
    _expectRect(
      tester.getRect(find.byKey(const ValueKey('account-picker-save'))),
      const Rect.fromLTWH(1715.6, 1050, 118, 50),
      2,
      'save',
    );
    // 머리 `초상 고르기` + (i)(시안 문구).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-picker-title')),
        matching: find.text('초상 고르기'),
      ),
      findsOneWidget,
    );
    final info = tester.widget<InfoPopover>(
      find.byKey(const ValueKey('account-picker-info')),
    );
    expect(info.title, '초상 고르기');
    expect(
      (info.children.single as InfoPopoverText).text,
      '학생 초상 중 하나를 고릅니다. 저장해야 계정 카드에 반영됩니다.',
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('account-picker-info-box')))
          .left,
      closeTo(1254, 2),
    );

    // 그리드: viewport 859.5×450, 6열, 첫 칸 1135.58,587.67 112×90.67, 다음 행은 19.04px 왼쪽.
    final grid = tester.widget<AssetImageGrid>(
      find.byKey(const ValueKey('account-portrait-grid')),
    );
    final gridBox = tester.getRect(
      find.byKey(const ValueKey('account-picker-viewport')),
    );
    _expectRect(
      gridBox,
      const Rect.fromLTWH(1057.6, 570, 859.5, 450),
      2,
      'viewport',
    );
    expect(grid.columns, 6);
    final firstLeft =
        gridBox.left + grid.contentPadding.left + grid.rowHorizontalOffsets[0];
    expect(firstLeft, closeTo(1135.58, 2));
    expect(gridBox.top + grid.contentPadding.top, closeTo(587.67, 2));
    expect(
      grid.rowHorizontalOffsets[0] - grid.rowHorizontalOffsets[1],
      closeTo(19.04, 0.1),
    );
    // 고른 초상(airi, 첫 칸): stucard 외곽선 #ff72b6 1.88, 다른 칸은 흰 1.
    expect(grid.selectedCell, 0);
    expect(grid.selectionColor, const Color(0xffff72b6));
    expect(grid.selectionWidthFraction * 90.67, closeTo(1.88, 0.01));
    expect(grid.items.first.outlineColor, Colors.white);
    expect(grid.items.first.outlineWidthFraction * 90.67, closeTo(1, 0.01));
    // 공용 사선 스크롤바(표준 썸 #e5a0ea)와 포그.
    final scrollbar = tester.widget<DiagonalScrollbar>(
      find.byType(DiagonalScrollbar).last,
    );
    expect(scrollbar.style, DiagonalScrollbarStyle.standard);
    expect(scrollbar.showFog, isTrue);
    expect(scrollbar.keyPrefix, 'account-portrait');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'close discards, picker save fills the draft, editor save persists',
    (tester) async {
      final service = _LastScanService();
      addTearDown(service.dispose);
      await _openEditor(tester, service);

      AssetImageGrid stucard() => tester.widget<AssetImageGrid>(
        find.byKey(const ValueKey('account-editor-portrait-grid')),
      );
      AssetImageGrid grid() => tester.widget<AssetImageGrid>(
        find.byKey(const ValueKey('account-portrait-grid')),
      );

      // 닫기 = 버림.
      await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
      await tester.pumpAndSettle();
      grid().onCellTap!(1);
      await tester.pump();
      expect(grid().selectedCell, 1);
      await tester.tap(find.byKey(const ValueKey('account-picker-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-portrait-grid')), findsNothing);
      expect(stucard().items.last.asset, 'assets/student_portraits/airi.png');
      _expectRect(
        _panelBounds(tester),
        const Rect.fromLTWH(1010, 470, 1000, 262),
        3,
        'collapsed again',
      );

      // 고르는 중을 다시 누르는 것도 닫기다.
      await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
      await tester.pumpAndSettle();
      grid().onCellTap!(2);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
      await tester.pumpAndSettle();
      expect(stucard().items.last.asset, 'assets/student_portraits/airi.png');

      // 저장(펼침) = 편집 중인 초상에만 반영하고 저장소는 부르지 않는다.
      await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
      await tester.pumpAndSettle();
      grid().onCellTap!(1);
      await tester.pump();
      final picked = grid().items[3].asset;
      await tester.tap(find.byKey(const ValueKey('account-picker-save')));
      await tester.pumpAndSettle();
      expect(stucard().items.last.asset, picked);
      expect(service.updates, isEmpty);
      expect(find.byKey(const ValueKey('account-editor-back')), findsOneWidget);

      // 편집기 저장 = 저장소 호출(원 revision) 뒤 관리 화면으로 돌아간다.
      await tester.tap(find.byKey(const ValueKey('account-editor-save')));
      await tester.pumpAndSettle();
      final pickedId = picked.split('/').last.replaceFirst('.png', '');
      expect(service.updates, hasLength(1));
      expect(service.updates.single.avatar, pickedId);
      expect(service.updates.single.name, '거모이는존재한다 (v7 UI 테스트)');
      final state = await service.loadRepositoryState(_mainId);
      expect(
        service.updates.single.revision,
        lessThanOrEqualTo(state.revision),
      );
      expect((await service.listProfiles()).single.avatarStudentId, pickedId);
      expect(
        find.byKey(const ValueKey('account-editor-section')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('account-manager-section')),
        findsOneWidget,
      );
    },
  );

  testWidgets('selected portrait far down the list is scrolled into view', (
    tester,
  ) async {
    final service = _LastScanService(avatar: 'hasumi');
    addTearDown(service.dispose);
    await _openEditor(tester, service);
    await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
    await tester.pumpAndSettle();

    final grid = tester.widget<AssetImageGrid>(
      find.byKey(const ValueKey('account-portrait-grid')),
    );
    final selected = grid.selectedCell!;
    expect(selected, greaterThan(24), reason: 'hasumi는 처음 4행 밖이다');
    final scroll = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('account-portrait-scroll')),
        )
        .controller!;
    final metrics = accountPortraitGridMetrics(const Size(859.5, 450), 267);
    final rowTop =
        metrics.padding.top +
        (selected ~/ 6) * (metrics.cell.height + metrics.rowGap);
    expect(scroll.offset, greaterThan(0));
    expect(rowTop, greaterThanOrEqualTo(scroll.offset));
    expect(
      rowTop + metrics.cell.height,
      lessThanOrEqualTo(scroll.offset + 450),
    );
  });

  testWidgets('meta line shows dashes without a scan or when history fails', (
    tester,
  ) async {
    final service = _LastScanService(failSummary: true);
    addTearDown(service.dispose);
    await _openEditor(tester, service);
    final meta = tester
        .widget<Text>(find.byKey(const ValueKey('account-editor-meta')))
        .data!;
    expect(meta, endsWith('· 마지막 스캔 —'));
    expect(service.summaryCalls, 1);
    // 목록은 그대로 보인다(이력 실패는 메타 줄만 '—').
    expect(find.byKey(const ValueKey('account-cluster-error')), findsNothing);

    final plain = MockAppService();
    addTearDown(plain.dispose);
    await _openEditor(tester, plain);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('account-editor-meta')))
          .data,
      endsWith('· 마지막 스캔 —'),
    );
  });

  testWidgets('small windows expand and collapse without overflow', (
    tester,
  ) async {
    for (final size in const [Size(1280, 720), Size(480, 270)]) {
      final service = _LastScanService(lastScan: _fixtureLastScan);
      addTearDown(service.dispose);
      await _openEditor(tester, service, size: size);
      final change = _ink(tester, 'account-change-portrait');
      change.onTap!();
      for (var frame = 0; frame < 32; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: '$size open $frame');
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-portrait-grid')),
        findsOneWidget,
      );
      // 글자는 버튼 path 안에 있다.
      for (final entry in const {
        'account-change-portrait': '고르는 중',
        'account-picker-close': '닫기',
        'account-picker-save': '저장',
      }.entries) {
        final action = tester.getRect(find.byKey(ValueKey(entry.key)));
        final text = tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey(entry.key)),
            matching: find.text(entry.value),
          ),
        );
        expect(text.width, lessThanOrEqualTo(action.width), reason: '$size');
        expect(text.height, lessThanOrEqualTo(action.height), reason: '$size');
      }
      _ink(tester, 'account-picker-close').onTap!();
      for (var frame = 0; frame < 32; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: '$size close $frame');
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-portrait-grid')), findsNothing);
    }
  });
}
