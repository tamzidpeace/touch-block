import 'package:flutter/material.dart';

import 'package:touch_block/features/overlay_settings/data/overlay_settings_repository.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';
import 'package:touch_block/features/overlay_settings/presentation/settings_view_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.viewModel, this.repository})
    : assert(viewModel != null || repository != null);

  final SettingsViewModel? viewModel;
  final OverlaySettingsRepository? repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsViewModel _viewModel;
  late final bool _ownsViewModel;
  int? _draftOpacity;

  @override
  void initState() {
    super.initState();

    final injectedViewModel = widget.viewModel;
    if (injectedViewModel != null) {
      assert(widget.repository == null);
      _viewModel = injectedViewModel;
      _ownsViewModel = false;
    } else {
      _viewModel = SettingsViewModel(repository: widget.repository!);
      _ownsViewModel = true;
    }

    _viewModel.load();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final settings = _viewModel.settings;
          final opacity = _draftOpacity ?? settings.opacityPercent;
          final controlsEnabled = !_viewModel.isLoading && !_viewModel.isSaving;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsSection(
                  title: 'Floating button',
                  child: SegmentedButton<OverlayIconSize>(
                    segments: const [
                      ButtonSegment(
                        value: OverlayIconSize.small,
                        label: Text('Small'),
                      ),
                      ButtonSegment(
                        value: OverlayIconSize.medium,
                        label: Text('Medium'),
                      ),
                      ButtonSegment(
                        value: OverlayIconSize.large,
                        label: Text('Large'),
                      ),
                    ],
                    selected: {settings.iconSize},
                    onSelectionChanged: controlsEnabled
                        ? (selection) {
                            if (selection.isNotEmpty) {
                              _viewModel.updateIconSize(selection.first);
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Opacity',
                  trailing: Text('$opacity%'),
                  child: Slider(
                    min: 40,
                    max: 100,
                    divisions: 12,
                    value: opacity.toDouble(),
                    label: '$opacity%',
                    onChanged: controlsEnabled
                        ? (value) {
                            setState(() => _draftOpacity = value.round());
                          }
                        : null,
                    onChangeEnd: controlsEnabled
                        ? (value) async {
                            final committedValue = value.round();
                            setState(() => _draftOpacity = null);
                            await _viewModel.updateOpacity(committedValue);
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Unlock gesture',
                  child: RadioGroup<UnlockGesture>(
                    groupValue: settings.unlockGesture,
                    onChanged: (value) {
                      if (controlsEnabled && value != null) {
                        _viewModel.updateUnlockGesture(value);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<UnlockGesture>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Double tap'),
                          value: UnlockGesture.doubleTap,
                          enabled: controlsEnabled,
                        ),
                        RadioListTile<UnlockGesture>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Triple tap'),
                          value: UnlockGesture.tripleTap,
                          enabled: controlsEnabled,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'A single tap still locks the screen.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_viewModel.isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _MessageCard(
                    message: _viewModel.errorMessage!,
                    action: TextButton(
                      onPressed: _viewModel.isLoading ? null : _viewModel.retry,
                      child: const Text('Retry'),
                    ),
                    isError: true,
                  ),
                ],
                if (_viewModel.statusMessage != null) ...[
                  const SizedBox(height: 16),
                  _MessageCard(message: _viewModel.statusMessage!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  DefaultTextStyle(
                    style: TextStyle(color: colorScheme.primary),
                    child: trailing!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    this.action,
    this.isError = false,
  });

  final String message;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isError
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: TextStyle(color: foregroundColor)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
