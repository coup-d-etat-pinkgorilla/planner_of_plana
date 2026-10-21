import 'package:flutter/services.dart';

class ScanDockPlacement {
  const ScanDockPlacement({
    required this.side,
    required this.width,
    required this.height,
    required this.gameResized,
  });

  final String side;
  final int width;
  final int height;
  final bool gameResized;
}

abstract interface class WindowDockService {
  Future<ScanDockPlacement> dockBeside(String targetId);
  Future<void> restore();
}

class WindowsWindowDockService implements WindowDockService {
  const WindowsWindowDockService();

  static const _channel = MethodChannel('ba_planner/window_dock');

  /// 러너가 붙일 수 있는 대상 id 접두(`windows/runner/flutter_window.cpp` `ParseTargetHandle`).
  static const nativeTargetPrefix = 'hwnd:';

  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async {
    // F3c-7: 네이티브 창이 아닌 대상(튜토리얼 가상 대상 · Mock 대상)은 러너가 창을 건드리지 않고 dock_failed로 답한다.
    // 채널을 부르지 않고 같은 실패를 바로 낸다(채널이 답하지 않는 시험 환경에서 시간 제한을 기다리지 않게).
    if (!targetId.startsWith(nativeTargetPrefix)) {
      throw PlatformException(
        code: 'dock_failed',
        message: 'not a native window target: $targetId',
      );
    }
    final wire = await _channel.invokeMapMethod<String, dynamic>('dock', {
      'target_id': targetId,
    });
    if (wire == null ||
        wire['side'] is! String ||
        wire['width'] is! int ||
        wire['height'] is! int ||
        wire['game_resized'] is! bool) {
      throw const FormatException('Invalid scan dock placement response');
    }
    return ScanDockPlacement(
      side: wire['side'] as String,
      width: wire['width'] as int,
      height: wire['height'] as int,
      gameResized: wire['game_resized'] as bool,
    );
  }

  @override
  Future<void> restore() => _channel.invokeMethod<void>('restore');
}
