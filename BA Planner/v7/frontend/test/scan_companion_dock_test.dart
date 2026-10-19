// FE8-g3: 아이템 진행 창(시안 Scan-Item-Run 진행 · 일시정지 · 끝). 예전 학생 dock 시험(STUDENT SCAN · 현재 학생 카드)은
// 학생이 FE8-g2부터 dock을 쓰지 않아 이 진행 창 시험으로 바꿨다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _kinds = [
  ScanCompanionKind(
    id: 'tech_notes',
    label: '기술 노트',
    chipLabel: '28칸',
    chipTone: AppTones.pink,
  ),
  ScanCompanionKind(
    id: 'tactical_bd',
    label: '전술 교육 BD',
    chipLabel: '대기',
    chipTone: AppTones.gray,
  ),
];

ScanCompanionState _state({
  ScanCompanionPhase phase = ScanCompanionPhase.running,
  List<ScanCompanionKind> kinds = _kinds,
  ScanCompanionCard? card,
  List<ScanCompanionLogLine> log = const [],
  VoidCallback? onPause,
  VoidCallback? onResume,
  VoidCallback? onCancel,
  VoidCallback? onOpenReview,
}) => ScanCompanionState(
  phase: phase,
  names: '기술 노트 · 전술 교육 BD',
  chipLabel: '진행 중',
  chipTone: AppTones.pink,
  countText: '28',
  countCaption: '칸 · 1번째 / 2종류',
  fraction: null,
  barColor: AppColors.accent,
  kinds: kinds,
  reading: kinds.first,
  card: card,
  log: log,
  onPause: onPause,
  onResume: onResume,
  onCancel: onCancel,
  onOpenReview: onOpenReview,
);

Future<void> _pump(
  WidgetTester tester,
  ScanCompanionState state, {
  Size size = const Size(375, 750),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox.fromSize(
        size: size,
        child: ScanCompanionDock(state: state),
      ),
    ),
  );
  await tester.pump();
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

VoidCallback? _pressed(WidgetTester tester, String key) => tester
    .widget<KitPressable>(
      find.descendant(of: _key(key), matching: find.byType(KitPressable)),
    )
    .onPressed;

void main() {
  testWidgets('running window: names, count, kinds, now reading, buttons', (
    tester,
  ) async {
    var cancelled = 0;
    var paused = 0;
    await _pump(
      tester,
      _state(
        onPause: () => paused += 1,
        onCancel: () => cancelled += 1,
        log: const [
          ScanCompanionLogLine(text: '오파츠 12칸 완료', tone: AppTones.ok),
        ],
      ),
    );
    expect(_text(tester, 'scan-dock-title'), 'Plan A · 아이템 스캔');
    expect(_text(tester, 'scan-dock-names'), '기술 노트 · 전술 교육 BD');
    expect(find.text('진행 중'), findsOneWidget);
    expect(_text(tester, 'scan-dock-count'), '28');
    expect(_text(tester, 'scan-dock-count-caption'), '칸 · 1번째 / 2종류');
    // 전체 분모 · % · 남은 시간은 고정 형식 밖이라 그리지 않는다.
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('남은 시간'), findsNothing);
    expect(_key('scan-dock-kind-tech_notes'), findsOneWidget);
    expect(_key('scan-dock-kind-tactical_bd'), findsOneWidget);
    expect(find.text('28칸'), findsOneWidget);
    expect(find.text('대기'), findsOneWidget);
    expect(find.text('NOW READING'), findsOneWidget);
    expect(_text(tester, 'scan-dock-reading-kind'), '기술 노트');
    expect(_text(tester, 'scan-dock-reading-item'), '—');
    for (final label in ['바뀐 수량', '확인 필요', '그대로']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(_key('scan-dock-log-0'), findsOneWidget);
    expect(find.text('오파츠 12칸 완료'), findsOneWidget);
    expect(_key('scan-dock-warning'), findsOneWidget);
    expect(find.text('마우스 · 키보드를 쓰면 일시정지합니다 · Esc 중지'), findsOneWidget);
    expect(_key('scan-dock-open-review'), findsNothing);

    await tester.tap(_key('scan-dock-pause'));
    await tester.tap(_key('scan-dock-cancel'));
    expect(paused, 1);
    expect(cancelled, 1);
    // Esc도 중지다(시안 `Esc 중지`).
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused window shows the card, resume and no warning', (
    tester,
  ) async {
    var resumed = 0;
    await _pump(
      tester,
      _state(
        phase: ScanCompanionPhase.paused,
        onResume: () => resumed += 1,
        onCancel: () {},
        card: const ScanCompanionCard(
          title: '마우스 입력이 감지되어 멈췄습니다',
          body: "게임 화면을 처음 위치로 되돌린 뒤 '이어서'를 누르십시오. 읽은 28칸은 그대로 남습니다.",
          tone: AppTones.warn,
        ),
      ),
    );
    expect(_text(tester, 'scan-dock-card-title'), '마우스 입력이 감지되어 멈췄습니다');
    expect(find.text('NOW READING'), findsNothing);
    expect(_key('scan-dock-warning'), findsNothing);
    expect(_key('scan-dock-pause'), findsNothing);
    expect(find.text('이어서'), findsOneWidget);
    await tester.tap(_key('scan-dock-resume'));
    expect(resumed, 1);
  });

  testWidgets('ended window offers only the review button', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      _state(
        phase: ScanCompanionPhase.ended,
        onOpenReview: () => opened += 1,
        card: const ScanCompanionCard(
          title: '스캔을 마쳤습니다',
          body: '곧 플래너가 앞으로 오고 결과 검토가 열립니다. 이 창은 함께 닫힙니다.',
          tone: AppTones.ok,
        ),
      ),
    );
    expect(_text(tester, 'scan-dock-card-title'), '스캔을 마쳤습니다');
    expect(_key('scan-dock-pause'), findsNothing);
    expect(_key('scan-dock-cancel'), findsNothing);
    expect(_key('scan-dock-warning'), findsNothing);
    await tester.tap(_key('scan-dock-open-review'));
    expect(opened, 1);
  });

  testWidgets('disabled buttons while starting or cancelling', (tester) async {
    await _pump(tester, _state(phase: ScanCompanionPhase.cancelling));
    expect(find.text('중지하는 중…'), findsOneWidget);
    expect(_pressed(tester, 'scan-dock-pause'), isNull);
    expect(_pressed(tester, 'scan-dock-cancel'), isNull);
  });

  testWidgets('the design size scales evenly and seven kinds fit', (
    tester,
  ) async {
    final seven = [
      for (final (index, id) in [
        'ooparts',
        'tech_notes',
        'tactical_bd',
        'activity_reports',
        'student_elephs',
        'equipment',
        'presents',
      ].indexed)
        ScanCompanionKind(
          id: id,
          label: '종류 $index',
          chipLabel: index == 0 ? '완료 · 120칸' : '대기',
          chipTone: index == 0 ? AppTones.ok : AppTones.gray,
        ),
    ];
    final log = [
      for (var index = 0; index < 6; index += 1)
        ScanCompanionLogLine(text: '줄 $index', tone: AppTones.ok),
    ];
    // 높이 540(시안 각주 예) · 1280×720 덮개 · 아주 좁은 창.
    for (final size in const [
      Size(270, 540),
      Size(1280, 720),
      Size(200, 300),
    ]) {
      await _pump(
        tester,
        _state(kinds: seven, log: log),
        size: size,
      );
      expect(tester.takeException(), isNull, reason: '$size');
      for (final kind in seven) {
        expect(_key('scan-dock-kind-${kind.id}'), findsOneWidget);
      }
      // 7종이면 최근 기록이 들어갈 자리가 없어 그리지 않는다(경고 줄과 겹치지 않는다).
      expect(_key('scan-dock-log-0'), findsNothing, reason: '$size');
    }
    // 2종이면 최근 기록 5줄까지.
    await _pump(tester, _state(log: log));
    expect(_key('scan-dock-log-4'), findsOneWidget);
    expect(_key('scan-dock-log-5'), findsNothing);
    // 설계 크기와 같은 창에서 막대 · 버튼 자리(시안 rect ±2px).
    final bar = tester.getRect(_key('scan-dock-bar'));
    expect((bar.left - 14).abs(), lessThanOrEqualTo(2));
    expect((bar.top - 131.6).abs(), lessThanOrEqualTo(2));
    expect((bar.width - 347).abs(), lessThanOrEqualTo(2));
    final kind = tester.getRect(_key('scan-dock-kind-tactical_bd'));
    expect((kind.top - 203).abs(), lessThanOrEqualTo(2));
    final cancel = tester.getRect(_key('scan-dock-cancel'));
    expect((cancel.top - 692).abs(), lessThanOrEqualTo(2));
    expect((cancel.right - 361).abs(), lessThanOrEqualTo(2));
    expect((cancel.height - 44).abs(), lessThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });
}
