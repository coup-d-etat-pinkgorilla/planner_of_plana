// 스캔 탭 고르기 순수 규칙(FE8-g1, 시안 Scan · Scan-Items, I-scan §2 · §5).
//
// - 화면 전환: 진행(시작 중 · 진행 · 일시정지 · 중지 요청 중)과 검토 대기(끝났고 적용하지 않은 후보)는 지금 `ScanPage`를,
//   그 밖에는 고르기를 보인다. 판단은 머리글 칩 · 탭 점과 같은 [ScanHeaderStatus]다(FE8-f2와 맞물림).
// - 시작 판정: 고르지 않음 · 여러 종류(FE8-g3 큐 전까지 막음, FD-143) · 백엔드 · 서비스 · 게임 창 · 계정 · 인식 준비 · 진행 중.
// - 추정치(FD-154): 시간은 종류별 기본 상수(학생 전체 약 8분 · 1명 약 10초 · 아이템 종류마다 약 1분 — 시안 값), 칸 수는
//   카탈로그에서 그 종류 `profileId`의 개수. 모르면 숨긴다.
// - 시각 글자: 오늘 · 어제는 시각까지(`어제 21:40`), 7일까지 `n일 전`, 그 뒤 `9/12`. 막대 = 지난 날짜 / 14(FD-147).
import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import 'scan_header_progress.dart';
import 'scan_session_controller.dart';

/// 아이템 칸 순서(시안 6칸 + 선물 7번째, FD-151).
const scanPickInventoryOrder = [
  InventoryScanProfile.ooparts,
  InventoryScanProfile.techNotes,
  InventoryScanProfile.tacticalBd,
  InventoryScanProfile.activityReports,
  InventoryScanProfile.studentElephs,
  InventoryScanProfile.equipment,
  InventoryScanProfile.presents,
];

/// 아이템 종류 이름(시안 칸 제목).
String scanInventoryProfileLabel(InventoryScanProfile profile) =>
    switch (profile) {
      InventoryScanProfile.ooparts => '오파츠',
      InventoryScanProfile.techNotes => '기술 노트',
      InventoryScanProfile.tacticalBd => '전술 교육 BD',
      InventoryScanProfile.activityReports => '활동 보고서',
      InventoryScanProfile.studentElephs => '엘레프',
      InventoryScanProfile.equipment => '장비',
      InventoryScanProfile.presents => '선물',
    };

/// 고른 아이템 종류를 칸 순서로.
List<InventoryScanProfile> scanPickOrderedProfiles(ScanPick pick) => [
  for (final profile in scanPickInventoryOrder)
    if (pick.inventoryScanProfiles.contains(profile)) profile,
];

/// 스캔 탭이 보일 화면.
enum ScanTabView { pick, session }

/// 진행 · 일시정지 · 검토 대기면 지금 `ScanPage`(진행 · 검토), 아니면 고르기. [appliedElsewhere]는 다른 탭이 적용한 후보.
ScanTabView scanTabViewFor(
  ScanSessionController controller, {
  Set<String> appliedElsewhere = const {},
}) =>
    ScanHeaderStatus.of(
          controller,
          appliedElsewhere: appliedElsewhere,
        ).activity ==
        ScanHeaderActivity.idle
    ? ScanTabView.pick
    : ScanTabView.session;

/// 시작을 막는 이유. [none]이면 시작할 수 있다.
enum ScanStartBlock {
  none,
  noSelection,
  multipleItems,
  backend,
  unavailable,
  noTarget,
  targetNotReady,
  profile,
  checkingRecognition,
  recognition,
  busy,
}

/// 고르기 · 연결 · 준비로 시작을 판정한다. 앞에 있는 이유가 먼저다(고르기 → 백엔드 → 게임 창 → 계정 → 인식 준비).
ScanStartBlock scanStartBlock(ScanSessionController controller) {
  final pick = controller.pick;
  if (pick.isNone) return ScanStartBlock.noSelection;
  if (pick.inventoryScanProfiles.length > 1) {
    return ScanStartBlock.multipleItems;
  }
  if (!controller.connected) return ScanStartBlock.backend;
  if (!controller.scannerAvailable || !controller.repositoryAvailable) {
    return ScanStartBlock.unavailable;
  }
  final target = controller.selectedTarget;
  if (target == null) return ScanStartBlock.noTarget;
  if (target.status != ScannerTargetStatus.ready) {
    return ScanStartBlock.targetNotReady;
  }
  if (controller.profile == null) return ScanStartBlock.profile;
  if (!controller.recognitionReady) {
    return controller.readinessLoading
        ? ScanStartBlock.checkingRecognition
        : ScanStartBlock.recognition;
  }
  if (!controller.canStart) return ScanStartBlock.busy;
  return ScanStartBlock.none;
}

/// 시작 버튼 옆 `.plain` 글자. 막혔으면 이유, 아니면 시안 설명.
String scanStartNote(ScanStartBlock block, ScanSessionController controller) {
  final pick = controller.pick;
  return switch (block) {
    ScanStartBlock.none =>
      pick.studentScanMode != null
          ? '시작해도 플래너를 그대로 쓸 수 있습니다. 다른 탭으로 옮겨도 스캔은 계속되고, '
                '진행은 맨 위 머리글에도 표시됩니다.'
          : '시작하면 플래너는 뒤로 갑니다. 진행은 게임 창 옆 작은 창에 나오고, '
                '끝나면 플래너가 다시 앞으로 와 결과 검토를 엽니다.',
    ScanStartBlock.noSelection => '학생이나 아이템을 고르면 시작할 수 있습니다.',
    ScanStartBlock.multipleItems =>
      '여러 종류는 차례로 스캔합니다. 차례 스캔은 아직 열리지 않아 지금은 한 종류만 골라 시작할 수 있습니다.',
    ScanStartBlock.backend => '백엔드에 연결되어 있지 않습니다.',
    ScanStartBlock.unavailable => '스캐너를 쓸 수 없습니다.',
    ScanStartBlock.noTarget => '게임 창을 연결하면 시작할 수 있습니다.',
    ScanStartBlock.targetNotReady =>
      switch (controller.selectedTarget?.status) {
        ScannerTargetStatus.minimized => '게임 창이 최소화되어 있습니다. 창을 연 뒤 시작하십시오.',
        ScannerTargetStatus.closed => '게임 창이 닫혔습니다. 게임 창을 다시 선택하십시오.',
        _ => '지원하지 않는 창입니다. 게임 창을 다시 선택하십시오.',
      },
    ScanStartBlock.profile => '계정을 불러오면 시작할 수 있습니다.',
    ScanStartBlock.checkingRecognition => '인식 준비를 확인하고 있습니다.',
    ScanStartBlock.recognition => '인식 준비가 끝나지 않았습니다.',
    ScanStartBlock.busy => '스캔이 진행 중입니다.',
  };
}

/// 주 버튼 두 줄(제목 · 부제).
({String title, String subtitle}) scanStartLabel(ScanPick pick) {
  final mode = pick.studentScanMode;
  final items = pick.inventoryScanProfiles.length;
  if (mode == StudentScanMode.full) {
    return (title: '학생 전체 스캔 시작', subtitle: '백그라운드 · 약 8분');
  }
  if (mode == StudentScanMode.single) {
    return (title: '학생 1명 스캔 시작', subtitle: '백그라운드 · 약 10초');
  }
  if (items > 0) {
    return (
      title: '아이템 $items종 스캔 시작',
      subtitle: '게임 창이 앞으로 나옵니다 · ${scanItemDurationText(items)}',
    );
  }
  return (title: '스캔 시작', subtitle: '종류를 고르십시오');
}

/// 아이템 [kinds]종의 시간 추정(종류마다 약 1분, 시안 2종 = 약 2분).
String scanItemDurationText(int kinds) => '약 $kinds분';

/// 카탈로그에서 고른 종류의 칸 수(`profileId`가 종류의 wire 이름). 카탈로그가 비었으면 null(숨김).
int? scanItemCellCount(
  Iterable<InventoryScanProfile> profiles,
  List<InventoryCatalogEntry> catalog,
) {
  if (catalog.isEmpty) return null;
  final wires = {for (final profile in profiles) profile.wireName};
  return catalog.where((entry) => wires.contains(entry.profileId)).length;
}

/// 종류의 대표 카탈로그 항목(정렬 순서 첫 항목, 칸 그림용). 없으면 null.
InventoryCatalogEntry? scanProfileRepresentative(
  InventoryScanProfile profile,
  List<InventoryCatalogEntry> catalog,
) {
  InventoryCatalogEntry? first;
  for (final entry in catalog) {
    if (entry.profileId != profile.wireName) continue;
    if (first == null || entry.orderIndex < first.orderIndex) first = entry;
  }
  return first;
}

// ---- 시각 ----

/// [at]과 [now]의 지역 달력 날짜 차.
int scanElapsedDays(DateTime at, DateTime now) {
  final a = at.toLocal();
  final b = now.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// `오늘 21:40` · `어제 21:40` · `3일 전`(7일까지) · `9/12`. [clock]이 false면 오늘 · 어제에 시각을 붙이지 않는다.
String scanWhenText(DateTime at, DateTime now, {bool clock = true}) {
  final local = at.toLocal();
  final days = scanElapsedDays(at, now);
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  return switch (days) {
    0 => clock ? '오늘 $time' : '오늘',
    1 => clock ? '어제 $time' : '어제',
    > 1 && <= 7 => '$days일 전',
    _ => '${local.month}/${local.day}',
  };
}

/// 종류 하나의 마지막 스캔(FB-2b `by_kind`). [known]이 false면 읽지 못함('—'), [at]이 null이면 스캔 없음.
class ScanLastScan {
  const ScanLastScan.unknown() : known = false, at = null;
  const ScanLastScan.none() : known = true, at = null;
  const ScanLastScan.at(DateTime this.at) : known = true;

  final bool known;
  final DateTime? at;

  /// 막대 비율(지난 날짜 / 14, 상한 1). 모르거나 없으면 null(빗금).
  double? fraction(DateTime now) {
    final at = this.at;
    if (at == null) return null;
    return (scanElapsedDays(at, now) / 14).clamp(0.0, 1.0).toDouble();
  }

  /// 막대 오른쪽 시각 글자(`어제 21:40` · `9/12` · `없음` · `—`).
  String text(DateTime now) {
    final at = this.at;
    if (!known) return '—';
    if (at == null) return '없음';
    return scanWhenText(at, now);
  }

  /// 칸 아래 `마지막 …` 글자(시각 없이).
  String tileText(DateTime now) {
    final at = this.at;
    if (!known) return '마지막 —';
    if (at == null) return '마지막 없음';
    return '마지막 ${scanWhenText(at, now, clock: false)}';
  }

  /// 칩(`최근` ≤ 7일 · `오래됨` · `스캔 없음` · 모르면 '—').
  (String, AppTone) chip(DateTime now) {
    final at = this.at;
    if (!known) return ('—', AppTones.gray);
    if (at == null) return ('스캔 없음', AppTones.gray);
    return scanElapsedDays(at, now) <= 7
        ? ('최근', AppTones.ok)
        : ('오래됨', AppTones.warn);
  }
}

/// FB-2b `by_kind` 목록에서 종류별 가장 늦은 시각. 학생은 `scan_kind == student`, 아이템은 `inventory` + 종류 wire 이름.
({ScanLastScan student, Map<InventoryScanProfile, ScanLastScan> items})
scanLastScansFrom(Iterable<({String kind, String? profile, String at})> rows) {
  DateTime? student;
  final items = <InventoryScanProfile, DateTime>{};
  DateTime? later(DateTime? a, DateTime b) => a == null || b.isAfter(a) ? b : a;
  for (final row in rows) {
    final at = DateTime.tryParse(row.at);
    if (at == null) continue;
    if (row.kind == 'student') {
      student = later(student, at);
    } else if (row.kind == 'inventory') {
      final profile = InventoryScanProfile.values
          .where((value) => value.wireName == row.profile)
          .firstOrNull;
      if (profile == null) continue;
      items[profile] = later(items[profile], at)!;
    }
  }
  final studentAt = student;
  return (
    student: studentAt == null
        ? const ScanLastScan.none()
        : ScanLastScan.at(studentAt),
    items: {
      for (final profile in scanPickInventoryOrder)
        profile: switch (items[profile]) {
          final DateTime at => ScanLastScan.at(at),
          null => const ScanLastScan.none(),
        },
    },
  );
}

// ---- 최근 스캔 행 ----

/// 최근 스캔 행 제목(`학생 전체 · 128명` · `학생 1명 · 쿠루미` · `아이템 · 기술 노트`).
String scanRecentTitle(
  ScannerRecentSummary item, {
  ScanRecentDetail? detail,
  Map<String, StudentCatalogEntry> studentCatalog = const {},
}) {
  switch (item.kind) {
    case ScannerKind.student:
      if (item.session.studentScanMode == StudentScanMode.full) {
        return '학생 전체 · ${item.progressCurrent ?? '—'}명';
      }
      final studentId = item.candidates
          .map((candidate) => candidate.payload['student_id'])
          .whereType<String>()
          .firstOrNull;
      final name = studentId == null
          ? null
          : studentCatalog[studentId]?.displayName ?? studentId;
      return name == null ? '학생 1명' : '학생 1명 · $name';
    case ScannerKind.inventory:
      final profile = detail?.inventoryScanProfile;
      return profile == null
          ? '아이템'
          : '아이템 · ${scanInventoryProfileLabel(profile)}';
    case ScannerKind.tacticalLobby:
      return '전술대항전';
  }
}

/// 최근 스캔 행 칩. [pending]은 아직 적용 · 폐기하지 않은 후보, [applied]는 그중 하나라도 적용했는가(스캔 화면 · 다른 탭).
/// 끝났고 남은 후보가 없으면 적용한 것이 있을 때 `확정`, 모두 폐기했으면 `폐기`, 읽은 결과가 없으면 `결과 없음`.
(String, AppTone) scanRecentChip(
  ScannerRecentSummary item,
  List<ScannerCandidate> pending, {
  bool applied = false,
}) {
  switch (item.outcome) {
    case 'failed':
      final code = item.terminalError?['code'];
      return (code == 'target_not_found' ? '실패 · 창 없음' : '실패', AppTones.danger);
    case 'cancelled':
      return ('중지', AppTones.gray);
    case 'completed':
      if (pending.isNotEmpty) {
        return pending.any((candidate) => candidate.reviewRequired)
            ? ('확인 ${pending.length}', AppTones.warn)
            : ('검토 ${pending.length}', AppTones.pink);
      }
      if (applied) return ('확정', AppTones.ok);
      return item.candidateCount > 0
          ? ('폐기', AppTones.gray)
          : ('결과 없음', AppTones.gray);
    default:
      return ('—', AppTones.gray);
  }
}
