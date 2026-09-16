import 'package:flutter/services.dart';

abstract interface class OverlayPlatformClient {
  Future<bool> checkOverlayPermission();

  Future<bool> requestOverlayPermission();

  Future<bool> startService();

  Future<bool> stopService();

  Future<bool> isServiceRunning();

  Future<Map<String, Object?>> getOverlaySettings();

  Future<Map<String, Object?>> updateOverlaySettings(
    Map<String, Object?> settings,
  );
}

final class MethodChannelOverlayPlatformClient
    implements OverlayPlatformClient {
  static const channelName = 'xyz.arafatpeace.touchblock/overlay';

  final MethodChannel _channel;

  const MethodChannelOverlayPlatformClient({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  @override
  Future<bool> checkOverlayPermission() async {
    return await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
  }

  @override
  Future<bool> requestOverlayPermission() async {
    return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
        false;
  }

  @override
  Future<bool> startService() async {
    return await _channel.invokeMethod<bool>('startService') ?? false;
  }

  @override
  Future<bool> stopService() async {
    return await _channel.invokeMethod<bool>('stopService') ?? false;
  }

  @override
  Future<bool> isServiceRunning() async {
    return await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
  }

  @override
  Future<Map<String, Object?>> getOverlaySettings() async {
    return _asMap(await _channel.invokeMethod<Object?>('getOverlaySettings'));
  }

  @override
  Future<Map<String, Object?>> updateOverlaySettings(
    Map<String, Object?> settings,
  ) async {
    return _asMap(
      await _channel.invokeMethod<Object?>('updateOverlaySettings', settings),
    );
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Expected a platform map');
    }

    return value.map<String, Object?>(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
}
