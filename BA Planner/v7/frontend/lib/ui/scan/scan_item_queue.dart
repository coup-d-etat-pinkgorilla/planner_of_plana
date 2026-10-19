// 아이템 여러 종류 차례 스캔과 진행 창 값(FE8-g3, FD-143 (a) 프론트 큐 · FD-141 (a) · FD-142 (a)).
//
// 근거: XB 2026-10-18 01:30 "FB-10 FE8-g3·g4·g5 기존 형식 고정 선언".
// - 한 세션 = 한 `inventory_scan_profile`. 고른 종류를 칸 순서대로 하나씩 시작하고, 지금 종류가 terminal이 된 뒤에 다음 종류를
//   시작한다(동시에 활성인 세션 0 — 겹치면 백엔드는 scanner_busy). 진행 창은 큐의 첫 종류에서 한 번 열고 큐가 끝나면 닫는다.
// - 끝난 종류의 결과는 그 세션의 최근 기록(세션 · generation · 후보)으로 따로 둔다. 다음 세션 후보와 섞지 않고, 검토는 지금
//   아이템 검토 화면에서 종류별로 연다(FE8-g5 전까지). 백엔드 일괄 적용 · 자동 폐기는 없다.
// - 규칙: 완료 → 다음 종류. 실패(terminal failed · 시작 응답 실패) → 그 종류만 `실패`로 두고 다음 종류. 중지(사용자 · Esc) →
//   큐 전체 중지(남은 종류 `읽지 않음`). 일시정지 → 그 세션 안에서만(큐는 기다린다, `paused` 이벤트 · 스냅숏만 멈춤으로 본다).
//   다음 종류를 시작할 조건이 사라짐(창 닫힘 · 최소화 · 백엔드 끊김 · 인식 준비) → 남은 종류 `읽지 않음`으로 끝.
// - 값: `progress.current` = 그 종류에서 인식한 entry 누계, `total` = null이라 분모 · % · 남은 시간은 그리지 않는다. 큐 누계 =
//   끝난 종류의 마지막 current + 지금 종류 current(모르는 종류는 더하지 않고, 하나도 모르면 '—'). 방문 칸 수가 아니다.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import '../models/planning_resource_assets.dart';
import '../widgets/scan_companion_dock.dart';
import 'scan_pick_logic.dart';
import 'scan_session_controller.dart';

/// 플래너 창을 진행 창으로 줄이는 네이티브 응답을 기다리는 시간. 넘으면 진행 창 없이 스캔한다.
const scanItemDockTimeout = Duration(seconds: 5);

/// 진행 창 끝 카드가 떠 있는 시간. 지나면 플래너가 원래 크기로 돌아온다(시안 `곧 플래너가 앞으로 오고`).
const scanItemDockCloseDelay = Duration(seconds: 2);

/// 큐 안 종류 하나의 상태.
enum ScanQueueStatus {
  /// 아직 차례가 오지 않음.
  waiting,

  /// 지금 차례(시작 중 · 진행 · 일시정지 · 중지 요청 중).
  running,
  completed,
  failed,

  /// 이 종류를 읽는 중에 중지했다(큐 전체 중지).
  cancelled,

  /// 중지 · 시작 조건 상실로 읽지 않았다.
  notRun,
}

/// 큐가 끝난 모습. 진행 중이면 null.
enum ScanQueueEnd { completed, partial, failed, cancelled }

/// 큐 안 종류 하나.
@immutable
class ScanQueueKind {
  const ScanQueueKind({
    required this.profile,
    this.status = ScanQueueStatus.waiting,
    this.session,
    this.count,
    this.result,
  });

  final InventoryScanProfile profile;
  final ScanQueueStatus status;

  /// 이 종류를 읽은 세션(시작 응답 뒤). 시작하지 못했으면 null.
  final ScannerSession? session;

  /// 이 종류의 마지막 `progress.current`(인식한 entry 누계). 모르면 null.
  final int? count;

  /// 끝났을 때의 최근 기록(세션 · generation · 후보). 시작하지 못했으면 null.
  final ScannerRecentSummary? result;

  ScanQueueKind copyWith({
    ScanQueueStatus? status,
    ScannerSession? session,
    int? count,
    ScannerRecentSummary? result,
  }) => ScanQueueKind(
    profile: profile,
    status: status ?? this.status,
    session: session ?? this.session,
    count: count ?? this.count,
    result: result ?? this.result,
  );
}

/// 아이템 차례 스캔 한 번(FD-143 (a)). 바뀔 때마다 새 값이다.
@immutable
class ScanItemQueue {
  ScanItemQueue({
    required this.id,
    required List<ScanQueueKind> kinds,
    this.index = 0,
    this.end,
  }) : kinds = List.unmodifiable(kinds);

  /// [profiles]를 이 순서대로 읽는 새 큐. 첫 종류가 지금 차례다.
  factory ScanItemQueue.start(int id, List<InventoryScanProfile> profiles) =>
      ScanItemQueue(
        id: id,
        kinds: [
          for (final (index, profile) in profiles.indexed)
            ScanQueueKind(
              profile: profile,
              status: index == 0
                  ? ScanQueueStatus.running
                  : ScanQueueStatus.waiting,
            ),
        ],
      );

  /// 큐 번호(이 컨트롤러 안에서 하나씩 늘어난다).
  final int id;
  final List<ScanQueueKind> kinds;

  /// 지금(끝났으면 마지막으로 다룬) 종류.
  final int index;
  final ScanQueueEnd? end;

  bool get running => end == null;
  int get length => kinds.length;
  ScanQueueKind get current => kinds[index];

  /// [session]을 읽은 종류의 자리. 없으면 null.
  int? indexOf(ScannerSession? session) {
    if (session == null) return null;
    for (final (index, kind) in kinds.indexed) {
      final read = kind.session;
      if (read != null &&
          read.id == session.id &&
          read.generation == session.generation) {
        return index;
      }
    }
    return null;
  }

  /// 지금 종류에 세션을 붙인다(시작 응답).
  ScanItemQueue withSession(ScannerSession session) => _replace(
    index,
    current.copyWith(status: ScanQueueStatus.running, session: session),
  );

  /// 지금 종류가 [status]로 끝났다. 중지면 큐 전체를 끝내고, 아니면 다음 종류가 있으면 그 종류가 지금 차례다.
  ScanItemQueue ended(
    ScanQueueStatus status, {
    int? count,
    ScannerRecentSummary? result,
  }) {
    final next = [...kinds];
    next[index] = current.copyWith(
      status: status,
      count: count,
      result: result,
    );
    if (status == ScanQueueStatus.cancelled) {
      return _finish(next, cancelled: true);
    }
    if (index + 1 < length) {
      next[index + 1] = next[index + 1].copyWith(
        status: ScanQueueStatus.running,
      );
      return ScanItemQueue(id: id, kinds: next, index: index + 1);
    }
    return _finish(next);
  }

  /// 다음 종류를 시작할 수 없다: 지금 차례(아직 세션 없음)와 남은 종류를 `읽지 않음`으로 두고 끝낸다.
  ScanItemQueue stopped() => _finish([...kinds]);

  /// 지금까지 인식한 칸 누계. 끝난 종류의 [ScanQueueKind.count] + 지금 종류의 [live]. 하나도 모르면 null.
  int? countWith(int? live) {
    int? sum;
    for (final (index, kind) in kinds.indexed) {
      final count = index == this.index && running ? live : kind.count;
      if (count != null) sum = (sum ?? 0) + count;
    }
    return sum;
  }

  ScanItemQueue _replace(int at, ScanQueueKind kind) {
    final next = [...kinds];
    next[at] = kind;
    return ScanItemQueue(id: id, kinds: next, index: index, end: end);
  }

  ScanItemQueue _finish(List<ScanQueueKind> next, {bool cancelled = false}) {
    for (final (at, kind) in next.indexed) {
      if (kind.status == ScanQueueStatus.waiting ||
          kind.status == ScanQueueStatus.running) {
        next[at] = kind.copyWith(status: ScanQueueStatus.notRun);
      }
    }
    final completed = next
        .where((kind) => kind.status == ScanQueueStatus.completed)
        .length;
    final end = cancelled
        ? ScanQueueEnd.cancelled
        : completed == next.length
        ? ScanQueueEnd.completed
        : completed == 0
        ? ScanQueueEnd.failed
        : ScanQueueEnd.partial;
    return ScanItemQueue(id: id, kinds: next, index: index, end: end);
  }
}

// ---- 글자 ----

/// `1번째 / 2종류`.
String scanQueuePositionText(ScanItemQueue queue) =>
    '${queue.index + 1}번째 / ${queue.length}종류';

/// 고른 종류 이름(`기술 노트 · 전술 교육 BD`, 칸 순서).
String scanQueueNamesText(ScanItemQueue queue) => [
  for (final kind in queue.kinds) scanInventoryProfileLabel(kind.profile),
].join(' · ');

/// 종류 칩(시안 `완료 · 28 / 28칸` · `12 / 30칸` — 분모를 몰라 누계만). [live]는 지금 종류의 진행 값.
(String, AppTone) scanQueueKindChip(ScanQueueKind kind, {int? live}) {
  switch (kind.status) {
    case ScanQueueStatus.waiting:
      return ('대기', AppTones.gray);
    case ScanQueueStatus.running:
      return (live == null ? '—' : '$live칸', AppTones.pink);
    case ScanQueueStatus.completed:
      final count = kind.count;
      return (count == null ? '완료' : '완료 · $count칸', AppTones.ok);
    case ScanQueueStatus.failed:
      return ('실패', AppTones.danger);
    case ScanQueueStatus.cancelled:
      final count = kind.count;
      return (count == null ? '중지' : '중지 · $count칸', AppTones.gray);
    case ScanQueueStatus.notRun:
      return ('읽지 않음', AppTones.gray);
  }
}

/// 끝난 종류의 `최근 기록` 줄(최근 먼저 — 시안 `기술 노트 28칸 완료`). 아이템 단위 줄은 고정 형식 밖이라 없다.
List<ScanCompanionLogLine> scanQueueLog(ScanItemQueue queue) => [
  for (final kind in queue.kinds.reversed) ?_logLine(kind),
];

ScanCompanionLogLine? _logLine(ScanQueueKind kind) {
  final name = scanInventoryProfileLabel(kind.profile);
  final count = kind.count;
  return switch (kind.status) {
    ScanQueueStatus.completed => ScanCompanionLogLine(
      text: count == null ? '$name 완료' : '$name $count칸 완료',
      tone: AppTones.ok,
    ),
    ScanQueueStatus.failed => ScanCompanionLogLine(
      text: '$name 읽지 못함',
      tone: AppTones.warn,
    ),
    ScanQueueStatus.cancelled => ScanCompanionLogLine(
      text: count == null ? '$name 중지' : '$name 중지 · $count칸까지 읽음',
      tone: AppTones.warn,
    ),
    ScanQueueStatus.notRun => ScanCompanionLogLine(
      text: '$name 읽지 않음',
      tone: AppTones.gray,
    ),
    ScanQueueStatus.waiting || ScanQueueStatus.running => null,
  };
}

/// 일시정지 카드(시안 `마우스 입력이 감지되어 멈췄습니다` · 읽은 칸은 그대로 남는다).
ScanCompanionCard scanQueuePausedCard(ScannerPauseReason? reason, int? count) {
  final kept = count == null ? '읽은 칸은 그대로 남습니다.' : '읽은 $count칸은 그대로 남습니다.';
  return switch (reason) {
    ScannerPauseReason.inputDetected => ScanCompanionCard(
      title: '마우스 입력이 감지되어 멈췄습니다',
      body: "게임 화면을 처음 위치로 되돌린 뒤 '이어서'를 누르십시오. $kept",
      tone: AppTones.warn,
    ),
    ScannerPauseReason.targetMinimized => ScanCompanionCard(
      title: '게임 창이 최소화되어 멈췄습니다',
      body: "게임 창을 다시 연 뒤 '이어서'를 누르십시오. $kept",
      tone: AppTones.warn,
    ),
    ScannerPauseReason.user || null => ScanCompanionCard(
      title: '일시정지했습니다',
      body: "'이어서'를 누르면 계속합니다. $kept",
      tone: AppTones.warn,
    ),
  };
}

/// 끝 카드(시안 `스캔을 마쳤습니다` · `곧 플래너가 앞으로 오고 결과 검토가 열립니다. 이 창은 함께 닫힙니다.`).
ScanCompanionCard scanQueueEndCard(ScanQueueEnd end) {
  const body = '곧 플래너가 앞으로 오고 결과 검토가 열립니다. 이 창은 함께 닫힙니다.';
  return switch (end) {
    ScanQueueEnd.completed => const ScanCompanionCard(
      title: '스캔을 마쳤습니다',
      body: body,
      tone: AppTones.ok,
    ),
    ScanQueueEnd.partial => const ScanCompanionCard(
      title: '일부 종류를 읽지 못했습니다',
      body: body,
      tone: AppTones.warn,
    ),
    ScanQueueEnd.failed => const ScanCompanionCard(
      title: '스캔이 실패했습니다',
      body: body,
      tone: AppTones.danger,
    ),
    ScanQueueEnd.cancelled => const ScanCompanionCard(
      title: '스캔을 중지했습니다',
      body: body,
      tone: AppTones.gray,
    ),
  };
}

/// 진행 창 단계. 큐가 진행 중인데 세션이 시작 중이거나 종류 사이면 [ScanCompanionPhase.starting].
ScanCompanionPhase scanCompanionPhase(ScanSessionController controller) {
  final queue = controller.itemQueue;
  if (queue == null || !queue.running) return ScanCompanionPhase.ended;
  final live =
      controller.session != null &&
      queue.indexOf(controller.session) == queue.index;
  if (!live) return ScanCompanionPhase.starting;
  return switch (controller.stage) {
    ScanSessionStage.running => switch (controller.control) {
      ScannerControlState.paused => ScanCompanionPhase.paused,
      ScannerControlState.pauseRequested => ScanCompanionPhase.pauseRequested,
      _ => ScanCompanionPhase.running,
    },
    ScanSessionStage.cancelling => ScanCompanionPhase.cancelling,
    _ => ScanCompanionPhase.starting,
  };
}

/// 지금 종류의 진행 값(그 종류 세션의 `progress.current`). 아직 세션이 없으면 null.
int? scanQueueLiveCount(ScanSessionController controller) {
  final queue = controller.itemQueue;
  if (queue == null || !queue.running) return null;
  return queue.indexOf(controller.session) == queue.index
      ? controller.progressCurrent
      : null;
}

/// 종류 대표 그림(카탈로그 정렬 첫 항목). 없으면 null(이름 글자).
String? scanQueueProfileIcon(
  InventoryScanProfile profile,
  List<InventoryCatalogEntry> catalog,
) {
  final entry = scanProfileRepresentative(profile, catalog);
  return entry == null
      ? null
      : planningResourceIconAsset(
          category: entry.category,
          itemId: entry.itemId,
        );
}

/// 컨트롤러의 큐 · 세션으로 진행 창 값을 만든다. 큐가 없으면 null. 버튼은 컨트롤러 메서드를 부른다.
ScanCompanionState? scanCompanionStateFor(ScanSessionController controller) {
  final queue = controller.itemQueue;
  if (queue == null) return null;
  final phase = scanCompanionPhase(controller);
  final live = scanQueueLiveCount(controller);
  final count = queue.countWith(live);
  final catalog = controller.inventoryCatalog;
  ScanCompanionKind kindRow(int index, ScanQueueKind kind) {
    final (label, tone) = scanQueueKindChip(
      kind,
      live: index == queue.index ? live : null,
    );
    return ScanCompanionKind(
      id: kind.profile.wireName,
      label: scanInventoryProfileLabel(kind.profile),
      chipLabel: label,
      chipTone: tone,
      iconAsset: scanQueueProfileIcon(kind.profile, catalog),
    );
  }

  final kinds = [
    for (final (index, kind) in queue.kinds.indexed) kindRow(index, kind),
  ];
  final end = queue.end;
  final (String, AppTone) chip = switch (phase) {
    ScanCompanionPhase.paused => (
      switch (controller.pauseReason) {
        ScannerPauseReason.inputDetected => '일시정지 · 입력 감지',
        ScannerPauseReason.targetMinimized => '일시정지 · 창 최소화',
        ScannerPauseReason.user || null => '일시정지',
      },
      AppTones.warn,
    ),
    ScanCompanionPhase.cancelling => ('중지하는 중', AppTones.gray),
    ScanCompanionPhase.ended => switch (end) {
      ScanQueueEnd.completed => ('완료', AppTones.ok),
      ScanQueueEnd.partial => ('일부 완료', AppTones.warn),
      ScanQueueEnd.failed => ('실패', AppTones.danger),
      ScanQueueEnd.cancelled || null => ('중지', AppTones.gray),
    },
    _ => ('진행 중', AppTones.pink),
  };
  final multiple = queue.length > 1;
  final caption = switch (phase) {
    ScanCompanionPhase.ended => multiple ? '칸 · ${queue.length}종류' : '칸',
    _ => multiple ? '칸 · ${scanQueuePositionText(queue)}' : '칸',
  };
  final canControl =
      phase == ScanCompanionPhase.running && !controller.controlBusy;
  final canResume =
      phase == ScanCompanionPhase.paused && !controller.controlBusy;
  final canCancel =
      phase == ScanCompanionPhase.running ||
      phase == ScanCompanionPhase.pauseRequested ||
      phase == ScanCompanionPhase.paused;
  return ScanCompanionState(
    phase: phase,
    names: scanQueueNamesText(queue),
    chipLabel: chip.$1,
    chipTone: chip.$2,
    countText: count?.toString() ?? '—',
    countCaption: caption,
    fraction: end == ScanQueueEnd.completed ? 1 : null,
    barColor: switch (phase) {
      ScanCompanionPhase.paused => AppColors.warning,
      ScanCompanionPhase.ended => AppTones.ok.foreground,
      _ => AppColors.accent,
    },
    kinds: kinds,
    reading: phase == ScanCompanionPhase.ended ? null : kinds[queue.index],
    card: switch (phase) {
      ScanCompanionPhase.paused => scanQueuePausedCard(
        controller.pauseReason,
        count,
      ),
      ScanCompanionPhase.ended => scanQueueEndCard(
        end ?? ScanQueueEnd.cancelled,
      ),
      _ => null,
    },
    log: scanQueueLog(queue),
    onPause: canControl ? () => unawaited(controller.pause()) : null,
    onResume: canResume ? () => unawaited(controller.resume()) : null,
    onCancel: canCancel ? () => unawaited(controller.cancel()) : null,
    onOpenReview: phase == ScanCompanionPhase.ended
        ? controller.closeItemDock
        : null,
  );
}
