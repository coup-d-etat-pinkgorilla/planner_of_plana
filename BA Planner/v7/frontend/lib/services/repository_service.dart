class RepositoryProfile {
  const RepositoryProfile({required this.id, required this.displayName, required this.revision, required this.selected});

  final String id;
  final String displayName;
  final int revision;
  final bool selected;

  factory RepositoryProfile.fromWire(Map<String, dynamic> value) {
    final id = value['profile_id'];
    final name = value['display_name'];
    final revision = value['revision'];
    final selected = value['selected'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty || revision is! int || selected is! bool) {
      throw const FormatException('Invalid repository profile payload');
    }
    return RepositoryProfile(id: id, displayName: name, revision: revision, selected: selected);
  }
}

abstract interface class RepositoryService {
  Future<List<RepositoryProfile>> listProfiles();
  Future<RepositoryProfile> createProfile(String displayName, String idempotencyKey);
  Future<int> selectProfile(String profileId, int expectedRevision, String idempotencyKey);
  Future<int> renameProfile(String profileId, String displayName, int expectedRevision, String idempotencyKey);
  Future<Map<String, dynamic>> loadRepositoryState(String profileId);
  Future<int> saveRepositoryGoals(String profileId, Map<String, dynamic> goals, int expectedRevision, String idempotencyKey);
}
