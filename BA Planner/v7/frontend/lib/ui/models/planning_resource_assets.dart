/// UI assets use canonical inventory IDs; no v6 runtime paths are retained.
String? planningResourceIconAsset({required String category, String? itemId}) {
  if (category == 'credits') {
    return 'assets/item_icons/currency/Currency_Icon_Gold.png';
  }
  if (itemId == null || itemId.isEmpty) return null;
  if (category == 'student_eleph') return 'assets/student_elephs/$itemId.png';
  final folder = switch (category) {
    'tech_notes' => 'skill_book',
    'tactical_bd' => 'skill_db',
    'oopart' || 'workbook' => 'ooparts',
    'activity_report' => 'activity_reports',
    'equipment' => 'equipment',
    'present' => 'presents',
    _ => null,
  };
  return folder == null ? null : 'assets/item_icons/$folder/$itemId.png';
}
