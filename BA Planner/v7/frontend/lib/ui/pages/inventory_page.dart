import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../widgets/diagonal_section.dart';
import '../widgets/repository_profile_panel.dart';

class InventoryCandidateContext {
  const InventoryCandidateContext({required this.session, required this.candidate});
  final ScannerSession session;
  final ScannerCandidate candidate;
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.service, required this.onOpenPlan,
    required this.onOpenScan, this.candidateContext, this.onCandidateCommitted});
  final AppService service;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenScan;
  final InventoryCandidateContext? candidateContext;
  final ValueChanged<ScannerCandidate>? onCandidateCommitted;

  @override State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();
  final Map<String,TextEditingController> _editors = {};
  final Set<String> _dirtyKeys = {};
  List<InventoryCatalogEntry> _catalog = const [];
  RepositoryProfile? _profile;
  RepositoryState? _repositoryState;
  InventoryShortageResult? _shortages;
  String? _category;
  String _mode = 'all';
  String _sort = 'catalog';
  bool _showShortages = false;
  bool _loading = true;
  bool _saving = false;
  String? _catalogError;
  String? _message;

  RepositoryService? get _repository => widget.service is RepositoryService ? widget.service as RepositoryService : null;
  ScannerService? get _scanner => widget.service is ScannerService ? widget.service as ScannerService : null;

  @override void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _loadCatalog();
  }

  @override void dispose() {
    widget.service.state.removeListener(_connectionChanged);
    _search.dispose();
    for (final editor in _editors.values) { editor.dispose(); }
    super.dispose();
  }

  void _connectionChanged() {
    if (mounted) setState(() {});
    if (widget.service.state.value.connection == BackendConnection.connected && _catalog.isEmpty && !_loading) _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    if (widget.service.state.value.connection != BackendConnection.connected) {
      if (mounted) setState(() { _loading=false; _message='Backend is disconnected.'; });
      return;
    }
    setState(() { _loading=true; _catalogError=null; _message=null; });
    try {
      final catalog = await widget.service.listInventoryItems();
      if (!mounted) return;
      setState(() { _catalog=catalog; _loading=false; });
      _syncEditors();
    } catch (error) {
      if (mounted) setState(() { _loading=false; _catalogError='Could not load inventory catalog: $error'; });
    }
  }

  Future<void> _selectProfile(RepositoryProfile profile) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final state = await repository.loadRepositoryState(profile.id);
      if (!mounted) return;
      setState(() { _profile=profile; _repositoryState=state; _shortages=null; _message=null; });
      _syncEditors();
    } catch (error) { if (mounted) setState(() => _message='Could not load profile: $error'); }
  }

  void _syncEditors() {
    final quantities = <String,String?>{};
    for (final entry in _repositoryState?.inventory.entries ?? const <Map<String,dynamic>>[]) {
      quantities[(entry['item_id'] ?? entry['key']) as String] = entry['quantity'] as String?;
    }
    for (final item in _catalog) {
      _editors.putIfAbsent(item.resourceKey, TextEditingController.new).text = quantities[item.resourceKey] ?? '';
    }
    _dirtyKeys.clear();
  }

  Map<String,dynamic> _inventoryWire() {
    final catalogKeys = _catalog.map((item) => item.resourceKey).toSet();
    final existingByKey = <String,Map<String,dynamic>>{
      for (final entry in _repositoryState?.inventory.entries ?? const <Map<String,dynamic>>[])
        (entry['item_id'] ?? entry['key']) as String:Map<String,dynamic>.from(entry),
    };
    final entries = <Map<String,dynamic>>[
      for (final entry in _repositoryState?.inventory.entries ?? const <Map<String,dynamic>>[])
        if (!catalogKeys.contains(entry['item_id'] ?? entry['key'])) Map<String,dynamic>.from(entry),
    ];
    final canonical = RegExp(r'^(0|[1-9][0-9]*)$');
    for (final item in _catalog) {
      final quantity = _editors[item.resourceKey]?.text.trim() ?? '';
      if (!_dirtyKeys.contains(item.resourceKey)) {
        final existing=existingByKey[item.resourceKey];
        if (existing != null) entries.add(existing);
        continue;
      }
      if (quantity.isEmpty) continue;
      if (!canonical.hasMatch(quantity)) throw FormatException('${item.displayName}: enter 0 or a non-negative integer.');
      entries.add({'key':item.resourceKey,'quantity':quantity,'item_id':item.itemId,
        'name':item.displayName,'index':item.orderIndex,'profile_id':item.profileId});
    }
    return {'version':1,'entries':entries};
  }

  Future<void> _save() async {
    final repository = _repository; final profile = _profile; final state = _repositoryState;
    if (repository == null || profile == null || state == null) {
      setState(() => _message='Select a repository profile first.'); return;
    }
    setState(() { _saving=true; _message=null; });
    try {
      final snapshot = RepositoryInventoryState.fromWire(_inventoryWire());
      final revision = await repository.saveRepositoryInventory(profile.id,snapshot,state.revision,
        'inventory-save-${DateTime.now().microsecondsSinceEpoch}');
      final reloaded = await repository.loadRepositoryState(profile.id);
      if (!mounted) return;
      setState(() { _repositoryState=reloaded; _shortages=null; _message='Saved complete inventory bucket at revision $revision.'; });
      _syncEditors();
    } catch (error) {
      if (mounted) setState(() => _message='Save failed; your draft was kept. Reload before retrying if the revision changed: $error');
    } finally { if (mounted) setState(() => _saving=false); }
  }

  Future<void> _reload() async { final profile=_profile; if (profile != null) await _selectProfile(profile); }

  Future<void> _calculateShortages() async {
    final state = _repositoryState;
    if (state == null) { setState(() => _message='Select a profile to analyze its saved plan.'); return; }
    if (state.goals.isEmpty) { setState(() => _message='This profile has no saved goals. Open Planning to save a plan first.'); return; }
    setState(() { _loading=true; _message=null; });
    try {
      final result = await widget.service.calculateShortages(
        currentStudents:state.students.map(confirmedStudentPlanningCurrent).toList(),
        plan:{'version':1,'goals':state.goals.map((goal) => Map<String,dynamic>.from(goal.values)).toList()},
        inventory:state.inventory.toWire());
      if (mounted) setState(() { _shortages=result; _showShortages=true; _loading=false; });
    } catch (error) { if (mounted) setState(() { _loading=false; _message='Could not calculate shortages: $error'; }); }
  }

  Future<void> _approveCandidate() async {
    final context=widget.candidateContext; final scanner=_scanner; final profile=_profile; final state=_repositoryState;
    if (context == null || scanner == null || profile == null || state == null) return;
    setState(() { _saving=true; _message=null; });
    try {
      final approved = context.candidate.reviewRequired && !context.candidate.approved
          ? await scanner.reviewScannerCandidate(context.session,context.candidate,context.candidate.payload,
              approve:true,reason:'approved_in_inventory_page') : context.candidate;
      await scanner.commitScannerCandidate(context.session,approved,profileId:profile.id,
        expectedRepositoryRevision:state.revision,idempotencyKey:'inventory-candidate-${approved.id}-${approved.revision}');
      await _reload();
      if (mounted) setState(() => _message='Scanner candidate committed.');
      widget.onCandidateCommitted?.call(context.candidate);
    } catch (error) { if (mounted) setState(() => _message='Candidate commit failed; comparison was kept: $error'); }
    finally { if (mounted) setState(() => _saving=false); }
  }

  List<InventoryCatalogEntry> get _visible {
    final query=_search.text;
    final catalogRank={for(var index=0;index<_catalog.length;index++) _catalog[index].resourceKey:index};
    final shortageByKey={for(final row in _shortages?.rows ?? const <InventoryShortageRow>[]) row.resourceKey:row};
    final values=_catalog.where((item) {
      final modeMatches=_mode == 'all' || (_mode == 'equipment' ? item.profileId == 'equipment' : item.profileId != 'equipment');
      return modeMatches && (_category == null || item.category == _category) && item.matches(query);
    }).toList();
    int quantity(InventoryCatalogEntry item) => int.tryParse(_editors[item.resourceKey]?.text ?? '') ?? -1;
    values.sort((a,b) {
      final primary=switch(_sort) {
        'name' => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        'quantity' => quantity(b).compareTo(quantity(a)),
        'shortage' => (shortageByKey[b.resourceKey]?.shortage ?? -1).compareTo(shortageByKey[a.resourceKey]?.shortage ?? -1),
        _ => catalogRank[a.resourceKey]!.compareTo(catalogRank[b.resourceKey]!),
      };
      return primary != 0 ? primary : a.resourceKey.compareTo(b.resourceKey);
    });
    return values;
  }

  @override Widget build(BuildContext context) => ValueListenableBuilder<AppServiceState>(
    valueListenable:widget.service.state,builder:(context,serviceState,_) {
      final connected=serviceState.connection == BackendConnection.connected;
      final categories=_catalog.map((item) => item.category).toSet().toList()..sort();
      final shortages={for(final row in _shortages?.rows ?? const <InventoryShortageRow>[]) row.resourceKey:row};
      return ColoredBox(color:AppColors.canvas.withValues(alpha:.72),child:ListView(
        key:const ValueKey('inventory-page'),padding:const EdgeInsets.fromLTRB(18,20,18,48),children:[
          RepositoryProfilePanel(service:widget.service,onSelected:_selectProfile),const SizedBox(height:12),
          DiagonalSection(child:Padding(padding:const EdgeInsets.fromLTRB(18,16,34,18),child:Wrap(
            spacing:12,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[
              const Text('Inventory',style:TextStyle(fontSize:24,fontWeight:FontWeight.w700)),
              SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Owned items')),ButtonSegment(value:true,label:Text('Plan shortages'))],
                selected:{_showShortages},onSelectionChanged:(value) => setState(() => _showShortages=value.first)),
              FilledButton.icon(onPressed:connected&&!_loading?_calculateShortages:null,icon:const Icon(Icons.analytics_outlined),label:const Text('Analyze saved plan')),
              OutlinedButton.icon(onPressed:widget.onOpenPlan,icon:const Icon(Icons.route_outlined),label:const Text('Open Planning')),
              OutlinedButton.icon(onPressed:widget.onOpenScan,icon:const Icon(Icons.document_scanner_outlined),label:const Text('Open Scan')),
            ]))),const SizedBox(height:12),
          if (widget.candidateContext != null) ...[_CandidatePanel(context:widget.candidateContext!,current:_repositoryState?.inventory,
            busy:_saving,onHold:() => setState(() => _message='Candidate held; repository inventory was not changed.'),onApprove:_approveCandidate),const SizedBox(height:12)],
          Wrap(spacing:10,runSpacing:10,children:[
            SizedBox(width:300,child:TextField(controller:_search,onChanged:(_) => setState(() {}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search name or ID'))),
            SizedBox(width:180,child:DropdownButtonFormField<String>(initialValue:_mode,isExpanded:true,decoration:const InputDecoration(labelText:'Mode'),
              items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'equipment',child:Text('Equipment')),DropdownMenuItem(value:'items',child:Text('Items'))],
              onChanged:(value) => setState(() => _mode=value ?? 'all'))),
            SizedBox(width:220,child:DropdownButtonFormField<String?>(initialValue:_category,isExpanded:true,decoration:const InputDecoration(labelText:'Category'),
              items:[const DropdownMenuItem(value:null,child:Text('All categories')), ...categories.map((value) => DropdownMenuItem(value:value,child:Text(value,overflow:TextOverflow.ellipsis)))],
              onChanged:(value) => setState(() => _category=value))),
            SizedBox(width:210,child:DropdownButtonFormField<String>(initialValue:_sort,isExpanded:true,decoration:const InputDecoration(labelText:'Sort'),
              items:const [DropdownMenuItem(value:'catalog',child:Text('Catalog order')),DropdownMenuItem(value:'name',child:Text('Name')),DropdownMenuItem(value:'quantity',child:Text('Quantity')),DropdownMenuItem(value:'shortage',child:Text('Shortage'))],
              onChanged:(value) => setState(() => _sort=value ?? 'catalog'))),
            FilledButton.icon(onPressed:connected&&!_saving&&_repositoryState!=null?_save:null,icon:const Icon(Icons.save_outlined),label:Text(_saving?'Saving…':'Save inventory')),
            TextButton(onPressed:_profile==null?_loadCatalog:_reload,child:const Text('Reload')),
          ]),const SizedBox(height:12),
          if (_catalogError != null) Padding(padding:const EdgeInsets.only(bottom:10),child:Text(_catalogError!,style:const TextStyle(color:AppColors.warning))),
          if (_message != null) Padding(padding:const EdgeInsets.only(bottom:10),child:Text(_message!,style:const TextStyle(color:AppColors.warning))),
          if (_repositoryState != null && _repositoryState!.inventory.entries.isEmpty)
            const Padding(padding:EdgeInsets.only(bottom:10),child:Text('Inventory snapshot is empty. Catalog-only rows remain Unknown until an explicit quantity is saved.',style:TextStyle(color:AppColors.textMuted))),
          if (!connected) const _InventoryNotice(icon:Icons.cloud_off,title:'Backend disconnected',body:'Reconnect to load catalog, inventory, and shortages.')
          else if (_loading) const Center(child:Padding(padding:EdgeInsets.all(32),child:CircularProgressIndicator()))
          else if (_catalog.isEmpty) const _InventoryNotice(icon:Icons.inventory_2_outlined,title:'Empty catalog',body:'No inventory metadata was returned.')
          else if (_showShortages && _shortages == null) const _InventoryNotice(icon:Icons.analytics_outlined,title:'No shortage result',body:'Analyze the selected profile’s saved plan and inventory.')
          else if (_visible.isEmpty) const _InventoryNotice(icon:Icons.filter_alt_off,title:'No matching items',body:'Change the search or category filter.')
          else for(final item in _visible) Padding(padding:const EdgeInsets.only(bottom:8),child:_InventoryRow(
            item:item,controller:_editors[item.resourceKey]!,shortage:shortages[item.resourceKey],showShortage:_showShortages,enabled:_repositoryState!=null&&!_saving,
            onChanged:() => _dirtyKeys.add(item.resourceKey))),
          if (_shortages?.warnings.isNotEmpty == true) ...[const SizedBox(height:8),Text(_shortages!.warnings.join('\n'),style:const TextStyle(color:AppColors.warning))],
        ]));
    });
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item,required this.controller,required this.shortage,required this.showShortage,required this.enabled,required this.onChanged});
  final InventoryCatalogEntry item; final TextEditingController controller; final InventoryShortageRow? shortage; final bool showShortage; final bool enabled; final VoidCallback onChanged;
  @override Widget build(BuildContext context) => Card(child:Padding(padding:const EdgeInsets.all(12),child:Wrap(
    spacing:14,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
      SizedBox(width:300,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.displayName,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),
        Text(item.resourceKey,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppColors.textMuted,fontSize:12)),
        Text('${item.category} · ${item.profileId} · #${item.orderIndex}',style:const TextStyle(color:AppColors.textMuted,fontSize:12))])),
      SizedBox(width:150,child:TextField(key:ValueKey('inventory-quantity-${item.resourceKey}'),controller:controller,enabled:enabled,
        keyboardType:TextInputType.number,onChanged:(_) => onChanged(),decoration:const InputDecoration(labelText:'Owned',hintText:'Unknown'))),
      if (showShortage) ...[
        _Metric(label:'Required',value:shortage?.requiredAmount.toString() ?? '—'),
        _Metric(label:'Owned',value:shortage?.owned?.toString() ?? 'Unknown'),
        _Metric(label:'Shortage',value:shortage?.shortage?.toString() ?? 'Unknown'),
        SizedBox(width:220,child:Text(shortage == null ? 'Not required by saved plan' : shortage!.affectedStudentIds.isEmpty ? 'No affected students' : 'Students: ${shortage!.affectedStudentIds.join(', ')}',maxLines:2,overflow:TextOverflow.ellipsis)),
      ],
    ])));
}

class _Metric extends StatelessWidget { const _Metric({required this.label,required this.value}); final String label,value;
  @override Widget build(BuildContext context) => SizedBox(width:92,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppColors.textMuted,fontSize:12)),Text(value,style:const TextStyle(fontWeight:FontWeight.w700))])); }

class _InventoryNotice extends StatelessWidget { const _InventoryNotice({required this.icon,required this.title,required this.body}); final IconData icon; final String title,body;
  @override Widget build(BuildContext context) => DiagonalSection(child:Padding(padding:const EdgeInsets.fromLTRB(18,22,34,22),child:Row(children:[Icon(icon,size:34),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),Text(body,style:const TextStyle(color:AppColors.textMuted))]))]))); }

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({required this.context,required this.current,required this.busy,required this.onHold,required this.onApprove});
  final InventoryCandidateContext context; final RepositoryInventoryState? current; final bool busy; final VoidCallback onHold; final VoidCallback onApprove;
  @override Widget build(BuildContext buildContext) {
    final candidateEntries=context.candidate.payload['entries'] as List? ?? const [];
    final currentValues={for(final item in current?.entries ?? const <Map<String,dynamic>>[]) item['item_id'] ?? item['key']:item['quantity']};
    final candidateValues={for(final item in candidateEntries.whereType<Map>()) item['item_id'] ?? item['key']:item['quantity']};
    final currentKeys=currentValues.keys.toSet(); final candidateKeys=candidateValues.keys.toSet();
    final added=candidateKeys.difference(currentKeys).length; final missing=currentKeys.difference(candidateKeys).length;
    final changed=candidateKeys.intersection(currentKeys).where((key) => candidateValues[key] != currentValues[key]).length;
    final unknown=candidateValues.values.where((value) => value == null).length;
    return DiagonalSection(child:Padding(padding:const EdgeInsets.fromLTRB(18,16,34,16),child:Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
      Text('Scanner candidate · added $added / changed $changed / missing $missing / unknown $unknown'),
      if (context.candidate.reviewRequired) const Chip(label:Text('Review required')),
      const Text('Missing rows stay unknown; they are never auto-filled with zero.',style:TextStyle(color:AppColors.textMuted)),
      OutlinedButton(onPressed:busy?null:onHold,child:const Text('Hold')),
      FilledButton(onPressed:busy?null:onApprove,child:const Text('Review & approve')),
    ])));
  }
}
