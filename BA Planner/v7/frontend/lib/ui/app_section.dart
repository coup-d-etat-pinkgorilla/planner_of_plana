import 'package:flutter/material.dart';

enum AppSection {
  home('홈', Icons.home_outlined, '오늘의 현황과 빠른 메뉴'),
  students('학생', Icons.groups_2_outlined, '학생 목록과 육성 상태'),
  plan('계획', Icons.fact_check_outlined, '육성 목표와 필요 재화'),
  inventory('인벤토리', Icons.inventory_2_outlined, '보유 재화와 장비'),
  pvp('전술대항전', Icons.sports_esports_outlined, '전술대항전 기록과 편성'),
  statistics('통계', Icons.query_stats_outlined, '계정 성장 통계'),
  scan('스캔', Icons.document_scanner_outlined, '화면 스캔과 진행 상태'),
  settings('설정', Icons.settings_outlined, '앱 및 연결 설정'),
  adaptiveSync('Adaptive-Sync 진단', Icons.monitor_heart_outlined, '그래픽 표시 진단');

  const AppSection(this.label, this.icon, this.description);

  final String label;
  final IconData icon;
  final String description;

  static const primary = <AppSection>[
    home,
    students,
    plan,
    inventory,
    pvp,
    statistics,
    scan,
    settings,
  ];
}
