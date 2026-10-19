// 메타데이터 관리자 도구 창(M2, `--tool=metadata-manager`, metadata-manager-workflow M2 절).
//
// 탭 ① 학생 ② 출처 ③ 자산 ④ 업데이트 ⑤ 배포. ④⑤는 자리만 둔다(M5 · M6).
// - ① 학생: 기존 학생 메타데이터 편집기([MetadataEditorPage], 읽기 · 편집 · 저장 그대로) + 오른쪽 "이 값은 어디서 왔나"
//   패널(`metadata.source.view`). 패널의 출처 · 버전 열은 계약대로 미입증이면 "확인되지 않음"이다(값을 지어내지 않는다).
//   창이 좁으면(1400 미만) 패널은 접힌 채 시작한다(편집기 폭을 지키려고). 오른쪽 띠의 버튼으로 연다.
// - ② 출처: `store.status`(연결 · store_root · lock 고정 버전 · extract · 검증 안 함 · 빠진 kind), `store.versions`,
//   `store.diff(from, to)`(저장소에 이미 있는 보고서만 읽는다. 없음 · 미연결은 "차이 0"이 아니다).
// - ③ 자산: `asset_map.list` · `asset_map.check(scope)` 표, 필터(누락 · 수동 · 이름 변경 · 해시 변경). M1은 로컬 구조만
//   확인하므로 "실물 검증 아님(M4 필요)"을 늘 보인다. 이름 변경 · 해시 변경은 M4 판정이라 지금은 고를 수 없다.
// - mock 모드(서비스 [OfflineMetadataManagerService])면 아무것도 부르지 않고 "저장소 미연결 · 빈 상태"로 그린다.
// UI는 v7 키트(`ui/kit`)만 쓴다. 개발자 도구는 golden 범위 밖이다.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../ui/kit/ba_chip.dart';
import '../ui/kit/buttons.dart';
import '../ui/kit/diagonal_row.dart';
import '../ui/kit/kit_pressable.dart';
import '../ui/kit/skew_controls.dart';
import '../ui/kit/titles.dart';
import 'legacy_tool_pages.dart';
import 'metadata_manager_dto.dart';
import 'metadata_manager_service.dart';
import 'tool_backend_client.dart';

/// 탭.
enum MetadataManagerTab {
  students('학생'),
  sources('출처'),
  assets('자산'),
  updates('업데이트'),
  release('배포');

  const MetadataManagerTab(this.label);

  final String label;
}

/// 패널이 처음부터 펼쳐지는 최소 폭.
const metadataManagerSourcePanelOpenWidth = 1400.0;

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.35,
  color: AppColors.text,
);

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.35,
  color: AppColors.textMuted,
);

const _monoStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.35,
  color: AppColors.textSecondary,
);

/// 해시 앞 12자리(전체는 보고서 · lock에 있다).
String _shortHash(String value) =>
    value.length <= 12 ? value : '${value.substring(0, 12)}…';

/// 오류 문구. 서버 실패는 `type: message`, 계약 불일치 · 그 밖은 그대로.
String _errorText(Object error) => switch (error) {
  MetadataManagerRemoteError(:final type, :final message) => '$type: $message',
  _ => error.toString(),
};

/// 메타데이터 관리자 창 본문.
class MetadataManagerPage extends StatefulWidget {
  const MetadataManagerPage({
    super.key,
    required this.client,
    required this.service,
    this.initialTab = MetadataManagerTab.students,
  });

  /// 기존 20 메서드(① 학생 탭의 편집기).
  final ToolBackend client;

  /// 새 6 메서드.
  final MetadataManagerService service;
  final MetadataManagerTab initialTab;

  @override
  State<MetadataManagerPage> createState() => _MetadataManagerPageState();
}

class _MetadataManagerPageState extends State<MetadataManagerPage> {
  late MetadataManagerTab _tab = widget.initialTab;

  /// 한 번이라도 연 탭(처음 열 때 읽고, 그 뒤에는 상태를 둔다).
  late final Set<MetadataManagerTab> _opened = {widget.initialTab};

  void _select(MetadataManagerTab tab) {
    setState(() {
      _tab = tab;
      _opened.add(tab);
    });
  }

  Widget _tabBody(MetadataManagerTab tab) {
    if (!_opened.contains(tab)) return const SizedBox.shrink();
    return switch (tab) {
      MetadataManagerTab.students => _StudentsTab(
        client: widget.client,
        service: widget.service,
      ),
      MetadataManagerTab.sources => _SourcesTab(service: widget.service),
      MetadataManagerTab.assets => _AssetsTab(service: widget.service),
      MetadataManagerTab.updates => const _PlaceholderTab(
        key: ValueKey('metadata-manager-updates-placeholder'),
        title: '업데이트 관리자',
        message: 'M5에서 채웁니다.',
        detail: '게임 패치 뒤 새 버전 등록 · 추출 · 차이 검토 · lock 갱신을 순서대로 실행하는 점검표가 이 자리에 옵니다.',
      ),
      MetadataManagerTab.release => const _PlaceholderTab(
        key: ValueKey('metadata-manager-release-placeholder'),
        title: '배포 관리자',
        message: 'M6에서 채웁니다.',
        detail: '스냅샷 번들 · 첫 실행 추출 명세 · 릴리스 빌드 · 데이터 변경 기록이 이 자리에 옵니다.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.service.offlineLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SkewSegmented<MetadataManagerTab>(
                    key: const ValueKey('metadata-manager-tabs'),
                    segments: [
                      for (final tab in MetadataManagerTab.values)
                        SkewSegment(
                          value: tab,
                          label: metadataManagerTabLabel(tab),
                        ),
                    ],
                    selected: _tab,
                    onChanged: _select,
                  ),
                ),
              ),
              if (offline != null) ...[
                const SizedBox(width: 10),
                BaChip(
                  key: const ValueKey('metadata-manager-offline'),
                  label: offline,
                  tone: AppTones.warn,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            sizing: StackFit.expand,
            children: [
              for (final tab in MetadataManagerTab.values) _tabBody(tab),
            ],
          ),
        ),
      ],
    );
  }
}

/// 비어 있는 탭 자리(④ · ⑤).
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    super.key,
    required this.title,
    required this.message,
    required this.detail,
  });

  final String title;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TileTitle(title),
          const SizedBox(height: 12),
          Text(message, style: _bodyStyle),
          const SizedBox(height: 6),
          Text(detail, style: _mutedStyle),
        ],
      ),
    ),
  );
}

/// 안내 · 빈 상태 한 덩어리.
class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.chip,
    required this.message,
    this.tone = AppTones.warn,
    this.onRetry,
  });

  final String chip;
  final String message;
  final AppTone tone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaChip(label: chip, tone: tone),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(message, style: _bodyStyle)),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            TonalButton(
              label: '다시 읽기',
              icon: Icons.refresh,
              height: 30,
              fontSize: AppType.bodySmallSize,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// 실패를 화면 안내로: mock · 연결 없음은 빈 상태, 그 밖은 오류.
Widget _failure(
  Object error, {
  required Key key,
  required String emptyChip,
  VoidCallback? onRetry,
}) {
  if (error is MetadataManagerUnavailable) {
    return _Notice(key: key, chip: emptyChip, message: error.message);
  }
  return _Notice(
    key: key,
    chip: error is MetadataManagerProtocolException ? '계약 불일치' : '읽기 실패',
    message: _errorText(error),
    tone: AppTones.danger,
    onRetry: onRetry,
  );
}

/// 읽은 결과 하나(읽는 중 · 결과 · 실패).
@immutable
class _Load<T> {
  const _Load.loading() : value = null, error = null, loading = true;
  const _Load.value(T this.value) : error = null, loading = false;
  const _Load.error(Object this.error) : value = null, loading = false;

  final T? value;
  final Object? error;
  final bool loading;
}

/// 표 한 줄(`.row` 바탕).
class _TableRow extends StatelessWidget {
  const _TableRow({super.key, required this.children, this.height = 38});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: children),
    ),
  );
}

Widget _cell(String text, {int flex = 1, TextStyle style = _bodyStyle}) =>
    Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );

Widget _chipCell(String label, AppTone tone, {int flex = 1}) => Expanded(
  flex: flex,
  child: Align(
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: BaChip(label: label, tone: tone),
    ),
  ),
);

// --- ① 학생 ----------------------------------------------------------------------

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.client, required this.service});

  final ToolBackend client;
  final MetadataManagerService service;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  String? _studentId;

  /// 사용자가 패널을 열거나 닫았으면 그 값, 아니면 폭으로 정한다.
  bool? _panelOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final open =
          _panelOpen ??
          constraints.maxWidth >= metadataManagerSourcePanelOpenWidth;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MetadataEditorPage(
              client: widget.client,
              onSelectedStudentChanged: (id) =>
                  setState(() => _studentId = id),
            ),
          ),
          const VerticalDivider(width: 1),
          if (open)
            SizedBox(
              width: 380,
              child: _SourcePanel(
                key: const ValueKey('metadata-manager-source-panel'),
                service: widget.service,
                studentId: _studentId,
                onClose: () => setState(() => _panelOpen = false),
              ),
            )
          else
            SizedBox(
              width: 40,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Tooltip(
                    message: '이 값은 어디서 왔나',
                    child: KitPressable(
                      key: const ValueKey('metadata-manager-source-open'),
                      semanticLabel: '이 값은 어디서 왔나 열기',
                      onPressed: () => setState(() => _panelOpen = true),
                      builder: (context, state) => const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.manage_search,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// "이 값은 어디서 왔나" 패널: 고른 학생의 필드마다 값 · 출처 · 버전 · 비교.
class _SourcePanel extends StatefulWidget {
  const _SourcePanel({
    super.key,
    required this.service,
    required this.studentId,
    required this.onClose,
  });

  final MetadataManagerService service;
  final String? studentId;
  final VoidCallback onClose;

  @override
  State<_SourcePanel> createState() => _SourcePanelState();
}

class _SourcePanelState extends State<_SourcePanel> {
  _Load<SourceView>? _view;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SourcePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId ||
        !identical(oldWidget.service, widget.service)) {
      _load();
    }
  }

  void _load() {
    final studentId = widget.studentId;
    final generation = ++_generation;
    if (studentId == null) {
      _view = null;
      return;
    }
    _view = const _Load.loading();
    widget.service.sourceView(studentId).then(
      (view) {
        if (!mounted || generation != _generation) return;
        setState(() => _view = _Load.value(view));
      },
      onError: (Object error) {
        if (!mounted || generation != _generation) return;
        setState(() => _view = _Load.error(error));
      },
    );
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final Widget body;
    if (widget.studentId == null || view == null) {
      body = const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '왼쪽 목록에서 저장된 학생을 고르면 필드마다 현재 값과 출처를 보입니다.',
          key: ValueKey('metadata-manager-source-empty'),
          style: _mutedStyle,
        ),
      );
    } else if (view.loading) {
      body = const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    } else if (view.error case final error?) {
      body = _failure(
        error,
        key: const ValueKey('metadata-manager-source-error'),
        emptyChip: '읽지 않음',
        onRetry: _reload,
      );
    } else {
      body = Expanded(child: _sourceTable(view.value!));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TileTitle(
            '이 값은 어디서 왔나',
            trailing: KitPressable(
              key: const ValueKey('metadata-manager-source-close'),
              semanticLabel: '패널 닫기',
              onPressed: widget.onClose,
              builder: (context, state) => const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (widget.studentId case final id?) ...[
            const SizedBox(height: 6),
            Text(id, style: _monoStyle),
          ],
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }

  Widget _sourceTable(SourceView view) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Notice(
        key: const ValueKey('metadata-manager-source-not-verified'),
        chip: '확인되지 않음',
        message:
            '출처 · 버전 · 비교는 아직 입증되지 않았습니다(M3에서 생성 출처를 기록합니다). 아래 값은 지금 쓰는 값입니다.\n${view.note}',
      ),
      if (view.unavailableGroups.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              const Text('아직 없는 묶음', style: _mutedStyle),
              for (final group in view.unavailableGroups)
                BaChip(label: group, tone: AppTones.gray),
            ],
          ),
        ),
      const _TableRow(
        height: 30,
        children: [
          Expanded(flex: 4, child: Text('필드', style: _mutedStyle)),
          Expanded(flex: 4, child: Text('값', style: _mutedStyle)),
          Expanded(flex: 3, child: Text('출처', style: _mutedStyle)),
          Expanded(flex: 3, child: Text('버전', style: _mutedStyle)),
        ],
      ),
      const SizedBox(height: 4),
      Expanded(
        child: view.fields.isEmpty
            ? const Text('필드가 없습니다.', style: _mutedStyle)
            : ListView.builder(
                key: const ValueKey('metadata-manager-source-fields'),
                itemCount: view.fields.length,
                itemExtent: 42,
                itemBuilder: (context, index) {
                  final field = view.fields[index];
                  final value = switch (field.value) {
                    _ when field.valueState == SourceValueState.unknown =>
                      '값 없음',
                    final String text => text,
                    final other => jsonEncode(other),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _TableRow(
                      key: ValueKey('metadata-manager-source-${field.field}'),
                      children: [
                        _cell(field.field, flex: 4, style: _monoStyle),
                        _cell(
                          value,
                          flex: 4,
                          style: field.valueState == SourceValueState.unknown
                              ? _mutedStyle
                              : _bodyStyle,
                        ),
                        // M1 계약: source_state = unknown, provenance = null(버전 없음).
                        _chipCell('확인되지 않음', AppTones.gray, flex: 3),
                        _chipCell('확인되지 않음', AppTones.gray, flex: 3),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

// --- ② 출처 ----------------------------------------------------------------------

class _SourcesTab extends StatefulWidget {
  const _SourcesTab({required this.service});

  final MetadataManagerService service;

  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab> {
  _Load<StoreStatus> _status = const _Load.loading();
  _Load<StoreVersions> _versions = const _Load.loading();
  _Load<StoreDiff>? _diff;
  StoreServer? _server;
  String? _fromId;
  String? _toId;

  /// 늦게 온 앞 요청의 응답이 새 결과를 덮지 않게 한다.
  int _loadGeneration = 0;
  int _diffGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SourcesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      _diff = null;
      _diffGeneration += 1;
      _load();
    }
  }

  void _load() {
    final generation = ++_loadGeneration;
    _status = const _Load.loading();
    _versions = const _Load.loading();
    widget.service.storeStatus().then(
      (value) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _status = _Load.value(value));
      },
      onError: (Object error) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _status = _Load.error(error));
      },
    );
    widget.service.storeVersions().then(
      (value) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _versions = _Load.value(value);
          _pickDefaults(value);
        });
      },
      onError: (Object error) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _versions = _Load.error(error));
      },
    );
  }

  void _reload() => setState(() {
    _diff = null;
    _diffGeneration += 1;
    _load();
  });

  /// 비교 대상을 바꿨다: 읽던 · 읽은 결과를 버린다.
  void _clearDiff() {
    _diff = null;
    _diffGeneration += 1;
  }

  List<StoreVersion> _versionsOf(StoreVersions versions, StoreServer server) =>
      [
        for (final version in versions.versions)
          if (version.server == server) version,
      ];

  /// 기본 비교: 버전이 둘 이상인 첫 서버의 고정 버전(없으면 첫 버전) → 마지막 다른 버전.
  void _pickDefaults(StoreVersions versions) {
    for (final server in StoreServer.values) {
      final list = _versionsOf(versions, server);
      if (list.length < 2) continue;
      final from = list.firstWhere(
        (version) => version.pinned,
        orElse: () => list.first,
      );
      final to = list.lastWhere((version) => version.versionId != from.versionId);
      _server = server;
      _fromId = from.versionId;
      _toId = to.versionId;
      return;
    }
    _server = null;
    _fromId = null;
    _toId = null;
  }

  void _readDiff() {
    final server = _server;
    final fromId = _fromId;
    final toId = _toId;
    if (server == null || fromId == null || toId == null) return;
    final generation = ++_diffGeneration;
    setState(() => _diff = const _Load.loading());
    widget.service
        .storeDiff(
          StoreVersionRef(server: server, versionId: fromId),
          StoreVersionRef(server: server, versionId: toId),
        )
        .then(
          (value) {
            if (!mounted || generation != _diffGeneration) return;
            setState(() => _diff = _Load.value(value));
          },
          onError: (Object error) {
            if (!mounted || generation != _diffGeneration) return;
            setState(() => _diff = _Load.error(error));
          },
        );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('metadata-manager-sources'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      PanelTitle(
        '저장소 상태',
        trailing: TonalButton(
          key: const ValueKey('metadata-manager-sources-reload'),
          label: '다시 읽기',
          icon: Icons.refresh,
          height: 32,
          fontSize: AppType.bodySmallSize,
          onPressed: _reload,
        ),
      ),
      const SizedBox(height: 10),
      ..._statusSection(),
      const SizedBox(height: 24),
      const PanelTitle('등록된 버전'),
      const SizedBox(height: 10),
      ..._versionsSection(),
      const SizedBox(height: 24),
      const PanelTitle('버전 차이(기존 보고서)'),
      const SizedBox(height: 10),
      ..._diffSection(),
      ],
    ),
  );

  List<Widget> _statusSection() {
    final status = _status;
    if (status.loading) return const [LinearProgressIndicator(minHeight: 2)];
    if (status.error case final error?) {
      return [
        _failure(
          error,
          key: const ValueKey('metadata-manager-status-error'),
          emptyChip: '저장소 미연결',
          onRetry: _reload,
        ),
      ];
    }
    final value = status.value!;
    return [
      if (value.connected)
        const _Notice(
          key: ValueKey('metadata-manager-store-connected'),
          chip: '저장소 연결됨',
          tone: AppTones.ok,
          message: '공용 클라이언트 자료 저장소를 찾았습니다. 해시는 다시 계산하지 않았습니다(not_verified).',
        )
      else
        const _Notice(
          key: ValueKey('metadata-manager-store-disconnected'),
          chip: '저장소 미연결',
          message:
              '저장소 폴더를 찾지 못했습니다. 기존 기능은 그대로 동작합니다. 아래 고정 버전은 ba-data.lock에서 읽은 값입니다.',
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 28,
        runSpacing: 10,
        children: [
          KV(
            label: '저장소 경로',
            value: SelectableText(value.storeRoot, style: _bodyStyle),
          ),
          const KV(
            label: '검증',
            value: Text('해시 다시 계산 안 함 · not_verified', style: _bodyStyle),
          ),
          KV(
            label: '빠진 kind',
            value: value.missingKinds.isEmpty
                ? const Text('없음', style: _bodyStyle)
                : Wrap(
                    spacing: 6,
                    children: [
                      for (final kind in value.missingKinds)
                        BaChip(
                          key: ValueKey('metadata-manager-missing-$kind'),
                          label: kind,
                          tone: AppTones.warn,
                        ),
                    ],
                  ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const SubHeader('lock 고정 버전'),
      const SizedBox(height: 6),
      for (final entry in value.pins.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _TableRow(
            key: ValueKey('metadata-manager-pin-${entry.key.wire}'),
            children: [
              _chipCell(entry.key.wire.toUpperCase(), AppTones.info),
              _cell(entry.value.versionId, flex: 3),
              _cell('클라이언트 ${entry.value.clientVersion ?? '—'}', flex: 2),
              _cell('번들 ${entry.value.bundleRevision ?? '—'}', flex: 2),
              _cell(
                '파일 ${entry.value.files.length}개 · '
                '${entry.value.files.entries.map((file) => '${file.key} ${_shortHash(file.value)}').join(', ')}',
                flex: 5,
                style: _monoStyle,
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      SubHeader('extract ${value.extracts.length}개'),
      const SizedBox(height: 6),
      if (value.extracts.isEmpty)
        const Text('lock에 extract가 없습니다.', style: _mutedStyle)
      else
        for (final (index, extract) in value.extracts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _TableRow(
              key: ValueKey('metadata-manager-extract-$index'),
              children: [
                _chipCell(extract.server.wire.toUpperCase(), AppTones.info),
                _cell(extract.kind, flex: 2),
                _cell(extract.versionId, flex: 2),
                _cell(extract.path, flex: 4, style: _monoStyle),
                _cell(
                  '출처 ${_shortHash(extract.provenanceSha256)} · 파일 ${extract.files.length}개',
                  flex: 3,
                  style: _monoStyle,
                ),
              ],
            ),
          ),
    ];
  }

  List<Widget> _versionsSection() {
    final versions = _versions;
    if (versions.loading) return const [LinearProgressIndicator(minHeight: 2)];
    if (versions.error case final error?) {
      return [
        _failure(
          error,
          key: const ValueKey('metadata-manager-versions-error'),
          emptyChip: '저장소 미연결',
          onRetry: _reload,
        ),
      ];
    }
    final value = versions.value!;
    if (value.state == StoreConnection.disconnected) {
      return const [
        _Notice(
          key: ValueKey('metadata-manager-versions-disconnected'),
          chip: '저장소 미연결',
          message: '저장소에 연결되지 않아 등록된 버전을 읽을 수 없습니다.',
        ),
      ];
    }
    if (value.versions.isEmpty) {
      return const [Text('등록된 버전이 없습니다.', style: _mutedStyle)];
    }
    return [
      for (final version in value.versions)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _TableRow(
            key: ValueKey(
              'metadata-manager-version-${version.server.wire}-${version.versionId}',
            ),
            children: [
              _chipCell(version.server.wire.toUpperCase(), AppTones.info),
              _cell(version.versionId, flex: 3),
              version.pinned
                  ? _chipCell('lock 고정', AppTones.ok)
                  : _cell('', flex: 1),
              _cell('클라이언트 ${version.clientVersion ?? '—'}', flex: 2),
              _cell('번들 ${version.bundleRevision ?? '—'}', flex: 2),
              _cell(
                'manifest ${_shortHash(version.manifestSha256)} · manifest만 확인',
                flex: 4,
                style: _monoStyle,
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _diffSection() {
    final versions = _versions.value;
    final server = _server;
    final fromId = _fromId;
    final toId = _toId;
    final List<StoreVersion> choices = versions == null || server == null
        ? const <StoreVersion>[]
        : _versionsOf(versions, server);
    final servers = <StoreServer>[
      if (versions != null)
        for (final candidate in StoreServer.values)
          if (_versionsOf(versions, candidate).length >= 2) candidate,
    ];
    final ready = server != null && fromId != null && toId != null;
    final diff = _diff;
    return [
      const Text(
        '저장소에 이미 있는 차이 보고서만 읽습니다. 새로 비교하지 않고, 보고서가 없거나 저장소에 연결되지 않은 것을 "차이 0"으로 보지 않습니다.',
        style: _mutedStyle,
      ),
      const SizedBox(height: 10),
      if (servers.isEmpty)
        const Text(
          '같은 서버에 등록된 버전이 둘 이상 있어야 비교할 수 있습니다.',
          key: ValueKey('metadata-manager-diff-unavailable'),
          style: _bodyStyle,
        )
      else ...[
        SkewSegmented<StoreServer>(
          key: const ValueKey('metadata-manager-diff-server'),
          segments: [
            for (final candidate in servers)
              SkewSegment(value: candidate, label: candidate.wire.toUpperCase()),
          ],
          selected: server,
          onChanged: (value) {
            final list = _versionsOf(versions!, value);
            setState(() {
              _server = value;
              _fromId = list.first.versionId;
              _toId = list.last.versionId;
              _clearDiff();
            });
          },
        ),
        const SizedBox(height: 10),
        _versionPicker(
          key: const ValueKey('metadata-manager-diff-from'),
          label: '이전',
          choices: choices,
          selected: fromId,
          onChanged: (id) => setState(() {
            _fromId = id;
            _clearDiff();
          }),
        ),
        const SizedBox(height: 8),
        _versionPicker(
          key: const ValueKey('metadata-manager-diff-to'),
          label: '다음',
          choices: choices,
          selected: toId,
          onChanged: (id) => setState(() {
            _toId = id;
            _clearDiff();
          }),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TonalButton(
            key: const ValueKey('metadata-manager-diff-read'),
            label: '기존 보고서 읽기',
            icon: Icons.difference_outlined,
            variant: TonalButtonVariant.primary,
            onPressed: ready && fromId != toId ? _readDiff : null,
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (diff != null)
        if (diff.loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (diff.error case final error?)
          _failure(
            error,
            key: const ValueKey('metadata-manager-diff-error'),
            emptyChip: '저장소 미연결',
            onRetry: _readDiff,
          )
        else
          _diffResult(diff.value!),
    ];
  }

  Widget _versionPicker({
    required Key key,
    required String label,
    required List<StoreVersion> choices,
    required String? selected,
    required ValueChanged<String> onChanged,
  }) => Row(
    children: [
      SizedBox(width: 48, child: Text(label, style: _mutedStyle)),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SkewSegmented<String>(
            key: key,
            height: 30,
            fontSize: AppType.bodySmallSize,
            segments: [
              for (final version in choices)
                SkewSegment(
                  value: version.versionId,
                  label: version.pinned
                      ? '${version.versionId} · 고정'
                      : version.versionId,
                ),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );

  Widget _diffResult(StoreDiff diff) {
    final report = diff.report;
    final header = switch (diff.state) {
      StoreDiffState.available => const _Notice(
        key: ValueKey('metadata-manager-diff-available'),
        chip: '보고서 있음',
        tone: AppTones.ok,
        message: '저장소의 기존 보고서를 읽었습니다. 보고서 지문만 확인했습니다(report_identity_only).',
      ),
      StoreDiffState.missing => const _Notice(
        key: ValueKey('metadata-manager-diff-missing'),
        chip: '보고서 없음',
        message: '두 버전의 기존 보고서가 저장소에 없습니다. 차이 0이 아닙니다(아직 비교하지 않았습니다).',
      ),
      StoreDiffState.disconnected => const _Notice(
        key: ValueKey('metadata-manager-diff-disconnected'),
        chip: '저장소 미연결',
        message: '저장소에 연결되지 않아 보고서를 읽을 수 없습니다. 차이 0이 아닙니다.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Text('${diff.from} → ${diff.to}', style: _monoStyle),
        const SizedBox(height: 4),
        Text('범위: ${diff.coverage}', style: _mutedStyle),
        if (report != null) ...[
          const SizedBox(height: 10),
          Text('생성 ${report.generatedUtc} · ${report.a} → ${report.b}', style: _mutedStyle),
          const SizedBox(height: 10),
          SubHeader('L1 파일 ${report.levelOneFiles.length}개'),
          const SizedBox(height: 6),
          for (final entry in report.levelOneFiles.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _TableRow(
                key: ValueKey('metadata-manager-diff-l1-${entry.key}'),
                children: [
                  _cell(entry.key, flex: 4, style: _monoStyle),
                  _chipCell(
                    entry.value.wire,
                    entry.value == StoreFileChange.same
                        ? AppTones.gray
                        : AppTones.warn,
                    flex: 2,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SubHeader('L2 extract ${report.levelTwoExtracts.length}개'),
          const SizedBox(height: 6),
          for (final kind in report.levelTwoExtracts.entries)
            for (final table in kind.value.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _TableRow(
                  key: ValueKey('metadata-manager-diff-l2-${kind.key}-${table.key}'),
                  children: [
                    _cell(kind.key, flex: 2),
                    _cell(table.key, flex: 3, style: _monoStyle),
                    _cell(jsonEncode(table.value), flex: 6, style: _monoStyle),
                  ],
                ),
              ),
          const SizedBox(height: 10),
          const SubHeader('L3 동작'),
          const SizedBox(height: 6),
          SelectableText(report.levelThreeBehavior, style: _bodyStyle),
        ],
      ],
    );
  }
}

// --- ③ 자산 ----------------------------------------------------------------------

/// 자산 표 필터.
enum _AssetFilter { missing, manual }

class _AssetsTab extends StatefulWidget {
  const _AssetsTab({required this.service});

  final MetadataManagerService service;

  @override
  State<_AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<_AssetsTab> {
  _Load<AssetMapList> _list = const _Load.loading();
  _Load<AssetCheck> _check = const _Load.loading();
  AssetCheckScope _scope = AssetCheckScope.all;
  final Set<_AssetFilter> _filters = {};
  int _listGeneration = 0;
  int _checkGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadList();
    _loadCheck();
  }

  @override
  void didUpdateWidget(_AssetsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      _loadList();
      _loadCheck();
    }
  }

  void _loadList() {
    final generation = ++_listGeneration;
    _list = const _Load.loading();
    widget.service.assetMapList().then(
      (value) {
        if (!mounted || generation != _listGeneration) return;
        setState(() => _list = _Load.value(value));
      },
      onError: (Object error) {
        if (!mounted || generation != _listGeneration) return;
        setState(() => _list = _Load.error(error));
      },
    );
  }

  void _loadCheck() {
    final generation = ++_checkGeneration;
    _check = const _Load.loading();
    widget.service.assetMapCheck(_scope).then(
      (value) {
        if (!mounted || generation != _checkGeneration) return;
        setState(() => _check = _Load.value(value));
      },
      onError: (Object error) {
        if (!mounted || generation != _checkGeneration) return;
        setState(() => _check = _Load.error(error));
      },
    );
  }

  void _reload() => setState(() {
    _loadList();
    _loadCheck();
  });

  static String _identity(AssetRole role, String path) =>
      '${role.name}|${path.toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final list = _list;
    final mapByIdentity = <String, AssetMapEntry>{
      for (final entry in list.value?.assets ?? const <AssetMapEntry>[])
        _identity(entry.role, entry.plannerPath): entry,
    };
    final rows = check.value?.rows ?? const <AssetCheckRow>[];
    final missingCount = rows
        .where((row) => row.localFile == AssetLocalFile.missing)
        .length;
    final manualCount = rows
        .where((row) => row.mapping == AssetMappingSource.manual)
        .length;
    final visible = [
      for (final row in rows)
        if ((!_filters.contains(_AssetFilter.missing) ||
                row.localFile == AssetLocalFile.missing) &&
            (!_filters.contains(_AssetFilter.manual) ||
                row.mapping == AssetMappingSource.manual))
          row,
    ];
    final Widget table;
    if (check.loading) {
      table = const Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(minHeight: 2),
      );
    } else if (check.error case final error?) {
      table = Align(
        alignment: Alignment.topLeft,
        child: _failure(
          error,
          key: const ValueKey('metadata-manager-assets-error'),
          emptyChip: '빈 상태',
          onRetry: _reload,
        ),
      );
    } else if (visible.isEmpty) {
      table = const Align(
        alignment: Alignment.topLeft,
        child: Text(
          '표시할 자산이 없습니다.',
          key: ValueKey('metadata-manager-assets-empty'),
          style: _mutedStyle,
        ),
      );
    } else {
      table = ListView.builder(
        key: const ValueKey('metadata-manager-assets-table'),
        itemCount: visible.length,
        itemExtent: 42,
        itemBuilder: (context, index) {
          final row = visible[index];
          final entry = mapByIdentity[_identity(row.role, row.plannerPath)];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _TableRow(
              key: ValueKey(
                'metadata-manager-asset-${row.role.name}-${row.plannerPath}',
              ),
              children: [
                _cell(row.plannerPath, flex: 5, style: _monoStyle),
                _chipCell(
                  row.role == AssetRole.ui ? 'UI' : '인식',
                  AppTones.info,
                ),
                _chipCell(
                  row.mapping == AssetMappingSource.manual ? '수동' : 'catalog',
                  row.mapping == AssetMappingSource.manual
                      ? AppTones.warn
                      : AppTones.gray,
                ),
                _chipCell(
                  row.localFile == AssetLocalFile.missing ? '로컬 누락' : '로컬 있음',
                  row.localFile == AssetLocalFile.missing
                      ? AppTones.danger
                      : AppTones.ok,
                ),
                _cell(entry?.addressKey ?? '—', flex: 3, style: _monoStyle),
                _cell(entry?.bundle ?? '—', flex: 3, style: _monoStyle),
                _cell(entry?.textureName ?? '—', flex: 2, style: _monoStyle),
                // M1: physical_state = not_verified(실물 검증은 M4).
                _chipCell('실물 확인 안 됨', AppTones.gray, flex: 2),
              ],
            ),
          );
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle(
            '자산 매핑',
            trailing: TonalButton(
              key: const ValueKey('metadata-manager-assets-reload'),
              label: '다시 읽기',
              icon: Icons.refresh,
              height: 32,
              fontSize: AppType.bodySmallSize,
              onPressed: _reload,
            ),
          ),
          const SizedBox(height: 8),
          const _Notice(
            key: ValueKey('metadata-manager-assets-m4-note'),
            chip: '실물 검증 아님(M4 필요)',
            message:
                'M1 검사는 asset-map 구조와 로컬 파일이 있는지만 봅니다(local_structure_only). 주소 키 · 번들 · 텍스처가 지금 게임 파일과 맞는지는 M4 검증기가 확인합니다.',
          ),
          if (list.error case final error?)
            _failure(
              error,
              key: const ValueKey('metadata-manager-asset-list-error'),
              emptyChip: '빈 상태',
              onRetry: _reload,
            )
          else if (list.value case final value?)
            Text(
              'asset-map v1 · M0 초안 · 매핑 ${value.assets.length}개(M0_mapping_draft; physical_not_verified)',
              key: const ValueKey('metadata-manager-asset-list-summary'),
              style: _mutedStyle,
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SkewSegmented<AssetCheckScope>(
                key: const ValueKey('metadata-manager-assets-scope'),
                height: 30,
                fontSize: AppType.bodySmallSize,
                segments: const [
                  SkewSegment(value: AssetCheckScope.all, label: '전체'),
                  SkewSegment(value: AssetCheckScope.ui, label: 'UI'),
                  SkewSegment(
                    value: AssetCheckScope.recognition,
                    label: '인식',
                  ),
                ],
                selected: _scope,
                onChanged: (scope) => setState(() {
                  _scope = scope;
                  _loadCheck();
                }),
              ),
              const SizedBox(width: 8),
              SkewToggleChip(
                key: const ValueKey('metadata-manager-filter-missing'),
                label: '누락',
                count: missingCount,
                selected: _filters.contains(_AssetFilter.missing),
                onChanged: (on) => setState(
                  () => on
                      ? _filters.add(_AssetFilter.missing)
                      : _filters.remove(_AssetFilter.missing),
                ),
              ),
              SkewToggleChip(
                key: const ValueKey('metadata-manager-filter-manual'),
                label: '수동',
                count: manualCount,
                selected: _filters.contains(_AssetFilter.manual),
                onChanged: (on) => setState(
                  () => on
                      ? _filters.add(_AssetFilter.manual)
                      : _filters.remove(_AssetFilter.manual),
                ),
              ),
              // 이름 변경 · 해시 변경은 M4 실물 검증의 판정(bundle-renamed · bundle-hash-changed)이다.
              const Tooltip(
                message: 'M4 실물 검증이 있어야 판정할 수 있습니다.',
                child: SkewToggleChip(
                  key: ValueKey('metadata-manager-filter-renamed'),
                  label: '이름 변경 · M4 필요',
                  selected: false,
                  onChanged: null,
                ),
              ),
              const Tooltip(
                message: 'M4 실물 검증이 있어야 판정할 수 있습니다.',
                child: SkewToggleChip(
                  key: ValueKey('metadata-manager-filter-hash'),
                  label: '해시 변경 · M4 필요',
                  selected: false,
                  onChanged: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${rows.length}개 중 ${visible.length}개 표시 · 로컬 누락 $missingCount · 수동 $manualCount',
            key: const ValueKey('metadata-manager-assets-count'),
            style: _mutedStyle,
          ),
          const SizedBox(height: 8),
          const _TableRow(
            height: 30,
            children: [
              Expanded(flex: 5, child: Text('경로', style: _mutedStyle)),
              Expanded(child: Text('역할', style: _mutedStyle)),
              Expanded(child: Text('매핑', style: _mutedStyle)),
              Expanded(child: Text('로컬 파일', style: _mutedStyle)),
              Expanded(flex: 3, child: Text('주소 키', style: _mutedStyle)),
              Expanded(flex: 3, child: Text('번들', style: _mutedStyle)),
              Expanded(flex: 2, child: Text('텍스처', style: _mutedStyle)),
              Expanded(flex: 2, child: Text('실물', style: _mutedStyle)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: table),
        ],
      ),
    );
  }
}

/// 탭 버튼 글자(① 학생 …). 위젯 테스트도 이 글자로 탭을 찾는다.
String metadataManagerTabLabel(MetadataManagerTab tab) =>
    '${'①②③④⑤'[tab.index]} ${tab.label}';
