import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/app_service.dart';
import 'asset_image_grid.dart';
import 'bond_rank_portrait.dart';
import 'student_section_layout.dart';

const studentGridWarmupStudentLimit = 64;
const studentGridWarmupBatchSize = 8;

List<StudentCatalogEntry> studentGridWarmupStudents(
  Iterable<StudentCatalogEntry> catalog, {
  int limit = studentGridWarmupStudentLimit,
}) {
  final ordered = catalog.toList(growable: false)
    ..sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
  return ordered.take(limit).toList(growable: false);
}

List<String> studentGridWarmupAssetPaths(
  Iterable<StudentCatalogEntry> catalog, {
  int studentLimit = studentGridWarmupStudentLimit,
}) => <String>{
  'assets/student_bond_backgrounds/square_blue.png',
  'assets/student_bond_backgrounds/square_yellow.png',
  'assets/student_bond_backgrounds/square_purple.png',
  for (final student in studentGridWarmupStudents(catalog, limit: studentLimit))
    'assets/student_portraits/${student.studentId}.png',
}.toList(growable: false);

class StudentGridImageWarmup {
  static final shared = StudentGridImageWarmup();

  final Set<String> _completedAssets = {};
  int _generation = 0;

  @visibleForTesting
  Set<String> get completedAssets => Set.unmodifiable(_completedAssets);

  Future<void> warm(
    BuildContext context,
    Iterable<StudentCatalogEntry> catalog, {
    int studentLimit = studentGridWarmupStudentLimit,
    int batchSize = studentGridWarmupBatchSize,
  }) async {
    assert(batchSize > 0);
    final generation = ++_generation;
    final assets = studentGridWarmupAssetPaths(
      catalog,
      studentLimit: studentLimit,
    ).where((asset) => !_completedAssets.contains(asset)).toList();

    for (var start = 0; start < assets.length; start += batchSize) {
      if (!context.mounted || generation != _generation) return;
      final end = (start + batchSize).clamp(0, assets.length);
      final batch = assets.sublist(start, end);
      await Future.wait([
        for (final asset in batch) _precacheAsset(context, asset),
      ]);
      if (!context.mounted || generation != _generation) return;
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _precacheAsset(BuildContext context, String asset) async {
    var succeeded = true;
    await precacheImage(
      AssetImage(asset),
      context,
      onError: (_, _) => succeeded = false,
    );
    if (succeeded) _completedAssets.add(asset);
  }
}

/// Paints one real grid card at effectively invisible opacity so the first
/// student-tab frame does not also have to initialize its clip, layer, text,
/// outline, and status-badge paint paths.
class StudentGridPaintWarmup extends StatelessWidget {
  const StudentGridPaintWarmup({super.key, required this.student});

  final StudentCatalogEntry student;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Opacity(
        // RenderOpacity quantizes to an 8-bit alpha. One step is the lowest
        // value that still forces a real paint instead of being skipped.
        opacity: 1 / 255,
        child: SizedBox(
          width: 126,
          height: 102,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetImageGrid(
                items: [
                  AssetImageGridItem(
                    asset: bondRankPortraitBackgroundAsset(null),
                    column: 0,
                    row: 0,
                    edgeCropFraction: 0.11,
                    clipPathBuilder: studentGridCardPath,
                  ),
                  AssetImageGridItem(
                    asset: 'assets/student_portraits/${student.studentId}.png',
                    column: 0,
                    row: 0,
                    scale: 0.98,
                    clipRadiusFraction: 0.12,
                    alphaThreshold: 0.04,
                  ),
                ],
              ),
              CustomPaint(
                painter: StudentGridCardOverlayPainter(
                  students: [student],
                  ownedIds: const {},
                  columns: 1,
                  rows: 1,
                  columnGap: 0,
                  rowGap: 0,
                  rowHorizontalOffsets: const [0],
                  contentPadding: EdgeInsets.zero,
                  showAttributes: true,
                  showNames: true,
                  selectedIndex: 0,
                  plannedIds: const {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
