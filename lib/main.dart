import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:touch_block/features/overlay_settings/data/overlay_platform_client.dart';
import 'package:touch_block/features/overlay_settings/data/overlay_settings_repository.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';
import 'package:touch_block/features/overlay_settings/presentation/settings_page.dart';

void main() {
  runApp(const TouchBlockApp());
}

/// Touch Block App - Main Application
///
/// A simple app that launches a floating overlay service
/// which can block screen touch input.
class TouchBlockApp extends StatelessWidget {
  const TouchBlockApp({
    super.key,
    this.platformClient = const MethodChannelOverlayPlatformClient(),
  });

  final OverlayPlatformClient platformClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touch Block',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(platformClient: platformClient),
    );
  }
}

/// Home Screen - Main UI for controlling the touch block service
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.platformClient = const MethodChannelOverlayPlatformClient(),
  });

  final OverlayPlatformClient platformClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _isServiceRunning = false;
  bool _isLoading = true;
  OverlaySettings _settings = OverlaySettings.defaults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when app returns to foreground (e.g., after permission settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  /// Check current permission and service status
  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);

    try {
      final hasPermission = await widget.platformClient
          .checkOverlayPermission();
      final isRunning = await widget.platformClient.isServiceRunning();
      OverlaySettings? loadedSettings;

      try {
        loadedSettings = OverlaySettings.fromMap(
          await widget.platformClient.getOverlaySettings(),
        );
      } catch (e) {
        debugPrint('Error loading overlay settings: $e');
      }

      if (!mounted) return;
      setState(() {
        _hasPermission = hasPermission;
        _isServiceRunning = isRunning;
        if (loadedSettings != null) _settings = loadedSettings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking status: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Request overlay permission from the user
  Future<void> _requestPermission() async {
    try {
      final granted = await widget.platformClient.requestOverlayPermission();
      if (mounted) setState(() => _hasPermission = granted);
    } on PlatformException catch (e) {
      debugPrint('Error requesting permission: $e');
      _showError('Failed to request permission');
    }
  }

  /// Start the floating overlay service
  Future<void> _startService() async {
    try {
      final success = await widget.platformClient.startService();
      if (success) {
        setState(() => _isServiceRunning = true);
        _showSuccess('Service started! Look for the floating icon.');
      }
    } on PlatformException catch (e) {
      debugPrint('Error starting service: $e');
      if (e.code == 'PERMISSION_DENIED') {
        _showError('Please grant overlay permission first');
      } else {
        _showError('Failed to start service');
      }
    }
  }

  /// Stop the floating overlay service
  Future<void> _stopService() async {
    try {
      await widget.platformClient.stopService();
      setState(() => _isServiceRunning = false);
      _showSuccess('Service stopped');
    } on PlatformException catch (e) {
      debugPrint('Error stopping service: $e');
      _showError('Failed to stop service');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          repository: MethodChannelOverlaySettingsRepository(
            client: widget.platformClient,
          ),
        ),
      ),
    );
    if (mounted) await _checkStatus();
  }

  String get _unlockInstruction =>
      _settings.unlockGesture == UnlockGesture.tripleTap
      ? 'Triple-tap the icon to unlock'
      : 'Double-tap the icon to unlock';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.3),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Settings',
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Touch Block',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Prevent accidental touches during video calls',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Status Cards
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Permission Status Card
                    _StatusCard(
                      icon: _hasPermission
                          ? Icons.check_circle
                          : Icons.warning_amber,
                      iconColor: _hasPermission ? Colors.green : Colors.orange,
                      title: 'Overlay Permission',
                      subtitle: _hasPermission
                          ? 'Permission granted'
                          : 'Required to show floating icon',
                      action: !_hasPermission
                          ? TextButton(
                              onPressed: _requestPermission,
                              child: const Text('Grant Permission'),
                            )
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Service Status Card
                    _StatusCard(
                      icon: _isServiceRunning
                          ? Icons.play_circle
                          : Icons.stop_circle,
                      iconColor: _isServiceRunning
                          ? Colors.green
                          : colorScheme.outline,
                      title: 'Floating Icon Service',
                      subtitle: _isServiceRunning
                          ? 'Active - look for the floating icon'
                          : 'Not running',
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to use:',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const _InstructionItem(
                          number: '1',
                          text: 'Tap the floating icon once to lock the screen',
                        ),
                        _InstructionItem(number: '2', text: _unlockInstruction),
                        const _InstructionItem(
                          number: '3',
                          text: 'Drag the icon to move it around',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main Action Button
                  if (!_isLoading)
                    FilledButton.icon(
                      onPressed: _hasPermission
                          ? (_isServiceRunning ? _stopService : _startService)
                          : _requestPermission,
                      icon: Icon(
                        _isServiceRunning ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(
                        _hasPermission
                            ? (_isServiceRunning
                                  ? 'Stop Service'
                                  : 'Start Service')
                            : 'Grant Permission First',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _isServiceRunning
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status card widget showing permission or service status
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Instruction item widget
class _InstructionItem extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
