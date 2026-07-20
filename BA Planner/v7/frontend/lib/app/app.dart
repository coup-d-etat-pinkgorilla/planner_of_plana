import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../ui/app_shell.dart';
import 'theme.dart';

class BAPlannerApp extends StatelessWidget {
  const BAPlannerApp({super.key, required this.service});

  final AppService service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BA Planner v7',
      theme: BAPlannerTheme.dark(),
      home: AppShell(service: service),
    );
  }
}
