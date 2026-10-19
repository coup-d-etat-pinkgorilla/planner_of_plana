part of 'scan_tab_sections.dart';

// 학생 진행 화면 3섹션(FE8-g2, 시안 Scan-Student-Run, I-scan §3). 섹션 path · 레일은 고르기와 같다.
// - 왼쪽 레일: 고르기와 같고 최근 스캔 첫 행에 지금 실행(`.btn.sel-pink`)을 넣는다. 진행 중에는 창을 바꾸지 않는다(창 행 ·
//   `게임 창 다시 선택`을 끈다 — 예전 스캔 화면도 진행 중에는 창 선택을 껐다).
// - 가운데: 제목 줄(제목 + (i) + 백그라운드 칩 + 일시정지/이어서 + 중지), 큰 진행 수치, 진행 막대, `지금 읽는 학생` · `지금까지`
//   타일, `방금 읽은 학생` 행 6개, 각주(일시정지 사유 · 세션 오류도 이 자리).
// - 오른쪽: `확인 필요`(진행 중에는 셀 수 없어 '—'), `백그라운드 스캔` 3줄, `다른 탭에서 보이는 모습`(머리글 칩 예시), 아래 버튼 2개.
// 값은 FB-10 고정 범위만 쓴다([ScanRunNumbers] · [scanRunVisible] 등, scan_run_logic.dart).

/// 학생 진행 3섹션. [onOpenStudents]가 없으면 `학생 탭으로 이동`을 끈다(셸 연결은 app_shell 몫).
class ScanRunWorkspace extends StatelessWidget {
  const ScanRunWorkspace({super.key, required this.view, this.onOpenStudents});

  final ScanPickView view;
  final VoidCallback? onOpenStudents;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      // 시안 그리기 순서: 가운데 → 왼쪽 → 오른쪽.
      return Stack(
        children: [
          Positioned.fill(
            child: _RunSection(size: size, view: view),
          ),
          Positioned.fill(
            child: _RailSection(size: size, view: view, live: true),
          ),
          Positioned.fill(
            child: _RunDetailSection(
              size: size,
              view: view,
              onOpenStudents: onOpenStudents,
            ),
          ),
        ],
      );
    },
  );
}

/// 레일 최근 스캔 첫 행: 지금 실행(시안 `학생 전체 · 진행 중 / 34 / 128명 / 백그라운드`, `.btn.sel-pink`). 누를 수 없다.
class _LiveRecentRow extends StatelessWidget {
  const _LiveRecentRow({required this.controller});

  final ScanSessionController controller;

  @override
  Widget build(BuildContext context) {
    final row = scanRunRecentRow(controller);
    return _RailRow(
      key: const ValueKey('scan-recent-row-live'),
      height: ScanMetrics.recentHeight,
      variant: RailButtonVariant.selectedPink,
      semanticLabel: '${row.title} · ${row.subtitle} · 백그라운드',
      onPressed: null,
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  key: const ValueKey('scan-recent-row-live-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.bodyPlusSize,
                    weight: AppType.bold,
                    height: 1.2,
                  ),
                ),
                Text(
                  row.subtitle,
                  key: const ValueKey('scan-recent-row-live-count'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(AppType.captionPlusSize, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const BaChip(label: '백그라운드'),
        ],
      ),
    );
  }
}

// --- 가운데 진행 ------------------------------------------------------------------

class _RunSection extends StatelessWidget {
  const _RunSection({required this.size, required this.view});

  final Size size;
  final ScanPickView view;

  @override
  Widget build(BuildContext context) {
    final controller = view.controller;
    final points = _polygon(size, scanPickSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final scale = ScanMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[0], points[3], y);
    double rightEdge(double y) => _edgeX(points[1], points[2], y);

    /// 줄 하나(왼쪽은 줄 아래 높이의 사선에서, 오른쪽은 줄 위 높이의 사선에서 [gap]).
    Rect band(double offset, double height, double gap) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + gap;
      return Rect.fromLTRB(left, y, math.max(left, rightEdge(y) - gap), y + h);
    }

    Widget scaled(Rect rect, Widget child, {Key? key}) => Positioned.fromRect(
      key: key,
      rect: rect,
      child: SectionScaledBox(scale: scale, child: child),
    );

    final numbers = ScanRunNumbers(
      current: controller.progressCurrent,
      total: controller.progressTotal,
    );
    final session = controller.session;
    final remaining = numbers.remaining(
      startedAt: session == null
          ? null
          : controller.recentDetail(session)?.startedAt,
      now: controller.now(),
    );
    final observed = controller.observedStudentIds;
    final titleLeft = points[0].dx + ScanMetrics.titleLeftInset;
    final titleRight = points[1].dx - ScanMetrics.titleRightInset;
    final children = <Widget>[
      Positioned(
        left: titleLeft,
        top: top + ScanMetrics.titleTop * scale,
        width: math.max(0.0, titleRight - titleLeft),
        height: ScanMetrics.titleHeight * scale,
        child: SectionScaledBox(
          scale: scale,
          child: _RunTitleRow(controller: controller),
        ),
      ),
      scaled(
        band(
          ScanMetrics.runNumbersTop,
          ScanMetrics.runNumbersHeight,
          ScanMetrics.runNumbersEdgeGap,
        ),
        _RunNumbers(numbers: numbers, remaining: remaining),
      ),
      scaled(
        band(
          ScanMetrics.runBarTop,
          ScanMetrics.runBarHeight,
          ScanMetrics.runBarEdgeGap,
        ),
        Center(
          child: SkewBar(
            key: const ValueKey('scan-run-bar'),
            fraction: numbers.fraction,
            color: AppColors.accent,
            height: ScanMetrics.runBarTrackHeight,
            style: const SkewBarStyle(
              trackColor: Color.fromRGBO(255, 255, 255, 0.08),
            ),
          ),
        ),
      ),
      ..._tiles(
        band(
          ScanMetrics.runTileTop,
          ScanMetrics.runTileHeight,
          ScanMetrics.bandEdgeGap,
        ),
        scale,
        numbers,
      ),
      scaled(
        band(
          ScanMetrics.runRecentHeaderTop,
          ScanMetrics.labelHeight,
          ScanMetrics.labelEdgeGap,
        ),
        _RunRecentHeader(caption: scanRunRecentCaption(observed.length)),
      ),
      if (observed.isEmpty)
        scaled(
          band(
            ScanMetrics.runRecentTop,
            ScanMetrics.runRecentHeight,
            ScanMetrics.bandEdgeGap,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '아직 읽은 학생이 없습니다.',
                key: const ValueKey('scan-run-recent-empty'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.bodySize, color: _muted),
              ),
            ),
          ),
        ),
      for (final (index, studentId) in observed.take(scanRunRecentRows).indexed)
        scaled(
          band(
            ScanMetrics.runRecentTop + ScanMetrics.runRecentPitch * index,
            ScanMetrics.runRecentHeight,
            ScanMetrics.bandEdgeGap,
          ),
          _RunStudentRow(
            studentId: studentId,
            name: scanStudentName(studentId, controller.studentCatalog),
          ),
          key: ValueKey('scan-run-recent-$studentId'),
        ),
      scaled(
        band(
          ScanMetrics.runNoteTop,
          ScanMetrics.runNoteHeight,
          ScanMetrics.labelEdgeGap,
        ),
        _RunNote(controller: controller),
      ),
    ];
    return SectionFrame(
      section: scanSection(scanPickSectionId),
      surfaceKey: const ValueKey('scan-run-surface'),
      children: children,
    );
  }

  /// `지금 읽는 학생` · `지금까지` 타일: 폭 비율 669.6 : 826.9, 평행사변형 변 사이 [ScanMetrics.studentTileGap].
  List<Widget> _tiles(Rect band, double scale, ScanRunNumbers numbers) {
    final controller = view.controller;
    final cut = diagonalCutDepth(band.height);
    final gap = ScanMetrics.studentTileGap * scale;
    final total = band.width + cut - gap;
    final liveWidth =
        total *
        ScanMetrics.runLiveTileWidth /
        (ScanMetrics.runLiveTileWidth + ScanMetrics.runSoFarTileWidth);
    final liveId = controller.liveFeedbackStudentId;
    return [
      Positioned(
        key: const ValueKey('scan-run-live-tile'),
        left: band.left,
        top: band.top,
        width: liveWidth,
        height: band.height,
        child: SectionScaledBox(
          scale: scale,
          child: _RunTile(
            child: _LiveStudent(
              studentId: liveId,
              name: liveId == null
                  ? '—'
                  : scanStudentName(liveId, controller.studentCatalog),
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        key: const ValueKey('scan-run-so-far-tile'),
        rect: Rect.fromLTRB(
          band.left + liveWidth - cut + gap,
          band.top,
          band.right,
          band.bottom,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: _RunTile(child: _SoFar(current: numbers.current)),
        ),
      ),
    ];
  }
}

/// 제목 줄: 제목 + (i) · 백그라운드 칩(일시정지면 wn `일시정지`) · 일시정지/이어서(FD-142, fb10a) · 중지.
class _RunTitleRow extends StatelessWidget {
  const _RunTitleRow({required this.controller});

  final ScanSessionController controller;

  @override
  Widget build(BuildContext context) {
    final running = controller.stage == ScanSessionStage.running;
    final control = controller.control;
    final paused = running && control == ScannerControlState.paused;
    final VoidCallback? onPause = !running || controller.controlBusy
        ? null
        : switch (control) {
            ScannerControlState.paused => () => unawaited(controller.resume()),
            ScannerControlState.running => () => unawaited(controller.pause()),
            _ => null,
          };
    return Row(
      children: [
        Expanded(
          child: _HelpTitle(
            title: scanRunTitle(scanRunMode(controller)),
            fontSize: AppType.headlineSize,
            width: 340,
            help:
                '게임 창을 뒤에 둔 채로 읽습니다. 다른 탭으로 옮기거나 플래너에서 다른 작업을 해도 스캔은 '
                '계속됩니다.',
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: BaChip(
              key: const ValueKey('scan-run-mode-chip'),
              label: paused ? '일시정지' : '백그라운드 · 플래너를 계속 쓸 수 있습니다',
              tone: paused ? AppTones.warn : AppTones.info,
              leading: const Icon(Icons.layers_outlined),
            ),
          ),
        ),
        const SizedBox(width: 10),
        TonalButton(
          key: ValueKey(paused ? 'scan-run-resume' : 'scan-run-pause'),
          label: scanRunPauseLabel(controller),
          icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          height: 34,
          onPressed: onPause,
        ),
        const SizedBox(width: 8),
        TonalButton(
          key: const ValueKey('scan-run-cancel'),
          label: controller.stage == ScanSessionStage.cancelling
              ? '중지하는 중…'
              : '중지',
          icon: Icons.stop_rounded,
          variant: TonalButtonVariant.danger,
          height: 34,
          onPressed: running ? () => unawaited(controller.cancel()) : null,
        ),
      ],
    );
  }
}

/// 큰 진행 수치: `34` `/ 128명` · `27%` · `남은 시간 약 6분`. total을 모르면 뒤 셋을 그리지 않는다.
class _RunNumbers extends StatelessWidget {
  const _RunNumbers({required this.numbers, required this.remaining});

  final ScanRunNumbers numbers;
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final totalText = numbers.totalText;
    final percentText = numbers.percentText;
    final remaining = this.remaining;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          numbers.currentText,
          key: const ValueKey('scan-run-current'),
          maxLines: 1,
          style: kitDisplayStyle(
            60,
            color: AppColors.text,
          ).copyWith(height: 1, fontWeight: AppType.bold),
        ),
        if (totalText != null) ...[
          const SizedBox(width: 10),
          Text(
            totalText,
            key: const ValueKey('scan-run-total'),
            maxLines: 1,
            style: _body(AppType.titleLargeSize, color: _muted),
          ),
        ],
        const Spacer(),
        if (percentText != null)
          Text(
            percentText,
            key: const ValueKey('scan-run-percent'),
            maxLines: 1,
            style: _body(AppType.bodyLargeSize, weight: AppType.bold),
          ),
        if (remaining != null) ...[
          const SizedBox(width: 10),
          Text(
            scanRemainingText(remaining),
            key: const ValueKey('scan-run-remaining'),
            maxLines: 1,
            style: _body(AppType.popoverBodySize, color: _muted),
          ),
        ],
      ],
    );
  }
}

/// 진행 화면 타일(`.tile` 평행사변형): 안쪽은 사선 깊이 + 10.
class _RunTile extends StatelessWidget {
  const _RunTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(ScanMetrics.runTileHeight) + 10;
    return DiagonalRow(
      variant: DiagonalRowVariant.tile,
      padding: EdgeInsets.fromLTRB(inset, 16, inset, 16),
      child: child,
    );
  }
}

/// `지금 읽는 학생`: 마지막 feedback 학생(관측값). 성장 5값은 identify `values = {}`라 '—'(FB-10 고정 범위 밖).
class _LiveStudent extends StatelessWidget {
  const _LiveStudent({required this.studentId, required this.name});

  final String? studentId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final studentId = this.studentId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SubHeader('지금 읽는 학생', fontSize: AppType.microSize),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StudentCards(
              studentIds: [?studentId],
              cards: 1,
              cardSize: const Size(136, 110),
              overlap: 0,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key: const ValueKey('scan-run-live-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kitDisplayStyle(AppType.panelTitleSize),
                  ),
                  const SizedBox(height: 6),
                  for (final field in scanRunLiveFields)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 62,
                            child: Text(
                              field,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _body(AppType.bodyPlusSize, color: _muted),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '—',
                              key: ValueKey('scan-run-live-$field'),
                              maxLines: 1,
                              style: _body(
                                AppType.bodyPlusSize,
                                weight: AppType.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `지금까지 · 34명`(FB-10 `progress.current`) + KPI 4칸('—', FD-156) + 확정값 안내.
class _SoFar extends StatelessWidget {
  const _SoFar({required this.current});

  final int? current;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SubHeader(
            current == null ? '지금까지 · —' : '지금까지 · $current명',
            key: const ValueKey('scan-run-so-far'),
            fontSize: AppType.microSize,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (index, label) in scanRunKpiLabels.indexed) ...[
              if (index > 0) const SizedBox(width: 14),
              Expanded(
                child: KpiTile(
                  key: ValueKey('scan-run-kpi-$label'),
                  label: label,
                  value: '—',
                  valueColor: _muted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '확정값은 아직 바뀌지 않았습니다. 끝나면 결과 검토에서 적용합니다.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.bodySmallSize, color: _muted),
        ),
      ],
    );
  }
}

/// `방금 읽은 학생` 머리: 분홍 사선 막대 + 제목(dsp 16) + `최근 순 · n명 중 k명`, 아래 룰.
class _RunRecentHeader extends StatelessWidget {
  const _RunRecentHeader({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const TitleBar(width: 6, height: 18),
          const SizedBox(width: 8),
          Text(
            '방금 읽은 학생',
            maxLines: 1,
            style: kitDisplayStyle(AppType.titleSize),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              caption,
              key: const ValueKey('scan-run-recent-caption'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      const TitleRule(),
    ],
  );
}

/// `방금 읽은 학생` 행(`.row` h62): 카드 · 이름 · 차이. 차이 · 분류 칩은 진행 중 후보가 있어야 알 수 있어 '—' · 숨김(FD-156).
class _RunStudentRow extends StatelessWidget {
  const _RunStudentRow({required this.studentId, required this.name});

  final String studentId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(ScanMetrics.runRecentHeight) + 10;
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Row(
        children: [
          _StudentCards(
            studentIds: [studentId],
            cards: 1,
            cardSize: const Size(57, 46),
            overlap: 0,
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 120,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.titleSmallSize, weight: AppType.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '—',
              maxLines: 1,
              style: _body(AppType.bodySize, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 각주: 평소엔 시안 문구, 일시정지면 사유(wn), 세션 오류면 오류(dg) + `진행 다시 읽기`(스냅숏 복구 — 예전 스캔 화면의
/// Recover snapshot과 같은 동작).
class _RunNote extends StatelessWidget {
  const _RunNote({required this.controller});

  final ScanSessionController controller;

  @override
  Widget build(BuildContext context) {
    final error = controller.sessionError;
    final paused = controller.pausedLabel;
    final (text, color) = error != null
        ? (error, AppColors.danger)
        : paused != null
        ? (paused, AppTones.warn.foreground)
        : (
            '다른 탭으로 옮겨도 계속됩니다. 진행은 맨 위 머리글에도 표시되고, 끝나면 알림으로 결과 검토를 엽니다.',
            _muted,
          );
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: error != null ? AppColors.danger : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            key: const ValueKey('scan-run-note'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(AppType.popoverBodySize, color: color, height: 1.2),
          ),
        ),
        if (error != null && controller.session != null) ...[
          const SizedBox(width: 10),
          TonalButton(
            key: const ValueKey('scan-run-recover'),
            label: controller.recovering ? '읽는 중…' : '진행 다시 읽기',
            height: 28,
            horizontalPadding: 12,
            fontSize: AppType.bodySmallSize,
            onPressed: controller.recovering
                ? null
                : () => unawaited(controller.recoverSnapshot()),
          ),
        ],
      ],
    );
  }
}

// --- 오른쪽 안내 ------------------------------------------------------------------

class _RunDetailSection extends StatelessWidget {
  const _RunDetailSection({
    required this.size,
    required this.view,
    required this.onOpenStudents,
  });

  final Size size;
  final ScanPickView view;
  final VoidCallback? onOpenStudents;

  @override
  Widget build(BuildContext context) {
    final controller = view.controller;
    final points = _polygon(size, scanDetailSectionId);
    final top = points[0].dy;
    final bottom = points[1].dy;
    final right = points[0].dx;
    final scale = ScanMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[3], points[2], y);
    Rect block(double offset, double height, double inset) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h / 2) + inset;
      return Rect.fromLTRB(left, y, math.max(left, right - inset), y + h);
    }

    /// 사선 행 · 버튼(왼쪽은 줄 아래 높이의 사선에서 24, 오른쪽 22). [y]는 화면 좌표.
    Rect edgeRow(double y, double height) {
      final h = height * scale;
      final left = leftEdge(y + h) + ScanMetrics.detailButtonEdgeGap;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, right - ScanMetrics.detailButtonRight),
        y + h,
      );
    }

    Widget placed(Rect rect, Widget child, {Key? key}) => Positioned.fromRect(
      key: key,
      rect: rect,
      child: SectionScaledBox(
        scale: scale,
        child: _MinBox(minWidth: 200, child: child),
      ),
    );

    const title = ScanMetrics.detailTitleInset;
    const content = ScanMetrics.detailContentInset;
    final (targetChip, targetTone) = scanRunTargetChip(controller);
    final background = [
      ('게임 창', targetChip, targetTone),
      ('플래너', '자유롭게 사용', AppTones.ok),
      ('최소화', '하면 일시정지', AppTones.warn),
    ];
    final current = controller.progressCurrent;
    final children = <Widget>[
      placed(
        block(
          ScanMetrics.detailHeaderTop,
          ScanMetrics.detailHeaderHeight,
          title,
        ),
        const _DetailHeader(title: '확인 필요', chip: '—', tone: AppTones.warn),
        key: const ValueKey('scan-run-review-header'),
      ),
      placed(
        block(
          ScanMetrics.detailSummaryTop,
          ScanMetrics.runReviewNoteHeight,
          content,
        ),
        Text(
          '스캔이 끝난 뒤 결과 검토에서 고칩니다. 지금은 미리 볼 수만 있습니다.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.popoverBodySize, color: _muted, height: 1.35),
        ),
      ),
      placed(
        block(
          ScanMetrics.runBackgroundTitleTop,
          ScanMetrics.detailBlockTitleHeight,
          title,
        ),
        const _BlockTitle('백그라운드 스캔'),
      ),
      for (final (index, (label, chip, tone)) in background.indexed)
        Positioned.fromRect(
          key: ValueKey('scan-run-background-$index'),
          rect: edgeRow(
            top +
                (ScanMetrics.runBackgroundTop +
                        ScanMetrics.runBackgroundPitch * index) *
                    scale,
            ScanMetrics.runBackgroundHeight,
          ),
          child: SectionScaledBox(
            scale: scale,
            child: _MinBox(
              minWidth: 200,
              child: DiagonalRow(
                variant: DiagonalRowVariant.plain,
                padding: EdgeInsets.only(
                  left: diagonalCutDepth(ScanMetrics.runBackgroundHeight) + 12,
                  right: 14,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(AppType.bodySize, color: _muted),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: BaChip(label: chip, tone: tone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      placed(
        block(
          ScanMetrics.runOtherTabTitleTop,
          ScanMetrics.detailBlockTitleHeight,
          title,
        ),
        const _BlockTitle('다른 탭에서 보이는 모습'),
      ),
      placed(
        block(
          ScanMetrics.runOtherTabTop,
          ScanMetrics.runOtherTabHeight,
          content,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderChipSample(status: ScanHeaderStatus.of(controller)),
            const SizedBox(height: 8),
            Text(
              '머리글 오른쪽의 연결 표시 자리에 나옵니다. 누르면 이 화면으로 옵니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
          ],
        ),
        key: const ValueKey('scan-run-other-tab'),
      ),
      Positioned.fromRect(
        rect: edgeRow(
          bottom - ScanMetrics.runStudentsButtonFromBottom * scale,
          ScanMetrics.detailButtonHeight,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: _DetailButton(
            title: '학생 탭으로 이동',
            note: '스캔은 그대로 계속됩니다',
            icon: Icons.person_outline,
            buttonKey: const ValueKey('scan-run-open-students'),
            onPressed: onOpenStudents,
          ),
        ),
      ),
      // 미리 검토는 진행 중 후보(고정 범위 밖)와 새 검토 화면(FE8-g4)이 있어야 열 수 있어 끈다.
      Positioned.fromRect(
        rect: edgeRow(
          bottom - ScanMetrics.detailButtonFromBottom * scale,
          ScanMetrics.detailButtonHeight,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: _DetailButton(
            title: '지금까지 읽은 ${current ?? '—'}명 미리 검토',
            note: '적용은 스캔이 끝난 뒤',
            icon: Icons.visibility_outlined,
            variant: RailButtonVariant.primary,
            buttonKey: const ValueKey('scan-run-preview'),
            onPressed: null,
          ),
        ),
      ),
    ];
    return SectionFrame(
      section: scanSection(scanDetailSectionId),
      surfaceKey: const ValueKey('scan-run-detail-surface'),
      children: children,
    );
  }
}

/// `다른 탭에서 보이는 모습` 칩 예시: 머리글 진행 칩과 같은 모양 · 값이지만 누를 수 없고 머리글 칩의 key를 쓰지 않는다.
class _HeaderChipSample extends StatelessWidget {
  const _HeaderChipSample({required this.status});

  final ScanHeaderStatus status;

  @override
  Widget build(BuildContext context) {
    final paused = status.activity == ScanHeaderActivity.paused;
    final base = paused ? AppColors.warning : AppColors.accent;
    final foreground = paused ? AppTones.warn.foreground : AppColors.accentText;
    final fraction = status.fraction;
    return Semantics(
      label: status.chipLabel,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('scan-run-chip-sample'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: base.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppSection.scan.icon, size: 14, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  status.chipLabel,
                  key: const ValueKey('scan-run-chip-sample-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppType.bodySmall.copyWith(
                    color: foreground,
                    fontWeight: AppType.semiBold,
                  ),
                ),
              ),
              if (fraction != null) ...[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    width: 60,
                    height: 5,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: ColoredBox(color: base),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
