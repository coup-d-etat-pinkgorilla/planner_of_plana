import 'package:flutter/foundation.dart';

import 'app_service.dart';

class MockAppService implements AppService, MockScenarioController {
  MockAppService({AppServiceState? initialState})
    : _state = ValueNotifier(
        initialState ??
            const AppServiceState(
              connection: BackendConnection.connected,
              scanPhase: ScanPhase.idle,
              imageLoadState: ImageLoadState.loaded,
              studentCount: 42,
              inventoryItemCount: 186,
              hasData: true,
              useLongNames: false,
              hasMissingMetadata: false,
            ),
      );

  final ValueNotifier<AppServiceState> _state;

  @override
  ValueListenable<AppServiceState> get state => _state;

  @override
  Future<void> reconnect() async {
    _state.value = _state.value.copyWith(
      connection: BackendConnection.connecting,
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _state.value = _state.value.copyWith(
      connection: BackendConnection.connected,
    );
  }

  @override
  Future<void> restartBackend() async {
    _state.value = _state.value.copyWith(
      connection: BackendConnection.disconnected,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await reconnect();
  }

  @override
  Future<void> startScan() async {
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.scanning);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.succeeded);
  }

  @override
  void setConnection(BackendConnection value) {
    _state.value = _state.value.copyWith(connection: value);
  }

  @override
  void setScanPhase(ScanPhase value) {
    _state.value = _state.value.copyWith(scanPhase: value);
  }

  @override
  void setImageLoadState(ImageLoadState value) {
    _state.value = _state.value.copyWith(imageLoadState: value);
  }

  @override
  void setHasData(bool value) {
    _state.value = _state.value.copyWith(hasData: value);
  }

  @override
  void setLargeDataset(bool value) {
    _state.value = _state.value.copyWith(
      studentCount: value ? 9999 : 42,
      inventoryItemCount: value ? 999999 : 186,
    );
  }

  @override
  void setLongNames(bool value) {
    _state.value = _state.value.copyWith(useLongNames: value);
  }

  @override
  void setMissingMetadata(bool value) {
    _state.value = _state.value.copyWith(hasMissingMetadata: value);
  }
}
