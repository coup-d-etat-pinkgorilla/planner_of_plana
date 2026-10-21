import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../ui/app_section.dart';
import '../ui/app_shell.dart';
import '../ui/first_run/first_run_rules.dart';
import '../ui/kit/game_image.dart';
import '../ui/pages/title_page.dart';
import '../ui/tutorial_host/tutorial_overlay.dart';
import '../ui/tutorial_host/tutorial_session.dart';
import 'theme.dart';

class BAPlannerApp extends StatefulWidget {
  const BAPlannerApp({
    super.key,
    required this.service,
    this.showTitle = false,
    this.onExitRequested,
    this.gameArtSource = GameArtScope.fallback,
    this.firstRun = FirstRunLaunch.off,
    this.onStartTutorial,
    this.tutorial = false,
    this.tutorialSession,
  });

  final AppService service;
  final bool showTitle;
  final VoidCallback? onExitRequested;

  /// 화면의 게임 그림 출처(F5a, FD-181). 기본은 번들 자산이다.
  final GameArtSource gameArtSource;

  /// 타이틀 위 첫 실행 ①~③(F3b). 기본은 끈다 — 실제 앱은 `main.dart`가 켠다.
  final FirstRunLaunch firstRun;

  /// 첫 실행 ③ 뒤 튜토리얼 시작(F3c 자리). 없으면 [tutorial] 세션이 시작하고, 그것도 없으면 홈으로 간다.
  final FirstRunTutorialStarter? onStartTutorial;

  /// 튜토리얼(F3c-3)을 켠다: 세션 · 덧그림 · 앱 시작 때 남은 임시 계정 정리. 기본은 끈다(시험 · golden) — 실제 앱은
  /// `main.dart`가 켠다.
  final bool tutorial;

  /// 시험이 넘기는 세션(없고 [tutorial]이면 앱이 만든다).
  final TutorialSession? tutorialSession;

  @override
  State<BAPlannerApp> createState() => _BAPlannerAppState();
}

class _BAPlannerAppState extends State<BAPlannerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  TutorialSession? _ownedSession;

  TutorialSession? get _session =>
      widget.tutorialSession ??
      (widget.tutorial
          ? _ownedSession ??= TutorialSession(service: widget.service)
          : null);

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant BAPlannerApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      oldWidget.service.state.removeListener(_connectionChanged);
      _ownedSession?.dispose();
      _ownedSession = null;
    }
    _attach();
  }

  @override
  void dispose() {
    widget.service.state.removeListener(_connectionChanged);
    _ownedSession?.dispose();
    super.dispose();
  }

  void _attach() {
    final session = _session;
    if (session == null) return;
    session.openShell = _openShell;
    widget.service.state.removeListener(_connectionChanged);
    widget.service.state.addListener(_connectionChanged);
    _connectionChanged();
  }

  /// 연결되면 한 번 남은 임시 계정을 정리한다(F3c-3, 세션이 한 번만 한다).
  void _connectionChanged() {
    final session = _session;
    if (session == null) return;
    if (widget.service.state.value.connection != BackendConnection.connected) {
      return;
    }
    widget.service.state.removeListener(_connectionChanged);
    session.recover();
  }

  /// 타이틀 위에서 시작한 튜토리얼이 다른 탭을 바탕으로 쓸 때 셸을 연다(타이틀의 `_openShell`과 같은 경로).
  void _openShell(AppSection section) {
    _navigatorKey.currentState?.pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => AppShell(
          service: widget.service,
          initialSection: section,
          animateHomeEntrance: section == AppSection.home,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final onStartTutorial =
        widget.onStartTutorial ??
        (session == null
            ? null
            : (BuildContext context, account) => session.start(account));
    return GameArtScope(
      source: widget.gameArtSource,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'BA Planner v7',
        theme: BAPlannerTheme.dark(),
        builder: session == null
            ? null
            : (context, child) => TutorialHost(
                session: session,
                child: child ?? const SizedBox.shrink(),
              ),
        home: widget.showTitle
            ? TitlePage(
                service: widget.service,
                onExitRequested: widget.onExitRequested,
                firstRun: widget.firstRun,
                onStartTutorial: onStartTutorial,
              )
            : AppShell(service: widget.service),
      ),
    );
  }
}
