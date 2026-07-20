import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';

class DevelopmentPanel extends StatelessWidget {
  const DevelopmentPanel({
    super.key,
    required this.service,
    required this.onOpenDiagnostics,
    required this.onClose,
  });

  final AppService service;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final controller = service is MockScenarioController
        ? service as MockScenarioController
        : null;

    return Material(
      color: AppColors.navigation,
      child: ValueListenableBuilder(
        valueListenable: service.state,
        builder: (context, state, _) {
          final largeDataset = state.studentCount > 1000;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '개발 상태 패널',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                ],
              ),
              const Text(
                '실제 스캔 없이 UI 상태를 즉시 재현합니다.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (controller == null)
                const _ProductionNotice()
              else ...[
                _EnumField<BackendConnection>(
                  label: '백엔드 연결',
                  value: state.connection,
                  values: BackendConnection.values,
                  itemLabel: _connectionLabel,
                  onChanged: controller.setConnection,
                ),
                const SizedBox(height: AppSpacing.md),
                _EnumField<ScanPhase>(
                  label: '스캔 상태',
                  value: state.scanPhase,
                  values: ScanPhase.values,
                  itemLabel: _scanLabel,
                  onChanged: controller.setScanPhase,
                ),
                const SizedBox(height: AppSpacing.md),
                _EnumField<ImageLoadState>(
                  label: '이미지 상태',
                  value: state.imageLoadState,
                  values: ImageLoadState.values,
                  itemLabel: _imageLabel,
                  onChanged: controller.setImageLoadState,
                ),
                const SizedBox(height: AppSpacing.md),
                _ScenarioSwitch(
                  label: '데이터 있음',
                  value: state.hasData,
                  onChanged: controller.setHasData,
                ),
                _ScenarioSwitch(
                  label: '학생·인벤토리 큰 수치',
                  value: largeDataset,
                  onChanged: controller.setLargeDataset,
                ),
                _ScenarioSwitch(
                  label: '긴 이름',
                  value: state.useLongNames,
                  onChanged: controller.setLongNames,
                ),
                _ScenarioSwitch(
                  label: '누락 메타데이터',
                  value: state.hasMissingMetadata,
                  onChanged: controller.setMissingMetadata,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _CountSummary(state: state),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonalIcon(
                onPressed: onOpenDiagnostics,
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('Adaptive-Sync 진단 열기'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: service.reconnect,
                icon: const Icon(Icons.link),
                label: const Text('백엔드 재연결'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: service.restartBackend,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Python 백엔드 재시작'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _connectionLabel(BackendConnection value) => switch (value) {
    BackendConnection.connected => '연결됨',
    BackendConnection.disconnected => '연결 안 됨',
    BackendConnection.connecting => '연결 중',
  };

  static String _scanLabel(ScanPhase value) => switch (value) {
    ScanPhase.idle => '대기',
    ScanPhase.scanning => '진행',
    ScanPhase.succeeded => '성공',
    ScanPhase.failed => '실패',
  };

  static String _imageLabel(ImageLoadState value) => switch (value) {
    ImageLoadState.loaded => '로딩 완료',
    ImageLoadState.loading => '로딩 중',
    ImageLoadState.failed => '로딩 실패',
  };
}

class _ProductionNotice extends StatelessWidget {
  const _ProductionNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text(
          '실제 백엔드 서비스가 사용 중입니다. 목업 시나리오 조작은 비활성화됩니다.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _EnumField<T> extends StatelessWidget {
  const _EnumField({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(itemLabel(item))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ScenarioSwitch extends StatelessWidget {
  const _ScenarioSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _CountSummary extends StatelessWidget {
  const _CountSummary({required this.state});

  final AppServiceState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _Count(label: '학생', value: '${state.studentCount}'),
            ),
            const SizedBox(height: 38, child: VerticalDivider()),
            Expanded(
              child: _Count(
                label: '인벤토리',
                value: '${state.inventoryItemCount}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
