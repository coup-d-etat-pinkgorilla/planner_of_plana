import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../../services/scanner_service.dart';

typedef InventoryIdentityAssignAction =
    Future<void> Function(
      ScannerUnresolvedSlot slot,
      String identity,
      bool persist,
    );

typedef InventoryIdentitySkipAction =
    Future<void> Function(ScannerUnresolvedSlot slot);

/// C5e-6e review surface for an inventory tile whose detail panel was readable
/// but did not yield a catalog identity.
///
/// This widget deliberately never guesses or mutates a candidate by itself.
/// Its caller owns protocol calls and replaces [slots] after each assignment.
class ScanInventoryIdentityReview extends StatefulWidget {
  const ScanInventoryIdentityReview({
    super.key,
    required this.slots,
    required this.catalog,
    required this.onAssign,
    this.onSkip,
    this.busySlots = const {},
    this.errors = const {},
  });

  final List<ScannerUnresolvedSlot> slots;
  final List<InventoryCatalogEntry> catalog;
  final InventoryIdentityAssignAction onAssign;
  final InventoryIdentitySkipAction? onSkip;
  final Set<int> busySlots;
  final Map<int, String> errors;

  @override
  State<ScanInventoryIdentityReview> createState() =>
      _ScanInventoryIdentityReviewState();
}

class _ScanInventoryIdentityReviewState
    extends State<ScanInventoryIdentityReview> {
  final Map<int, String> _queries = {};
  final Map<int, String> _selected = {};

  @override
  void didUpdateWidget(ScanInventoryIdentityReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final active = widget.slots.map((slot) => slot.slot).toSet();
    _queries.removeWhere((slot, _) => !active.contains(slot));
    _selected.removeWhere((slot, _) => !active.contains(slot));
  }

  List<InventoryCatalogEntry> _results(ScannerUnresolvedSlot slot) {
    final query = _queries[slot.slot] ?? '';
    if (query.trim().isEmpty) return const [];
    return widget.catalog
        .where(
          (entry) =>
              entry.profileId == slot.profile.wireName &&
              entry.itemId != null &&
              entry.matches(query),
        )
        .take(6)
        .toList(growable: false);
  }

  String _label(String identity) =>
      widget.catalog
          .where((entry) => entry.itemId == identity)
          .map((entry) => entry.displayName)
          .firstOrNull ??
      identity;

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('확인이 필요한 새 아이템', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final slot in widget.slots) ...[
          _card(context, slot),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, ScannerUnresolvedSlot slot) {
    final busy = widget.busySlots.contains(slot.slot);
    final selected = _selected[slot.slot];
    final results = _results(slot);
    return Card(
      key: ValueKey('inventory-unresolved-${slot.slot}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 112,
                  height: 92,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Image.memory(
                    slot.cropPng,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('슬롯 ${slot.slot + 1} · ${slot.profile.wireName}'),
                      Text(
                        '${slot.width}×${slot.height}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (slot.candidates.isEmpty)
                        const Text('추천 후보 없음 · 아래에서 검색하세요')
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final candidate in slot.candidates)
                              ChoiceChip(
                                label: Text(
                                  '${_label(candidate.identity)} ${(candidate.score * 100).toStringAsFixed(0)}%',
                                ),
                                selected: selected == candidate.identity,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(
                                        () => _selected[slot.slot] =
                                            candidate.identity,
                                      ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: '카탈로그/팩 검색',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _queries[slot.slot] = value),
            ),
            if (results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    final chosen = selected == entry.itemId;
                    return ListTile(
                      dense: true,
                      selected: chosen,
                      leading: Icon(
                        chosen
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(entry.displayName),
                      subtitle: Text(entry.itemId!),
                      onTap: busy
                          ? null
                          : () => setState(
                              () => _selected[slot.slot] = entry.itemId!,
                            ),
                    );
                  },
                ),
              ),
            if (widget.errors[slot.slot] case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onSkip != null)
                  TextButton(
                    onPressed: busy ? null : () => widget.onSkip!(slot),
                    child: const Text('건너뛰기'),
                  ),
                OutlinedButton(
                  onPressed: busy || selected == null
                      ? null
                      : () => widget.onAssign(slot, selected, false),
                  child: const Text('이번 세션만'),
                ),
                FilledButton(
                  onPressed: busy || selected == null
                      ? null
                      : () => widget.onAssign(slot, selected, true),
                  child: const Text('영구 승인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
