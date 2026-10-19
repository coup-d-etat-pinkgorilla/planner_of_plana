// 통계 탭이 읽은 원천 자료(FE7-a). `StatisticsPage._reload()`가 채우고 화면에 그대로 넘긴다.
//
// 다섯 데이터 버킷을 섞지 않도록 출처별로 따로 둔다: 계정 상태(스캔 현재 상태 · 사용자 목표 · 인벤토리),
// 정적 메타(학생 목록 · 인벤토리 목록), 총 계산 결과(`calculatePlan`), 재고 기반 부족(`calculateShortages`).
// FE7-a 골격은 읽기 상태(연결 · 읽는 중 · 오류 · 계정 없음)만 쓰고, 값은 FE7-b부터 쓴다.
import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';

@immutable
class StatisticsSourceData {
  const StatisticsSourceData({
    required this.connection,
    required this.loading,
    this.profile,
    this.state,
    this.students,
    this.inventory,
    this.gross,
    this.shortages,
    this.errors = const [],
  });

  final BackendConnection connection;
  final bool loading;
  final RepositoryProfile? profile;
  final RepositoryState? state;
  final List<StudentCatalogEntry>? students;
  final List<InventoryCatalogEntry>? inventory;
  final Map<String, dynamic>? gross;
  final InventoryShortageResult? shortages;

  /// 출처별 읽기 오류(읽은 순서).
  final List<String> errors;

  /// 근거 패널에 띄울 읽기 상태 안내. 읽기가 끝나 보여 줄 근거를 기다리는 상태면 `null`이다.
  String? get notice {
    switch (connection) {
      case BackendConnection.disconnected:
        return '백엔드에 연결되지 않았습니다. 다시 연결하면 통계를 읽습니다.';
      case BackendConnection.connecting:
        return '백엔드에 연결하는 중입니다.';
      case BackendConnection.connected:
        break;
    }
    if (loading) return '통계 자료를 읽는 중입니다.';
    if (errors.isNotEmpty) return errors.join('\n');
    if (profile == null) {
      return '선택된 계정이 없습니다. 설정에서 계정을 고르면 통계가 보입니다.';
    }
    return null;
  }
}
