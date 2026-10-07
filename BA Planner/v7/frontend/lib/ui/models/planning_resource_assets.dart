import '../kit/game_assets.dart';

/// UI assets use canonical inventory IDs; no v6 runtime paths are retained.
String? planningResourceIconAsset({required String category, String? itemId}) {
  if (category == 'credits') {
    return GameAssets.creditIcon;
  }
  if (itemId == null || itemId.isEmpty) return null;
  if (category == 'student_eleph') return GameAssets.studentEleph(itemId);
  final folder = switch (category) {
    'tech_notes' => 'skill_book',
    'tactical_bd' => 'skill_db',
    'oopart' || 'workbook' => 'ooparts',
    'activity_report' => 'activity_reports',
    'equipment' => 'equipment',
    'present' => 'presents',
    _ => null,
  };
  return folder == null ? null : GameAssets.itemIcon(folder, itemId);
}
