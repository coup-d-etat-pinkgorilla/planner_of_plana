import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../ui/app_shell.dart';
import '../ui/pages/title_page.dart';
import 'theme.dart';

class BAPlannerApp extends StatelessWidget {
  const BAPlannerApp({
    super.key,
    required this.service,
    this.showTitle = false,
    this.onExitRequested,
  });

  final AppService service;
  final bool showTitle;
  final VoidCallback? onExitRequested;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BA Planner v7',
      theme: BAPlannerTheme.dark(),
      home: showTitle
          ? TitlePage(service: service, onExitRequested: onExitRequested)
          : AppShell(service: service),
    );
  }
}
