// 인벤토리 분석 S2 오파츠 확장의 선택 오파츠 상세 열(FE6-d, 시안 Inventory-Analysis-Opa `SelectedOopartPanel`, E 보고서 §4.2).
//
// 확장 섹션 오른쪽(오른쪽 변에서 504, 위 115.8, 폭 474)에 묶음 다섯을 14 간격으로 쌓는다:
// - 머리: 아이콘 64×52 · "선택한 오파츠" / 이름(22px) · 산점도 핵심 병목이면 "핵심 병목" 칩.
// - "티어별 보유 / 필요 (계획 요구량)": 카탈로그 티어마다 한 행(티어 점 · skew 막대 · `보유 n / 필요 n` · 충분 / −n).
//   계획 밖 티어는 `필요 0` · 빈 막대 · `—`, 보유 모름은 빗금 막대 · `보유 —` · `—`(FD-033 모름 ≠ 0).
// - "사용 학생": 초상 5명 + `…+n`. 누르거나 올리면 학생별 부족 티어 필요량 플라이아웃(FD-101, 시안 `T4 12 · T3 8`).
// - "병목 순위 · 가장 부족한 티어 기준": 오파츠마다 가장 부족한 티어 하나, 부족량 큰 순 5행. 핵심 병목은 분홍 글자, 고른
//   오파츠는 굵게. 행을 누르면 그 오파츠를 고른다.
// - "계획에서 쓰는 단계 보기": 계획 탭으로 이동만 한다(재화 · 단계 포커스 인계는 후속).
part of 'inventory_workspace.dart';

/// 상세 열 캡션(`.cap` 12px 600 #9eb0c2).
const _opaCaption = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.25,
  fontWeight: AppType.semiBold,
  color: AppColors.textMuted,
);

/// 티어별 보유 / 필요 막대(시안 10px, r3, rgba(255,255,255,.07), skewX(−10°)).
const _opaBarStyle = SkewBarStyle(
  trackColor: Color.fromRGBO(255, 255, 255, 0.07),
  radius: 3,
);

/// 사용 학생 플라이아웃(시안 `.fly` 아래로, 오른쪽 맞춤 right −20, 폭 340, 꼬리 오른쪽 34).
const _opaStudentsFlyout = FlyoutPreset(
  placement: KitOverlayPlacement.below(
    align: KitOverlayAlign.end,
    gap: 12,
    outset: 20,
    tailInset: 34,
  ),
  width: 340,
);

/// 사용 학생 플라이아웃 최대 줄 수(넘으면 `… 외 n명`).
const _opaStudentRows = 8;

extension _InventoryOpaSections on _InventoryAnalysisSections {
  /// 확장 S2의 상세 열. [reveal]은 등장 진행(0 → 1: 투명 → 불투명, 오른쪽 24px에서 제자리).
  Widget _oopartDetail(_SectionQuad quad, double reveal) {
    final top = quad.top + InventoryOpaMetrics.detailTop;
    final left = quad.rightAt(top) - InventoryOpaMetrics.detailRight;
    final panel = _SelectedOopartPanel(
      key: const ValueKey('inventory-oopart-detail'),
      detail: controller.selectedOopartDetail,
      ranking: controller.oopartRanking,
      selectedFamily: controller.selectedOopartFamily,
      studentName: controller.studentName,
      onSelect: controller.selectOopart,
      onOpenPlan: onOpenPlan,
    );
    return Positioned(
      left: left,
      top: top,
      width: InventoryOpaMetrics.detailWidth,
      height: math.max(0.0, quad.bottom - 12 - top),
      child: Transform.translate(
        offset: Offset(24 * (1 - reveal), 0),
        child: _Fit(
          minWidth: InventoryOpaMetrics.detailWidth,
          minHeight: 640,
          child: Align(
            alignment: Alignment.topLeft,
            child: reveal >= 1 ? panel : Opacity(opacity: reveal, child: panel),
          ),
        ),
      ),
    );
  }
}

/// 선택 오파츠 상세 열.
class _SelectedOopartPanel extends StatelessWidget {
  const _SelectedOopartPanel({
    super.key,
    required this.detail,
    required this.ranking,
    required this.selectedFamily,
    required this.studentName,
    required this.onSelect,
    required this.onOpenPlan,
  });

  final InventoryOopartDetail? detail;
  final List<InventoryOopartRank> ranking;
  final String? selectedFamily;
  final String Function(String) studentName;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    if (detail == null) {
      return const SizedBox(
        width: InventoryOpaMetrics.detailWidth,
        height: 120,
        child: _AnalysisNotice(
          key: ValueKey('inventory-oopart-detail-empty'),
          text: '고를 오파츠가 없습니다.',
        ),
      );
    }
    const gap = SizedBox(height: InventoryOpaMetrics.detailGap);
    return SizedBox(
      width: InventoryOpaMetrics.detailWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(detail),
          gap,
          _OpaBox(
            key: const ValueKey('inventory-oopart-detail-tiers'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '티어별 보유 / 필요 (계획 요구량)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _opaCaption,
                ),
                const SizedBox(height: InventoryOpaMetrics.boxCaptionGap),
                for (final (index, view) in detail.tiers.indexed) ...[
                  if (index > 0)
                    const SizedBox(height: InventoryOpaMetrics.tierRowGap),
                  _OopartTierRow(
                    key: ValueKey('inventory-oopart-detail-tier-${view.item.tier}'),
                    view: view,
                  ),
                ],
              ],
            ),
          ),
          gap,
          _students(detail),
          gap,
          _ranks(),
          gap,
          Row(
            children: [
              TonalButton(
                key: const ValueKey('inventory-oopart-open-plan'),
                label: '계획에서 쓰는 단계 보기',
                variant: TonalButtonVariant.primary,
                height: InventoryOpaMetrics.actionHeight,
                horizontalPadding: 14,
                fontSize: AppType.bodySmallSize,
                leading: CustomPaint(
                  size: const Size.square(15),
                  painter: _AnalysisGlyphPainter(
                    _AnalysisGlyph.layers,
                    color: TonalButtonColors.of(
                      TonalButtonVariant.primary,
                    ).foreground,
                  ),
                ),
                onPressed: onOpenPlan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(InventoryOopartDetail detail) => Row(
    key: const ValueKey('inventory-oopart-detail-header'),
    children: [
      _OopartTile(
        view: detail.icon,
        size: const Size(
          InventoryOpaMetrics.headerIconWidth,
          InventoryOpaMetrics.headerIconHeight,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('선택한 오파츠', maxLines: 1, style: _opaCaption),
            const SizedBox(height: 4),
            Text(
              detail.label,
              key: const ValueKey('inventory-oopart-detail-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kitDisplayStyle(22),
            ),
          ],
        ),
      ),
      if (detail.bottleneck) ...[
        const SizedBox(width: 12),
        BaChip(
          key: const ValueKey('inventory-oopart-detail-bottleneck'),
          label: '핵심 병목',
          tone: AppTones.pink,
        ),
      ],
    ],
  );

  Widget _students(InventoryOopartDetail detail) {
    final students = detail.students;
    final ids = [for (final student in students) student.studentId];
    final tiers = detail.studentTiers.take(2).toList();
    final strip = PortraitStrip(studentIds: ids);
    return _OpaBox(
      key: const ValueKey('inventory-oopart-detail-students'),
      child: Row(
        children: [
          const SizedBox(
            width: InventoryOpaMetrics.studentCaptionWidth,
            child: Text('사용 학생', maxLines: 1, style: _opaCaption),
          ),
          const SizedBox(width: 12 + InventoryOpaMetrics.studentStripLeft),
          SizedBox(
            width: InventoryOpaMetrics.studentStripWidth,
            height: 28,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ids.isEmpty
                  ? const Text('—', style: _muted)
                  : AnchoredFlyout(
                      key: const ValueKey('inventory-oopart-students-flyout'),
                      semanticLabel: '${detail.label} 사용 학생 ${ids.length}명 보기',
                      panelLabel: '${detail.label} 사용 학생',
                      preset: _opaStudentsFlyout,
                      children: [
                        FlyoutHeader(
                          '${detail.label} · 사용 학생 ${ids.length}명',
                          note: '부족한 티어별 필요량',
                        ),
                        for (final student in students.take(_opaStudentRows))
                          _OopartStudentRow(
                            key: ValueKey(
                              'inventory-oopart-student-${student.studentId}',
                            ),
                            student: student,
                            name: studentName(student.studentId),
                            tiers: tiers,
                          ),
                        if (students.length > _opaStudentRows)
                          FlyoutFooter(
                            text: '… 외 ${students.length - _opaStudentRows}명',
                          ),
                      ],
                      child: strip,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ranks() => _OpaBox(
    key: const ValueKey('inventory-oopart-detail-ranks'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '병목 순위 · 가장 부족한 티어 기준',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _opaCaption,
        ),
        const SizedBox(height: InventoryOpaMetrics.boxCaptionGap),
        if (ranking.isEmpty)
          const SizedBox(
            height: InventoryOpaMetrics.rankRowHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('모자라는 오파츠가 없습니다.', maxLines: 1, style: _muted),
            ),
          ),
        for (final (index, rank) in ranking.indexed)
          _OopartRankRow(
            key: ValueKey('inventory-oopart-rank-$index'),
            index: index,
            rank: rank,
            selected: rank.family == selectedFamily,
            onPressed: () => onSelect(rank.family),
          ),
      ],
    ),
  );
}

/// 상세 열 묶음 상자(rgba(14,21,31,.45), r8, 안쪽 10 · 14).
class _OpaBox extends StatelessWidget {
  const _OpaBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color.fromRGBO(14, 21, 31, 0.45),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: InventoryOpaMetrics.boxPaddingVertical,
        horizontal: InventoryOpaMetrics.boxPaddingHorizontal,
      ),
      child: child,
    ),
  );
}

/// 티어별 보유 / 필요 한 행(높이 40).
class _OopartTierRow extends StatelessWidget {
  const _OopartTierRow({super.key, required this.view});

  final InventoryItemView view;

  @override
  Widget build(BuildContext context) {
    final tier = view.item.tier ?? 0;
    final color = inventoryOopartTierColor(tier);
    final owned = view.owned;
    final required = view.requiredAmount;
    final shortage = view.shortageAmount;
    // 막대: 계획 밖이면 빈 막대(0), 보유 모름이면 빗금(null).
    final fraction = required == null ? 0.0 : view.fulfillment;
    final (status, statusColor) = switch ((required, shortage)) {
      (null, _) || (_, null) => ('—', AppColors.textMuted),
      (_, final short?) when short > 0 => (
        '−${inventoryAmount(short)}',
        AppColors.accent,
      ),
      _ => ('충분', AppColors.success),
    };
    return SizedBox(
      height: InventoryOpaMetrics.tierRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: InventoryOpaMetrics.tierLabelWidth,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'T$tier',
                  maxLines: 1,
                  style: _body.copyWith(
                    fontSize: AppType.bodySize,
                    fontWeight: AppType.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SkewBar(
              fraction: fraction,
              color: color,
              height: 10,
              style: _opaBarStyle,
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: InventoryOpaMetrics.tierValueWidth,
            ),
            child: Text(
              '보유 ${_amountOrDash(owned)} / 필요 ${inventoryAmount(required ?? 0)}',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: _muted.copyWith(
                fontSize: AppType.bodySmallSize,
                fontWeight: AppType.regular,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: InventoryOpaMetrics.tierStatusWidth,
            child: Text(
              status,
              key: ValueKey('inventory-oopart-detail-tier-$tier-status'),
              maxLines: 1,
              textAlign: TextAlign.right,
              style: kitDisplayStyle(16, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사용 학생 플라이아웃 한 줄(초상 38×31 · 이름 · 부족 티어 필요량 두 칸, 시안 `T4 12` · `T3 8`).
class _OopartStudentRow extends StatelessWidget {
  const _OopartStudentRow({
    super.key,
    required this.student,
    required this.name,
    required this.tiers,
  });

  final InventoryOopartStudent student;
  final String name;

  /// 보일 티어(높은 티어 먼저, 최대 둘).
  final List<int> tiers;

  @override
  Widget build(BuildContext context) => FlyoutRow(
    children: [
      PortraitStrip(
        studentIds: [student.studentId],
        maxVisible: 1,
        portraitSize: const Size(38, 31),
      ),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body.copyWith(
            fontSize: AppType.bodySize,
            fontWeight: AppType.bold,
          ),
        ),
      ),
      for (final (index, tier) in tiers.indexed)
        SizedBox(
          width: index == 0 ? null : 40,
          child: Text(
            _needText(tier),
            maxLines: 1,
            textAlign: index == 0 ? TextAlign.left : TextAlign.right,
            style: _muted.copyWith(
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.bold,
              color: inventoryOopartTierColor(tier),
            ),
          ),
        ),
    ],
  );

  /// `T4 12`. 이 학생이 그 티어에서 모자라지 않으면 빈 글자, 단계 부족을 모르면 `—`.
  String _needText(int tier) {
    final amount = student.need(tier);
    if (amount != null) return 'T$tier ${inventoryAmount(amount)}';
    return student.unknown ? '—' : '';
  }
}

/// 병목 순위 한 줄(높이 38: 순위 · 아이콘 35×28 · 이름 · 티어 · 부족).
class _OopartRankRow extends StatelessWidget {
  const _OopartRankRow({
    super.key,
    required this.index,
    required this.rank,
    required this.selected,
    required this.onPressed,
  });

  final int index;
  final InventoryOopartRank rank;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    semanticLabel: '${index + 1}위 ${rank.label} 보기',
    selected: selected,
    builder: (context, state) => SizedBox(
      height: InventoryOpaMetrics.rankRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: InventoryOpaMetrics.rankNumberWidth,
            child: Text(
              '${index + 1}',
              maxLines: 1,
              style: kitDisplayStyle(AppType.bodySize, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          _OopartTile(
            view: rank.view,
            size: const Size(
              InventoryOpaMetrics.rankIconWidth,
              InventoryOpaMetrics.rankIconHeight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rank.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body.copyWith(
                fontSize: AppType.bodySize,
                fontWeight: selected ? AppType.bold : AppType.medium,
                color: rank.bottleneck ? AppColors.accentText : AppColors.text,
                decoration: state.hovered ? TextDecoration.underline : null,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'T${rank.tier}',
            maxLines: 1,
            style: _muted.copyWith(fontSize: AppType.bodySmallSize),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: InventoryOpaMetrics.rankValueWidth,
            child: Text(
              '−${inventoryAmount(rank.shortage)}',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: _body.copyWith(
                fontSize: AppType.bodySize,
                fontWeight: AppType.bold,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 오파츠 아이콘 타일(시안 `.pt`: 배경판 + 92% 아이콘). 아이콘 그림이 없으면 이름 앞 두 글자다.
class _OopartTile extends StatelessWidget {
  const _OopartTile({required this.view, required this.size});

  final InventoryItemView view;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final fallback = _OopartInitials(view: view, fontSize: AppType.captionSize);
    final asset = planningResourceIconAsset(
      category: view.item.category,
      itemId: view.item.itemId,
    );
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: const ItemIconAssetImage(GameAssets.itemBackgroundBasic),
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) =>
                const ItemIconPlaceholder(),
          ),
          if (asset == null)
            fallback
          else
            Positioned.fromRect(
              rect: ItemIconTile.iconRectFor(size),
              child: Image(
                image: ItemIconAssetImage(asset),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
        ],
      ),
    );
  }
}
