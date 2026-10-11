// 개발자 도구 등록표(M2). `developer_tools_main.dart`의 `--tool` 분기가 이 표를 읽는다.
//
// 도구 하나 = 아래 [developerTools]의 항목 하나(id · 창 제목 · 화면 빌더). 새 도구(예: A2 애니메이션 스펙트럼)는 항목
// 한 줄만 더한다. [DeveloperToolEntry.aliases]는 옛 이름이다: `student-metadata`는 한 릴리스 동안 메타데이터 관리자
// 창(① 학생 탭)을 연다.
import 'package:flutter/material.dart';

import 'legacy_tool_pages.dart';
import 'metadata_manager_page.dart';
import 'metadata_manager_service.dart';
import 'tool_backend_client.dart';

/// 도구 화면이 받는 백엔드: 기존 20 메서드 [client], 메타데이터 관리자 새 6 메서드 [metadataManager].
@immutable
class DeveloperToolServices {
  const DeveloperToolServices({
    required this.client,
    required this.metadataManager,
  });

  /// [client] 하나로: envelope 전송을 지원하면 새 메서드도 그 백엔드로 부른다.
  DeveloperToolServices.forClient(ToolBackend client)
    : this(client: client, metadataManager: metadataManagerServiceFor(client));

  /// mock 모드: Python 백엔드 없이 연다(편집기는 빈 목록, 새 메서드는 부르지 않음).
  const DeveloperToolServices.mock()
    : this(
        client: const MockToolBackend(),
        metadataManager: const OfflineMetadataManagerService.mock(),
      );

  final ToolBackend client;
  final MetadataManagerService metadataManager;
}

typedef DeveloperToolBuilder = Widget Function(DeveloperToolServices services);

/// 등록된 도구 하나.
@immutable
class DeveloperToolEntry {
  const DeveloperToolEntry({
    required this.id,
    required this.title,
    required this.builder,
    this.aliases = const [],
  });

  /// `--tool=<id>` 값.
  final String id;

  /// 창 제목.
  final String title;
  final DeveloperToolBuilder builder;

  /// 옛 `--tool` 이름.
  final List<String> aliases;

  bool matches(String name) => name == id || aliases.contains(name);
}

/// 처음 열 도구(이름이 없거나 모르는 이름일 때).
const defaultDeveloperToolId = 'metadata-manager';

/// 등록표. 도구 1개당 1항목.
final List<DeveloperToolEntry> developerTools = List.unmodifiable([
  DeveloperToolEntry(id: 'metadata-manager', title: 'BA Planner v7 · 메타데이터 관리자', aliases: const ['student-metadata'], builder: (services) => MetadataManagerPage(client: services.client, service: services.metadataManager)),
  DeveloperToolEntry(id: 'student-template', title: 'BA Planner v7 · 학생 템플릿 추출기', builder: (services) => TemplateExtractorPage(client: services.client)),
  DeveloperToolEntry(id: 'inventory-grid', title: 'BA Planner v7 · 인벤토리 그리드 매치 검사기', builder: (services) => GridInspectorPage(client: services.client)),
]);

/// [name](id 또는 옛 이름)의 도구. 없거나 모르면 [defaultDeveloperToolId].
DeveloperToolEntry developerToolFor(String? name) {
  final wanted = name?.trim() ?? '';
  for (final entry in developerTools) {
    if (wanted.isNotEmpty && entry.matches(wanted)) return entry;
  }
  return developerTools.firstWhere(
    (entry) => entry.id == defaultDeveloperToolId,
  );
}
