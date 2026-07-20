import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AdaptiveSyncPage extends StatefulWidget {
  const AdaptiveSyncPage({super.key});

  @override
  State<AdaptiveSyncPage> createState() => _AdaptiveSyncPageState();
}

class _AdaptiveSyncPageState extends State<AdaptiveSyncPage> {
  bool _isolateCards = true;
  int _rebuildKey = 0;

  static const _images = <String>[
    'students.png',
    'plan.png',
    'inventory.png',
    'scan.png',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('adaptive-sync-scroll'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adaptive-Sync 표시 진단',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  '주기적 애니메이션 없이 실제 PNG hover와 탭 전환 시 깜빡임을 확인합니다.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('카드별 RepaintBoundary'),
                      selected: _isolateCards,
                      onSelected: (value) =>
                          setState(() => _isolateCards = value),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _rebuildKey++),
                      icon: const Icon(Icons.refresh),
                      label: const Text('카드 전체 재생성'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          key: ValueKey(_rebuildKey),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _images.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 170,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: (context, index) {
            final card = _ProbeCard(fileName: _images[index]);
            return _isolateCards ? RepaintBoundary(child: card) : card;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '확인 순서: 카드 사이로 커서를 빠르게 왕복 → 다른 탭과 반복 전환 → 창 크기 변경 → 창 모드와 최대화 상태 비교',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProbeCard extends StatefulWidget {
  const _ProbeCard({required this.fileName});

  final String fileName;

  @override
  State<_ProbeCard> createState() => _ProbeCardState();
}

class _ProbeCardState extends State<_ProbeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/home_menu/${widget.fileName}',
              fit: BoxFit.cover,
            ),
            if (_hovered) const ColoredBox(color: Color(0x24ffffff)),
          ],
        ),
      ),
    );
  }
}
