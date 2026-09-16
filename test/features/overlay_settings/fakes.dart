import 'package:touch_block/features/overlay_settings/data/overlay_platform_client.dart';
import 'package:touch_block/features/overlay_settings/data/overlay_settings_repository.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings_update_result.dart';

final class FakeOverlayPlatformClient implements OverlayPlatformClient {
  Map<String, Object?> settingsResponse = {
    'iconSize': 'medium',
    'opacityPercent': 95,
    'unlockTapCount': 2,
  };

  Map<String, Object?> updateResponse = {
    'settings': {
      'iconSize': 'large',
      'opacityPercent': 80,
      'unlockTapCount': 3,
    },
    'serviceRunning': true,
    'liveApplied': true,
  };

  Map<String, Object?>? lastUpdate;
  int startCalls = 0;

  @override
  Future<Map<String, Object?>> getOverlaySettings() async => settingsResponse;

  @override
  Future<Map<String, Object?>> updateOverlaySettings(
    Map<String, Object?> settings,
  ) async {
    lastUpdate = settings;
    return updateResponse;
  }

  @override
  Future<bool> checkOverlayPermission() async => true;

  @override
  Future<bool> requestOverlayPermission() async => true;

  @override
  Future<bool> startService() async {
    startCalls++;
    return true;
  }

  @override
  Future<bool> stopService() async => true;

  @override
  Future<bool> isServiceRunning() async => false;
}

final class FakeSettingsRepository implements OverlaySettingsRepository {
  OverlaySettings loaded = OverlaySettings.defaults;
  OverlaySettingsUpdateResult? nextUpdate;
  OverlaySettings? lastUpdate;
  Object? loadError;
  Object? updateError;
  int updateCalls = 0;

  @override
  Future<OverlaySettings> getSettings() async {
    if (loadError != null) throw loadError!;
    return loaded;
  }

  @override
  Future<OverlaySettingsUpdateResult> updateSettings(
    OverlaySettings settings,
  ) async {
    if (updateError != null) throw updateError!;
    updateCalls++;
    lastUpdate = settings;
    return nextUpdate ??
        OverlaySettingsUpdateResult(
          settings: settings,
          serviceRunning: false,
          liveApplied: false,
        );
  }
}
