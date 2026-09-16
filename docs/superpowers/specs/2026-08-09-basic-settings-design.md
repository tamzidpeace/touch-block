# Touch Block — Basic Settings and Configurable Unlock Gesture

**Date:** 2026-08-09  
**Status:** Draft for written review  
**Scope:** Add a small settings screen for the existing floating overlay and make the unlock tap count configurable.

## 1. Problem

Touch Block currently has one focused workflow: the user starts a floating overlay service, taps the floating icon once to block touch input, and double-taps the icon to unlock. The service behavior is useful but several user-facing values are hardcoded in `FloatingOverlayService.kt`:

- floating icon size and opacity;
- locked-screen dim amount;
- haptic feedback;
- double-tap unlock behavior.

The app needs a minimal settings surface that lets users tune these values without expanding the product beyond its core use case.

## 2. Goals

- Add a settings screen reachable from the main Flutter screen.
- Let users choose the floating icon size.
- Let users adjust floating icon opacity.
- Let users choose the locked-screen dim level.
- Let users enable or disable haptic feedback.
- Let users choose double-tap or triple-tap as the unlock gesture.
- Let users choose System, Light, or Dark theme for the Flutter UI.
- Persist settings across app and service restarts.
- Apply overlay settings while the service is running when practical; otherwise apply them the next time the user starts the service.
- Preserve the existing explicit user-initiated service start and single-tap lock workflow.

## 3. Non-goals

The initial settings release will not include:

- remembering the floating icon position;
- a reset-position action;
- an auto-stop timer;
- automatic service startup;
- per-app allowlists or profiles;
- volume-button or custom unlock gestures;
- configurable tap timing;
- sound effects or custom icon colors;
- new platform targets or a new persistence dependency unless implementation constraints require one.

## 4. Locked requirements

| Setting | UI | Default |
|---|---|---|
| Floating icon size | Small / Medium / Large | Medium |
| Floating icon opacity | Slider from 40% to 100% | 95% |
| Locked-screen dim | Off / Low / Medium / High | Medium, 20% |
| Haptic feedback | Switch | On |
| Unlock gesture | Double tap / Triple tap | Double tap |
| Flutter UI theme | System / Light / Dark | System |

The existing interaction remains unchanged unless the unlock gesture setting changes it:

- single tap locks the screen;
- the configured tap count unlocks the screen;
- dragging the icon does not count as a tap.

## 5. User experience

The home screen gets a settings affordance in the top app area. The settings screen is grouped into four sections:

### Floating button

- **Size:** a three-choice control for Small, Medium, and Large.
- **Opacity:** a slider labelled with the current percentage and constrained to 40–100%.

The size values are implemented as density-independent dimensions rather than raw pixels so the control behaves consistently across Android devices.

### Locked screen

- **Dim level:** Off, Low, Medium, and High. The initial mapping is 0%, 10%, 20%, and 35% black overlay respectively.
- **Haptic feedback:** controls the existing short vibration on lock and unlock.

### Unlock gesture

- **Double tap:** unlocks on the second tap.
- **Triple tap:** unlocks on the third tap.

The settings copy must explicitly say that single tap still locks the screen. There is no separate configurable lock gesture in this release.

### Appearance

- **Theme:** System, Light, or Dark.

Theme changes affect the Flutter UI only. They do not change the locked overlay color, which remains the existing state-based red/white treatment.

## 6. Gesture behavior

The service will use one internal multi-tap recognition window; tap timing is not user-configurable.

- When unlocked, one tap with no additional tap in the recognition window confirms a lock.
- If additional taps arrive within the window, the pending single-tap lock is cancelled so a double- or triple-tap sequence is not accidentally interpreted as a lock.
- When locked, only the configured tap count unlocks the screen.
- In Double tap mode, the second tap unlocks; a third tap has no additional effect.
- In Triple tap mode, two taps do not unlock; the third tap is required.
- Movement beyond the existing drag threshold continues to cancel tap handling.
- Haptic feedback fires only after a real lock or unlock state transition, and only when enabled.

The implementation must keep the floating icon above the blocking overlay so the configured unlock gesture remains available.

## 7. Architecture

### Flutter settings UI

The Flutter layer owns the settings screen, control state, validation display, and theme selection. It communicates through the existing method channel rather than adding a second platform bridge.

The settings API is intentionally small:

- `getSettings` returns the complete normalized settings map;
- `updateSettings` accepts a partial or complete settings map and returns the normalized result.

The Flutter UI renders defaults while the initial read is pending and replaces them with the persisted values when available. A platform failure keeps the last known values and shows an error message.

### Native settings store

Android owns the persisted source of truth in a small `SharedPreferences`-backed settings store. The store is responsible for:

- default values;
- reading and writing values;
- clamping opacity to 40–100%;
- rejecting unknown enum values;
- normalizing invalid tap counts to Double tap;
- returning a complete settings map to Flutter.

Keeping the overlay configuration native avoids coupling the service to Flutter plugin storage details.

### Overlay service integration

`FloatingOverlayService` reads the normalized settings when it is created. While the service is running, the activity can call a process-local update entry point on the service. The service applies updates on the main thread to:

- the floating view dimensions and alpha;
- the blocking overlay color;
- haptic behavior;
- the tap-count recognizer.

If the service is not running, `updateSettings` only persists the value; it must not start the service implicitly. The next explicit Start Service action reads the saved configuration.

## 8. Data flow

```text
SettingsScreen
    │ getSettings / updateSettings
    ▼
MainActivity MethodChannel handler
    │
    ├── Native settings store → SharedPreferences
    └── if service is running → FloatingOverlayService.applySettings()
                                      │
                                      ├── icon size / opacity
                                      ├── dim overlay
                                      ├── haptic behavior
                                      └── unlock tap count
```

The existing service start/stop method names and overlay permission flow remain unchanged.

## 9. Error handling and compatibility

- Missing preferences use the defined defaults.
- Invalid stored values are normalized rather than crashing the app or service.
- A settings write failure leaves the last successfully saved value visible and reports a retryable error in the Flutter UI.
- A live update failure does not stop or restart the service; the persisted value is used on the next service start.
- Settings must not bypass overlay permission checks or make the service start automatically.
- Existing users upgrading from the current version receive the defaults and retain current behavior: medium-sized icon, 95% opacity, 20% dim, haptic enabled, double-tap unlock, and system theme.

## 10. Testing strategy

### Flutter tests

- Settings screen renders all six controls.
- Defaults are shown when no native values exist.
- Changing each control sends the expected method-channel payload.
- Theme selection changes the Flutter theme mode.
- A method-channel error keeps the UI usable and shows an error state.

### Native tests

- Settings store returns defaults for empty preferences.
- Opacity values are clamped to the supported range.
- Unknown size, dim, theme, and gesture values fall back safely.
- Double-tap mode and triple-tap mode unlock only at the configured count.
- Dragging beyond the threshold never triggers lock or unlock.
- Haptic feedback is skipped when disabled.

### Physical-device verification

On a supported Android device, verify:

1. Each icon size and opacity is visible while the service is running.
2. Each dim level changes the locked overlay without allowing touches through.
3. Haptic feedback toggles correctly.
4. Double tap unlocks in Double tap mode.
5. Two taps do not unlock in Triple tap mode, while three taps do.
6. A drag still repositions the icon without changing lock state.
7. Settings changed while the service is running apply without starting a stopped service.
8. Settings survive stopping and starting the service.
9. The existing overlay permission and explicit Start Service flows still work.

## 11. Acceptance criteria

- A user can open Settings from the home screen and change every in-scope setting.
- All settings persist across app restarts and service restarts.
- The service never starts as a side effect of opening or editing Settings.
- Single tap still locks the screen.
- The selected double- or triple-tap gesture reliably unlocks the screen.
- The configured dim level still intercepts all screen touches except the floating icon.
- Dragging does not trigger a tap action.
- `flutter analyze` reports no new issues.
- Existing widget tests pass, and new settings/gesture tests cover the acceptance behavior.

