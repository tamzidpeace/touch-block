
# Overlay Settings and Configurable Unlock Gesture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add persisted Floating button size, opacity, and Double/Triple-tap unlock settings to Touch Block, with live updates while the Android foreground service is running.

**Architecture:** Keep the existing home screen and Android overlay workflow intact, while adding a feature-scoped Dart Domain/Data/Presentation split. Flutter owns view state and calls a repository; MainActivity owns the existing MethodChannel; Android SharedPreferences owns persistence; FloatingOverlayService owns live application; and a pure Kotlin tap state machine owns gesture decisions.

**Tech Stack:** Flutter/Dart, Material 3 widgets, Kotlin, Android SharedPreferences, the existing Flutter MethodChannel, Android WindowManager, Handler, and JUnit 4 local unit tests. No new runtime package dependency.

**Spec:** docs/superpowers/specs/2026-09-03-overlay-settings-design.md

## Global Constraints

- Do not change the package ID xyz.arafatpeace.touchblock or the MethodChannel name xyz.arafatpeace.touchblock/overlay.
- Button size options are Small 48dp, Medium 56dp, and Large 64dp; default Medium.
- Native padding is Small 10dp, Medium 12dp, and Large 14dp on all sides.
- Opacity is an integer percentage from 40 to 100 in 5% steps; default 95.
- Unlock choices are Double tap and Triple tap; default Double tap.
- The tap recognition window remains fixed at 300ms; it is not exposed as a setting.
- A settings update must not instantiate or start the service.
- Live-update failure must not stop or restart an active service.
- Keep overlay flags, blocking-layer geometry, permissions, service type, and explicit start/stop flow unchanged.
- Keep screen dim, haptic toggle, position persistence, auto-stop, profiles, custom gestures, and other future features out of this change.
- Do not add new runtime dependencies or new platform targets. junit:junit:4.13.2 is test-only if the Android module needs an explicit local-test dependency.
- Every user-visible unlock instruction must be either Double-tap the icon to unlock or Triple-tap the icon to unlock.
- Preserve the existing uncommitted changes in .gitignore, README.md, analysis_options.yaml, android/gradle.properties, and pubspec.lock. Never reset or overwrite them.
- Before release, run flutter analyze, flutter test, Android unit tests, and the physical-device verification matrix.

## File Map

Create these Dart files:

- lib/features/overlay_settings/domain/overlay_settings.dart — immutable enums, model, defaults, normalization, and wire serialization.
- lib/features/overlay_settings/domain/overlay_settings_update_result.dart — normalized settings plus service/live-apply result.
- lib/features/overlay_settings/data/overlay_platform_client.dart — existing MethodChannel name and all overlay/status/settings platform calls.
- lib/features/overlay_settings/data/overlay_settings_repository.dart — platform-map to domain-model conversion.
- lib/features/overlay_settings/presentation/settings_view_model.dart — loading, saving, errors, and non-blocking live-apply status.
- lib/features/overlay_settings/presentation/settings_page.dart — Material 3 Settings UI and local opacity preview.

Create these Dart test files:

- test/features/overlay_settings/domain/overlay_settings_test.dart
- test/features/overlay_settings/data/overlay_settings_repository_test.dart
- test/features/overlay_settings/presentation/settings_view_model_test.dart
- test/features/overlay_settings/presentation/settings_page_test.dart
- test/features/overlay_settings/fakes.dart — shared Dart test doubles for platform and repository tests.

Create these Android files:

- android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlaySettings.kt — native settings value object and enum metadata.
- android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlaySettingsStore.kt — normalized SharedPreferences persistence and a testable preferences adapter.
- android/app/src/main/kotlin/xyz/arafatpeace/touchblock/TapGestureRecognizer.kt — pure tap/timeout state machine.
- android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlayNotificationText.kt — deterministic unlock instruction strings.
- android/app/src/test/kotlin/xyz/arafatpeace/touchblock/OverlaySettingsStoreTest.kt
- android/app/src/test/kotlin/xyz/arafatpeace/touchblock/TapGestureRecognizerTest.kt
- android/app/src/test/kotlin/xyz/arafatpeace/touchblock/OverlayNotificationTextTest.kt

Modify these existing files:

- lib/main.dart — inject the shared platform client, add Settings entry, load the active unlock gesture, and update home instructions.
- android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt — add getOverlaySettings and updateOverlaySettings handlers without starting the service.
- android/app/src/main/kotlin/xyz/arafatpeace/touchblock/FloatingOverlayService.kt — read settings on startup, apply size/opacity/gesture changes live, and use the gesture state machine.
- android/app/build.gradle.kts — add the explicit test-only JUnit dependency.
- README.md — document the three settings and live-apply behavior while preserving existing release notes.
- pubspec.yaml — increment the build number from 1.0.0+1 to 1.0.0+2 for the release containing this feature.

---

### Task 1: Add the Dart overlay settings domain model

**Files:**

- Create: lib/features/overlay_settings/domain/overlay_settings.dart
- Create: lib/features/overlay_settings/domain/overlay_settings_update_result.dart
- Test: test/features/overlay_settings/domain/overlay_settings_test.dart

**Interfaces:**

- Produces OverlayIconSize with small, medium, and large values.
- Produces UnlockGesture with doubleTap and tripleTap values.
- Produces OverlaySettings.defaults with Medium, 95, and Double tap.
- Produces OverlaySettings.fromMap(Map<Object?, Object?>).
- Produces OverlaySettings.copyWith({OverlayIconSize? iconSize, int? opacityPercent, UnlockGesture? unlockGesture}).
- Produces Map<String, Object> toMap() using iconSize, opacityPercent, and unlockTapCount.
- Produces OverlaySettingsUpdateResult with settings, serviceRunning, and liveApplied.

- [ ] Step 1: Write the failing model tests

~~~dart
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
~~~

- [ ] Step 2: Run the domain test and verify it fails

Run from the repository root:

~~~bash
flutter test test/features/overlay_settings/domain/overlay_settings_test.dart
~~~

Expected: FAIL because the domain files and symbols do not exist yet.

- [ ] Step 3: Implement the immutable model

Use @immutable and const constructors. The model must parse unknown enum values as Medium or Double tap, clamp opacity to 40..100, and serialize exactly as follows:

~~~dart
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
~~~

Keep OverlaySettingsUpdateResult as a separate immutable class with the three required fields.

Use this shape in lib/features/overlay_settings/domain/overlay_settings_update_result.dart:

~~~dart
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
}
~~~

- [ ] Step 4: Run the focused test and formatter

~~~bash
flutter test test/features/overlay_settings/domain/overlay_settings_test.dart
dart format lib/features/overlay_settings/domain test/features/overlay_settings/domain
~~~

Expected: all domain tests pass.

- [ ] Step 5: Commit the domain slice

~~~bash
git add lib/features/overlay_settings/domain test/features/overlay_settings/domain
git commit -m "feat: add overlay settings domain model"
~~~

### Task 2: Add native settings values and SharedPreferences storage

**Files:**

- Create: android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlaySettings.kt
- Create: android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlaySettingsStore.kt
- Modify: android/app/build.gradle.kts to add the test-only JUnit dependency.
- Test: android/app/src/test/kotlin/xyz/arafatpeace/touchblock/OverlaySettingsStoreTest.kt

**Interfaces:**

- Produces native OverlayIconSize values with wire names, size dp, and padding dp.
- Produces native OverlaySettings(iconSize, opacityPercent, unlockTapCount).
- Produces OverlaySettingsStore(Context).read(): OverlaySettings.
- Produces OverlaySettingsStore.update(Map<*, *>): OverlaySettings.
- Produces SettingsPersistenceException when SharedPreferences.Editor.commit() returns false.

- [ ] Step 1: Add the test-only JUnit dependency and write failing store tests

Add a dependencies block if one is absent, then add this test-only dependency:

~~~kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
}
~~~

Write tests against an in-memory OverlaySettingsPreferences fake. The fake stores the current native value and has a configurable commit result, so tests do not need Android framework objects:

~~~kotlin
class OverlaySettingsStoreTest {
    @Test
    fun emptyPreferencesReturnSafeDefaults() {
        val store = OverlaySettingsStore(FakeOverlaySettingsPreferences())

        assertEquals(OverlaySettings.DEFAULT, store.read())
    }

    @Test
    fun updateMergesMissingFieldsAndClampsOpacity() {
        val preferences = FakeOverlaySettingsPreferences(
            OverlaySettings(
                iconSize = OverlayIconSize.SMALL,
                opacityPercent = 70,
                unlockTapCount = 3,
            ),
        )
        val store = OverlaySettingsStore(preferences)

        val result = store.update(mapOf("opacityPercent" to 1000))

        assertEquals(OverlayIconSize.SMALL, result.iconSize)
        assertEquals(100, result.opacityPercent)
        assertEquals(3, result.unlockTapCount)
        assertEquals(result, store.read())
    }

    @Test
    fun invalidEnumAndTapValuesUseMediumAndDoubleTap() {
        val store = OverlaySettingsStore(FakeOverlaySettingsPreferences())

        val result = store.update(
            mapOf(
                "iconSize" to "not-a-size",
                "opacityPercent" to 40,
                "unlockTapCount" to 9,
            ),
        )

        assertEquals(OverlayIconSize.MEDIUM, result.iconSize)
        assertEquals(40, result.opacityPercent)
        assertEquals(2, result.unlockTapCount)
    }

    @Test(expected = SettingsPersistenceException::class)
    fun failedCommitIsReported() {
        val store = OverlaySettingsStore(
            FakeOverlaySettingsPreferences(commitResult = false),
        )

        store.update(mapOf("opacityPercent" to 80))
    }
}
~~~

Start the test file with package xyz.arafatpeace.touchblock and imports for org.junit.Assert.assertEquals and org.junit.Test. Add this complete in-memory adapter after the test class:

~~~kotlin
private class FakeOverlaySettingsPreferences(
    initial: OverlaySettings = OverlaySettings.DEFAULT,
    private val commitResult: Boolean = true,
) : OverlaySettingsPreferences {
    private var value = initial

    override fun readString(key: String, defaultValue: String?): String? =
        when (key) {
            "overlay_icon_size" -> value.iconSize.wireValue
            else -> defaultValue
        }

    override fun readInt(key: String, defaultValue: Int): Int =
        when (key) {
            "overlay_opacity_percent" -> value.opacityPercent
            "overlay_unlock_tap_count" -> value.unlockTapCount
            else -> defaultValue
        }

    override fun save(settings: OverlaySettings): Boolean {
        if (commitResult) value = settings
        return commitResult
    }
}
~~~

- [ ] Step 2: Run the focused Android test and verify it fails

Run from android/:

~~~bash
./gradlew :app:testDebugUnitTest --tests xyz.arafatpeace.touchblock.OverlaySettingsStoreTest
~~~

Expected: FAIL because the native settings classes and test adapter do not exist yet.

- [ ] Step 3: Implement the native model and store

Use these exact enum metadata and normalization rules:

~~~kotlin
enum class OverlayIconSize(
    val wireValue: String,
    val sizeDp: Int,
    val paddingDp: Int,
) {
    SMALL("small", 48, 10),
    MEDIUM("medium", 56, 12),
    LARGE("large", 64, 14),
}

data class OverlaySettings(
    val iconSize: OverlayIconSize = OverlayIconSize.MEDIUM,
    val opacityPercent: Int = 95,
    val unlockTapCount: Int = 2,
) {
    fun normalized(): OverlaySettings = copy(
        opacityPercent = opacityPercent.coerceIn(40, 100),
        unlockTapCount = if (unlockTapCount == 3) 3 else 2,
    )

    fun toMap(): Map<String, Any> = mapOf(
        "iconSize" to iconSize.wireValue,
        "opacityPercent" to opacityPercent,
        "unlockTapCount" to unlockTapCount,
    )

    companion object {
        val DEFAULT = OverlaySettings()

        fun fromMap(
            values: Map<*, *>,
            fallback: OverlaySettings = DEFAULT,
        ): OverlaySettings {
            val iconSize = if (values.containsKey("iconSize")) {
                OverlayIconSize.entries.firstOrNull {
                    it.wireValue == values["iconSize"]
                } ?: OverlayIconSize.MEDIUM
            } else {
                fallback.iconSize
            }
            val opacity = if (values.containsKey("opacityPercent")) {
                (values["opacityPercent"] as? Number)?.toInt()
                    ?: fallback.opacityPercent
            } else {
                fallback.opacityPercent
            }
            val taps = if (values.containsKey("unlockTapCount")) {
                (values["unlockTapCount"] as? Number)?.toInt()
                    ?.takeIf { it == 2 || it == 3 } ?: 2
            } else {
                fallback.unlockTapCount
            }
            return OverlaySettings(iconSize, opacity, taps).normalized()
        }
    }
}
~~~

Implement OverlaySettingsStore with preference file name touch_block_overlay_settings and keys overlay_icon_size, overlay_opacity_percent, and overlay_unlock_tap_count. The Context constructor must use context.applicationContext and Context.MODE_PRIVATE. Keep an internal OverlaySettingsPreferences adapter with readString, readInt, and save. The production adapter must call Editor.commit() and return its Boolean result. update must read current values, merge the incoming map, normalize, save, and throw SettingsPersistenceException when save returns false.

- [ ] Step 4: Run the native store tests

~~~bash
./gradlew :app:testDebugUnitTest --tests xyz.arafatpeace.touchblock.OverlaySettingsStoreTest
~~~

Expected: all store tests pass, including merge preservation and failed-commit reporting.

- [ ] Step 5: Commit the native storage slice

~~~bash
git add android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlaySettings.kt android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlaySettingsStore.kt android/app/src/test/kotlin/xyz/arafatpeace/touchblock/OverlaySettingsStoreTest.kt android/app/build.gradle.kts
git commit -m "feat: persist overlay settings on Android"
~~~

### Task 3: Add and test the pure tap gesture state machine

**Files:**

- Create: android/app/src/main/kotlin/xyz/arafatpeace/touchblock/TapGestureRecognizer.kt
- Test: android/app/src/test/kotlin/xyz/arafatpeace/touchblock/TapGestureRecognizerTest.kt

**Interfaces:**

- Produces TapDecision with NONE, SCHEDULE_LOCK, CANCEL_PENDING_LOCK, LOCK, and UNLOCK.
- Produces TapGestureRecognizer(unlockTapCount: Int, tapWindowMs: Long = 300L).
- Produces onTap(timestampMs: Long, isBlocking: Boolean): TapDecision.
- Produces onLockTimeout(timestampMs: Long): TapDecision.
- Produces updateUnlockTapCount(tapCount: Int) and reset().

- [ ] Step 1: Write failing recognizer tests

~~~kotlin
class TapGestureRecognizerTest {
    @Test
    fun isolatedTapWhileUnlockedLocksAfterTimeout() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(100, false))
        assertEquals(TapDecision.LOCK, recognizer.onLockTimeout(400))
    }

    @Test
    fun multiTapWhileUnlockedCancelsPendingLock() {
        val recognizer = TapGestureRecognizer(3)

        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(100, false))
        assertEquals(TapDecision.CANCEL_PENDING_LOCK, recognizer.onTap(200, false))
        assertEquals(TapDecision.NONE, recognizer.onTap(250, false))
        assertEquals(TapDecision.NONE, recognizer.onLockTimeout(400))
    }

    @Test
    fun doubleTapUnlocksOnSecondTap() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(200, true))
    }

    @Test
    fun tripleTapNeedsThreeTaps() {
        val recognizer = TapGestureRecognizer(3)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(200, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(250, true))
    }

    @Test
    fun sequenceExpiresAndStartsAgain() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(500, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(600, true))
    }

    @Test
    fun resetCancelsASequenceAfterDrag() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(100, false))
        recognizer.reset()

        assertEquals(TapDecision.NONE, recognizer.onLockTimeout(400))
    }

    @Test
    fun tapAfterUnlockIsConsumedWithinTheSameWindow() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(200, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(250, false))
        assertEquals(TapDecision.SCHEDULE_LOCK, recognizer.onTap(501, false))
    }

    @Test
    fun changingUnlockCountResetsPendingRecognition() {
        val recognizer = TapGestureRecognizer(2)

        assertEquals(TapDecision.NONE, recognizer.onTap(100, true))
        recognizer.updateUnlockTapCount(3)

        assertEquals(TapDecision.NONE, recognizer.onTap(200, true))
        assertEquals(TapDecision.NONE, recognizer.onTap(250, true))
        assertEquals(TapDecision.UNLOCK, recognizer.onTap(275, true))
    }
}
~~~

- [ ] Step 2: Run the focused recognizer test and verify it fails

~~~bash
./gradlew :app:testDebugUnitTest --tests xyz.arafatpeace.touchblock.TapGestureRecognizerTest
~~~

Expected: FAIL because the recognizer and decisions do not exist yet.

- [ ] Step 3: Implement deterministic tap and timeout transitions

Keep state independent from WindowManager and Android views. The state machine must:

- Return SCHEDULE_LOCK for the first unlocked tap.
- Return CANCEL_PENDING_LOCK for the next tap within 300ms while unlocked, suppressing remaining taps in that physical sequence.
- Return LOCK only from a valid onLockTimeout call.
- Count consecutive locked taps inside 300ms and return UNLOCK exactly on the configured second or third tap.
- Reset locked count when the time window expires.
- After UNLOCK, consume taps until timestamp plus 300ms so an extra physical tap cannot relock.
- reset all sequence state; updateUnlockTapCount normalizes to 2 or 3 and calls reset.

Use a generation or exact Runnable reference in the service so an old Handler callback cannot act on a newer sequence.

Use this state shape and transition implementation:

~~~kotlin
internal enum class TapDecision {
    NONE,
    SCHEDULE_LOCK,
    CANCEL_PENDING_LOCK,
    LOCK,
    UNLOCK,
}

internal class TapGestureRecognizer(
    unlockTapCount: Int,
    private val tapWindowMs: Long = 300L,
) {
    private var requiredUnlockTaps = if (unlockTapCount == 3) 3 else 2
    private var pendingLockAt: Long? = null
    private var lockedTapCount = 0
    private var lastLockedTapAt: Long? = null
    private var consumeUntilMs: Long? = null

    fun onTap(timestampMs: Long, isBlocking: Boolean): TapDecision {
        if (!isBlocking) {
            val ignoredUntil = consumeUntilMs
            if (ignoredUntil != null && timestampMs < ignoredUntil) {
                return TapDecision.NONE
            }
            consumeUntilMs = null

            val firstTapAt = pendingLockAt
            if (firstTapAt == null || timestampMs - firstTapAt >= tapWindowMs) {
                pendingLockAt = timestampMs
                return TapDecision.SCHEDULE_LOCK
            }

            pendingLockAt = null
            consumeUntilMs = firstTapAt + tapWindowMs
            return TapDecision.CANCEL_PENDING_LOCK
        }

        pendingLockAt = null
        val lastTapAt = lastLockedTapAt
        lockedTapCount = if (lastTapAt == null || timestampMs - lastTapAt >= tapWindowMs) {
            1
        } else {
            lockedTapCount + 1
        }
        lastLockedTapAt = timestampMs

        if (lockedTapCount < requiredUnlockTaps) return TapDecision.NONE

        lockedTapCount = 0
        lastLockedTapAt = null
        consumeUntilMs = timestampMs + tapWindowMs
        return TapDecision.UNLOCK
    }

    fun onLockTimeout(timestampMs: Long): TapDecision {
        val firstTapAt = pendingLockAt ?: return TapDecision.NONE
        if (timestampMs - firstTapAt < tapWindowMs) return TapDecision.NONE

        pendingLockAt = null
        return TapDecision.LOCK
    }

    fun updateUnlockTapCount(tapCount: Int) {
        requiredUnlockTaps = if (tapCount == 3) 3 else 2
        reset()
    }

    fun reset() {
        pendingLockAt = null
        lockedTapCount = 0
        lastLockedTapAt = null
        consumeUntilMs = null
    }
}
~~~

- [ ] Step 4: Run all recognizer tests

~~~bash
./gradlew :app:testDebugUnitTest --tests xyz.arafatpeace.touchblock.TapGestureRecognizerTest
~~~

Expected: all eight recognizer tests pass.

- [ ] Step 5: Commit the gesture slice

~~~bash
git add android/app/src/main/kotlin/xyz/arafatpeace/touchblock/TapGestureRecognizer.kt android/app/src/test/kotlin/xyz/arafatpeace/touchblock/TapGestureRecognizerTest.kt
git commit -m "feat: add configurable tap gesture recognition"
~~~

### Task 4: Add the Flutter platform client and settings repository

**Files:**

- Create: lib/features/overlay_settings/data/overlay_platform_client.dart
- Create: lib/features/overlay_settings/data/overlay_settings_repository.dart
- Create: test/features/overlay_settings/fakes.dart
- Test: test/features/overlay_settings/data/overlay_settings_repository_test.dart

**Interfaces:**

- OverlayPlatformClient exposes checkOverlayPermission, requestOverlayPermission, startService, stopService, isServiceRunning, getOverlaySettings, and updateOverlaySettings.
- MethodChannelOverlayPlatformClient uses exactly xyz.arafatpeace.touchblock/overlay.
- OverlaySettingsRepository exposes getSettings() and updateSettings(OverlaySettings settings).
- MethodChannelOverlaySettingsRepository accepts a required OverlayPlatformClient.

- [ ] Step 1: Write failing repository tests with a fake platform client

Create test/features/overlay_settings/fakes.dart with the shared fakes below, including imports for the platform client, repository, domain model, and update result. Import that file from repository, ViewModel, and page tests. FakeOverlayPlatformClient must record the last update map and service start calls; FakeSettingsRepository must record the last settings update and update calls.

~~~dart
class FakeOverlayPlatformClient implements OverlayPlatformClient {
  Map<String, Object?> settingsResponse = {
    'iconSize': 'medium',
    'opacityPercent': 95,
    'unlockTapCount': 2,
  };
  Map<String, Object?> updateResponse = {
    'settings': {
      'iconSize': 'large',
      'opacityPercent': 80,
      'unlockTapCount': 3,
    },
    'serviceRunning': true,
    'liveApplied': true,
  };
  Map<String, Object?>? lastUpdate;
  int startCalls = 0;

  @override
  Future<Map<String, Object?>> getOverlaySettings() async => settingsResponse;

  @override
  Future<Map<String, Object?>> updateOverlaySettings(
    Map<String, Object?> settings,
  ) async {
    lastUpdate = settings;
    return updateResponse;
  }

  @override
  Future<bool> checkOverlayPermission() async => true;

  @override
  Future<bool> requestOverlayPermission() async => true;

  @override
  Future<bool> startService() async {
    startCalls++;
    return true;
  }

  @override
  Future<bool> stopService() async => true;

  @override
  Future<bool> isServiceRunning() async => false;
}

class FakeSettingsRepository implements OverlaySettingsRepository {
  OverlaySettings loaded = OverlaySettings.defaults;
  OverlaySettingsUpdateResult? nextUpdate;
  OverlaySettings? lastUpdate;
  Object? loadError;
  Object? updateError;
  int updateCalls = 0;

  @override
  Future<OverlaySettings> getSettings() async {
    if (loadError != null) throw loadError!;
    return loaded;
  }

  @override
  Future<OverlaySettingsUpdateResult> updateSettings(
    OverlaySettings settings,
  ) async {
    if (updateError != null) throw updateError!;
    updateCalls++;
    lastUpdate = settings;
    return nextUpdate ?? OverlaySettingsUpdateResult(
      settings: settings,
      serviceRunning: false,
      liveApplied: false,
    );
  }
}

~~~

In test/features/overlay_settings/data/overlay_settings_repository_test.dart, add the imports and tests below after importing the shared fakes:

~~~dart
void main() {
  test('repository parses settings and update status', () async {
    final client = FakeOverlayPlatformClient();
    final repository = MethodChannelOverlaySettingsRepository(client: client);

    expect(await repository.getSettings(), OverlaySettings.defaults);

    final result = await repository.updateSettings(
      OverlaySettings.defaults.copyWith(
        iconSize: OverlayIconSize.large,
        opacityPercent: 80,
        unlockGesture: UnlockGesture.tripleTap,
      ),
    );

    expect(client.lastUpdate?['unlockTapCount'], 3);
    expect(result.settings.iconSize, OverlayIconSize.large);
    expect(result.settings.opacityPercent, 80);
    expect(result.settings.unlockGesture, UnlockGesture.tripleTap);
    expect(result.serviceRunning, isTrue);
    expect(result.liveApplied, isTrue);
  });

  test('repository rejects an update response without settings', () async {
    final client = FakeOverlayPlatformClient()
      ..updateResponse = {
        'serviceRunning': false,
        'liveApplied': false,
      };
    final repository = MethodChannelOverlaySettingsRepository(client: client);

    expect(
      () => repository.updateSettings(OverlaySettings.defaults),
      throwsA(isA<FormatException>()),
    );
  });
}
~~~

- [ ] Step 2: Run the focused repository test and verify it fails

~~~bash
flutter test test/features/overlay_settings/data/overlay_settings_repository_test.dart
~~~

Expected: FAIL because the client and repository do not exist yet.

- [ ] Step 3: Implement the client and repository

Define the client as:

~~~dart
abstract interface class OverlayPlatformClient {
  Future<bool> checkOverlayPermission();
  Future<bool> requestOverlayPermission();
  Future<bool> startService();
  Future<bool> stopService();
  Future<bool> isServiceRunning();
  Future<Map<String, Object?>> getOverlaySettings();
  Future<Map<String, Object?>> updateOverlaySettings(
    Map<String, Object?> settings,
  );
}
~~~

MethodChannelOverlayPlatformClient must have one channel constant, retain all five existing method names, use invokeMethod<Object?>, and throw FormatException when a settings result is not a Map. The repository must parse payload['settings'], use OverlaySettings.fromMap, and convert serviceRunning/liveApplied with == true.

- [ ] Step 4: Run repository tests and formatter

~~~bash
flutter test test/features/overlay_settings/data/overlay_settings_repository_test.dart
dart format lib/features/overlay_settings/data test/features/overlay_settings/data
~~~

Expected: all repository tests pass.

- [ ] Step 5: Commit the platform data slice

~~~bash
git add lib/features/overlay_settings/data test/features/overlay_settings/data test/features/overlay_settings/fakes.dart
git commit -m "feat: add overlay settings platform repository"
~~~

### Task 5: Add the Settings ViewModel

**Files:**

- Create: lib/features/overlay_settings/presentation/settings_view_model.dart
- Test: test/features/overlay_settings/presentation/settings_view_model_test.dart

**Interfaces:**

- Produces SettingsViewModel({required OverlaySettingsRepository repository}).
- Exposes OverlaySettings settings, bool isLoading, bool isSaving, String? errorMessage, and String? statusMessage.
- Produces load(), retry(), updateIconSize(), updateOpacity(), and updateUnlockGesture().

- [ ] Step 1: Write failing ViewModel tests

Test these behaviors with a fake repository:

~~~dart
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

test('running-service live failure keeps settings and shows restart status', () async {
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
~~~

Use FakeSettingsRepository from test/features/overlay_settings/fakes.dart; it exposes loaded, nextUpdate, lastUpdate, loadError, updateError, and updateCalls.

- [ ] Step 2: Run the focused ViewModel test and verify it fails

~~~bash
flutter test test/features/overlay_settings/presentation/settings_view_model_test.dart
~~~

Expected: FAIL because SettingsViewModel does not exist yet.

- [ ] Step 3: Implement ChangeNotifier state transitions

Initialize settings with OverlaySettings.defaults. load must set isLoading, clear the previous error, publish the repository result only on success, and keep defaults or the last known state on failure. Updates must not replace the committed state until the repository returns successfully:

~~~dart
Future<void> _update(OverlaySettings next) async {
  if (_isLoading || _isSaving) return;
  _isSaving = true;
  _errorMessage = null;
  _statusMessage = null;
  notifyListeners();

  try {
    final result = await repository.updateSettings(next);
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
~~~

Use private fields with public getters in the actual class. updateOpacity receives the integer value from Slider.onChangeEnd and clamps through OverlaySettings.copyWith. retry calls load. No ViewModel method may call a service-start method.

- [ ] Step 4: Run ViewModel tests and formatter

~~~bash
flutter test test/features/overlay_settings/presentation/settings_view_model_test.dart
dart format lib/features/overlay_settings/presentation/settings_view_model.dart test/features/overlay_settings/presentation/settings_view_model_test.dart
~~~

Expected: all ViewModel tests pass.

- [ ] Step 5: Commit the ViewModel slice

~~~bash
git add lib/features/overlay_settings/presentation/settings_view_model.dart test/features/overlay_settings/presentation/settings_view_model_test.dart
git commit -m "feat: manage overlay settings state"
~~~

### Task 6: Add notification copy and integrate native live application

**Files:**

- Create: android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlayNotificationText.kt
- Modify: android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt
- Modify: android/app/src/main/kotlin/xyz/arafatpeace/touchblock/FloatingOverlayService.kt
- Test: android/app/src/test/kotlin/xyz/arafatpeace/touchblock/OverlayNotificationTextTest.kt

**Interfaces:**

- Produces OverlayNotificationText.unlockInstruction(unlockTapCount: Int): String.
- Produces FloatingOverlayService.applySettings(settings: OverlaySettings): Boolean.
- MainActivity persists settings first and returns settings, serviceRunning, and liveApplied.

- [ ] Step 1: Write failing notification-copy tests

~~~kotlin
@Test
fun doubleTapInstructionIsStable() {
    assertEquals(
        "Double-tap the icon to unlock",
        OverlayNotificationText.unlockInstruction(2),
    )
}

@Test
fun tripleTapInstructionIsStable() {
    assertEquals(
        "Triple-tap the icon to unlock",
        OverlayNotificationText.unlockInstruction(3),
    )
}

@Test
fun invalidTapCountUsesDoubleTapCopy() {
    assertEquals(
        "Double-tap the icon to unlock",
        OverlayNotificationText.unlockInstruction(9),
    )
}
~~~

- [ ] Step 2: Run the notification test and verify it fails

~~~bash
./gradlew :app:testDebugUnitTest --tests xyz.arafatpeace.touchblock.OverlayNotificationTextTest
~~~

Expected: FAIL because OverlayNotificationText does not exist yet.

- [ ] Step 3: Implement notification copy and wire it into the service

~~~kotlin
internal object OverlayNotificationText {
    fun unlockInstruction(unlockTapCount: Int): String =
        if (unlockTapCount == 3) {
            "Triple-tap the icon to unlock"
        } else {
            "Double-tap the icon to unlock"
        }
}
~~~

Use the helper for the locked notification text: Screen is locked - followed by the helper result. Leave the unlocked notification text unchanged.

- [ ] Step 4: Add the two settings handlers to MainActivity

Create one application-scoped OverlaySettingsStore. Add these branches to the existing channel handler:

~~~kotlin
"getOverlaySettings" -> {
    result.success(settingsStore.read().toMap())
}
"updateOverlaySettings" -> {
    try {
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val normalized = settingsStore.update(arguments)
        val running = FloatingOverlayService.isRunning
        val liveApplied = if (running) {
            FloatingOverlayService.applySettings(normalized)
        } else {
            false
        }
        result.success(
            mapOf(
                "settings" to normalized.toMap(),
                "serviceRunning" to running,
                "liveApplied" to liveApplied,
            ),
        )
    } catch (_: SettingsPersistenceException) {
        result.error(
            "SETTINGS_PERSIST_FAILED",
            "Could not persist overlay settings",
            null,
        )
    }
}
~~~

Use applicationContext for the store. Do not call startFloatingService from either branch. Catch live view failures inside FloatingOverlayService so persistence remains successful and liveApplied is false.

- [ ] Step 5: Make the service consume settings before creating its view

Add a settings value, OverlaySettingsStore, TapGestureRecognizer, main-thread Handler, pending lock Runnable, and process-local instance. In onCreate, read settings before startForeground and createFloatingIcon. Initialize the recognizer with settings.unlockTapCount. In onDestroy, cancel callbacks, clear the instance, and remove the existing views.

Use TypedValue.applyDimension with COMPLEX_UNIT_DIP for sizeDp and paddingDp. Set floatingParams.width/height, ImageView padding, and alpha, then call windowManager.updateViewLayout. Apply the new gesture count with updateUnlockTapCount and reset the pending lock state. Refresh the notification. Return false when the floating view is unavailable or a WindowManager update throws.

- [ ] Step 6: Replace timestamp comparison with recognizer decisions

Keep DRAG_THRESHOLD at 10 and preserve the current overlay flags and blocking geometry. On movement past the threshold, call recognizer.reset() and cancelPendingLock(). Map decisions as follows:

~~~kotlin
when (recognizer.onTap(System.currentTimeMillis(), isBlocking)) {
    TapDecision.SCHEDULE_LOCK -> scheduleLockConfirmation()
    TapDecision.CANCEL_PENDING_LOCK -> cancelPendingLock()
    TapDecision.LOCK -> setBlocking(true)
    TapDecision.UNLOCK -> setBlocking(false)
    TapDecision.NONE -> Unit
}
~~~

scheduleLockConfirmation must use the existing Handler and 300ms delay, call onLockTimeout, and call setBlocking(true) only for LOCK. cancelPendingLock must remove the exact Runnable. setBlocking must preserve the current vibration, blocking overlay creation/removal, icon-state update, and notification update.

- [ ] Step 7: Run all native unit tests

~~~bash
./gradlew :app:testDebugUnitTest
~~~

Expected: store, recognizer, and notification tests pass. The diff must not modify AndroidManifest.xml, permissions, package ID, channel name, overlay flags, or blocking-layer geometry.

- [ ] Step 8: Commit native integration

~~~bash
git add android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt android/app/src/main/kotlin/xyz/arafatpeace/touchblock/FloatingOverlayService.kt android/app/src/main/kotlin/xyz/arafatpeace/touchblock/OverlayNotificationText.kt android/app/src/test/kotlin/xyz/arafatpeace/touchblock/OverlayNotificationTextTest.kt
git commit -m "feat: apply overlay settings live in service"
~~~

### Task 7: Build the Settings page and connect it to HomeScreen

**Files:**

- Create: lib/features/overlay_settings/presentation/settings_page.dart
- Create: test/features/overlay_settings/presentation/settings_page_test.dart
- Modify: lib/main.dart

**Interfaces:**

- Produces SettingsPage({SettingsViewModel? viewModel, OverlaySettingsRepository? repository}).
- Assert that viewModel and repository are not both supplied; create the repository-backed ViewModel when viewModel is omitted.
- SettingsPage owns and disposes a ViewModel only when it created that ViewModel.
- TouchBlockApp and HomeScreen accept an injectable OverlayPlatformClient and default to MethodChannelOverlayPlatformClient.

- [ ] Step 1: Write failing Settings page and Home instruction tests

Use a fake repository and fake platform client. Do not rely on a real MethodChannel in widget tests:

~~~dart
testWidgets('Settings page renders all three controls', (tester) async {
  final viewModel = SettingsViewModel(
    repository: FakeSettingsRepository(),
  );

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

testWidgets('opacity is saved when the slider gesture ends', (tester) async {
  final repository = FakeSettingsRepository();
  final viewModel = SettingsViewModel(repository: repository);

  await tester.pumpWidget(
    MaterialApp(home: SettingsPage(viewModel: viewModel)),
  );
  await tester.pumpAndSettle();

  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(Slider)),
  );
  await gesture.moveBy(const Offset(80, 0));
  await tester.pump();
  expect(repository.updateCalls, 0);
  await gesture.up();
  await tester.pumpAndSettle();

  expect(repository.updateCalls, 1);
});

testWidgets('Settings action opens the page without starting the service',
    (tester) async {
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

testWidgets('selecting Triple tap saves without starting the service',
    (tester) async {
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

testWidgets('HomeScreen shows the selected Triple tap instruction',
    (tester) async {
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
~~~

Import FakeSettingsRepository and FakeOverlayPlatformClient from test/features/overlay_settings/fakes.dart. The fake platform client must return permission true, service-running false, and the configured settings map; its startCalls value must remain zero after opening and editing Settings.

- [ ] Step 2: Run the focused widget tests and verify they fail

~~~bash
flutter test test/features/overlay_settings/presentation/settings_page_test.dart
~~~

Expected: FAIL because SettingsPage, injectable clients, and dynamic home instructions do not exist yet.

- [ ] Step 3: Implement the Settings page with local opacity preview

Use ListenableBuilder and no new state-management package. Render:

- AppBar titled Settings.
- A Floating button section with SegmentedButton<OverlayIconSize> for Small, Medium, and Large.
- An Opacity section with Slider(min: 40, max: 100, divisions: 12) and a percentage label.
- An Unlock gesture section with RadioListTile<UnlockGesture> for Double tap and Triple tap.
- Supporting text exactly A single tap still locks the screen.
- Inline retryable error text and Retry button when errorMessage is non-null.
- Non-blocking statusMessage text below the controls.

Keep _draftOpacity local to the page. Slider.onChanged updates only _draftOpacity; Slider.onChangeEnd clears the draft and awaits viewModel.updateOpacity(value.round()). Disable controls while loading or saving, but never call a service-start method from the page. The page must load settings on entry and must never request overlay permission.

- [ ] Step 4: Add the Settings entry point and dynamic instruction text to main.dart

Refactor the five existing status/service calls in _HomeScreenState to use widget.platformClient. During _checkStatus, also read getOverlaySettings() and parse it with OverlaySettings.fromMap; retain the last known/default Double tap instruction if that read fails.

Add an IconButton with tooltip Settings at the top-right of the existing home content. Open the page with the same client:

~~~dart
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
~~~

Replace the hardcoded unlock instruction with the active Double tap or Triple tap text. Keep permission requests and explicit start/stop behavior unchanged. Update TouchBlockApp to pass its injectable client to HomeScreen.

- [ ] Step 5: Run widget tests, all Flutter tests, analyzer, and formatter

~~~bash
flutter test test/features/overlay_settings/presentation/settings_page_test.dart
flutter test
flutter analyze
dart format lib test
~~~

Expected: focused tests and the complete Flutter suite pass; flutter analyze reports zero issues.

- [ ] Step 6: Commit the Flutter UI slice

~~~bash
git add lib/features/overlay_settings/presentation/settings_page.dart lib/main.dart test/features/overlay_settings/presentation/settings_page_test.dart
git commit -m "feat: add overlay settings screen"
~~~

### Task 8: Document, version, and verify the Play Store candidate

**Files:**

- Modify: README.md
- Modify: pubspec.yaml

**Interfaces:**

- README documents the three shipped settings, defaults, fixed 300ms gesture window, and live-apply behavior.
- pubspec.yaml changes version 1.0.0+1 to version 1.0.0+2.

- [ ] Step 1: Add concise user/developer documentation

Append this Settings section to README.md without removing existing release information:

~~~markdown
## Settings

Touch Block provides three settings:

- Floating button size: Small (48dp), Medium (56dp), or Large (64dp).
- Floating button opacity: 40% to 100% in 5% steps; default 95%.
- Unlock gesture: Double tap or Triple tap; default Double tap.

Single tap locks the screen in both unlock modes. The tap window is fixed at
300ms. Settings persist across restarts and size, opacity, and unlock changes
apply immediately while the foreground service is running. Editing Settings
never starts the service.
~~~

- [ ] Step 2: Increment the Android build number

Change only the version line in pubspec.yaml:

~~~yaml
version: 1.0.0+2
~~~

Do not add signing files, keystores, passwords, or android/key.properties.

- [ ] Step 3: Run complete automated verification

Run each command from the specified directory:

~~~bash
# repository root
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test

# android/
./gradlew :app:testDebugUnitTest

# repository root
flutter build apk --release
git diff --check
~~~

Expected: every command exits with status 0; analyzer has zero issues; Flutter and Android test suites pass; and a release APK is produced. A missing release keystore must not be solved by committing credentials.

- [ ] Step 4: Execute the physical-device verification matrix

Install the exact release APK on a supported Android device and verify:

1. With the service stopped, change all three settings; no overlay appears and the service does not start.
2. Start the service; saved size and opacity are visible.
3. Change size and opacity while running; the floating view updates without disappearing or restarting.
4. In Double tap mode, the second tap unlocks.
5. In Triple tap mode, two taps keep the screen locked and three taps unlock it.
6. A single tap locks in both modes.
7. Dragging the icon never locks or unlocks.
8. The foreground notification matches the selected unlock gesture.
9. Stop and start the service; settings remain persisted.
10. Reinstall the app; defaults are Medium, 95%, and Double tap.

- [ ] Step 5: Review final diff and commit release documentation

~~~bash
git status --short
git diff --stat
git diff --check
git diff -- README.md pubspec.yaml
git add README.md pubspec.yaml
git commit -m "chore: prepare overlay settings release"
~~~

Confirm the final feature diff contains no changes to AndroidManifest.xml, the package ID, the MethodChannel name, overlay flags, or blocking-layer geometry. Keep unrelated pre-existing working-tree changes unstaged.

## Final Acceptance Checklist

- [ ] Settings opens from HomeScreen without requesting permission or starting the service.
- [ ] Small/Medium/Large persist as small/medium/large with exact dp and padding values.
- [ ] Opacity persists as 40..100 integer percentage values in 5% UI steps.
- [ ] Double/Triple tap persists as 2/3 and updates the recognizer live.
- [ ] Running-service size and opacity updates call updateViewLayout and alpha without service restart.
- [ ] Stopped-service updates persist without starting the service.
- [ ] Single tap locks; Double tap and Triple tap unlock at exactly their configured counts.
- [ ] Dragging and post-unlock extra taps cannot trigger an unintended transition.
- [ ] Home instructions and locked notification use the active unlock gesture.
- [ ] Persistence, malformed values, live-apply failure, and retryable UI errors are covered.
- [ ] flutter analyze, flutter test, Android unit tests, release build, and physical-device verification pass.
