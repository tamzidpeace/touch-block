import 'package:flutter/foundation.dart';

import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';

@immutable
class OverlaySettingsUpdateResult {
  final OverlaySettings settings;
  final bool serviceRunning;
  final bool liveApplied;

  const OverlaySettingsUpdateResult({
    required this.settings,
    required this.serviceRunning,
    required this.liveApplied,
  });

  @override
  bool operator ==(Object other) {
    return other is OverlaySettingsUpdateResult &&
        other.settings == settings &&
        other.serviceRunning == serviceRunning &&
        other.liveApplied == liveApplied;
  }

  @override
  int get hashCode => Object.hash(settings, serviceRunning, liveApplied);
}
