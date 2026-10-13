// 홈 메뉴 교체 연출(FE8-e, 시안 Home-Connect-Effect, A §7.2, FD-116 (a)·FD-119).
//
// 시안은 10초 루프 CSS keyframes다. 앱은 그 안의 두 구간만 한 번씩 재생한다.
// - 연결(A → B): 1.8s 예비동작(+14) → 2.05–2.7s 왼쪽 퇴장(−820, 180°) → 2.75s 첫 버튼 교체
//   → 2.8–3.6s 왼쪽에서 진입(−10까지) → 3.6–4.0s 안착 → 3.8–4.6s flash. 창 선택 패널은 2.0–2.7s 오른쪽 퇴장(0°).
// - 해제(B → A): 7.0s부터 같은 예비동작·퇴장 → 7.95s 교체 → 7.9–8.8s 진입 → 9.2s 안착. flash·패널 없음.
// 거리는 시안 px(메뉴 섹션 742×1018 설계 좌표)다. 화면에서는 메뉴와 같이 FittedBox로 축소된다.
// 곡선은 CSS keyframes 기본 곡선(`ease`)을 구간마다 쓴다. 이 전이 전용이고 공용 섹션 모션으로 올리지 않는다(FD-119).
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../app/theme.dart';

@immutable
class HomeMenuSwapTimeline {
  const HomeMenuSwapTimeline._({
    required this.hold,
    required this.enter,
    required this.flash,
    required this.movesPanel,
  });

  /// 연결: 메뉴 A → B, flash, 열린 패널 퇴장.
  static const connect = HomeMenuSwapTimeline._(
    hold: AppMotion.connectSwapHold,
    enter: AppMotion.connectMenuEnter,
    flash: true,
    movesPanel: true,
  );

  /// 해제(FD-116 "B → A 해제 연출"): 메뉴 B → A. flash 없음.
  static const release = HomeMenuSwapTimeline._(
    hold: Duration.zero,
    enter: AppMotion.connectReleaseEnter,
    flash: false,
    movesPanel: false,
  );

  /// 시안 px(설계 좌표).
  static const anticipation = 14.0;
  static const exitDistance = 820.0;
  static const overshoot = 10.0;
  static const panelExitDistance = 820.0;

  /// 퇴장이 끝난 뒤 첫 버튼을 바꾸는 시점(시안 2.75s·7.95s = 퇴장 끝 + 0.05s).
  static const swapLag = Duration(milliseconds: 50);

  /// CSS keyframes 기본 곡선.
  static const curve = Curves.ease;

  final Duration hold;
  final Duration enter;
  final bool flash;
  final bool movesPanel;

  Duration get anticipationEnd => AppMotion.connectAnticipate;
  Duration get exitEnd => anticipationEnd + AppMotion.connectMenuExit;
  Duration get swapAt => exitEnd + swapLag;
  Duration get enterStart => exitEnd + hold;
  Duration get enterEnd => enterStart + enter;
  Duration get settleEnd => enterEnd + AppMotion.connectMenuSettle;
  Duration get flashPeak => settleEnd;
  Duration get flashStart => flashPeak - AppMotion.connectFlashIn;
  Duration get flashEnd => flashPeak + AppMotion.connectFlashOut;
  Duration get panelStart => AppMotion.connectPanelDelay;
  Duration get panelEnd => panelStart + AppMotion.connectPanelExit;

  /// 전체 길이(연결 2.8s, 해제 2.2s).
  Duration get total => flash ? flashEnd : settleEnd;

  /// 컨트롤러 값(0~1)을 시각으로 바꾼다.
  Duration at(double value) => total * value.clamp(0.0, 1.0);

  static double _segment(Duration t, Duration start, Duration end) {
    if (end <= start) return t >= end ? 1 : 0;
    final raw = (t - start).inMicroseconds / (end - start).inMicroseconds;
    return curve.transform(raw.clamp(0.0, 1.0).toDouble());
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// 메뉴 가로 이동(설계 px). 양수 = 오른쪽.
  double menuOffset(Duration t) {
    if (t <= Duration.zero) return 0;
    if (t < anticipationEnd) {
      return _lerp(0, anticipation, _segment(t, Duration.zero, anticipationEnd));
    }
    if (t < exitEnd) {
      return _lerp(
        anticipation,
        -exitDistance,
        _segment(t, anticipationEnd, exitEnd),
      );
    }
    if (t < enterStart) return -exitDistance;
    if (t < enterEnd) {
      return _lerp(-exitDistance, -overshoot, _segment(t, enterStart, enterEnd));
    }
    if (t < settleEnd) {
      return _lerp(-overshoot, 0, _segment(t, enterEnd, settleEnd));
    }
    return 0;
  }

  /// 첫 버튼이 새 내용으로 바뀌었는가.
  bool swapped(Duration t) => t >= swapAt;

  /// flash 불투명도(0~1). 연결에만 있다.
  double flashOpacity(Duration t) {
    if (!flash || t <= flashStart || t >= flashEnd) return 0;
    if (t < flashPeak) return _segment(t, flashStart, flashPeak);
    return 1 - _segment(t, flashPeak, flashEnd);
  }

  /// 창 선택 패널 가로 이동(설계 px, 오른쪽 퇴장). 연결에만 있다.
  double panelOffset(Duration t) =>
      movesPanel ? panelExitDistance * _segment(t, panelStart, panelEnd) : 0;

  /// 패널이 다 빠져 숨겨도 되는가(시안 2.71s 이후 숨김).
  bool panelGone(Duration t) => movesPanel && t >= panelEnd;
}
