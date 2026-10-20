// 아이템 아이콘 `.pt`와 아이템 타일 (FE2-d, H §2.2·§6.6).
//
// `.pt`: 배경(아이템 배경 그림)을 상자 전체에 깔고, 아이콘을 92% 크기 contain으로 올린다(CSS margin 4%는
// 상자 폭 기준이라 위쪽도 폭의 4%다). 크기 변형은 42×34 / 47×38 / 52×42 / 74×60이고, 플라이아웃처럼
// 다른 크기도 받는다.
// 그림 파일이 없으면(배포본은 첫 실행 때 사용자 설치본에서 추출) 배경 자리에 빈 상자를 그리고 예외를 내지 않는다.
// 아이콘 그림만 없으면 배경만 그린다. 그림은 공용 출처([GameImage], F5a)에서 읽고, 읽는 도중 타일이 트리에서
// 빠져도(목록 다시 그리기·정렬) 오류를 조용히 받는다([GameArtAssetImage]).
// 아이템 타일(W-Data "아이템 타일 + 충족 막대"): 74×74 칸에 `.pt` 74×60, 오른쪽 아래 수량(`.dsp` 13 흰색 +
// 그림자), 밑 막대 64.9×4(왼쪽 1.5, 위 64, r1, 기울임, 충족 상태 색 · 계획 무관이면 없음),
// 선택 = 2px 핑크 링 + 14px 글로우(r6).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'game_assets.dart';
import 'game_image.dart';
import 'kit_overlay.dart';
import 'skew_bar.dart';
import 'titles.dart';

/// `.pt` 크기 변형.
abstract final class ItemIconSizes {
  static const s42 = Size(42, 34);
  static const s47 = Size(47, 38);
  static const s52 = Size(52, 42);
  static const s74 = Size(74, 60);
}

/// 그림이 없을 때의 빈 상자 색.
const itemIconPlaceholderColor = AppColors.indicatorSurface;

/// 그림 대신 쓰는 이름 글자 색(시안 `#3d4d5c`).
const itemIconLabelColor = Color(0xff3d4d5c);

/// 아이템 아이콘(`.pt`).
///
/// [iconAsset]이 없으면 배경만 그린다. [label]은 아이콘 그림이 없는 견본의 이름 글자(시안 "기술\n노트")다.
class ItemIconTile extends StatelessWidget {
  const ItemIconTile({
    super.key,
    this.iconAsset,
    this.background = ItemBackground.basic,
    this.backgroundAsset,
    this.size = ItemIconSizes.s42,
    this.label,
    this.semanticLabel,
  });

  final String? iconAsset;
  final ItemBackground background;

  /// [background] 대신 쓸 배경 그림 경로.
  final String? backgroundAsset;
  final Size size;
  final String? label;
  final String? semanticLabel;

  /// 아이콘 상자(CSS `width:92%; height:92%; margin:4%`, margin은 폭 기준).
  static Rect iconRectFor(Size size) => Rect.fromLTWH(
    size.width * 0.04,
    size.width * 0.04,
    size.width * 0.92,
    size.height * 0.92,
  );

  @override
  Widget build(BuildContext context) {
    final iconAsset = this.iconAsset;
    final label = this.label;
    final iconRect = iconRectFor(size);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameImage(
              backgroundAsset ?? background.asset,
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) => const ItemIconPlaceholder(),
            ),
            if (label != null)
              Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: kitDisplayStyle(
                    size.width < 60 ? 8 : 10,
                    color: itemIconLabelColor,
                  ).copyWith(height: 1.15),
                ),
              ),
            if (iconAsset != null)
              Positioned.fromRect(
                rect: iconRect,
                child: GameImage(
                  iconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 그림이 없을 때의 빈 상자(r4).
class ItemIconPlaceholder extends StatelessWidget {
  const ItemIconPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    key: ValueKey('item-icon-placeholder'),
    decoration: BoxDecoration(
      color: itemIconPlaceholderColor,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
  );
}

/// 아이템 타일 수량 글자(`.dsp` 13 흰색 + 그림자 `0 1px 2px #000, 0 0 3px #000`).
final itemTileQuantityStyle = kitDisplayStyle(13, color: Colors.white).copyWith(
  shadows: const [
    Shadow(offset: Offset(0, 1), blurRadius: 2),
    Shadow(blurRadius: 3),
  ],
);

/// 아이템 타일(74×74): `.pt` 74×60 + 수량 + 충족 막대 + 선택 링.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.quantity,
    this.iconAsset,
    this.background = ItemBackground.basic,
    this.label,
    this.tone,
    this.fraction,
    this.selected = false,
    this.semanticLabel,
  });

  /// 오른쪽 아래 수량 글자.
  final String quantity;
  final String? iconAsset;
  final ItemBackground background;
  final String? label;

  /// 충족 상태. `null`이면 계획 무관이라 막대를 그리지 않는다.
  final CoverageTone? tone;

  /// 보유 / 필요(0~1). 모르면 `null`(빗금).
  final double? fraction;
  final bool selected;
  final String? semanticLabel;

  static const size = Size(74, 74);

  /// 막대 자리(왼쪽 1.5, 위 64, 64.9×4).
  static const barRect = Rect.fromLTWH(1.5, 64, 64.9, 4);

  static final _selectedShadows = [
    const BoxShadow(color: AppColors.accent, spreadRadius: 2),
    BoxShadow(
      color: const Color.fromRGBO(242, 179, 239, 0.45),
      blurRadius: kitCssBlur(14),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    return Semantics(
      label: semanticLabel,
      selected: selected,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  boxShadow: selected ? _selectedShadows : null,
                ),
                child: ItemIconTile(
                  iconAsset: iconAsset,
                  background: background,
                  size: ItemIconSizes.s74,
                  label: label,
                ),
              ),
            ),
            Positioned(
              right: 5,
              top: 41,
              child: Text(quantity, maxLines: 1, style: itemTileQuantityStyle),
            ),
            if (tone != null)
              Positioned.fromRect(
                rect: barRect,
                child: SkewBar.tone(
                  fraction: fraction,
                  tone: tone,
                  height: barRect.height,
                  style: SkewBarStyle.itemTile,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
