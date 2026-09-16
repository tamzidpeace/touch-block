import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_block/features/overlay_settings/domain/overlay_settings.dart';
import 'package:touch_block/features/overlay_settings/presentation/settings_page.dart';
import 'package:touch_block/features/overlay_settings/presentation/settings_view_model.dart';
import 'package:touch_block/main.dart';

import '../fakes.dart';

void main() {
  testWidgets('Settings page renders all three controls', (tester) async {
    final viewModel = SettingsViewModel(repository: FakeSettingsRepository());

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Floating button'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
    expect(find.text('Double tap'), findsOneWidget);
    expect(find.text('Triple tap'), findsOneWidget);
    expect(find.text('A single tap still locks the screen.'), findsOneWidget);
  });

  testWidgets('Settings action opens the page without starting the service', (
    tester,
  ) async {
    final client = FakeOverlayPlatformClient();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(platformClient: client)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Floating button'), findsOneWidget);
    expect(client.startCalls, 0);
  });

  testWidgets('selecting Triple tap saves without starting the service', (
    tester,
  ) async {
    final repository = FakeSettingsRepository();
    final viewModel = SettingsViewModel(repository: repository);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple tap'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdate?.unlockGesture, UnlockGesture.tripleTap);
    expect(repository.updateCalls, 1);
  });

  testWidgets('opacity is saved when the slider gesture ends', (tester) async {
    final repository = FakeSettingsRepository();
    final viewModel = SettingsViewModel(repository: repository);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdate, isNotNull);
  });

  testWidgets('HomeScreen shows the selected Triple tap instruction', (
    tester,
  ) async {
    final client = FakeOverlayPlatformClient()
      ..settingsResponse = {
        'iconSize': 'medium',
        'opacityPercent': 95,
        'unlockTapCount': 3,
      };

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(platformClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Triple-tap the icon to unlock'), findsOneWidget);
  });
}
