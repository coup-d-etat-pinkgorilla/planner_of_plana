import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../ui/app_shell.dart';
import '../ui/first_run/first_run_rules.dart';
import '../ui/kit/game_image.dart';
import '../ui/pages/title_page.dart';
import 'theme.dart';

class BAPlannerApp extends StatelessWidget {
  const BAPlannerApp({
    super.key,
    required this.service,
    this.showTitle = false,
    this.onExitRequested,
    this.gameArtSource = GameArtScope.fallback,
    this.firstRun = FirstRunLaunch.off,
    this.onStartTutorial,
  });

  final AppService service;
  final bool showTitle;
  final VoidCallback? onExitRequested;

  /// 화면의 게임 그림 출처(F5a, FD-181). 기본은 번들 자산이다.
  final GameArtSource gameArtSource;

  /// 타이틀 위 첫 실행 ①~③(F3b). 기본은 끈다 — 실제 앱은 `main.dart`가 켠다.
  final FirstRunLaunch firstRun;

  /// 첫 실행 ③ 뒤 튜토리얼 시작(F3c 자리). 없으면 홈으로 간다.
  final FirstRunTutorialStarter? onStartTutorial;

  @override
  Widget build(BuildContext context) {
    return GameArtScope(
      source: gameArtSource,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BA Planner v7',
        theme: BAPlannerTheme.dark(),
        home: showTitle
            ? TitlePage(
                service: service,
                onExitRequested: onExitRequested,
                firstRun: firstRun,
                onStartTutorial: onStartTutorial,
              )
            : AppShell(service: service),
      ),
    );
  }
}
