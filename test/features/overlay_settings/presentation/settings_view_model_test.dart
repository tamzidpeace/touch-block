import 'package:flutter_test/flutter_test.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings_update_result.dart';
import 'package:touch_block/features/overlay_settings/presentation/settings_view_model.dart';

import '../fakes.dart';

void main() {
  test('load publishes repository settings', () async {
    final repository = FakeSettingsRepository()
      ..loaded = const OverlaySettings(
        iconSize: OverlayIconSize.large,
        opacityPercent: 80,
        unlockGesture: UnlockGesture.tripleTap,
      );
    final viewModel = SettingsViewModel(repository: repository);

    await viewModel.load();

    expect(viewModel.settings.iconSize, OverlayIconSize.large);
    expect(viewModel.settings.opacityPercent, 80);
    expect(viewModel.settings.unlockGesture, UnlockGesture.tripleTap);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('successful running-service update publishes live status', () async {
    final repository = FakeSettingsRepository()
      ..nextUpdate = OverlaySettingsUpdateResult(
        settings: OverlaySettings.defaults.copyWith(opacityPercent: 80),
        serviceRunning: true,
        liveApplied: true,
      );
    final viewModel = SettingsViewModel(repository: repository);
    await viewModel.load();

    await viewModel.updateOpacity(80);

    expect(viewModel.settings.opacityPercent, 80);
    expect(viewModel.statusMessage, contains('running service'));
    expect(viewModel.errorMessage, isNull);
  });

  test('live-apply failure keeps settings and shows restart status', () async {
    final repository = FakeSettingsRepository()
      ..nextUpdate = OverlaySettingsUpdateResult(
        settings: OverlaySettings.defaults.copyWith(opacityPercent: 80),
        serviceRunning: true,
        liveApplied: false,
      );
    final viewModel = SettingsViewModel(repository: repository);
    await viewModel.load();

    await viewModel.updateOpacity(80);

    expect(viewModel.settings.opacityPercent, 80);
    expect(viewModel.statusMessage, contains('starts again'));
    expect(viewModel.errorMessage, isNull);
  });

  test('persistence failure keeps the previous committed state', () async {
    final repository = FakeSettingsRepository()
      ..updateError = StateError('SETTINGS_PERSIST_FAILED');
    final viewModel = SettingsViewModel(repository: repository);
    await viewModel.load();

    await viewModel.updateIconSize(OverlayIconSize.large);

    expect(viewModel.settings, OverlaySettings.defaults);
    expect(viewModel.errorMessage, isNotNull);
    expect(viewModel.isSaving, isFalse);
  });
}
