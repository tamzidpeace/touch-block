# Touch Block Play Store Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Touch Block uploadable to Google Play as a release-signed App Bundle under a permanent package name, with a compliant icon set and all required policy text.

**Architecture:** Touch Block is a Flutter app whose entire function lives in Android native Kotlin. `lib/main.dart` renders the UI and talks to `MainActivity.kt` over a single MethodChannel; `MainActivity.kt` starts `FloatingOverlayService.kt`, a foreground service that draws two `WindowManager` overlays — a draggable floating icon and a full-screen touch-blocking layer. This plan changes packaging, signing, permissions, and assets. It does not change how blocking works.

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5, Kotlin, Gradle 8.14 with Kotlin DSL, Android SDK 36, `flutter_launcher_icons` (dev-only), `cairosvg` (authoring-only).

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec.

- **Package name:** `xyz.arafatpeace.touchblock` — permanent, must appear identically in `namespace`, `applicationId`, Kotlin directory path, both `package` declarations, and both sides of the MethodChannel.
- **MethodChannel name:** `xyz.arafatpeace.touchblock/overlay` — must be byte-identical in `lib/main.dart` and `MainActivity.kt`. A mismatch produces no build error, only a runtime `MissingPluginException`.
- **Dart package name:** `touch_block`
- **SDK versions:** `compileSdk = 36`, `minSdk = 24`, `targetSdk = 36` — literals, not `flutter.*` references.
- **App version:** stays `1.0.0+1`.
- **Icon palette:** gradient `#28216F` (bottom-left) → `#5C427C` (mid) → `#956E95` (top-right); glyph `#FFFFFF`.
- **Blocking behavior is frozen.** Do not modify gesture thresholds, overlay flags, overlay geometry, or the tap/double-tap logic in `FloatingOverlayService.kt`.
- **Store copy rules:** no emoji, no ALL CAPS, no performance claims ("best", "#1", "top"), no price language ("free", "no ads"), no calls to action ("download now"). Title ≤30 chars, short description ≤80 chars, full description ≤4000 chars.
- **Audience framing:** describe the app as for *parents*. Never describe children as the audience.
- **Secrets:** `key.properties`, `*.jks`, `*.keystore` must never be committed.

## File Structure

**Created:**
- `assets/icon/icon.svg` — canonical vector icon source
- `assets/icon/icon.png`, `icon_background.png`, `icon_foreground.png` — 1024×1024 rasters
- `tool/render_icons.py` — rasterizes the SVG into those masters
- `tool/verify_naming.sh` — package-rename and MethodChannel guard
- `store/icon-512.png` — Play Console hi-res icon
- `store/privacy-policy.html` — page to publish at arafatpeace.xyz
- `store/listing.md` — store listing copy, FGS justification, Data safety answers
- `android/key.properties.example` — template documenting the untracked real file
- `LICENSE` — MIT, matching the README's claim
- `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/` — relocated Kotlin sources

**Modified:**
- `android/app/build.gradle.kts` — namespace, applicationId, SDK pins, signing
- `android/app/src/main/AndroidManifest.xml` — POST_NOTIFICATIONS, remove `<queries>`
- `android/app/src/main/kotlin/.../MainActivity.kt` — package, channel name, permission request
- `android/app/src/main/kotlin/.../FloatingOverlayService.kt` — package declaration only
- `lib/main.dart` — channel name, five `withOpacity` calls
- `pubspec.yaml` — name, dev dependency, icon config
- `test/widget_test.dart` — import path, unused import
- `.gitignore` — secrets
- `README.md` — minSdk correction

**Deleted:** `ios/`, `macos/`, `linux/`, `windows/`, `web/`

---

### Task 1: Remove unused platform targets

Delete first, before the rename. Those trees contain `com.example.dontTouch2` bundle identifiers that would otherwise pollute the Task 2 verification grep.

**Files:**
- Delete: `ios/`, `macos/`, `linux/`, `windows/`, `web/`

**Interfaces:**
- Consumes: nothing
- Produces: an Android-only repo. Task 2's grep gate depends on these trees being gone.

- [ ] **Step 1: Confirm the platform directories currently carry example identifiers**

Run:
```bash
grep -rl "com\.example" ios macos linux windows web 2>/dev/null
```
Expected: several matches (Xcode project files, CMake configs). This is what we are removing.

- [ ] **Step 2: Delete the directories**

```bash
git rm -r --quiet ios macos linux windows web
```

- [ ] **Step 3: Verify the app still analyzes and tests**

Run:
```bash
flutter analyze
flutter test
```
Expected: `flutter analyze` reports the same 6 pre-existing issues as before (5 `withOpacity`, 1 unused import) — no new errors. `flutter test` passes.

- [ ] **Step 4: Verify Android is still a registered platform**

Run:
```bash
ls android/app/src/main/kotlin
```
Expected: the `com` directory still exists. Only non-Android targets were removed.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove unused iOS, macOS, Linux, Windows and web targets

The app is Android-only: its entire function is WindowManager overlays
implemented in Kotlin. These trees were flutter create boilerplate."
```

---

### Task 2: Rename package to xyz.arafatpeace.touchblock

The highest-risk task in the plan. The MethodChannel name is a bare string on both the Dart and Kotlin sides with no compile-time link between them, so a partial rename builds cleanly and fails only at runtime.

**Files:**
- Modify: `android/app/build.gradle.kts` (namespace line 11, applicationId line 20)
- Move: `android/app/src/main/kotlin/com/example/dont_touch_2/` → `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/`
- Modify: `MainActivity.kt` (package declaration, `CHANNEL` constant)
- Modify: `FloatingOverlayService.kt` (package declaration)
- Modify: `lib/main.dart` (`_channel` constant, line 48)
- Modify: `pubspec.yaml` (name)
- Modify: `test/widget_test.dart` (import)

**Interfaces:**
- Consumes: Task 1's deletion of non-Android platform trees
- Produces: package `xyz.arafatpeace.touchblock`; Dart package `touch_block`; MethodChannel `xyz.arafatpeace.touchblock/overlay`. Tasks 3, 4 and 5 edit files at the new Kotlin path.

- [ ] **Step 1: Write the failing verification check**

Create `tool/verify_naming.sh`:

```bash
#!/usr/bin/env bash
# Verifies the package rename left nothing behind and that the MethodChannel
# name matches on both sides of the platform boundary.
set -euo pipefail

FAIL=0

echo "== checking for stale identifiers =="
# docs/ is excluded deliberately: the spec and plan discuss the old package
# name at length, and that is not a leak. This script also excludes itself,
# because it contains the search string.
if grep -rn "com\.example\|dont_touch_2" \
     --exclude-dir=build --exclude-dir=.git --exclude-dir=.dart_tool \
     --exclude-dir=docs --exclude=verify_naming.sh . ; then
  echo "FAIL: stale identifiers found"
  FAIL=1
else
  echo "OK: no stale identifiers"
fi

echo "== checking MethodChannel agreement =="
DART=$(grep -c "xyz\.arafatpeace\.touchblock/overlay" lib/main.dart || true)
KOTLIN=$(grep -c "xyz\.arafatpeace\.touchblock/overlay" \
  android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt || true)

if [ "$DART" -eq 1 ] && [ "$KOTLIN" -eq 1 ]; then
  echo "OK: channel name matches on both sides"
else
  echo "FAIL: channel occurrences dart=$DART kotlin=$KOTLIN (expected 1 and 1)"
  FAIL=1
fi

exit $FAIL
```

Make it executable:
```bash
chmod +x tool/verify_naming.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tool/verify_naming.sh`
Expected: FAIL. It reports stale `com.example` / `dont_touch_2` hits, and the Kotlin grep errors because `android/app/src/main/kotlin/xyz/...` does not exist yet.

- [ ] **Step 3: Move the Kotlin source directory**

```bash
mkdir -p android/app/src/main/kotlin/xyz/arafatpeace
git mv android/app/src/main/kotlin/com/example/dont_touch_2 \
       android/app/src/main/kotlin/xyz/arafatpeace/touchblock
rm -rf android/app/src/main/kotlin/com
```

- [ ] **Step 4: Update both Kotlin package declarations**

In `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt`, line 1:
```kotlin
package xyz.arafatpeace.touchblock
```

In `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/FloatingOverlayService.kt`, line 1:
```kotlin
package xyz.arafatpeace.touchblock
```

- [ ] **Step 5: Update the Kotlin channel constant**

In `MainActivity.kt`, inside `companion object`:
```kotlin
private const val CHANNEL = "xyz.arafatpeace.touchblock/overlay"
```

- [ ] **Step 6: Update the Dart channel constant**

In `lib/main.dart`, in `_HomeScreenState`:
```dart
  static const _channel = MethodChannel('xyz.arafatpeace.touchblock/overlay');
```

- [ ] **Step 7: Update Gradle namespace and applicationId**

In `android/app/build.gradle.kts`, replace:
```kotlin
    namespace = "com.example.dont_touch_2"
```
with:
```kotlin
    namespace = "xyz.arafatpeace.touchblock"
```

And replace these three lines:
```kotlin
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.dont_touch_2"
```
with:
```kotlin
        applicationId = "xyz.arafatpeace.touchblock"
```

- [ ] **Step 8: Rename the Dart package**

In `pubspec.yaml`, line 1:
```yaml
name: touch_block
```

In `test/widget_test.dart`:
```dart
import 'package:touch_block/main.dart';
```

- [ ] **Step 9: Run the verification check to confirm it passes**

Run: `./tool/verify_naming.sh`
Expected: PASS — "OK: no stale identifiers" and "OK: channel name matches on both sides", exit code 0.

- [ ] **Step 10: Run the test suite**

Run:
```bash
flutter pub get
flutter test
```
Expected: passes. If it fails with "package:dont_touch_2 not found", Step 8's import edit was missed.

- [ ] **Step 11: Confirm the Android build compiles under the new namespace**

Run: `flutter build apk --debug`
Expected: succeeds. This proves the Kotlin package declarations match their directory path — a mismatch is a compile error.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "refactor: rename package to xyz.arafatpeace.touchblock

Google Play rejects any package name containing com.example. The new
identifier is reverse-DNS of arafatpeace.xyz and is permanent after
first publish.

Adds tool/verify_naming.sh to guard the MethodChannel name, which is a
bare string on both sides of the platform boundary and fails silently
at runtime if the two drift apart."
```

---

### Task 3: Pin SDK versions

**Files:**
- Modify: `android/app/build.gradle.kts` (defaultConfig block)

**Interfaces:**
- Consumes: Task 2's renamed `applicationId`
- Produces: literal SDK versions. Task 8's `flutter_launcher_icons` config reuses `min_sdk_android: 24`.

- [ ] **Step 1: Record the currently-inherited values**

Run:
```bash
grep -n "compileSdk\|minSdk\|targetSdk" android/app/build.gradle.kts
```
Expected: all three reference `flutter.*`. These resolve to 36 / 24 / 36 with Flutter 3.41.9, but track whatever SDK is installed.

- [ ] **Step 2: Replace the compileSdk reference**

In `android/app/build.gradle.kts`, replace:
```kotlin
    compileSdk = flutter.compileSdkVersion
```
with:
```kotlin
    compileSdk = 36
```

- [ ] **Step 3: Replace the minSdk and targetSdk references**

Replace:
```kotlin
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
```
with:
```kotlin
        // Pinned rather than inherited from the installed Flutter SDK:
        // Google Play requires targetSdk 36 for new submissions from
        // 2026-08-31, and an older Flutter would silently lower this.
        minSdk = 24
        targetSdk = 36
```

- [ ] **Step 4: Verify the build still succeeds**

Run: `flutter build apk --debug`
Expected: succeeds.

- [ ] **Step 5: Verify the pinned values took effect**

Run:
```bash
grep -n "compileSdk = 36\|minSdk = 24\|targetSdk = 36" android/app/build.gradle.kts
```
Expected: three matches.

- [ ] **Step 6: Commit**

```bash
git add android/app/build.gradle.kts
git commit -m "build: pin compileSdk, minSdk and targetSdk to literals

Play requires targetSdk 36 for new submissions from 2026-08-31.
Inheriting from flutter.* meant an older local Flutter SDK could
silently produce a non-compliant build."
```

---

### Task 4: Configure release signing

**Files:**
- Modify: `android/app/build.gradle.kts` (imports, signingConfigs, buildTypes)
- Create: `android/key.properties.example`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 3's build config
- Produces: a `release` signing config active only when `android/key.properties` exists. Task 11 verifies the resulting AAB's certificate.

- [ ] **Step 1: Prove the release build is currently debug-signed**

Run:
```bash
flutter build apk --release
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk | grep -i "owner"
```
Expected: `Owner: C=US, O=Android, CN=Android Debug` — the defect this task fixes.

- [ ] **Step 2: Add the secrets to .gitignore**

Append to `.gitignore`:
```
# Signing secrets — never commit
key.properties
*.jks
*.keystore
```

- [ ] **Step 3: Create the tracked template**

Create `android/key.properties.example`:
```properties
# Copy to android/key.properties and fill in. That file is gitignored.
# Generate the keystore with:
#   keytool -genkey -v -keystore ~/touch-block-upload.jks \
#     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
storePassword=changeme
keyPassword=changeme
keyAlias=upload
storeFile=/absolute/path/to/touch-block-upload.jks
```

- [ ] **Step 4: Add the property loader to the top of build.gradle.kts**

Insert above the `plugins { }` block in `android/app/build.gradle.kts`:
```kotlin
import java.io.FileInputStream
import java.util.Properties

// Release signing is configured only when android/key.properties exists.
// Keeping it optional means `flutter run --release` still works on a fresh
// clone, which has no keystore because the file is deliberately untracked.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasKeystore) FileInputStream(keystorePropertiesFile).use { load(it) }
}
```

- [ ] **Step 5: Add the signingConfigs block**

In `android/app/build.gradle.kts`, inside `android { }` and immediately before `buildTypes { }`:
```kotlin
    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
```

- [ ] **Step 6: Point the release build type at it**

Replace the existing `buildTypes` block:
```kotlin
    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
```

- [ ] **Step 7: Verify the build still works without a keystore**

Run: `flutter build apk --release`
Expected: succeeds, still debug-signed. This confirms the fallback path — a fresh clone is not broken by the new config.

- [ ] **Step 8: Generate the real keystore**

This step requires the developer, not an automated agent — it prompts interactively and sets passwords that must be stored securely.

```bash
keytool -genkey -v -keystore ~/touch-block-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` from the template, filling in the real values and the absolute path to `~/touch-block-upload.jks`.

Back up the `.jks` file somewhere outside the repository.

- [ ] **Step 9: Verify the release build is now upload-signed**

Run:
```bash
flutter build apk --release
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk | grep -i "owner"
```
Expected: the certificate details entered in Step 8. It must **not** say `CN=Android Debug`.

- [ ] **Step 10: Verify no secrets are staged**

Run: `git status --porcelain`
Expected: no `key.properties`, no `.jks`, no `.keystore` entries.

- [ ] **Step 11: Commit**

```bash
git add android/app/build.gradle.kts android/key.properties.example .gitignore
git commit -m "build: sign release builds with an upload keystore

Play rejects debug-signed artifacts. The signing config activates only
when android/key.properties is present, so a fresh clone without the
keystore still builds instead of failing outright."
```

---

### Task 5: Add POST_NOTIFICATIONS and clean the manifest

Without this permission the foreground-service notification is hidden on Android 13+. That notification is what makes the service user-perceptible, which is the central claim of the foreground-service declaration in Task 10.

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt`

**Interfaces:**
- Consumes: Task 2's Kotlin path and `CHANNEL` constant
- Produces: `MainActivity.ensureNotificationPermission()`, a private method with signature `private fun ensureNotificationPermission()`, called from the `"startService"` branch of the method-channel handler.

- [ ] **Step 1: Confirm the permission is currently absent**

Run:
```bash
grep -c "POST_NOTIFICATIONS" android/app/src/main/AndroidManifest.xml || echo 0
```
Expected: `0`.

- [ ] **Step 2: Declare the permission**

In `android/app/src/main/AndroidManifest.xml`, after the `VIBRATE` permission:
```xml
    <!-- Required so the foreground service notification is visible on
         Android 13+. Without it the service runs with no indicator and
         no route back to the app. -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 3: Remove the unused queries block**

Delete this block from `android/app/src/main/AndroidManifest.xml` entirely:
```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
```

It is `flutter create` boilerplate. The app has no text-processing feature, and an unexplained declaration invites questions in a manifest a reviewer is already scrutinising.

- [ ] **Step 4: Add the imports to MainActivity.kt**

Add to the import block in `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt`:
```kotlin
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
```

`androidx.core` is already on the classpath — `FloatingOverlayService.kt` uses `androidx.core.app.NotificationCompat`. No dependency change is needed.

- [ ] **Step 5: Add the request-code constant**

In `MainActivity.kt`, inside `companion object`, below the existing overlay constant:
```kotlin
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
```

- [ ] **Step 6: Implement the permission request**

Add this method to `MainActivity`, next to `checkOverlayPermission()`:
```kotlin
    /**
     * Ask for notification permission on Android 13+ so the foreground
     * service notification is visible.
     *
     * Deliberately fire-and-forget: a denial hides the notification but does
     * not stop a foreground service from running, so the service must start
     * either way. Blocking the app's primary function on a secondary
     * permission would be the wrong trade.
     */
    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED

        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }
```

- [ ] **Step 7: Call it from the startService branch**

In the method-channel handler, replace the `"startService"` branch with:
```kotlin
                "startService" -> {
                    if (checkOverlayPermission()) {
                        ensureNotificationPermission()
                        startFloatingService()
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                    }
                }
```

- [ ] **Step 8: Verify it compiles**

Run: `flutter build apk --debug`
Expected: succeeds.

- [ ] **Step 9: Verify the manifest changes landed**

Run:
```bash
grep -c "POST_NOTIFICATIONS" android/app/src/main/AndroidManifest.xml
grep -c "PROCESS_TEXT" android/app/src/main/AndroidManifest.xml || echo 0
```
Expected: `1` then `0`.

- [ ] **Step 10: Manual device check**

Install the debug build on a device running Android 13 or newer:
```bash
flutter install
```
Grant overlay permission, tap Start Service, and confirm the system notification-permission dialog appears and the floating icon appears regardless of which button is chosen.

- [ ] **Step 11: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml \
        android/app/src/main/kotlin/xyz/arafatpeace/touchblock/MainActivity.kt
git commit -m "feat: request POST_NOTIFICATIONS so the service is user-visible

On Android 13+ the foreground service notification is hidden without
this permission, leaving the service running with no indicator and no
route back to the app. The request is fire-and-forget: a denial must not
block the service from starting.

Also drops the unused PROCESS_TEXT queries block."
```

---

### Task 6: Clear analyzer warnings and fix documentation

**Files:**
- Modify: `lib/main.dart` (lines 168, 265, 356, 363, 415)
- Modify: `test/widget_test.dart` (remove unused import)
- Modify: `README.md`
- Create: `LICENSE`

**Interfaces:**
- Consumes: Task 2's renamed Dart package
- Produces: a zero-warning `flutter analyze`, which Task 11 asserts.

- [ ] **Step 1: Confirm the six issues exist**

Run: `flutter analyze`
Expected: 6 issues — 5 `withOpacity` deprecations and 1 unused import.

- [ ] **Step 2: Replace all five withOpacity calls**

In `lib/main.dart`, make these exact substitutions:

| Line | From | To |
|------|------|-----|
| 168 | `colorScheme.primaryContainer.withOpacity(0.3)` | `colorScheme.primaryContainer.withValues(alpha: 0.3)` |
| 265 | `colorScheme.surfaceContainerHighest.withOpacity(0.5)` | `colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)` |
| 356 | `colorScheme.outlineVariant.withOpacity(0.5)` | `colorScheme.outlineVariant.withValues(alpha: 0.5)` |
| 363 | `iconColor.withOpacity(0.1)` | `iconColor.withValues(alpha: 0.1)` |
| 415 | `colorScheme.primary.withOpacity(0.1)` | `colorScheme.primary.withValues(alpha: 0.1)` |

`withOpacity` multiplies into an 8-bit alpha channel; `withValues` keeps the wider float precision. Behaviour is visually identical at these values.

- [ ] **Step 3: Remove the unused import**

In `test/widget_test.dart`, delete:
```dart
import 'package:flutter/material.dart';
```

- [ ] **Step 4: Verify the analyzer is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Verify tests still pass**

Run: `flutter test`
Expected: passes.

- [ ] **Step 6: Correct the README's API level claim**

In `README.md`, replace both occurrences of the incorrect minimum:
- `- **Platform**: Android only (API 21+)` → `- **Platform**: Android only (API 24+)`
- `- Android SDK (API 21+)` → `- Android SDK (API 24+)`

The actual `minSdk` is 24, pinned in Task 3.

- [ ] **Step 7: Add the missing licence file**

The README states "available under the MIT License" but no `LICENSE` file exists. Create `LICENSE`:

```
MIT License

Copyright (c) 2026 arafatpeace

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 8: Commit**

```bash
git add lib/main.dart test/widget_test.dart README.md LICENSE
git commit -m "chore: clear analyzer warnings, fix README, add LICENSE

Replaces five deprecated withOpacity calls with withValues, drops an
unused import, corrects the documented minSdk from 21 to 24, and adds
the MIT LICENSE file the README already claimed."
```

---

### Task 7: Author the icon source and rasterize masters

The icon currently has no source — it was generated once and survives only as 192×192 and smaller PNGs. This task creates the permanent vector source.

**Files:**
- Create: `assets/icon/icon.svg`
- Create: `assets/icon/icon.png`, `icon_foreground.png`, `icon_background.png`, `icon_monochrome.png`
- Create: `tool/render_icons.py`

**Interfaces:**
- Consumes: nothing
- Produces: four 1024×1024 PNGs at `assets/icon/`. Task 8's `flutter_launcher_icons` config references all four by exact path.

- [ ] **Step 1: Install the rasterizer**

```bash
python3 -m pip install --user cairosvg
```

Verify:
```bash
python3 -c "import cairosvg; print('ok')"
```
Expected: `ok`.

If this fails with a libcairo error, install the native library first — cairosvg binds to it:
```bash
brew install cairo libffi
```

- [ ] **Step 2: Author the vector source**

Create `assets/icon/icon.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="field" x1="0" y1="1024" x2="1024" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#28216F"/>
      <stop offset="0.5" stop-color="#5C427C"/>
      <stop offset="1" stop-color="#956E95"/>
    </linearGradient>
  </defs>

  <rect id="bg" width="1024" height="1024" rx="224" fill="url(#field)"/>

  <g id="glyph" fill="none" stroke="#FFFFFF" stroke-width="46"
     stroke-linecap="round" stroke-linejoin="round">
    <!-- downward touch arrow, drawn first so the slash crosses it -->
    <path d="M446 300 V520"/>
    <path d="M366 448 L446 528 L526 448"/>
    <!-- prohibition ring and slash -->
    <circle cx="446" cy="424" r="252"/>
    <path d="M268 246 L624 602"/>
    <!-- padlock, lower right -->
    <rect x="642" y="712" width="216" height="164" rx="30" fill="#FFFFFF" stroke="none"/>
    <path d="M690 712 V656 a60 60 0 0 1 120 0 V712"/>
  </g>
</svg>
```

- [ ] **Step 3: Write the render script**

Create `tool/render_icons.py`:

```python
"""Rasterize assets/icon/icon.svg into the 1024x1024 masters.

The SVG is the single source of truth for the launcher icon. Re-run this
after editing it, then re-run `dart run flutter_launcher_icons`.
"""
import re
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "icon" / "icon.svg"
OUT = ROOT / "assets" / "icon"
SIZE = 1024

svg = SRC.read_text()


def render(name: str, markup: str) -> None:
    target = OUT / name
    cairosvg.svg2png(
        bytestring=markup.encode(),
        write_to=str(target),
        output_width=SIZE,
        output_height=SIZE,
    )
    print(f"wrote {target.relative_to(ROOT)}")


def drop(markup: str, element_id: str) -> str:
    """Remove a top-level element by id.

    Handles the two shapes present in icon.svg separately. A single combined
    pattern would be wrong: the glyph group contains self-closing <path/>
    children, so a non-greedy match ending in `/>` would stop at the first
    child and leave the rest of the group orphaned.
    """
    group = rf'<g id="{element_id}".*?</g>'
    if re.search(group, markup, flags=re.DOTALL):
        return re.sub(group, "", markup, flags=re.DOTALL)
    return re.sub(rf'<rect id="{element_id}"[^>]*/>', "", markup)


def inset_glyph(markup: str, scale: float) -> str:
    """Shrink the glyph toward the canvas centre.

    Adaptive icons are masked to a 72dp safe zone inside a 108dp canvas,
    so full-bleed artwork gets clipped. 0.66 keeps the glyph inside it.
    """
    offset = SIZE * (1 - scale) / 2
    return markup.replace(
        '<g id="glyph"',
        f'<g id="glyph" transform="translate({offset},{offset}) scale({scale})"',
    )


# Full-bleed master: used for the legacy square launcher icon and the
# Play Console 512x512 hi-res icon.
render("icon.png", svg)

# Adaptive background: the gradient field with no glyph.
render("icon_background.png", drop(svg, "glyph"))

# Adaptive foreground: glyph only, inset into the safe zone, transparent.
# This doubles as the Android 13+ themed (monochrome) layer — the system
# tints that layer itself, so a white-on-transparent glyph is already the
# correct input and a separate file would be byte-identical.
render("icon_foreground.png", inset_glyph(drop(svg, "bg"), 0.66))
```

- [ ] **Step 4: Run it**

```bash
python3 tool/render_icons.py
```
Expected output: three `wrote assets/icon/...` lines — `icon.png`, `icon_background.png`, `icon_foreground.png`.

- [ ] **Step 5: Verify dimensions and transparency**

Run:
```bash
cd assets/icon && for f in *.png; do
  printf "%-24s " "$f"
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" | tail -3 | tr -d '\n'
  echo
done; cd ../..
```
Expected: all three are 1024×1024, and `icon_foreground.png` reports `hasAlpha: yes`. An opaque foreground means the `drop()` call failed to strip the background rect, which would produce an adaptive icon with a doubled, clipped field.

- [ ] **Step 6: Visually inspect the result**

Open the files and confirm the glyph reads correctly: a downward arrow inside a crossed-out ring, with a padlock at the lower right, white on a purple diagonal gradient.

```bash
open assets/icon/icon.png assets/icon/icon_foreground.png
```

If the composition needs adjustment, edit `assets/icon/icon.svg` and re-run Step 4. Do not hand-edit the PNGs — the SVG is the source of truth.

- [ ] **Step 7: Commit**

```bash
git add assets/icon tool/render_icons.py
git commit -m "feat: add vector icon source and rasterized masters

The launcher icon previously had no source file at any resolution above
192x192, making the Play-required 512x512 impossible without upscaling.
assets/icon/icon.svg is now the single source of truth; tool/render_icons.py
derives the full-bleed master plus adaptive background, foreground and
monochrome layers from it."
```

---

### Task 8: Generate launcher icons and the store icon

**Files:**
- Modify: `pubspec.yaml` (dev dependency + `flutter_launcher_icons` config)
- Create: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (generated)
- Modify: `android/app/src/main/res/mipmap-*/ic_launcher.png` (regenerated)
- Create: `store/icon-512.png`

**Interfaces:**
- Consumes: Task 7's four PNGs at `assets/icon/`; Task 3's `minSdk = 24`
- Produces: `store/icon-512.png` at exactly 512×512, which Task 11 asserts.

- [ ] **Step 1: Record the current icon state**

Run:
```bash
ls android/app/src/main/res/ | grep mipmap
```
Expected: five density folders, no `mipmap-anydpi-v26`. The absence of that folder is why the icon renders inside a white circle on Android 8+.

- [ ] **Step 2: Add the dev dependency**

In `pubspec.yaml`, under `dev_dependencies`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4
```

This is a code generator. It runs once, its output is committed, and it is never packaged into the APK.

- [ ] **Step 3: Add the generator config**

Append to `pubspec.yaml`, at the top level (not nested under `flutter:`):
```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: false
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "assets/icon/icon_background.png"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  adaptive_icon_monochrome: "assets/icon/icon_foreground.png"
  min_sdk_android: 24
```

The monochrome layer intentionally points at the same file as the
foreground. Android tints that layer itself, so a white-on-transparent
glyph is already the correct input.

- [ ] **Step 4: Run the generator**

```bash
flutter pub get
dart run flutter_launcher_icons
```
Expected: output ending in a success line, having written the mipmap densities and the adaptive XML.

- [ ] **Step 5: Verify the adaptive icon was created**

Run:
```bash
cat android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
```
Expected: an `<adaptive-icon>` element containing `<background>`, `<foreground>` and `<monochrome>` children.

- [ ] **Step 6: Verify the density PNGs were regenerated**

Run:
```bash
cd android/app/src/main/res && for d in mipmap-?dpi mipmap-??dpi mipmap-???dpi; do
  [ -f "$d/ic_launcher.png" ] && { printf "%-16s " "$d"; sips -g pixelWidth "$d/ic_launcher.png" | tail -1; }
done; cd -
```
Expected: 48, 72, 96, 144 and 192 pixel widths across the five folders.

- [ ] **Step 7: Produce the Play Console hi-res icon**

```bash
mkdir -p store
sips -z 512 512 assets/icon/icon.png --out store/icon-512.png
```

- [ ] **Step 8: Verify the store icon**

Run:
```bash
sips -g pixelWidth -g pixelHeight store/icon-512.png
```
Expected: exactly 512 × 512.

- [ ] **Step 9: Confirm the app builds and the icon renders**

```bash
flutter build apk --debug
flutter install
```
On the device, check the launcher: the icon must fill its shape with no white ring, and adopt the launcher's mask (circle, squircle, etc.).

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/res store/icon-512.png
git commit -m "feat: generate adaptive launcher icons and 512px store icon

Adds flutter_launcher_icons as a dev-only generator driven by the vector
masters from the previous commit. Produces the adaptive and monochrome
icons the app previously lacked, plus the 512x512 hi-res icon Play
requires for the listing."
```

---

### Task 9: Write the privacy policy page

**Files:**
- Create: `store/privacy-policy.html`

**Interfaces:**
- Consumes: nothing
- Produces: a page to publish at `https://arafatpeace.xyz/touch-block/privacy`. Task 10's listing copy and Data safety answers must stay consistent with it.

- [ ] **Step 1: Confirm the app makes no network calls or persistent writes**

Run:
```bash
grep -rn "http\|Socket\|SharedPreferences\|getSharedPreferences\|File(" \
  lib/ android/app/src/main/kotlin/ || echo "none found"
```
Expected: `none found`. This substantiates the "collects nothing" claim — if anything turns up, the policy text must be revised to match before publishing.

- [ ] **Step 2: Write the page**

Create `store/privacy-policy.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Privacy Policy — Touch Block</title>
<style>
  body { max-width: 42rem; margin: 3rem auto; padding: 0 1.25rem;
         font: 16px/1.65 system-ui, -apple-system, sans-serif; color: #1c1b1f; }
  h1 { font-size: 1.75rem; margin-bottom: .25rem; }
  h2 { font-size: 1.15rem; margin-top: 2rem; }
  .updated { color: #666; margin-top: 0; }
  code { background: #f2f0f5; padding: .1rem .3rem; border-radius: 3px; }
</style>
</head>
<body>
<h1>Privacy Policy for Touch Block</h1>
<p class="updated">Last updated: 8 August 2026</p>

<h2>Summary</h2>
<p>Touch Block does not collect, store, transmit or share any personal data.
The app has no analytics, no advertising, no accounts and no network
connection of any kind.</p>

<h2>Data we collect</h2>
<p>None. Touch Block does not request access to your contacts, location,
camera, microphone, files, or any other personal information. Nothing you do
in the app leaves your device, because the app never connects to the
internet.</p>

<h2>Permissions and why they are needed</h2>
<p>Touch Block requests three Android permissions, each used only for the
app's single function of blocking screen touches:</p>
<ul>
  <li><strong>Display over other apps</strong> (<code>SYSTEM_ALERT_WINDOW</code>)
      — draws the floating button and the transparent layer that absorbs
      touches. This is the app's core function and it cannot work without it.
      The overlay is only shown after you start the service yourself.</li>
  <li><strong>Foreground service</strong>
      (<code>FOREGROUND_SERVICE</code>, <code>FOREGROUND_SERVICE_SPECIAL_USE</code>)
      — keeps the floating button running while you use other apps. Android
      would otherwise stop it, removing the block without warning.</li>
  <li><strong>Notifications</strong> (<code>POST_NOTIFICATIONS</code>)
      — shows an ongoing notification while the service runs, so you can
      always see it is active and return to the app to stop it.</li>
  <li><strong>Vibration</strong> (<code>VIBRATE</code>)
      — gives short haptic feedback when you lock or unlock the screen.</li>
</ul>
<p>None of these permissions are used to gather information about you.</p>

<h2>Children</h2>
<p>Touch Block is intended for adults. It is not directed at children and
does not knowingly collect information from anyone.</p>

<h2>Third parties</h2>
<p>Touch Block contains no third-party software development kits, no
advertising libraries and no analytics services. No data is shared with
anyone, because no data is gathered.</p>

<h2>Changes to this policy</h2>
<p>If this policy changes, the revised version will be posted on this page
with an updated date.</p>

<h2>Contact</h2>
<p>Questions about this policy can be sent to
<a href="mailto:contact@arafatpeace.xyz">contact@arafatpeace.xyz</a>.</p>
</body>
</html>
```

- [ ] **Step 3: Verify it renders**

```bash
open store/privacy-policy.html
```
Expected: a readable page with all sections present and no broken markup.

- [ ] **Step 4: Confirm the contact address is real**

The `mailto:` address in the Contact section must be an address the developer actually monitors — Google may use it, and a bouncing address on a policy page is a compliance risk. Replace it if `contact@arafatpeace.xyz` is not deliverable.

- [ ] **Step 5: Commit**

```bash
git add store/privacy-policy.html
git commit -m "docs: add privacy policy page for the Play listing

Every Play listing requires a publicly reachable privacy policy that is
cross-checked against the Data safety declaration. Touch Block collects
nothing, so the page documents that and explains why each permission is
requested."
```

---

### Task 10: Write the Play Console submission text

**Files:**
- Create: `store/listing.md`

**Interfaces:**
- Consumes: Task 9's privacy policy content, which these answers must not contradict
- Produces: the text the developer pastes into Play Console.

- [ ] **Step 1: Write the submission document**

Create `store/listing.md`:

````markdown
# Play Console Submission Text — Touch Block

Paste-ready copy for each Play Console field. Written against Google's
metadata policy: no emoji, no ALL CAPS, no performance claims, no price
language, no calls to action.

---

## Store listing

**App name** (max 30 characters — this is 11)

```
Touch Block
```

**Short description** (max 80 characters — this is 73)

```
Block screen touches with a floating button so calls are not interrupted.
```

**Full description** (max 4000 characters)

```
Touch Block puts a small floating button on your screen that locks out all
touch input until you unlock it again.

It was built for video calls. When you hand your phone to someone, or set it
down mid-call, a stray touch can end the call, mute the microphone or switch
the camera. Touch Block stops those touches from reaching anything.

How it works

1. Start the service from the app. A small floating button appears and stays
   on top of whatever you are doing.
2. Tap the button once. A transparent layer covers the screen and absorbs
   every touch.
3. Tap the button twice to remove the layer and return to normal.
4. Drag the button at any time to move it out of your way.

The button changes colour so you can always tell whether the screen is
locked or not.

Why Touch Block needs the display-over-other-apps permission

The floating button and the touch-blocking layer are drawn on top of other
applications, which Android only allows with the display-over-other-apps
permission. This is the app's core function and it cannot work without it.
You grant the permission yourself in Android settings, and the overlay only
appears after you start the service.

An ongoing notification is shown the whole time the service is running, so
you can always see that it is active and return to the app to stop it.

What Touch Block does not do

Touch Block has no account, no advertising and no analytics. It does not
connect to the internet and it does not collect any information about you.

Limitations

Touch Block is an overlay, not a device lock. You can always stop the
service from the notification, or from Android settings. This is deliberate:
it means you can never be locked out of your own phone.

Requires Android 7.0 or newer.
```

---

## App content declarations

**Privacy policy URL**

```
https://arafatpeace.xyz/touch-block/privacy
```

**Target audience:** 18 and over.

Do not select any age band that includes children. The app is used by
parents; children are not the audience. Declaring a child audience triggers
the Families policy, under which overlay applications receive substantially
stricter review.

**Ads:** No, this app does not contain ads.

**Content rating questionnaire:** complete it — unrated apps are not
permitted on Google Play. Touch Block has no user-generated content, no
violence, no in-app purchases and no data collection, which results in the
lowest rating band.

**News app:** No.
**Government app:** No.

---

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | No |
| Is all of the user data collected by your app encrypted in transit? | Not applicable — no data is collected |
| Do you provide a way for users to request that their data is deleted? | Not applicable — no data is collected |

This must match the privacy policy exactly. Any inconsistency between the
two is a documented cause of suspension.

---

## Foreground service declaration

Play Console: **App content → Foreground service permissions**.

**Permission declared:** `FOREGROUND_SERVICE_SPECIAL_USE`
**Manifest subtype value:** `touch_blocking_overlay`

**What the feature does**

```
Touch Block displays a floating button over other applications. When the
user taps it, the app draws a transparent full-screen layer that absorbs
touch input, preventing accidental taps from reaching whatever application
is in the foreground. Tapping the button twice removes the layer.

The service exists solely to keep that floating button and blocking layer
present while the user is in another application, typically a video call.
The user starts it explicitly from the app's main screen and stops it from
the same screen or from the ongoing notification.
```

**Why a foreground service is required**

```
The blocking layer must remain on screen while the user is inside another
application, which is precisely when the app itself is in the background.
A background service would be stopped by the system, and the user has no
way to know that has happened: the floating button would disappear and the
screen would silently stop being protected in the middle of a call, which
is the exact failure the app exists to prevent.

The service is user-initiated, runs only while the user has chosen to have
it running, and is user-perceptible for its entire lifetime through an
ongoing notification that cannot be dismissed while the service is active.
```

**Why the special use type**

```
No standard foreground service type describes this feature. The service
does not play media, track location, make phone calls, sync data, process
health data or transfer files. Its sole purpose is maintaining a
user-controlled window overlay, for which Android provides no dedicated
foreground service type. FOREGROUND_SERVICE_SPECIAL_USE is therefore the
only applicable declaration, with the manifest subtype value
touch_blocking_overlay.
```

**Impact if deferred or interrupted**

```
If the system defers the service, the floating button never appears and the
user cannot block the screen at all. If the system interrupts it while
running, the blocking layer is removed and touches reach the underlying
application again without the user being told, which can end a call or
change call settings unintentionally.
```

**Demonstration video**

Record and upload as an unlisted YouTube video, then paste the link. It must
show the full user journey:

1. Open Touch Block from the launcher
2. Tap "Grant Permission" and enable display-over-other-apps in settings
3. Return to the app and tap "Start Service"
4. Show the floating button appearing and the ongoing notification
5. Open another app, for example a video call
6. Tap the floating button once — show that touches no longer register
7. Tap it twice — show that touches work again
8. Return to Touch Block and tap "Stop Service"

---

## Pre-submission checklist

- [ ] Privacy policy published and reachable at the URL above
- [ ] Screenshots re-captured at 1080x1920 (the repository copies are
      504x1024, which violates Play's 9:16 minimum ratio)
- [ ] Feature graphic produced at 1024x500, no transparency
- [ ] Hi-res icon uploaded from `store/icon-512.png`
- [ ] Demonstration video recorded and uploaded
- [ ] Closed test running with 12 testers opted in for 14 continuous days
````

- [ ] **Step 2: Verify the character limits**

Run:
```bash
python3 - <<'PY'
title = "Touch Block"
short = "Block screen touches with a floating button so calls are not interrupted."
print(f"title  {len(title):>4} / 30  {'ok' if len(title) <= 30 else 'TOO LONG'}")
print(f"short  {len(short):>4} / 80  {'ok' if len(short) <= 80 else 'TOO LONG'}")
PY
```
Expected: both report `ok`.

- [ ] **Step 3: Check the copy for banned terms**

Run:
```bash
grep -niE "\b(best|#1|top|free|no ads|download now|click here)\b" store/listing.md \
  || echo "no banned terms in copy"
```
Expected: `no banned terms in copy`. If the grep matches inside the policy-explanation prose rather than the copy blocks, confirm by reading before changing anything.

- [ ] **Step 4: Commit**

```bash
git add store/listing.md
git commit -m "docs: add Play Console submission text

Store listing copy within Google's metadata limits, the special-use
foreground service justification, Data safety answers and the app content
declarations, all consistent with the privacy policy."
```

---

### Task 11: Final release verification

Runs every acceptance criterion from the spec against the finished build.

**Files:**
- No source changes. Creates the release artifact only.

**Interfaces:**
- Consumes: all previous tasks
- Produces: a verified `app-release.aab` ready for upload.

- [ ] **Step 1: Verify naming**

Run: `./tool/verify_naming.sh`
Expected: PASS, exit code 0.

- [ ] **Step 2: Verify the analyzer and tests**

Run:
```bash
flutter analyze
flutter test
```
Expected: `No issues found!` and all tests passing.

- [ ] **Step 3: Build the App Bundle**

Play requires an App Bundle, not an APK, for new apps.

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
Expected: succeeds, writing `build/app/outputs/bundle/release/app-release.aab`.

- [ ] **Step 4: Verify the bundle's package name**

Run:
```bash
unzip -p build/app/outputs/bundle/release/app-release.aab \
  base/manifest/AndroidManifest.xml | strings | grep -c "xyz.arafatpeace.touchblock"
```
Expected: at least `1`. The manifest inside a bundle is protobuf-encoded, so `strings` is used to read the embedded identifiers.

- [ ] **Step 5: Verify the bundle is upload-signed, not debug-signed**

Run:
```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep -i owner
```
Expected: the certificate created in Task 4 Step 8. If this reads `CN=Android Debug`, `android/key.properties` is missing or its `storeFile` path is wrong — the fallback silently used the debug key.

- [ ] **Step 6: Verify no secrets are tracked**

Run:
```bash
git ls-files | grep -E "key\.properties$|\.jks$|\.keystore$" || echo "no secrets tracked"
```
Expected: `no secrets tracked`. `android/key.properties.example` is tracked and is fine — the grep anchors on `key.properties` at end of path, so the example file does not match.

- [ ] **Step 7: Verify the store icon**

Run:
```bash
sips -g pixelWidth -g pixelHeight store/icon-512.png
```
Expected: exactly 512 × 512.

- [ ] **Step 8: Manual device verification with the release build**

Build and install a release APK for on-device testing — an AAB cannot be installed directly.

```bash
flutter build apk --release
flutter install --release
```

Walk through and confirm each:

1. Grant overlay permission, then grant notification permission
2. Tap "Start Service" — the floating icon appears and the notification appears
3. Single-tap the floating icon — the screen blocks and the icon turns red
4. Double-tap the floating icon — the screen unblocks and the icon turns white
5. Drag the floating icon — it moves and stays where it was dropped
6. Stop the service from the notification — the floating icon disappears
7. Confirm the launcher icon fills its shape with no white ring

- [ ] **Step 9: Manual verification with notifications denied**

Uninstall, reinstall, and this time **deny** the notification permission.

```bash
adb uninstall xyz.arafatpeace.touchblock
flutter install --release
```

Confirm the service still starts and blocking still works. A denial must degrade the experience, not break the app.

- [ ] **Step 10: Commit any residual changes**

```bash
git status --porcelain
```
If anything is uncommitted (for example `pubspec.lock`), commit it:
```bash
git add -A
git commit -m "chore: sync lockfile after release verification"
```

---

## Handoff to the developer

Work that cannot be automated and must be done before submission:

1. **Start the closed test now.** Personal accounts created after 13 November 2023 need 12 testers opted in for 14 continuous days. This is a hard floor and the longest item on the critical path.
2. **Re-capture screenshots** at 1080×1920. The repository copies are 504×1024 and violate Play's 9:16 minimum ratio.
3. **Produce the feature graphic** at 1024×500, no transparency.
4. **Record the demonstration video** per the storyboard in `store/listing.md`.
5. **Publish the privacy policy** at `https://arafatpeace.xyz/touch-block/privacy`.
6. **Back up the upload keystore** outside the repository.
7. **After the listing goes live**, replace the Google Drive APK download
   badge in `README.md` with the Play Store link. It is left in place until
   then so the README does not advertise a URL that does not yet resolve.
