import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../app_section.dart';

class SectionPlaceholderPage extends StatelessWidget {
  const SectionPlaceholderPage({
    super.key,
    required this.section,
    required this.service,
    this.onOpenDiagnostics,
  });

  final AppSection section;
  final AppService service;
  final VoidCallback? onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, _) {
        return ListView(
          key: PageStorageKey('${section.name}-scroll'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SectionIntro(section: section),
            const SizedBox(height: AppSpacing.md),
            if (!state.hasData &&
                section != AppSection.settings &&
                section != AppSection.scan)
              const _EmptyState()
            else
              _ContentSkeleton(section: section, state: state),
            if (section == AppSection.scan) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed:
                      !state.scanAvailable ||
                          state.scanPhase == ScanPhase.scanning
                      ? null
                      : service.startScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    !state.scanAvailable
                        ? '스캐너 미연결'
                        : state.scanPhase == ScanPhase.scanning
                        ? '스캔 진행 중'
                        : '목업 스캔 시작',
                  ),
                ),
              ),
            ],
            if (section == AppSection.settings) ...[
              const SizedBox(height: AppSpacing.md),
              _SettingsActions(
                service: service,
                onOpenDiagnostics: onOpenDiagnostics,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(section.icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${section.description} 화면의 v7 골격입니다.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Chip(label: Text('UI MOCK')),
          ],
        ),
      ),
    );
  }
}

class _ContentSkeleton extends StatelessWidget {
  const _ContentSkeleton({required this.section, required this.state});

  final AppSection section;
  final AppServiceState state;

  @override
  Widget build(BuildContext context) {
    final count = switch (section) {
      AppSection.students => state.studentCount,
      AppSection.inventory => state.inventoryItemCount,
      _ => 3,
    };
    final scanText = switch (state.scanPhase) {
      ScanPhase.idle => '스캔 대기',
      ScanPhase.scanning => '스캔 진행',
      ScanPhase.succeeded => '스캔 성공',
      ScanPhase.failed => '스캔 실패',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section == AppSection.scan ? scanText : '표시 항목 $count개',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < 3; index++) ...[
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.md),
                    Icon(section.icon, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        state.useLongNames
                            ? '${section.label}의 매우 긴 테스트 항목 이름 ${index + 1} — 말줄임과 큰 수치 확인'
                            : '${section.label} 항목 ${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      index == 0 && state.hasMissingMetadata
                          ? '메타데이터 없음'
                          : '${(index + 1) * 1200}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ),
              ),
              if (index != 2) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
              SizedBox(height: AppSpacing.md),
              Text(
                '아직 표시할 데이터가 없습니다',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                '스캔하거나 데이터를 불러오면 여기에 표시됩니다.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsActions extends StatelessWidget {
  const _SettingsActions({
    required this.service,
    required this.onOpenDiagnostics,
  });

  final AppService service;
  final VoidCallback? onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              onPressed: service.reconnect,
              icon: const Icon(Icons.link),
              label: const Text('백엔드 재연결'),
            ),
            FilledButton.tonalIcon(
              onPressed: service.restartBackend,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Python 백엔드 재시작'),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenDiagnostics,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('Adaptive-Sync 진단'),
            ),
          ],
        ),
      ),
    );
  }
}
