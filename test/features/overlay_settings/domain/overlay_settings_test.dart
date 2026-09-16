import 'package:flutter_test/flutter_test.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';

void main() {
  test('defaults use Medium, 95 percent, and Double tap', () {
    expect(OverlaySettings.defaults.iconSize, OverlayIconSize.medium);
    expect(OverlaySettings.defaults.opacityPercent, 95);
    expect(OverlaySettings.defaults.unlockGesture, UnlockGesture.doubleTap);
  });

  test('toMap uses the platform wire contract', () {
    const settings = OverlaySettings(
      iconSize: OverlayIconSize.large,
      opacityPercent: 80,
      unlockGesture: UnlockGesture.tripleTap,
    );

    expect(settings.toMap(), {
      'iconSize': 'large',
      'opacityPercent': 80,
      'unlockTapCount': 3,
    });
  });

  test('fromMap parses native values', () {
    final settings = OverlaySettings.fromMap({
      'iconSize': 'small',
      'opacityPercent': 40,
      'unlockTapCount': 2,
    });

    expect(settings.iconSize, OverlayIconSize.small);
    expect(settings.opacityPercent, 40);
    expect(settings.unlockGesture, UnlockGesture.doubleTap);
  });

  test('invalid values use safe defaults or bounds', () {
    final settings = OverlaySettings.fromMap({
      'iconSize': 'unknown',
      'opacityPercent': 130,
      'unlockTapCount': 9,
    });

    expect(settings.iconSize, OverlayIconSize.medium);
    expect(settings.opacityPercent, 100);
    expect(settings.unlockGesture, UnlockGesture.doubleTap);
  });

  test('copyWith preserves fields that are not changed', () {
    const original = OverlaySettings(
      iconSize: OverlayIconSize.small,
      opacityPercent: 70,
      unlockGesture: UnlockGesture.doubleTap,
    );

    final updated = original.copyWith(opacityPercent: 75);

    expect(updated.iconSize, OverlayIconSize.small);
    expect(updated.opacityPercent, 75);
    expect(updated.unlockGesture, UnlockGesture.doubleTap);
  });
}
