// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/tactical_service.dart';
import '../widgets/diagonal_section.dart';

enum TacticalMode { records, jokbo }

class TacticalPage extends StatefulWidget {
  const TacticalPage({super.key, required this.service, this.reloadToken = 0});
  final AppService service;
  final int reloadToken;
  @override
  State<TacticalPage> createState() => _TacticalPageState();
}

class _TacticalPageState extends State<TacticalPage> {
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;
  TacticalService? get _tactical => widget.service is TacticalService
      ? widget.service as TacticalService
      : null;
  RepositoryProfile? _profile;
  RepositoryState? _repositoryState;
  TacticalState? _state;
  List<StudentCatalogEntry> _catalog = const [];
  TacticalMode _mode = TacticalMode.records;
  String _query = '', _kind = 'all', _result = 'all';
  DateTimeRange? _dateRange;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connection);
    _reload();
  }

  @override
  void didUpdateWidget(TacticalPage old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      old.service.state.removeListener(_connection);
      widget.service.state.addListener(_connection);
      _reload();
    } else if (old.reloadToken != widget.reloadToken)
      _reload();
  }

  @override
  void dispose() {
    _generation++;
    widget.service.state.removeListener(_connection);
    super.dispose();
  }

  void _connection() {
    if (!mounted) return;
    if (widget.service.state.value.connection == BackendConnection.connected)
      _reload();
    else
      setState(() {
        _loading = false;
        _error = '백엔드 연결이 끊어졌습니다.';
      });
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = _repository, tactical = _tactical;
      if (repository == null || tactical == null)
        throw StateError('전술 서비스가 제공되지 않습니다.');
      final profiles = await repository.listProfiles();
      RepositoryProfile? selected;
      for (final item in profiles)
        if (item.selected) {
          selected = item;
          break;
        }
      if (selected == null) {
        if (mounted && generation == _generation)
          setState(() {
            _profile = null;
            _state = null;
            _loading = false;
          });
        return;
      }
      final results = await Future.wait<Object>([
        repository.loadRepositoryState(selected.id),
        tactical.loadTacticalState(selected.id),
        widget.service.listStudents(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _profile = selected;
        _repositoryState = results[0] as RepositoryState;
        _state = results[1] as TacticalState;
        _catalog = results[2] as List<StudentCatalogEntry>;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() {
          _loading = false;
          _error = '$error';
        });
    }
  }

  List<TacticalMatch> get _matches {
    final needle = _query.trim().toLowerCase(),
        students = {
          for (final item in _catalog)
            item.studentId: item.displayName.toLowerCase(),
        };
    final items = (_state?.matches ?? const <TacticalMatch>[]).where((item) {
      if (_kind != 'all' && item.kind != _kind ||
          _result != 'all' && item.result != _result) {
        return false;
      }
      if (_dateRange != null) {
        final occurred = item.occurredOn == null
            ? null
            : DateTime.tryParse(item.occurredOn!);
        if (occurred == null ||
            occurred.isBefore(_dateRange!.start) ||
            occurred.isAfter(_dateRange!.end)) {
          return false;
        }
      }
      final ids = [
        ...item.attackDeck.strikers,
        ...item.attackDeck.specials,
        ...item.defenseDeck.strikers,
        ...item.defenseDeck.specials,
      ].whereType<String>();
      final text = [
        item.id,
        item.opponent,
        item.season,
        item.notes,
        item.kind,
        item.result,
        item.occurredOn ?? '',
        ...ids,
        ...ids.map((id) => students[id] ?? ''),
      ].join(' ').toLowerCase();
      return needle.isEmpty || text.contains(needle);
    }).toList();
    items.sort((a, b) {
      final date = (b.occurredOn ?? '').compareTo(a.occurredOn ?? '');
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return items;
  }

  List<StudentCatalogEntry> _candidates(
    String combatClass, {
    required bool own,
  }) {
    final owned = {
      ...?_repositoryState?.students.map((item) => item.studentId),
    };
    return _catalog
        .where(
          (item) =>
              item.combatClass?.toLowerCase() == combatClass &&
              (!own || owned.contains(item.studentId)),
        )
        .toList();
  }

  String _deckLabel(TacticalDeck deck) {
    final labels = {
      for (final item in _catalog) item.studentId: item.displayName,
    };
    String slots(List<String?> values) =>
        values.map((id) => id == null ? '—' : (labels[id] ?? id)).join(' / ');
    return 'STR ${slots(deck.strikers)} · SP ${slots(deck.specials)}';
  }

  Future<void> _editMatch([TacticalMatch? source, bool copy = false]) async {
    final original = copy ? null : source;
    var kind = source?.kind ?? 'attack',
        result = source?.result ?? 'win',
        date = source?.occurredOn,
        season = source?.season ?? '';
    var opponent = source?.opponent ?? '', notes = source?.notes ?? '';
    var attack = source?.attackDeck ?? TacticalDeck.empty(),
        defense = source?.defenseDeck ?? TacticalDeck.empty();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final ownAttack = kind == 'attack';
          return AlertDialog(
            title: Text(
              copy
                  ? '기록으로 복사'
                  : source == null
                  ? '대전 기록 추가'
                  : '대전 기록 수정',
            ),
            content: SizedBox(
              width: 780,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: kind,
                          items: const [
                            DropdownMenuItem(
                              value: 'attack',
                              child: Text('공격 기록'),
                            ),
                            DropdownMenuItem(
                              value: 'defense',
                              child: Text('방어 기록'),
                            ),
                          ],
                          onChanged: (v) => setLocal(() => kind = v!),
                        ),
                        DropdownButton<String>(
                          value: result,
                          items: const [
                            DropdownMenuItem(value: 'win', child: Text('승리')),
                            DropdownMenuItem(value: 'loss', child: Text('패배')),
                          ],
                          onChanged: (v) => setLocal(() => result = v!),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: date == null
                                  ? DateTime.now()
                                  : DateTime.parse(date!),
                            );
                            if (picked != null)
                              setLocal(
                                () => date = picked.toIso8601String().substring(
                                  0,
                                  10,
                                ),
                              );
                          },
                          child: Text(date ?? '날짜 없음'),
                        ),
                        if (date != null)
                          TextButton(
                            onPressed: () => setLocal(() => date = null),
                            child: const Text('날짜 지우기'),
                          ),
                      ],
                    ),
                    TextFormField(
                      initialValue: season,
                      decoration: const InputDecoration(labelText: '시즌'),
                      onChanged: (v) => season = v,
                    ),
                    TextFormField(
                      initialValue: opponent,
                      decoration: const InputDecoration(labelText: '상대 (필수)'),
                      onChanged: (v) => opponent = v,
                    ),
                    const SizedBox(height: 12),
                    _DeckEditor(
                      label: ownAttack ? '내 공격 덱' : '상대 공격 덱',
                      deck: attack,
                      strikers: _candidates('striker', own: ownAttack),
                      specials: _candidates('special', own: ownAttack),
                      onChanged: (v) => attack = v,
                    ),
                    const SizedBox(height: 12),
                    _DeckEditor(
                      label: ownAttack ? '상대 방어 덱' : '내 방어 덱',
                      deck: defense,
                      strikers: _candidates('striker', own: !ownAttack),
                      specials: _candidates('special', own: !ownAttack),
                      onChanged: (v) => defense = v,
                    ),
                    TextFormField(
                      initialValue: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: '메모'),
                      onChanged: (v) => notes = v,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: opponent.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true || _profile == null || _state == null) return;
    final item = TacticalMatch(
      id: original?.id ?? 'match-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      occurredOn: date,
      season: season,
      opponent: opponent,
      result: result,
      attackDeck: attack,
      defenseDeck: defense,
      notes: notes,
    );
    await _mutation(
      (service) => service.saveTacticalMatch(
        _profile!.id,
        item,
        _state!.revision,
        'match-${item.id}-${_state!.revision}',
      ),
    );
  }

  Future<void> _editJokbo([TacticalJokbo? source]) async {
    final original = source;
    var defense = source?.defenseDeck ?? TacticalDeck.empty(),
        attack = source?.attackDeck ?? TacticalDeck.empty(),
        notes = source?.notes ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(source == null ? '족보 추가' : '족보 수정'),
        content: SizedBox(
          width: 780,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DeckEditor(
                  label: '상대 방어 덱',
                  deck: defense,
                  strikers: _candidates('striker', own: false),
                  specials: _candidates('special', own: false),
                  onChanged: (v) => defense = v,
                ),
                const SizedBox(height: 12),
                _DeckEditor(
                  label: '내 공격 덱',
                  deck: attack,
                  strikers: _candidates('striker', own: true),
                  specials: _candidates('special', own: true),
                  onChanged: (v) => attack = v,
                ),
                TextFormField(
                  initialValue: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '메모'),
                  onChanged: (v) => notes = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (saved != true || _profile == null || _state == null) return;
    final item = TacticalJokbo(
      id: original?.id ?? 'jokbo-${DateTime.now().microsecondsSinceEpoch}',
      defenseDeck: defense,
      attackDeck: attack,
      notes: notes,
    );
    await _mutation(
      (service) => service.saveTacticalJokbo(
        _profile!.id,
        item,
        _state!.revision,
        'jokbo-${item.id}-${_state!.revision}',
      ),
    );
  }

  Future<void> _copyJokboToMatch(TacticalJokbo item) => _editMatch(
    TacticalMatch(
      id: item.id,
      kind: 'attack',
      occurredOn: null,
      season: '',
      opponent: '',
      result: 'win',
      attackDeck: item.attackDeck,
      defenseDeck: item.defenseDeck,
      notes: item.notes,
    ),
    true,
  );

  Future<void> _mutation(Future<int> Function(TacticalService) action) async {
    try {
      await action(_tactical!);
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했습니다. 새로고침 후 다시 시도하세요.')),
        );
      }
    }
  }

  Future<void> _deleteMatch(TacticalMatch item) async {
    if (!await _confirm('이 대전 기록을 삭제할까요?') ||
        _profile == null ||
        _state == null)
      return;
    await _mutation(
      (s) => s.deleteTacticalMatch(
        _profile!.id,
        item.id,
        _state!.revision,
        'delete-${item.id}-${_state!.revision}',
      ),
    );
  }

  Future<void> _deleteJokbo(TacticalJokbo item) async {
    if (!await _confirm('이 족보를 삭제할까요?') || _profile == null || _state == null)
      return;
    await _mutation(
      (s) => s.deleteTacticalJokbo(
        _profile!.id,
        item.id,
        _state!.revision,
        'delete-${item.id}-${_state!.revision}',
      ),
    );
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: DiagonalSection(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 36, 10),
            child: Row(
              children: [
                const Icon(Icons.sports_esports_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TACTICAL / PVP',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        '전술 대전',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${_profile?.displayName ?? '프로필 없음'} · ${_profile?.id ?? '-'} · tactical revision ${_state?.revision ?? '-'}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '새로고침',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null)
      return _Message(icon: Icons.person_off_outlined, text: '선택된 프로필이 없습니다.');
    if (_error != null && _state == null)
      return _Message(icon: Icons.cloud_off, text: _error!, action: _reload);
    final labels = {
      for (final item in _catalog)
        item.studentId: item.displayName.toLowerCase(),
    };
    final jokbo = (_state?.jokbo ?? const <TacticalJokbo>[]).where((item) {
      final needle = _query.trim().toLowerCase();
      final ids = [
        ...item.defenseDeck.strikers,
        ...item.defenseDeck.specials,
        ...item.attackDeck.strikers,
        ...item.attackDeck.specials,
      ].whereType<String>();
      final text = [
        item.id,
        item.notes,
        ...ids,
        ...ids.map((id) => labels[id] ?? ''),
      ].join(' ').toLowerCase();
      return needle.isEmpty || text.contains(needle);
    }).toList();
    return Column(
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(onPressed: _reload, child: const Text('다시 시도')),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<TacticalMode>(
                segments: const [
                  ButtonSegment(
                    value: TacticalMode.records,
                    label: Text('대전 기록'),
                  ),
                  ButtonSegment(value: TacticalMode.jokbo, label: Text('족보')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '상대·학생·시즌·메모 검색',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (_mode == TacticalMode.records) ...[
                DropdownButton<String>(
                  value: _kind,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('공격/방어 전체')),
                    DropdownMenuItem(value: 'attack', child: Text('공격')),
                    DropdownMenuItem(value: 'defense', child: Text('방어')),
                  ],
                  onChanged: (v) => setState(() => _kind = v!),
                ),
                DropdownButton<String>(
                  value: _result,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('승패 전체')),
                    DropdownMenuItem(value: 'win', child: Text('승리')),
                    DropdownMenuItem(value: 'loss', child: Text('패배')),
                  ],
                  onChanged: (v) => setState(() => _result = v!),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('tactical-date-filter'),
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDateRange: _dateRange,
                    );
                    if (range != null && mounted) {
                      setState(() => _dateRange = range);
                    }
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _dateRange == null
                        ? '기간 전체'
                        : '${_dateRange!.start.toIso8601String().substring(0, 10)}~${_dateRange!.end.toIso8601String().substring(0, 10)}',
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    tooltip: '기간 초기화',
                    onPressed: () => setState(() => _dateRange = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
              FilledButton.icon(
                onPressed: () =>
                    _mode == TacticalMode.records ? _editMatch() : _editJokbo(),
                icon: const Icon(Icons.add),
                label: Text(_mode == TacticalMode.records ? '대전 기록' : '족보 추가'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mode == TacticalMode.records
              ? (_matches.isEmpty
                    ? const _Message(
                        icon: Icons.sports_esports_outlined,
                        text: '저장된 대전 기록이 없습니다.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _matches.length,
                        itemBuilder: (context, index) {
                          final item = _matches[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                '${item.opponent} · ${item.result == 'win' ? '승리' : '패배'}',
                              ),
                              isThreeLine: true,
                              subtitle: Text(
                                '${item.kind == 'attack' ? '내 공격 / 상대 방어' : '상대 공격 / 내 방어'} · ${item.occurredOn ?? '날짜 없음'} · ${item.season.isEmpty ? '시즌 없음' : item.season}\n'
                                '공격 ${_deckLabel(item.attackDeck)}\n방어 ${_deckLabel(item.defenseDeck)}${item.notes.isEmpty ? '' : ' · ${item.notes}'}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: '수정',
                                    onPressed: () => _editMatch(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '새 기록으로 복사',
                                    onPressed: () => _editMatch(item, true),
                                    icon: const Icon(Icons.copy_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '삭제',
                                    onPressed: () => _deleteMatch(item),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ))
              : (jokbo.isEmpty
                    ? const _Message(
                        icon: Icons.menu_book_outlined,
                        text: '저장된 수동 족보가 없습니다.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: jokbo.length,
                        itemBuilder: (context, index) {
                          final item = jokbo[index];
                          return Card(
                            child: ListTile(
                              title: Text('족보 ${item.id}'),
                              isThreeLine: true,
                              subtitle: Text(
                                '방어 ${_deckLabel(item.defenseDeck)}\n공격 ${_deckLabel(item.attackDeck)}${item.notes.isEmpty ? '' : ' · ${item.notes}'}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: '수정',
                                    onPressed: () => _editJokbo(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '공격 기록으로 복사',
                                    onPressed: () => _copyJokboToMatch(item),
                                    icon: const Icon(Icons.copy_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '삭제',
                                    onPressed: () => _deleteJokbo(item),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
        ),
      ],
    );
  }
}

class _DeckEditor extends StatefulWidget {
  const _DeckEditor({
    required this.label,
    required this.deck,
    required this.strikers,
    required this.specials,
    required this.onChanged,
  });
  final String label;
  final TacticalDeck deck;
  final List<StudentCatalogEntry> strikers, specials;
  final ValueChanged<TacticalDeck> onChanged;
  @override
  State<_DeckEditor> createState() => _DeckEditorState();
}

class _DeckEditorState extends State<_DeckEditor> {
  late List<String?> strikers, specials;
  @override
  void initState() {
    super.initState();
    strikers = [...widget.deck.strikers];
    specials = [...widget.deck.specials];
  }

  void change(bool striker, int index, String? value) {
    setState(() => (striker ? strikers : specials)[index] = value);
    widget.onChanged(TacticalDeck(strikers: strikers, specials: specials));
  }

  Widget slot(bool striker, int index) {
    final values = striker ? widget.strikers : widget.specials,
        current = (striker ? strikers : specials)[index];
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String?>(
        initialValue: current,
        decoration: InputDecoration(
          labelText: '${striker ? 'Striker' : 'Special'} ${index + 1}',
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('비어 있음')),
          ...values
              .where(
                (item) =>
                    item.studentId == current ||
                    ![...strikers, ...specials].contains(item.studentId),
              )
              .map(
                (item) => DropdownMenuItem<String?>(
                  value: item.studentId,
                  child: Text(
                    item.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
        onChanged: (v) => change(striker, index, v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: widget.label),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 4; i++) slot(true, i),
        for (var i = 0; i < 2; i++) slot(false, i),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48),
        const SizedBox(height: 12),
        Text(text),
        if (action != null)
          TextButton(onPressed: action, child: const Text('다시 시도')),
      ],
    ),
  );
}
