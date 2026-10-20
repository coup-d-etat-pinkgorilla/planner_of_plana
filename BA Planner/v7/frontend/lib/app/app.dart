import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../ui/app_shell.dart';
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
  });

  final AppService service;
  final bool showTitle;
  final VoidCallback? onExitRequested;

  /// 화면의 게임 그림 출처(F5a, FD-181). 기본은 번들 자산이다.
  final GameArtSource gameArtSource;

  @override
  Widget build(BuildContext context) {
    return GameArtScope(
      source: gameArtSource,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BA Planner v7',
        theme: BAPlannerTheme.dark(),
        home: showTitle
            ? TitlePage(service: service, onExitRequested: onExitRequested)
            : AppShell(service: service),
      ),
    );
  }
}
