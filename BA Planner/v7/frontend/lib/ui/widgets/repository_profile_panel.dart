import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';

class RepositoryProfilePanel extends StatefulWidget {
  const RepositoryProfilePanel({super.key, required this.service, this.onSelected});
  final AppService service;
  final FutureOr<void> Function(RepositoryProfile profile)? onSelected;

  @override
  State<RepositoryProfilePanel> createState() => _RepositoryProfilePanelState();
}

class _RepositoryProfilePanelState extends State<RepositoryProfilePanel> {
  List<RepositoryProfile> _profiles = const [];
  bool _loading = false;
  String? _error;

  RepositoryService? get _repository => widget.service is RepositoryService ? widget.service as RepositoryService : null;
  RepositoryProfile? get _selected {
    for (final profile in _profiles) {
      if (profile.selected) return profile;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repository = _repository;
    if (repository == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profiles = await repository.listProfiles();
      if (mounted) {
        setState(() => _profiles = profiles);
        final selected = _selected;
        if (selected != null) await widget.onSelected?.call(selected);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _ask(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(key: const ValueKey('profile-name-input'), controller: controller, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('확인'))],
    ));
    controller.dispose();
    return value?.isEmpty == true ? null : value;
  }

  String _key(String action) => '$action-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _create() async {
    final name = await _ask('프로필 만들기');
    if (name == null) return;
    try { await _repository!.createProfile(name, _key('create')); await _reload(); }
    catch (error) { if (mounted) setState(() => _error = error.toString()); }
  }

  Future<void> _select(RepositoryProfile profile) async {
    try { await _repository!.selectProfile(profile.id, profile.revision, _key('select')); await _reload(); }
    catch (error) { if (mounted) setState(() => _error = error.toString()); }
  }

  Future<void> _rename() async {
    final profile = _selected;
    if (profile == null) return;
    final name = await _ask('프로필 이름 변경', initial: profile.displayName);
    if (name == null) return;
    try { await _repository!.renameProfile(profile.id, name, profile.revision, _key('rename')); await _reload(); }
    catch (error) { if (mounted) setState(() => _error = error.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    if (_repository == null) return const SizedBox.shrink();
    final selected = _selected;
    return Card(
      key: const ValueKey('repository-profile-panel'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          const Icon(Icons.person_outline), const SizedBox(width: 8),
          Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<RepositoryProfile>(
            value: selected,
            hint: Text(_profiles.isEmpty ? '저장 프로필 없음' : '프로필 선택'),
            isExpanded: true,
            items: _profiles.map((profile) => DropdownMenuItem(value: profile, child: Text('${profile.displayName} · r${profile.revision}'))).toList(),
            onChanged: _loading ? null : (profile) { if (profile != null && !profile.selected) _select(profile); },
          ))),
          if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(key: const ValueKey('profile-create'), tooltip: '프로필 만들기', onPressed: _loading ? null : _create, icon: const Icon(Icons.add)),
          IconButton(key: const ValueKey('profile-rename'), tooltip: '이름 변경', onPressed: selected == null || _loading ? null : _rename, icon: const Icon(Icons.edit_outlined)),
          if (_error != null) Tooltip(message: _error!, child: const Icon(Icons.error_outline, color: Colors.redAccent)),
        ]),
      ),
    );
  }
}
