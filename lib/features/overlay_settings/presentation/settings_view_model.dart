import 'package:flutter/foundation.dart';

import 'package:touch_block/features/overlay_settings/data/overlay_settings_repository.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required OverlaySettingsRepository repository})
    : _repository = repository;

  final OverlaySettingsRepository _repository;

  OverlaySettings _settings = OverlaySettings.defaults;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _statusMessage;

  OverlaySettings get settings => _settings;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get statusMessage => _statusMessage;

  Future<void> load() async {
    if (_isLoading || _isSaving) return;

    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      _settings = await _repository.getSettings();
    } catch (_) {
      _errorMessage = 'Could not load settings.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => load();

  Future<void> updateIconSize(OverlayIconSize value) {
    return _update(_settings.copyWith(iconSize: value));
  }

  Future<void> updateOpacity(int value) {
    return _update(_settings.copyWith(opacityPercent: value));
  }

  Future<void> updateUnlockGesture(UnlockGesture value) {
    return _update(_settings.copyWith(unlockGesture: value));
  }

  Future<void> _update(OverlaySettings next) async {
    if (_isLoading || _isSaving) return;

    _isSaving = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final result = await _repository.updateSettings(next);
      _settings = result.settings;
      _statusMessage = result.liveApplied
          ? 'Applied to the running service.'
          : result.serviceRunning
          ? 'Saved. It will apply when the service starts again.'
          : 'Saved. It will apply when the service starts.';
    } catch (_) {
      _errorMessage = 'Could not save settings.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
