// 스캔 탭 학생 진행 화면 순수 규칙(FE8-g2, 시안 Scan-Student-Run, FB-10 고정 범위 · FD-154 · FD-156).
//
// 값 출처는 FB-10 형식 고정 선언(2026-10-15 17:05)의 범위만이다: `progress.current/total|null/message_key`,
// `feedback`(`student_id` · `field` · `values`), `paused`/`resumed`, terminal. identify feedback은 `values = {}`라 성장 5값은
// 모르고('—'), 관측한 학생은 승인 후보 · 저장 기록이 아니다. 바뀐 값 · 새 학생 · 확인 필요 · 그대로 수와 학생별 차이는 진행 중
// 후보(early candidate — 고정 범위 밖)가 있어야 셀 수 있어 '—'다(FD-156: 이벤트가 오기 전에는 (b)처럼 숨김).
// - total을 모르면(null) `/ n명` · % · 남은 시간을 그리지 않고 막대는 빗금이다(0과 다르다). 보유 수로 분모를 지어내지 않는다.
// - 남은 시간(FD-154): total을 알고 1명 이상 읽었으면 시작부터 지난 시간 ÷ 읽은 수 × 남은 수(실측 속도). 모르면 숨긴다.
import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import 'scan_session_controller.dart';

/// `방금 읽은 학생` 행 수(시안 6행).
const scanRunRecentRows = 6;

/// 진행 화면을 보이는가: 학생 세션이 시작 중 · 진행(일시정지 포함) · 중지 요청 중일 때. 아이템 · 전술 로비 진행과 끝난 뒤
/// (검토 대기)는 지금 `ScanPage`다(아이템 진행 창은 FE8-g3, 검토는 FE8-g4).
bool scanRunVisible(ScanSessionController controller) {
  final active = switch (controller.stage) {
    ScanSessionStage.starting ||
    ScanSessionStage.running ||
    ScanSessionStage.cancelling => true,
    ScanSessionStage.idle || ScanSessionStage.terminal => false,
  };
  return active &&
      (controller.session?.kind ?? controller.kind) == ScannerKind.student;
}

/// 진행 중인 세션의 학생 모드(시작 응답 전에는 고른 모드).
StudentScanMode scanRunMode(ScanSessionController controller) =>
    controller.session?.studentScanMode ?? controller.studentScanMode;

/// 제목(`학생 전체 스캔` · `학생 1명 스캔`).
String scanRunTitle(StudentScanMode mode) =>
    mode == StudentScanMode.full ? '학생 전체 스캔' : '학생 1명 스캔';

/// 큰 진행 수치 한 벌.
class ScanRunNumbers {
  const ScanRunNumbers({required this.current, required this.total});

  /// FB-10 `progress.current`. 아직 진행 이벤트가 없으면 null('—').
  final int? current;

  /// FB-10 `progress.total`. 모르면 null(0과 다르다 — 분모 · % · 남은 시간을 그리지 않는다).
  final int? total;

  /// 막대 비율. total을 모르거나 0이면 null(빗금).
  double? get fraction {
    final current = this.current;
    final total = this.total;
    if (current == null || total == null || total <= 0) return null;
    return (current / total).clamp(0.0, 1.0).toDouble();
  }

  /// `34`, 모르면 '—'.
  String get currentText => current?.toString() ?? '—';

  /// `/ 128명`, total을 모르면 null.
  String? get totalText {
    final total = this.total;
    return total == null ? null : '/ $total명';
  }

  /// `27%`, 비율을 모르면 null.
  String? get percentText {
    final fraction = this.fraction;
    return fraction == null ? null : '${(fraction * 100).round()}%';
  }

  /// 남은 시간(FD-154 실측 속도). total을 모르거나, 아직 한 명도 읽지 않았거나, 다 읽었거나, 시작 시각을 모르면 null.
  Duration? remaining({required DateTime? startedAt, required DateTime now}) {
    final current = this.current;
    final total = this.total;
    if (startedAt == null || current == null || total == null) return null;
    if (current <= 0 || current >= total) return null;
    final elapsed = now.difference(startedAt);
    if (elapsed.isNegative) return null;
    return elapsed * ((total - current) / current);
  }
}

/// `남은 시간 약 6분`(분 반올림, 1분보다 짧아도 `약 1분`).
String scanRemainingText(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).round();
  return '남은 시간 약 ${minutes < 1 ? 1 : minutes}분';
}

/// 레일 `최근 스캔` 첫 행(지금 실행): 제목 · 아래 글자.
({String title, String subtitle}) scanRunRecentRow(
  ScanSessionController controller,
) {
  final mode = scanRunMode(controller);
  final paused = controller.control == ScannerControlState.paused;
  final head = mode == StudentScanMode.full ? '학생 전체' : '학생 1명';
  final current = controller.progressCurrent;
  final total = controller.progressTotal;
  return (
    title: '$head · ${paused ? '일시정지' : '진행 중'}',
    subtitle: current == null
        ? '—'
        : total == null
        ? '$current명'
        : '$current / $total명',
  );
}

/// 학생 이름(카탈로그 표시 이름, 없으면 id).
String scanStudentName(
  String studentId,
  Map<String, StudentCatalogEntry> catalog,
) => catalog[studentId]?.displayName ?? studentId;

/// `방금 읽은 학생` 머리 오른쪽 글자(`최근 순 · 34명 중 6명`). 관측한 학생이 없으면 `최근 순`.
String scanRunRecentCaption(int observed) {
  if (observed == 0) return '최근 순';
  final shown = observed < scanRunRecentRows ? observed : scanRunRecentRows;
  return '최근 순 · $observed명 중 $shown명';
}

/// 일시정지 버튼 글자(FD-142, fb10a): 진행 `일시정지`, 요청을 받은 뒤 `멈추는 중…`, 멈춘 뒤 `이어서`.
String scanRunPauseLabel(ScanSessionController controller) =>
    switch (controller.control) {
      ScannerControlState.paused => '이어서',
      ScannerControlState.pauseRequested => '멈추는 중…',
      _ => '일시정지',
    };

/// 오른쪽 `백그라운드 스캔`의 게임 창 칩(시안 `뒤에 있음 · 읽는 중` ok).
(String, AppTone) scanRunTargetChip(ScanSessionController controller) {
  switch (controller.stage) {
    case ScanSessionStage.starting:
      return ('시작하는 중', AppTones.gray);
    case ScanSessionStage.cancelling:
      return ('중지하는 중', AppTones.gray);
    case ScanSessionStage.running:
      return controller.control == ScannerControlState.paused
          ? ('일시정지', AppTones.warn)
          : ('뒤에 있음 · 읽는 중', AppTones.ok);
    case ScanSessionStage.idle:
    case ScanSessionStage.terminal:
      return ('—', AppTones.gray);
  }
}

/// `지금 읽는 학생` 칸(시안 5줄). 성장 값은 identify feedback `values = {}`라 모두 '—'(FB-10 고정 범위 밖).
const scanRunLiveFields = ['레벨', '성급', '스킬', '장비', '전용무기'];

/// `지금까지` KPI 4칸(시안 이름). 값은 진행 중 후보가 있어야 셀 수 있어 '—'(FD-156, 회색 — 시안의 노랑 · 흰색은 센 값의 색).
const scanRunKpiLabels = ['바뀐 값', '새 학생', '확인 필요', '그대로'];
