# Touch Block Overlay Settings and Configurable Unlock Gesture

**Date:** 2026-09-03
**Status:** Approved design
**Scope:** Add three user settings to the existing Android overlay workflow:
floating button size, floating button opacity, and the unlock gesture.

## 1. Goal

Let users tune the existing floating overlay without changing Touch Block's
core purpose or requiring a service restart. Settings must be persisted across
app and service restarts and applied immediately while the foreground service is
running.

The selected settings are:

1. **Floating button size**
2. **Floating button opacity**
3. **Unlock gesture**

## 2. Current baseline

Touch Block is an Android-only Flutter app. `lib/main.dart` owns the current
home screen and communicates with Android through the existing
`xyz.arafatpeace.touchblock/overlay` MethodChannel. The native
`FloatingOverlayService` owns the draggable floating `WindowManager` overlay,
the full-screen touch-intercepting overlay, and tap/drag recognition.

The current native implementation has these relevant hardcoded values:

- floating view size: `150 x 150` raw pixels;
- floating view opacity: `0.95f`;
- initial unlock gesture: double tap;
- tap recognition window: `300ms`;
- drag threshold: `10` pixels.

The existing package ID, permissions, service lifecycle, overlay flags,
blocking geometry, and MethodChannel name are not changing.

## 3. Scope and non-goals

### In scope

- A Settings screen reachable from the home screen.
- Size choices: Small, Medium, Large.
- Opacity slider from 40% to 100%.
- Unlock choices: Double tap or Triple tap.
- Native persistence using Android `SharedPreferences`.
- Live application of all three settings while the service is running.
- Applying persisted settings when the service starts later.
- Updated Flutter instructions and foreground-service notification text that
  reflect the selected unlock gesture.

### Out of scope

- Screen dim level.
- Haptic feedback toggle.
- Remembering or resetting the floating button position.
- Configurable tap timing.
- Automatic service startup, auto-stop timers, per-app profiles, or custom
  unlock gestures.
- Changes to overlay flags, blocking-layer geometry, lock colors, or the
  explicit permission/start/stop flow.
- New runtime dependencies or new platform targets.

## 4. Product requirements

| Setting | Options | Default | Stored value | Runtime effect |
|---|---|---|---|---|
| Button size | Small `48dp`, Medium `56dp`, Large `64dp` | Medium | `small`, `medium`, `large` | Updates overlay width, height, and padding |
| Button opacity | 40%–100%, 5% steps | 95% | Integer `40`–`100` | Updates `floatingView.alpha` |
| Unlock gesture | Double tap, Triple tap | Double tap | Integer `2` or `3` | Changes the number of taps required to unlock |

The default Medium size is expressed in density-independent pixels. Native
code converts it to physical pixels before creating or updating
`WindowManager.LayoutParams`. The minimum 48dp size keeps the overlay usable as
an Android touch target. To preserve the current icon-to-button visual ratio,
native padding uses Small `10dp`, Medium `12dp`, and Large `14dp` on all sides.

Opacity is represented as an integer percentage across the platform boundary.
The Flutter slider uses 5% divisions. Native validation clamps values to
40–100 before persisting or returning them.

The tap recognition window remains fixed at `300ms`; it is not exposed as a
setting. Invalid size or gesture values normalize to Medium or Double tap.

## 5. Interaction contract

The existing single-tap lock behavior remains intact:

- When unlocked, one tap starts a pending single-tap lock.
- If no additional tap arrives within 300ms, the screen locks.
- If a second or third tap arrives within the same recognition window, the
  pending single-tap lock is cancelled. A multi-tap sequence while unlocked
  must never accidentally lock the screen.
- When locked, consecutive taps inside the 300ms window are counted.
- Double-tap mode unlocks on the second tap.
- Triple-tap mode remains locked after two taps and unlocks on the third tap.
- A tap sequence expires after the recognition window and starts again from
  one tap.
- Movement beyond the existing drag threshold cancels the pending tap
  sequence; dragging never locks or unlocks the screen.
- After an unlock, remaining taps from the same physical sequence are consumed
  for the rest of that recognition window so a third tap cannot immediately
  lock the screen again.
- Changing the unlock setting while the service is running resets the pending
  tap sequence but does not change the current locked/unlocked state.

The Flutter instruction text must say either “Double-tap the icon to unlock”
or “Triple-tap the icon to unlock” based on the saved setting. The foreground
service notification must use the same instruction while locked.

## 6. User experience

### Entry point

Add a Settings icon button to the right side of the home screen's top bar. It
opens a full-screen `SettingsPage`. Opening Settings must never request overlay
permission or start the foreground service.

### Settings screen

The page contains two focused sections:

#### Floating button

- A three-choice selector labelled Small, Medium, and Large.
- An opacity slider labelled with the current percentage.
- The selected size and opacity are visible without opening another dialog.

The opacity value is previewed locally while the slider moves and is persisted
and sent to Android on slider release. The final value applies without a
service restart.

#### Unlock gesture

- Radio choices for Double tap and Triple tap.
- Supporting text explicitly states that a single tap still locks the screen.
- Selecting a choice persists and applies it immediately when the service is
  running.

The page displays defaults while the initial platform read is pending. A
platform failure leaves the last known state visible and shows a retryable
error message; it must not crash the app or start the service.

## 7. Layered architecture

The implementation follows a small feature-scoped UI/Data/Domain split without
restructuring unrelated parts of the app.

### Domain layer

Create an immutable Dart `OverlaySettings` model with:

- `OverlayIconSize iconSize` (`small`, `medium`, `large`);
- `int opacityPercent` normalized to 40–100;
- `UnlockGesture unlockGesture` (`doubleTap`, `tripleTap`);
- `copyWith`, `fromMap`, and `toMap` helpers.

The model is responsible for safe Dart-side parsing and wire-format
serialization. It does not access Flutter platform APIs.

### Data layer

Create an `OverlayPlatformClient` that owns the existing MethodChannel name and
wraps platform calls for overlay status, service control, and settings. Create
an `OverlaySettingsRepository` that converts platform maps into
`OverlaySettings` and exposes:

```dart
Future<OverlaySettings> getSettings();
Future<OverlaySettingsUpdateResult> updateSettings(
  OverlaySettings settings,
);
```

`OverlaySettingsUpdateResult` contains the normalized settings plus
`serviceRunning` and `liveApplied` flags. This allows the UI to distinguish a
successful persisted update while the service is stopped from a live-update
failure.

The existing home screen service/permission calls should use the shared client
so the MethodChannel name is defined in one Dart location.

### Presentation layer

Create a `SettingsViewModel` extending `ChangeNotifier`. It receives the
repository through its constructor, owns loading/error/status state, and
exposes commands for each setting. `SettingsPage` remains a lean view and
renders the view model with `ListenableBuilder`.

Because the current app does not use a global Flutter dependency-injection
package, the Settings page owns and disposes its view model unless a test
injects one. No new state-management dependency is needed.

### Native data layer

Create `OverlaySettingsStore.kt` backed by an app-private
`SharedPreferences` file. It owns the following keys:

- `overlay_icon_size`
- `overlay_opacity_percent`
- `overlay_unlock_tap_count`

The store returns a complete normalized settings object for every read. It
merges partial updates with the current values, validates every field, and
never throws for an unknown enum value or an out-of-range opacity received from
the platform boundary.

### Native service layer

`FloatingOverlayService` reads `OverlaySettingsStore` before creating the
floating view. It exposes a process-local live-update entry point used only
when an existing service instance is running. `applySettings` runs on the main
thread and:

- converts the selected dp size to pixels;
- updates `floatingParams.width` and `floatingParams.height`;
- updates the matching `ImageView` padding: `10dp`, `12dp`, or `14dp`;
- calls `windowManager.updateViewLayout`;
- updates `floatingView.alpha`;
- updates the gesture recognizer's unlock count and resets its pending state;
- refreshes the notification text.

The service instance is cleared on destruction. A settings update must not
instantiate or start the service.

## 8. MethodChannel contract

All calls use the existing channel:

```text
xyz.arafatpeace.touchblock/overlay
```

### `getOverlaySettings`

Arguments: none.

Returns a complete map:

```json
{
  "iconSize": "medium",
  "opacityPercent": 95,
  "unlockTapCount": 2
}
```

### `updateOverlaySettings`

Arguments: a complete settings map from the repository. Native code may accept
partial maps for forward compatibility, merges them with stored values, and
returns:

```json
{
  "settings": {
    "iconSize": "large",
    "opacityPercent": 80,
    "unlockTapCount": 3
  },
  "serviceRunning": true,
  "liveApplied": true
}
```

When the service is stopped, `serviceRunning` and `liveApplied` are both
`false`, while the update still succeeds and is persisted. If the service is
running but `WindowManager` cannot apply the update, the normalized setting is
still persisted, `serviceRunning` is `true`, and `liveApplied` is `false`; the
Flutter UI shows that the value will be applied on the next service start.

Persistence failures return a `SETTINGS_PERSIST_FAILED` platform error and do
not update the view model's committed state. Malformed field values are
normalized rather than treated as persistence failures.

## 9. Live-update lifecycle

1. `SettingsViewModel` loads settings through `OverlaySettingsRepository`.
2. The user changes one of the three controls.
3. The view model sends the complete current `OverlaySettings` snapshot.
4. `MainActivity` asks `OverlaySettingsStore` to normalize and persist it.
5. If `FloatingOverlayService` has a live instance, `applySettings` runs on
   the main thread.
6. `MainActivity` returns normalized settings and live-application status.
7. The view model publishes the normalized state and a non-blocking status
   message when live application was unavailable or failed.
8. On the next service start, `onCreate` reads the same persisted settings
   before adding the overlay.

The existing service start/stop MethodChannel methods and overlay permission
flow remain unchanged.

## 10. Gesture implementation boundary

The current timestamp comparison in `FloatingOverlayService` should be
replaced with a small testable `TapGestureRecognizer`/state machine. The
recognizer receives tap timestamps, the current blocking state, drag resets,
and the configured unlock count. It returns one of `none`, `scheduleLock`,
`cancelPendingLock`, `lock`, or `unlock` decisions; the Android service owns
the `Handler` used to schedule the 300ms single-tap confirmation.

The recognizer must keep these concerns separate:

- tap counting and timeout decisions are pure state logic;
- `WindowManager` overlay creation/removal remains in the service;
- vibration remains the existing unconditional behavior;
- live settings updates reset recognition state without toggling blocking.

This boundary makes Double tap and Triple tap behavior unit-testable without a
physical overlay window.

## 11. Error handling and compatibility

- Missing preferences produce Medium, 95%, and Double tap defaults.
- Unknown size or gesture values fall back safely.
- Opacity is clamped to 40–100% before it reaches the view.
- Settings screen loading or update errors are recoverable and do not affect
  the service's current state.
- A live-update failure never stops or restarts an active service.
- A stopped service remains stopped after any settings operation.
- Existing users retain the current interaction semantics after upgrading:
  single tap locks, double tap unlocks by default, and dragging is ignored by
  the gesture recognizer.
- The package ID, MethodChannel name, manifest permissions, service type, and
  overlay flags remain unchanged.

## 12. Testing strategy

### Dart automated tests

- `OverlaySettings` defaults, `fromMap`, `toMap`, `copyWith`, and invalid-value
  normalization.
- `OverlaySettingsRepository` maps platform responses and reports live-update
  status correctly using a fake platform client.
- `SettingsViewModel` loads defaults, commits normalized updates, preserves the
  previous state on persistence failure, and shows the live-apply status.
- `SettingsPage` renders all three controls, sends the expected values, keeps
  the unlock explanation visible, and does not start the service.
- `HomeScreen` displays the selected Double tap or Triple tap instruction.

### Android unit tests

- `OverlaySettingsStore` returns defaults for empty preferences.
- Store updates merge fields and normalize invalid size, opacity, and tap
  values.
- `TapGestureRecognizer` locks after one isolated tap while unlocked.
- A second/third tap cancels a pending unlocked-state lock.
- Double tap unlocks in Double tap mode.
- Two taps do not unlock in Triple tap mode; three taps do.
- Timeout resets the tap count.
- Drag reset prevents lock/unlock.
- An extra tap after unlock cannot immediately relock the screen.
- Changing the configured unlock count resets pending recognition state.

### Physical-device verification

On a supported Android device, verify the exact debug/release build:

1. With the service stopped, change all three settings and confirm no overlay
   appears or service starts.
2. Start the service and confirm the saved size and opacity are visible.
3. Change size and opacity while running and confirm the floating view updates
   without disappearing or requiring a restart.
4. Confirm Double tap unlocks on the second tap.
5. Select Triple tap; confirm two taps leave the screen locked and three taps
   unlock it.
6. Confirm a single tap still locks in both modes.
7. Drag the icon and confirm no lock/unlock action occurs.
8. Confirm the notification instruction matches the selected gesture.
9. Stop and start the service; confirm settings persist.
10. Reinstall with defaults and confirm Medium, 95%, and Double tap behavior.

## 13. Acceptance criteria

- A user can open Settings from the home screen and change size, opacity, and
  unlock gesture.
- Every committed setting persists across app and service restarts.
- Size and opacity changes apply immediately while the service is running.
- Unlock gesture changes apply immediately while the service is running.
- The service never starts as a side effect of opening or editing Settings.
- Single tap locks in both unlock modes.
- Double tap and Triple tap unlock exactly at their configured counts.
- Dragging never triggers a lock or unlock action.
- Flutter instructions and the service notification describe the active unlock
  gesture.
- Existing overlay permission and explicit start/stop flows remain intact.
- `flutter analyze`, `flutter test`, Android unit tests, and the physical-device
  verification matrix pass before release.

## 14. Release constraints

- Do not change `xyz.arafatpeace.touchblock` or
  `xyz.arafatpeace.touchblock/overlay`.
- Increment `versionCode` for the release containing this feature.
- Do not commit `android/key.properties`, keystores, or passwords.
- Keep screen dim, haptic, position persistence, auto-stop, and other future
  features out of this change.
