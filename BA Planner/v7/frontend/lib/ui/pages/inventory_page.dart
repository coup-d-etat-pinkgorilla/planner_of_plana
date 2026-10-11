// 인벤토리 탭(FE6-a, 시안 Inventory "부족한 것" 보기). 로드·편집·저장·부족 계산·후보 승인은
// [InventoryController](`ui/inventory/inventory_controller.dart`)가, 4섹션 화면은 [InventoryWorkspace]가 맡는다.
// 후보 승인 패널(`_CandidatePanel`)은 스캔 탭 아이템 검토(FE8-g5)로 옮길 때까지 그대로 두고 위험도 목록 위 띠에 둔다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../inventory/inventory_controller.dart';
import '../inventory/inventory_workspace.dart';
import '../widgets/diagonal_section.dart';

export '../inventory/inventory_controller.dart' show InventoryCandidateContext;

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.service,
    required this.onOpenPlan,
    required this.onOpenScan,
    this.candidateContext,
    this.onCandidateCommitted,
    this.controller,
  });
  final AppService service;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenScan;
  final InventoryCandidateContext? candidateContext;
  final ValueChanged<ScannerCandidate>? onCandidateCommitted;

  /// 없으면 화면이 직접 만든다(테스트·golden이 상태를 미리 정할 때 넘긴다). 넘긴 컨트롤러는 부른 쪽이 정리한다.
  final InventoryController? controller;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  InventoryController? _ownController;

  InventoryController get _controller =>
      widget.controller ??
      (_ownController ??= InventoryController(widget.service));

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    // 첫 로드는 build 밖에서 시작한다(넘겨받은 컨트롤러에 이미 듣는 위젯이 있어도 build 중 알림이 생기지 않게).
    Future<void>.microtask(() {
      if (mounted) _controller.load();
    });
  }

  @override
  void dispose() {
    widget.service.state.removeListener(_connectionChanged);
    _ownController?.dispose();
    super.dispose();
  }

  void _connectionChanged() {
    final controller = _controller;
    final connected =
        widget.service.state.value.connection == BackendConnection.connected;
    if (connected && !controller.loading && controller.disconnected) {
      controller.load();
    } else if (!connected && !controller.disconnected) {
      controller.load();
    }
  }

  Future<void> _approveCandidate() async {
    final context = widget.candidateContext;
    if (context == null) return;
    final committed = await _controller.approveCandidate(context);
    if (committed && mounted) {
      widget.onCandidateCommitted?.call(context.candidate);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final controller = _controller;
      final candidate = widget.candidateContext;
      return InventoryWorkspace(
        controller: controller,
        onOpenPlan: widget.onOpenPlan,
        onOpenScan: widget.onOpenScan,
        candidatePanel: candidate == null
            ? null
            : _CandidatePanel(
                key: const ValueKey('inventory-candidate-panel'),
                context: candidate,
                current: controller.repositoryState?.inventory,
                busy: controller.saving,
                onHold: controller.holdCandidate,
                onApprove: _approveCandidate,
              ),
      );
    },
  );
}

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({
    super.key,
    required this.context,
    required this.current,
    required this.busy,
    required this.onHold,
    required this.onApprove,
  });
  final InventoryCandidateContext context;
  final RepositoryInventoryState? current;
  final bool busy;
  final VoidCallback onHold;
  final VoidCallback onApprove;
  @override
  Widget build(BuildContext buildContext) {
    final candidateEntries =
        context.candidate.payload['entries'] as List? ?? const [];
    final currentValues = {
      for (final item in current?.entries ?? const <Map<String, dynamic>>[])
        item['item_id'] ?? item['key']: item['quantity'],
    };
    final candidateValues = {
      for (final item in candidateEntries.whereType<Map>())
        item['item_id'] ?? item['key']: item['quantity'],
    };
    final currentKeys = currentValues.keys.toSet();
    final candidateKeys = candidateValues.keys.toSet();
    final added = candidateKeys.difference(currentKeys).length;
    final missing = currentKeys.difference(candidateKeys).length;
    final changed = candidateKeys
        .intersection(currentKeys)
        .where((key) => candidateValues[key] != currentValues[key])
        .length;
    final unknown = candidateValues.values
        .where((value) => value == null)
        .length;
    return DiagonalSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 34, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Scanner candidate · added $added / changed $changed / missing $missing / unknown $unknown',
            ),
            if (context.candidate.reviewRequired)
              const Chip(label: Text('Review required')),
            const Text(
              'Missing rows stay unknown; they are never auto-filled with zero.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            OutlinedButton(
              onPressed: busy ? null : onHold,
              child: const Text('Hold'),
            ),
            FilledButton(
              onPressed: busy ? null : onApprove,
              child: const Text('Review & approve'),
            ),
          ],
        ),
      ),
    );
  }
}
