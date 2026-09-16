import 'package:flutter_test/flutter_test.dart';
import 'package:touch_block/features/overlay_settings/data/overlay_settings_repository.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';

import '../fakes.dart';

void main() {
  test('repository parses settings and update status', () async {
    final client = FakeOverlayPlatformClient();
    final repository = MethodChannelOverlaySettingsRepository(client: client);

    expect(await repository.getSettings(), OverlaySettings.defaults);

    final result = await repository.updateSettings(
      OverlaySettings.defaults.copyWith(
        iconSize: OverlayIconSize.large,
        opacityPercent: 80,
        unlockGesture: UnlockGesture.tripleTap,
      ),
    );

    expect(client.lastUpdate?['unlockTapCount'], 3);
    expect(result.settings.iconSize, OverlayIconSize.large);
    expect(result.settings.opacityPercent, 80);
    expect(result.settings.unlockGesture, UnlockGesture.tripleTap);
    expect(result.serviceRunning, isTrue);
    expect(result.liveApplied, isTrue);
  });

  test('repository rejects an update response without settings', () async {
    final client = FakeOverlayPlatformClient()
      ..updateResponse = {'serviceRunning': false, 'liveApplied': false};
    final repository = MethodChannelOverlaySettingsRepository(client: client);

    expect(
      () => repository.updateSettings(OverlaySettings.defaults),
      throwsA(isA<FormatException>()),
    );
  });
}
