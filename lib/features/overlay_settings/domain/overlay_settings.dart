import 'package:flutter/foundation.dart';

enum OverlayIconSize { small, medium, large }

enum UnlockGesture { doubleTap, tripleTap }

@immutable
class OverlaySettings {
  static const defaults = OverlaySettings(
    iconSize: OverlayIconSize.medium,
    opacityPercent: 95,
    unlockGesture: UnlockGesture.doubleTap,
  );

  final OverlayIconSize iconSize;
  final int opacityPercent;
  final UnlockGesture unlockGesture;

  const OverlaySettings({
    required this.iconSize,
    required this.opacityPercent,
    required this.unlockGesture,
  });

  factory OverlaySettings.fromMap(Map<Object?, Object?> values) {
    final iconSize = switch (values['iconSize']) {
      'small' => OverlayIconSize.small,
      'large' => OverlayIconSize.large,
      _ => OverlayIconSize.medium,
    };
    final rawOpacity = values['opacityPercent'];
    final opacity = rawOpacity is num ? rawOpacity.round() : 95;
    final unlockGesture = switch (values['unlockTapCount']) {
      3 => UnlockGesture.tripleTap,
      _ => UnlockGesture.doubleTap,
    };

    return OverlaySettings(
      iconSize: iconSize,
      opacityPercent: opacity.clamp(40, 100).toInt(),
      unlockGesture: unlockGesture,
    );
  }

  OverlaySettings copyWith({
    OverlayIconSize? iconSize,
    int? opacityPercent,
    UnlockGesture? unlockGesture,
  }) {
    return OverlaySettings(
      iconSize: iconSize ?? this.iconSize,
      opacityPercent: (opacityPercent ?? this.opacityPercent)
          .clamp(40, 100)
          .toInt(),
      unlockGesture: unlockGesture ?? this.unlockGesture,
    );
  }

  Map<String, Object> toMap() => {
    'iconSize': iconSize.name,
    'opacityPercent': opacityPercent,
    'unlockTapCount': unlockGesture == UnlockGesture.tripleTap ? 3 : 2,
  };

  @override
  bool operator ==(Object other) {
    return other is OverlaySettings &&
        other.iconSize == iconSize &&
        other.opacityPercent == opacityPercent &&
        other.unlockGesture == unlockGesture;
  }

  @override
  int get hashCode => Object.hash(iconSize, opacityPercent, unlockGesture);
}
