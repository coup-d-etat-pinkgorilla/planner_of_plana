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

  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async {
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
