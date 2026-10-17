// 홈 스캔 팝업(FE8-f3, 시안 Home-Connected-Scan, FD-140 (a) · FD-150 (b) · FD-151 (a)).
//
// 게임 창이 연결된 홈에서 첫 버튼 `스캔`을 누르면 뜨는 떠 있는 모달이다(FD-019 예외: 모달은 떠 있다). 좌표는 시안 artboard의
// 팝업 rect(520,300 1520×780)를 원점으로 한 설계 px이고, 홈이 메뉴와 같은 배율로 줄여 가운데에 놓는다. Studio 섹션이 아니다.
// - 머리 줄: 분홍 사선 막대 + `스캔` + (i) + 크기를 넣은 연결 칩(`연결됨 · Blue Archive · 2560×1440`), `창 다시 선택`, ×.
// - 줄 라벨(학생 · 아이템 · 기타)이 80° 계단으로 왼쪽으로 밀리고, 타일은 80° 평행사변형 r9(바탕 삼각 무늬, 선 .74 1.8px).
// - 학생 2(전체 · 지금 화면 1명) · 아이템 5(오파츠 · 기술 노트 · 전술 교육 BD · 활동 보고서 · 엘레프) · 기타 3(장비 · 선물 ·
//   전술대항전). 선물은 시안 2칸 줄을 같은 폭에서 3칸으로 나눴다(FD-151 (a), 칸 사이 사선 간격 12 그대로).
// - 타일 그림은 열 때마다 바뀐다(시안 무작위). 같은 [HomeScanPopup.seed]면 같은 그림이다(golden · 시험).
// - 학생 · 아이템 · 선물 타일 = 그 종류 하나 바로 시작(FD-140 (a)), 전술대항전 타일 = 전술대항전 탭 링크(FD-150 (b)).
//   진행 중 · 검토 대기면 시작 타일을 막고 아래 안내 줄에 이유를 쓴다(FE8-g1 고르기 판정 [scanTabViewFor]과 같은 뜻).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart' show ConfirmedStudentState;
import '../../services/scanner_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/titles.dart';
import '../models/planning_resource_assets.dart';
import '../scan/header_connection_chip.dart' show connectedTargetLabel;
import '../scan/scan_header_progress.dart';
import '../scan/scan_pick_logic.dart';
import '../scan/scan_session_controller.dart';
import '../widgets/asset_image_grid.dart';
import '../widgets/ba_triangle_background.dart';
import '../widgets/section_surface.dart';
import '../widgets/student_section_layout.dart' show studentGridCardPath;

/// 팝업 바탕(시안 `rgba(29,42,58,.97)`).
const _popupFill = Color.fromRGBO(29, 42, 58, 0.97);

/// 타일 외곽선(시안 `rgba(56,81,107,.74)` 1.8px)과 줄 라벨 막대(`#71c7f4` 6×18).
const _tileStroke = Color.fromRGBO(56, 81, 107, 0.74);
const _tileStrokeWidth = 1.8;

/// 타일 hover(시안에 없음 — 키트 `.tile` hover와 같은 밝기의 흰 .05 덮개).
const _tileHover = Color.fromRGBO(255, 255, 255, 0.05);

/// `창 다시 선택`(시안 `#3a4b58`, 글자 `#d6e4f0`)과 ×(흰 .07, 선 `rgba(56,81,107,.8)` 1.2px, 글자 `#dfe7ee`).
const _reselectFill = Color(0xff3a4b58);
const _reselectHoverFill = Color(0xff455866);
const _reselectText = Color(0xffd6e4f0);
const _closeFill = Color.fromRGBO(255, 255, 255, 0.07);
const _closeHoverFill = Color.fromRGBO(255, 255, 255, 0.12);
const _closeStroke = Color.fromRGBO(56, 81, 107, 0.8);

/// 전술대항전 타일 아이콘(시안 `#5d7288`).
const _tacticalGlyph = Color(0xff5d7288);

/// 막힌 이유 글자(시안 `.chip.wn` 글자 `#ffd08a`, FE8-g1 시작 판정 글자와 같은 색).
const _noteWarn = Color(0xffffd08a);

/// 타일 바탕 삼각 무늬(시안 그림 = 계획 요소 텍스처 `_planElementTexture`와 같은 값, UI-Elements 7번).
const _tileTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 76,
  tessellationContrast: 0.05,
  randomSeed: 7319,
  macroTriangleChance: 0.08,
  macroTriangleScale: 2.5,
  macroTriangleContrast: 0.035,
  lightStrength: 0.11,
  edgeVignetteStrength: 0.11,
  fogStrength: 0.06,
);

/// 팝업 타일 하나가 하는 일.
sealed class HomeScanTile {
  const HomeScanTile();

  /// 타일 key 꼬리(`home-scan-popup-tile-<id>`).
  String get id;
}

/// 학생 타일(전체 · 지금 화면 1명).
final class HomeScanStudentTile extends HomeScanTile {
  const HomeScanStudentTile(this.mode);

  final StudentScanMode mode;

  @override
  String get id => 'student-${mode.name}';
}

/// 아이템 한 종류(아이템 줄 5칸, 기타 줄 장비 · 선물).
final class HomeScanInventoryTile extends HomeScanTile {
  const HomeScanInventoryTile(this.profile);

  final InventoryScanProfile profile;

  @override
  String get id => 'inventory-${profile.wireName}';
}

/// 전술대항전 탭 링크(FD-150 (b)).
final class HomeScanTacticalTile extends HomeScanTile {
  const HomeScanTacticalTile();

  @override
  String get id => 'tactical';
}

/// 팝업 시작 타일을 막는 진행 상태.
enum HomeScanPopupBusy {
  /// 시작 중 · 진행 · 일시정지 · 중지 요청 중.
  session,

  /// 끝났고 아직 적용 · 폐기하지 않은 후보가 있다(새로 시작하면 결과를 잃는다).
  review,
}

/// 스캔 탭이 고르기 대신 진행 · 검토를 보이는 상태면 팝업 시작 타일도 막는다(FE8-g1 [scanTabViewFor]와 같은 판정).
HomeScanPopupBusy? homeScanPopupBusy(
  ScanSessionController controller, {
  Set<String> appliedElsewhere = const {},
}) {
  if (scanTabViewFor(controller, appliedElsewhere: appliedElsewhere) ==
      ScanTabView.pick) {
    return null;
  }
  return ScanHeaderStatus.of(
            controller,
            appliedElsewhere: appliedElsewhere,
          ).activity ==
          ScanHeaderActivity.reviewPending
      ? HomeScanPopupBusy.review
      : HomeScanPopupBusy.session;
}

/// 막은 이유 글자. 진행은 FE8-g1 시작 판정 글자([ScanStartBlock.busy]) 그대로다.
String homeScanPopupBusyText(
  HomeScanPopupBusy busy,
  ScanSessionController controller,
) => switch (busy) {
  HomeScanPopupBusy.session => scanStartNote(ScanStartBlock.busy, controller),
  HomeScanPopupBusy.review => '검토하지 않은 스캔 결과가 있습니다. 스캔 탭에서 검토한 뒤 시작할 수 있습니다.',
};

/// [tile] 하나로 스캔을 시작한다(FD-140 (a)). 고르기를 그 타일로 바꿔 FE8-g1 시작 판정([scanStartBlock])을 그대로 받고,
/// 시작할 수 있으면 [ScanSessionController.startPick]을 부른다(dock 등 시작 동작은 컨트롤러 그대로). 막혔으면 스캔 탭
/// 고르기를 원래대로 되돌리고 이유를 돌려준다. 시작했으면 스캔 탭 고르기는 시작한 종류로 남는다.
ScanStartBlock homeScanStartTile(
  ScanSessionController controller,
  HomeScanTile tile,
) {
  final previous = controller.pick;
  switch (tile) {
    case HomeScanStudentTile(:final mode):
      controller.pickStudent(mode);
    case HomeScanInventoryTile(:final profile):
      controller.pickInventory([profile]);
    case HomeScanTacticalTile():
      return ScanStartBlock.none;
  }
  final block = scanStartBlock(controller);
  if (block == ScanStartBlock.none) {
    unawaited(controller.startPick());
    return block;
  }
  if (previous != controller.pick) {
    final mode = previous.studentScanMode;
    if (mode != null) {
      controller.pickStudent(mode);
    } else if (previous.inventoryScanProfiles.isNotEmpty) {
      controller.pickInventory(previous.inventoryScanProfiles);
    } else {
      controller.clearPick();
    }
  }
  return block;
}

/// 팝업 안 타일 하나의 자리(설계 px)와 줄.
typedef HomeScanTileSlot = ({HomeScanTile tile, Rect rect, int row});

class HomeScanPopup extends StatelessWidget {
  const HomeScanPopup({
    super.key,
    required this.controller,
    required this.target,
    required this.seed,
    required this.onTile,
    required this.onReselect,
    required this.onClose,
    required this.onOpenScanTab,
    this.appliedElsewhere = const {},
    this.note,
  });

  /// 시안 팝업 rect(viewport 520,300).
  static const designSize = Size(1520, 780);
  static const designOrigin = Offset(520, 300);

  /// 홈 메뉴 섹션 위(시안 202)에서 팝업 위(300)까지.
  static const menuTopOffset = 98.0;

  /// 팝업 r(시안 path Q 18).
  static const radius = 18.0;

  /// 줄 라벨 자리(팝업 좌표, 시안 654,440 · 615,666 · 582,882).
  static const rowLabels = [
    Rect.fromLTWH(134, 140, 170, 210),
    Rect.fromLTWH(95, 366, 170, 200),
    Rect.fromLTWH(62, 582, 170, 150),
  ];

  /// 칸 사이 겹침(시안 기타 줄 574.7 − 560.2). 사선 간격 12는 줄 높이와 무관하게 같다.
  static const _otherOverlap = 14.5;

  /// 기타 줄 3칸 폭: 시안 2칸 줄 폭(242.5 → 1377.4)을 그대로 두고 칸만 나눈다(FD-151 (a)).
  static const otherTileWidth = (1377.4 - 242.5 + 2 * _otherOverlap) / 3;

  static const _itemProfiles = [
    InventoryScanProfile.ooparts,
    InventoryScanProfile.techNotes,
    InventoryScanProfile.tacticalBd,
    InventoryScanProfile.activityReports,
    InventoryScanProfile.studentElephs,
  ];

  /// 타일 자리(팝업 좌표, 시안 rect).
  static final List<HomeScanTileSlot> slots = [
    (
      tile: const HomeScanStudentTile(StudentScanMode.full),
      rect: const Rect.fromLTWH(309.8, 140, 666.9, 210),
      row: 0,
    ),
    (
      tile: const HomeScanStudentTile(StudentScanMode.single),
      rect: const Rect.fromLTWH(951.7, 140, 503.6, 210),
      row: 0,
    ),
    for (final (index, profile) in _itemProfiles.indexed)
      (
        tile: HomeScanInventoryTile(profile),
        rect: Rect.fromLTWH(271.7 + 224.1 * index, 366, 247.4, 200),
        row: 1,
      ),
    for (final (index, tile) in const <HomeScanTile>[
      HomeScanInventoryTile(InventoryScanProfile.equipment),
      HomeScanInventoryTile(InventoryScanProfile.presents),
      HomeScanTacticalTile(),
    ].indexed)
      (
        tile: tile,
        rect: Rect.fromLTWH(
          242.5 + (otherTileWidth - _otherOverlap) * index,
          582,
          otherTileWidth,
          150,
        ),
        row: 2,
      ),
  ];

  /// 아래 안내 줄(시안에 없음 — 막힌 이유 · 진행 중 문구, 기타 줄 아래 여백).
  static const noteRect = Rect.fromLTWH(60, 744, 1300, 26);

  final ScanSessionController controller;

  /// 연결된 게임 창(칩 글자). 없으면 칩을 그리지 않는다.
  final ScannerTarget? target;

  /// 타일 그림을 고르는 씨앗. 열 때마다 바뀐다.
  final int seed;

  final ValueChanged<HomeScanTile> onTile;
  final VoidCallback onReselect;
  final VoidCallback onClose;
  final VoidCallback onOpenScanTab;

  /// 다른 탭(학생 · 인벤토리)에서 적용한 후보(FE8-f2, 검토 대기에서 뺀다).
  final Set<String> appliedElsewhere;

  /// 마지막으로 누른 타일이 막힌 이유(FE8-g1 시작 판정 글자).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final busy = homeScanPopupBusy(
      controller,
      appliedElsewhere: appliedElsewhere,
    );
    final target = this.target;
    final note = busy == null
        ? this.note
        : homeScanPopupBusyText(busy, controller);
    return Semantics(
      container: true,
      label: '스캔',
      child: SizedBox.fromSize(
        key: const ValueKey('home-scan-popup'),
        size: designSize,
        child: SectionSurface(
          clipper: const _PopupClipper(),
          fill: _popupFill,
          child: Stack(
            children: [
              Positioned(
                left: 167,
                top: 30,
                right: 330,
                height: 36,
                child: Row(
                  children: [
                    const TitleBar(width: 7, height: 26),
                    const SizedBox(width: 14),
                    Text(
                      '스캔',
                      maxLines: 1,
                      style: kitDisplayStyle(AppType.displaySmallSize),
                    ),
                    const SizedBox(width: 14),
                    InfoPopover(
                      label: '스캔 도움말',
                      title: '스캔',
                      children: [
                        InfoPopoverText.plain(
                          '게임에서 해당 화면을 열어 둔 뒤 누르십시오. 스캔하는 동안에는 게임 창을 가리지 마십시오.',
                        ),
                      ],
                    ),
                    if (target != null) ...[
                      const SizedBox(width: 20),
                      Flexible(child: _TargetChip(target: target)),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 1218.7,
                top: 28,
                width: 186,
                height: 40,
                child: _ReselectButton(onPressed: onReselect),
              ),
              Positioned(
                left: 1416.7,
                top: 28,
                width: 58,
                height: 40,
                child: _CloseButton(onPressed: onClose),
              ),
              for (final (index, title) in const ['학생', '아이템', '기타'].indexed)
                Positioned.fromRect(
                  rect: rowLabels[index],
                  child: _RowLabel(
                    title: title,
                    subtitle: switch (index) {
                      0 => '학생 화면',
                      1 => '인벤토리 · 종류별',
                      _ => null,
                    },
                  ),
                ),
              for (final slot in slots)
                Positioned.fromRect(
                  rect: slot.rect,
                  child: _tile(slot, busy: busy != null),
                ),
              if (note != null)
                Positioned.fromRect(
                  rect: noteRect,
                  child: _NoteLine(
                    text: note,
                    warn: busy == null,
                    onOpenScanTab: busy == null ? null : onOpenScanTab,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(HomeScanTileSlot slot, {required bool busy}) {
    final tile = slot.tile;
    final enabled = tile is HomeScanTacticalTile || !busy;
    final label = _tileTitle(tile);
    return _PopupTile(
      key: ValueKey('home-scan-popup-tile-${tile.id}'),
      semanticLabel: label,
      onPressed: enabled ? () => onTile(tile) : null,
      contentInset: switch (slot.row) {
        0 => const EdgeInsets.only(left: 59, right: 22),
        1 => const EdgeInsets.only(left: 57, right: 22),
        _ => const EdgeInsets.only(left: 48, right: 22),
      },
      child: switch (slot.row) {
        2 => _OtherTileBody(
          icon: _tileIcon(tile, const Size(72, 58)),
          title: label,
          subtitle: _otherSubtitle(tile),
        ),
        _ => _ColumnTileBody(
          picture: _tilePicture(tile),
          title: label,
          subtitle: switch (tile) {
            HomeScanStudentTile(mode: StudentScanMode.full) => '학생 목록을 차례로 넘기며',
            HomeScanStudentTile() => '열려 있는 학생 정보 한 명',
            _ => null,
          },
        ),
      },
    );
  }

  static String _tileTitle(HomeScanTile tile) => switch (tile) {
    HomeScanStudentTile(mode: StudentScanMode.full) => '전체 학생',
    HomeScanStudentTile() => '지금 화면 1명',
    HomeScanInventoryTile(:final profile) => scanInventoryProfileLabel(profile),
    HomeScanTacticalTile() => '전술대항전',
  };

  /// 기타 줄 설명(시안 `장비 인벤토리`, 선물 · 전술대항전은 같은 짜임으로 지은 글자).
  static String _otherSubtitle(HomeScanTile tile) => switch (tile) {
    HomeScanInventoryTile(profile: InventoryScanProfile.equipment) => '장비 인벤토리',
    HomeScanInventoryTile(profile: InventoryScanProfile.presents) => '선물 인벤토리',
    HomeScanTacticalTile() => '전술대항전 탭으로 이동',
    _ => '',
  };

  Widget _tilePicture(HomeScanTile tile) => switch (tile) {
    HomeScanStudentTile(:final mode) => _StudentCards(
      studentIds: _studentPicks(mode),
      cards: mode == StudentScanMode.full ? 3 : 1,
    ),
    _ => _tileIcon(tile, const Size(96, 78)),
  };

  /// 보유 학생을 씨앗으로 섞어 앞에서부터 고른다(시안 12장 중 무작위). 모르면 빈 카드.
  List<String> _studentPicks(StudentScanMode mode) {
    final owned = [
      for (final ConfirmedStudentState student
          in controller.repositoryState?.students ?? const [])
        student.studentId,
    ]..sort();
    owned.shuffle(math.Random(seed * 31 + mode.index));
    return owned.take(mode == StudentScanMode.full ? 3 : 1).toList();
  }

  Widget _tileIcon(HomeScanTile tile, Size size) {
    switch (tile) {
      case HomeScanTacticalTile():
        // 빈 아이템 칸 위에 교차한 칼 선 아이콘(시안 24.36px, `#5d7288`).
        return Stack(
          alignment: Alignment.center,
          children: [
            ItemIconTile(size: size, semanticLabel: '전술대항전'),
            SizedBox.square(
              dimension: size.height * 0.42,
              child: const CustomPaint(painter: _SwordsPainter()),
            ),
          ],
        );
      case HomeScanInventoryTile(:final profile):
        final entry = _itemPick(profile);
        final icon = entry == null
            ? null
            : planningResourceIconAsset(
                category: entry.category,
                itemId: entry.itemId,
              );
        final label = scanInventoryProfileLabel(profile);
        return ItemIconTile(
          iconAsset: icon,
          size: size,
          label: icon == null
              ? label.substring(0, math.min(4, label.length))
              : null,
          semanticLabel: label,
        );
      case HomeScanStudentTile():
        return SizedBox.fromSize(size: size);
    }
  }

  /// 그 종류 카탈로그 항목 하나(씨앗으로 고름, 시안 종류마다 3~7장 중 무작위). 없으면 null.
  InventoryCatalogEntry? _itemPick(InventoryScanProfile profile) {
    final entries = [
      for (final entry in controller.inventoryCatalog)
        if (entry.profileId == profile.wireName) entry,
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (entries.isEmpty) return null;
    return entries[math.Random(
      seed * 31 + 7 + profile.index,
    ).nextInt(entries.length)];
  }
}

/// 팝업 표면: 80° 평행사변형 r18(시안 path).
class _PopupClipper extends CustomClipper<Path> {
  const _PopupClipper();

  @override
  Path getClip(Size size) => _parallelogram(size, HomeScanPopup.radius);

  @override
  bool shouldReclip(_PopupClipper oldClipper) => false;
}

/// 80° 평행사변형(위가 오른쪽으로 밀림). 시안 path는 Q 곡선이다.
Path _parallelogram(Size size, double radius) {
  final cut = diagonalCutDepth(size.height);
  return diagonalRoundedPolygon(
    [
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width - cut, size.height),
      Offset(0, size.height),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.quadratic,
  );
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => _parallelogram(size, radius);

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) =>
      oldClipper.radius != radius;
}

/// 줄 라벨: 하늘 사선 막대 6×18 + 제목(dsp 22) + 설명(14).
class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Transform(
              transform: Matrix4.skewX(-10 * math.pi / 180),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 6,
                height: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.headlineMediumSize),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.titleSmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: AppType.regular,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 팝업 타일: 80° 평행사변형 r9, 삼각 무늬 바탕, 선 .74 1.8px. 누를 수 없으면 내용 .45(시안 `준비 중` 타일).
class _PopupTile extends StatelessWidget {
  const _PopupTile({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.contentInset,
    required this.child,
  });

  static const radius = 9.0;

  final String semanticLabel;
  final VoidCallback? onPressed;
  final EdgeInsets contentInset;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _ParallelogramClipper(radius),
    child: KitPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, state) => CustomPaint(
        painter: const _TileTexturePainter(),
        foregroundPainter: _TileOutlinePainter(hovered: state.hovered),
        child: Padding(
          padding: contentInset,
          child: Opacity(opacity: onPressed == null ? 0.45 : 1, child: child),
        ),
      ),
    ),
  );
}

class _TileTexturePainter extends CustomPainter {
  const _TileTexturePainter();

  @override
  void paint(Canvas canvas, Size size) =>
      BATriangleTexturePainter(_tileTexture).paint(canvas, size);

  @override
  bool shouldRepaint(_TileTexturePainter oldDelegate) => false;
}

class _TileOutlinePainter extends CustomPainter {
  const _TileOutlinePainter({required this.hovered});

  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _parallelogram(size, _PopupTile.radius);
    if (hovered) canvas.drawPath(path, Paint()..color = _tileHover);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _tileStrokeWidth
        ..color = _tileStroke,
    );
  }

  @override
  bool shouldRepaint(_TileOutlinePainter oldDelegate) =>
      oldDelegate.hovered != hovered;
}

/// 학생 · 아이템 줄 타일 내용: 그림 위, 제목(dsp 21) · 설명(12.5) 아래, 간격 14.
class _ColumnTileBody extends StatelessWidget {
  const _ColumnTileBody({
    required this.picture,
    required this.title,
    this.subtitle,
  });

  final Widget picture;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: picture,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(AppType.headlineSmallSize),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodySmall.copyWith(
              fontSize: AppType.popoverBodySize,
              color: AppColors.textMuted,
              fontWeight: AppType.regular,
            ),
          ),
        ],
      ],
    );
  }
}

/// 기타 줄 타일 내용: 아이콘 72×58 왼쪽, 제목(dsp 19) · 설명(12.5) 오른쪽, 간격 16.
class _OtherTileBody extends StatelessWidget {
  const _OtherTileBody({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      icon,
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kitDisplayStyle(AppType.panelTitleSize),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySmall.copyWith(
                fontSize: AppType.popoverBodySize,
                color: AppColors.textMuted,
                fontWeight: AppType.regular,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 학생 카드 겹침(시안 stucard 96.35×78, 다음 카드 −53): square.png 테두리 잘라 채움 + 초상 98%, 흰 1px.
class _StudentCards extends StatelessWidget {
  const _StudentCards({required this.studentIds, required this.cards});

  static const cardSize = Size(96.35, 78);
  static const overlap = 53.0;

  final List<String> studentIds;
  final int cards;

  @override
  Widget build(BuildContext context) {
    const pitch = 96.35 - overlap;
    return SizedBox(
      width: cardSize.width + pitch * (cards - 1),
      height: cardSize.height,
      child: Stack(
        children: [
          for (var index = 0; index < cards; index++)
            Positioned(
              left: pitch * index,
              top: 0,
              width: cardSize.width,
              height: cardSize.height,
              child: AssetImageGrid(
                items: [
                  const AssetImageGridItem(
                    asset: 'assets/studio_features/square.png',
                    column: 0,
                    row: 0,
                    edgeCropFraction: 0.11,
                    clipPathBuilder: studentGridCardPath,
                    outlineColor: Colors.white,
                    outlineWidthFraction: 1 / 96,
                  ),
                  if (index < studentIds.length)
                    AssetImageGridItem(
                      asset:
                          'assets/student_portraits/${studentIds[index]}.png',
                      column: 0,
                      row: 0,
                      scale: 0.98,
                      clipRadiusFraction: 0.12,
                      alphaThreshold: 0.04,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 교차한 칼(시안 svg `M4 4l10 10M14 18l4-4M4 20l5-5M20 4L10 14M6 14l4 4`, stroke 1.8 round).
class _SwordsPainter extends CustomPainter {
  const _SwordsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 24;
    Offset p(double x, double y) => Offset(x * unit, y * unit);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8 * unit
      ..color = _tacticalGlyph;
    for (final (a, b) in [
      (p(4, 4), p(14, 14)),
      (p(14, 18), p(18, 14)),
      (p(4, 20), p(9, 15)),
      (p(20, 4), p(10, 14)),
      (p(6, 14), p(10, 18)),
    ]) {
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(_SwordsPainter oldDelegate) => false;
}

/// 연결 칩(시안 `.conn`: 녹 #58d6a7, 채움 .12, 안쪽 선 .55, 점 8, 12px w600). 크기를 넣는다(FD-001).
class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.target});

  final ScannerTarget target;

  @override
  Widget build(BuildContext context) {
    final label = connectedTargetLabel(target);
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: '게임 창 $label',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    key: const ValueKey('home-scan-popup-target'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppType.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: AppType.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `창 다시 선택`(80° 평행사변형 r7, #3a4b58, 아이콘 + 13px w600).
class _ReselectButton extends StatelessWidget {
  const _ReselectButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    key: const ValueKey('home-scan-popup-reselect'),
    onPressed: onPressed,
    semanticLabel: '창 다시 선택',
    builder: (context, state) => ClipPath(
      clipper: const _ParallelogramClipper(7),
      child: ColoredBox(
        color: state.hovered ? _reselectHoverFill : _reselectFill,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, size: 15, color: _reselectText),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '창 다시 선택',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(
                  color: _reselectText,
                  fontWeight: AppType.semiBold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// ×(80° 평행사변형 r7, 흰 .07 + 선 1.2px).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    key: const ValueKey('home-scan-popup-close'),
    onPressed: onPressed,
    semanticLabel: '닫기',
    builder: (context, state) => CustomPaint(
      painter: _CloseFramePainter(hovered: state.hovered),
      child: const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CustomPaint(
            painter: KitGlyphPainter(
              glyph: KitGlyph.close,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    ),
  );
}

class _CloseFramePainter extends CustomPainter {
  const _CloseFramePainter({required this.hovered});

  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _parallelogram(size, 7);
    canvas
      ..drawPath(path, Paint()..color = hovered ? _closeHoverFill : _closeFill)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.2
          ..color = _closeStroke,
      );
  }

  @override
  bool shouldRepaint(_CloseFramePainter oldDelegate) =>
      oldDelegate.hovered != hovered;
}

/// 아래 안내 줄: 막힌 이유(노랑) 또는 진행 중 문구(회색) + `스캔 탭 열기`.
class _NoteLine extends StatelessWidget {
  const _NoteLine({
    required this.text,
    required this.warn,
    required this.onOpenScanTab,
  });

  final String text;
  final bool warn;
  final VoidCallback? onOpenScanTab;

  @override
  Widget build(BuildContext context) {
    final onOpenScanTab = this.onOpenScanTab;
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            key: const ValueKey('home-scan-popup-note'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.titleSmall.copyWith(
              color: warn ? _noteWarn : AppColors.textSecondary,
              fontWeight: AppType.regular,
            ),
          ),
        ),
        if (onOpenScanTab != null) ...[
          const SizedBox(width: 14),
          KitPressable(
            key: const ValueKey('home-scan-popup-open-scan'),
            onPressed: onOpenScanTab,
            semanticLabel: '스캔 탭 열기',
            builder: (context, state) => Text(
              '스캔 탭 열기',
              maxLines: 1,
              style: AppType.titleSmall.copyWith(
                color: state.hovered ? AppColors.accentText : AppColors.accent,
                fontWeight: AppType.semiBold,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
