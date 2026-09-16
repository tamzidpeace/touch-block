import 'package:touch_block/features/overlay_settings/data/overlay_platform_client.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings_update_result.dart';

abstract interface class OverlaySettingsRepository {
  Future<OverlaySettings> getSettings();

  Future<OverlaySettingsUpdateResult> updateSettings(OverlaySettings settings);
}

final class MethodChannelOverlaySettingsRepository
    implements OverlaySettingsRepository {
  final OverlayPlatformClient _client;

  const MethodChannelOverlaySettingsRepository({
    required OverlayPlatformClient client,
  }) : _client = client;

  @override
  Future<OverlaySettings> getSettings() async {
    return OverlaySettings.fromMap(await _client.getOverlaySettings());
  }

  @override
  Future<OverlaySettingsUpdateResult> updateSettings(
    OverlaySettings settings,
  ) async {
    final payload = await _client.updateOverlaySettings(settings.toMap());
    final rawSettings = payload['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('Expected settings in update response');
    }

    final normalizedSettings = OverlaySettings.fromMap(
      rawSettings.map<Object?, Object?>((key, value) => MapEntry(key, value)),
    );

    return OverlaySettingsUpdateResult(
      settings: normalizedSettings,
      serviceRunning: payload['serviceRunning'] == true,
      liveApplied: payload['liveApplied'] == true,
    );
  }
}
