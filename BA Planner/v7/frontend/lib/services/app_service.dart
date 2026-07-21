import 'package:flutter/foundation.dart';

enum BackendConnection { connected, disconnected, connecting }

enum ScanPhase { idle, scanning, succeeded, failed }

enum ImageLoadState { loaded, loading, failed }

@immutable
class AppServiceState {
  const AppServiceState({
    required this.connection,
    required this.scanPhase,
    required this.imageLoadState,
    required this.studentCount,
    required this.inventoryItemCount,
    required this.hasData,
    required this.scanAvailable,
    required this.useLongNames,
    required this.hasMissingMetadata,
  });

  final BackendConnection connection;
  final ScanPhase scanPhase;
  final ImageLoadState imageLoadState;
  final int studentCount;
  final int inventoryItemCount;
  final bool hasData;
  final bool scanAvailable;
  final bool useLongNames;
  final bool hasMissingMetadata;

  AppServiceState copyWith({
    BackendConnection? connection,
    ScanPhase? scanPhase,
    ImageLoadState? imageLoadState,
    int? studentCount,
    int? inventoryItemCount,
    bool? hasData,
    bool? scanAvailable,
    bool? useLongNames,
    bool? hasMissingMetadata,
  }) {
    return AppServiceState(
      connection: connection ?? this.connection,
      scanPhase: scanPhase ?? this.scanPhase,
      imageLoadState: imageLoadState ?? this.imageLoadState,
      studentCount: studentCount ?? this.studentCount,
      inventoryItemCount: inventoryItemCount ?? this.inventoryItemCount,
      hasData: hasData ?? this.hasData,
      scanAvailable: scanAvailable ?? this.scanAvailable,
      useLongNames: useLongNames ?? this.useLongNames,
      hasMissingMetadata: hasMissingMetadata ?? this.hasMissingMetadata,
    );
  }
}

/// UI가 사용하는 유일한 백엔드 경계입니다.
///
/// ProcessAppService도 이 계약만 구현하며 Widget은 변경하지 않습니다.
abstract interface class AppService {
  ValueListenable<AppServiceState> get state;

  Future<void> reconnect();

  Future<void> restartBackend();

  Future<void> startScan();

  Future<Map<String, dynamic>?> getStudent(String studentId);

  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan);

  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  });

  Future<void> dispose();
}

abstract interface class MockScenarioController {
  void setConnection(BackendConnection value);

  void setScanPhase(ScanPhase value);

  void setImageLoadState(ImageLoadState value);

  void setHasData(bool value);

  void setLargeDataset(bool value);

  void setLongNames(bool value);

  void setMissingMetadata(bool value);
}
