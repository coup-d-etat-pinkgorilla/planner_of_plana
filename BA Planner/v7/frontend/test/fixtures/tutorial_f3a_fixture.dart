// F3a 튜토리얼 부품 시험 · golden 공용 fixture(가짜 데이터).
//
// - 가짜 그림: 2×2 분홍 PNG(게임 그림 아님). 얼굴 칩 · 서 있는 그림 자리 시험용.
// - [TutorialCardPartsBoard]: 시안 W-Tutorial-Card의 상태들(진행 · 하위 체크 · 기다림 · 완료 체크) + 강조 테두리 3종
//   (버튼 · 행 · 타일) + 머리글 칩 + 진행 창 한 줄 + 카드 자리(꼭지) 예. 기준 viewport 2560×1392 좌표.
// - [PlanaDialogueBoard]: 가짜 화면 위 대사 띠(프라나 04 대사 2 / 5) + 밝히기 구멍 1개, 서 있는 그림 없음(시안 ③).
// 움직임은 [tutorialStillHost]로 멈춘다(움직임 줄이기 = golden 정착).
import 'dart:typed_data';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/tutorial/plana_dialogue.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_highlight.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_tokens.dart';
import 'package:flutter/material.dart';

/// 2×2 분홍(#f2b3ef) PNG.
final tutorialFakeImageBytes = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 2, //
  0, 0, 0, 2, 8, 6, 0, 0, 0, 114, 182, 13, 36, 0, 0, 0, 17, 73, 68, 65, //
  84, 120, 156, 99, 248, 180, 249, 253, 127, 16, 102, 128, 49, 0, 127, 248, //
  14, 77, 255, 100, 231, 116, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

/// 가짜 그림(얼굴 칩 · 서 있는 그림 자리).
final tutorialFakeImage = MemoryImage(tutorialFakeImageBytes);

/// 움직임 줄이기를 켠 자리(애니메이션 정지 → golden 정착).
Widget tutorialStillHost(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// 시험용 앱 껍데기(테마 · 움직임 줄이기 선택).
Widget tutorialTestApp(Widget child, {bool reduceMotion = false}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(body: reduceMotion ? tutorialStillHost(child) : child),
    );

/// 강조 견본 대상: 80° 평행사변형 바탕.
class FakeSlantTarget extends StatelessWidget {
  const FakeSlantTarget({
    super.key,
    required this.size,
    required this.label,
    this.onTap,
  });

  final Size size;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: _SlantPainter(),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tutorialText(16, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

class _SlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = tutorialHighlightPath(
      (Offset.zero & size).deflate(tutorialHighlightOffset),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xff2a3d54));
  }

  @override
  bool shouldRepaint(_SlantPainter oldDelegate) => false;
}

/// W-Tutorial-Card 상태 보드(2560×1392).
class TutorialCardPartsBoard extends StatelessWidget {
  const TutorialCardPartsBoard({super.key});

  static const buttonRect = Rect.fromLTWH(800, 294, 300, 60);
  static const rowRect = Rect.fromLTWH(800, 454, 760, 58);
  static const tileRect = Rect.fromLTWH(800, 604, 260, 160);
  static const placementArea = Rect.fromLTWH(1700, 560, 820, 520);
  static const placementTarget = Rect.fromLTWH(2330, 790, 160, 56);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.canvas,
    child: Stack(
      children: [
        Positioned(
          left: 60,
          top: 172,
          child: TutorialStepCard(step: tutorialSteps['3']!, onQuit: () {}),
        ),
        Positioned(
          left: 60,
          top: 392,
          child: TutorialStepCard(
            step: tutorialSteps['7-2']!,
            width: 560,
            onQuit: () {},
          ),
        ),
        Positioned(
          left: 60,
          top: 646,
          child: TutorialStepCard(
            step: tutorialSteps['2']!,
            mode: TutorialCardMode.waiting,
            waitDone: 34,
            waitTotal: 128,
            onQuit: () {},
          ),
        ),
        Positioned(
          left: 60,
          top: 898,
          child: TutorialStepCard(
            step: tutorialSteps['3']!,
            mode: TutorialCardMode.complete,
            face: tutorialFakeImage,
            onQuit: () {},
          ),
        ),
        // 강조 테두리: 버튼 · 행(평행사변형) · 타일(둥근 사각형).
        Positioned.fromRect(
          rect: buttonRect,
          child: const FakeSlantTarget(
            size: Size(300, 60),
            label: '학생 전체 스캔 시작',
          ),
        ),
        Positioned.fromRect(
          rect: rowRect,
          child: const FakeSlantTarget(
            size: Size(760, 58),
            label: '리오(무장)의 엘레프',
          ),
        ),
        Positioned.fromRect(
          rect: tileRect,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color.fromRGBO(16, 24, 35, 0.6),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        const TutorialHighlightRing(target: buttonRect),
        const TutorialHighlightRing(target: rowRect),
        const TutorialHighlightRing(
          target: tileRect,
          shape: TutorialHighlightShape.roundedRect,
          targetRadius: 10,
        ),
        // 머리글 표시.
        Positioned(
          left: 780,
          top: 846,
          child: Row(
            children: [
              Text('학생', style: tutorialText(20, height: 1.2)),
              const SizedBox(width: 12),
              const TutorialHeaderChip(),
            ],
          ),
        ),
        // 진행 창 안 한 줄(아이템 스캔).
        Positioned(
          left: 800,
          top: 1000,
          width: 347,
          child: TutorialInlineStepLine(
            step: tutorialSteps['5']!,
            onQuit: () {},
          ),
        ),
        // 카드 자리 예: 오른쪽 끝 대상 → 왼쪽에 붙고 꼭지는 오른쪽.
        Positioned.fromRect(
          rect: placementArea,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color.fromRGBO(16, 24, 35, 0.5),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: placementTarget,
          child: const FakeSlantTarget(size: Size(160, 56), label: '적용'),
        ),
        const TutorialHighlightRing(target: placementTarget),
        Positioned.fill(
          child: TutorialCardLayer(
            target: placementTarget,
            bounds: placementArea,
            card: TutorialStepCard(step: tutorialSteps['9']!, onQuit: () {}),
          ),
        ),
      ],
    ),
  );
}

/// 대사 띠 보드(2560×1392): 가짜 화면 + 프라나 04 대사 2 / 5 + 밝히기 구멍, 서 있는 그림 없음.
class PlanaDialogueBoard extends StatelessWidget {
  const PlanaDialogueBoard({
    super.key,
    this.sceneId = 'plana-04',
    this.lineIndex = 1,
    this.revealRects = const [Rect.fromLTRB(565, 342, 1860, 581)],
    this.figure,
    this.onNext,
    this.onQuit,
    this.onBackButton,
  });

  final String sceneId;
  final int lineIndex;
  final List<Rect> revealRects;
  final ImageProvider? figure;
  final VoidCallback? onNext;
  final VoidCallback? onQuit;

  /// 뒤 화면 버튼(입력 막음 시험용). null이면 버튼 없음.
  final VoidCallback? onBackButton;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: FakeAppScreen(onButton: onBackButton)),
      Positioned.fill(
        child: PlanaDialogueOverlay(
          scene: tutorialScenes[sceneId]!,
          lineIndex: lineIndex,
          revealRects: revealRects,
          figure: figure,
          onNext: onNext ?? () {},
          onQuit: onQuit ?? () {},
        ),
      ),
    ],
  );
}

/// 뒤 화면 대신 쓰는 가짜 화면(머리글 띠 + 판 몇 개). 실제 화면 연결은 F3c.
class FakeAppScreen extends StatelessWidget {
  const FakeAppScreen({super.key, this.onButton});

  final VoidCallback? onButton;

  static const buttonKey = ValueKey('fake-app-button');

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.canvas,
    child: Stack(
      children: [
        const Positioned(
          left: 18,
          top: 14,
          right: 18,
          height: 170,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.fromRGBO(36, 52, 72, 0.6),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
        Positioned(
          left: 40,
          top: 90,
          child: Row(
            children: [
              Text('스캔', style: tutorialText(20, height: 1.2)),
              const SizedBox(width: 12),
              const TutorialHeaderChip(),
            ],
          ),
        ),
        for (final rect in const [
          Rect.fromLTWH(14, 260, 520, 1080),
          Rect.fromLTWH(565, 260, 1300, 1080),
          Rect.fromLTWH(1890, 260, 650, 1080),
        ])
          Positioned.fromRect(
            rect: rect,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
        for (var row = 0; row < 6; row++)
          Positioned(
            left: 590,
            top: 360.0 + row * 80,
            width: 1250,
            height: 64,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.rowSurface,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        if (onButton != null)
          Positioned(
            left: 40,
            top: 300,
            width: 300,
            height: 60,
            child: ElevatedButton(
              key: buttonKey,
              onPressed: onButton,
              child: const Text('뒤 화면 버튼'),
            ),
          ),
      ],
    ),
  );
}
