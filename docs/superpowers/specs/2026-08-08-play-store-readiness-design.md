# Touch Block — Play Store Readiness

**Date:** 2026-08-08
**Status:** Approved design, ready for implementation planning
**Scope:** Make the app publishable on Google Play. Code changes, icon pipeline, and authored text deliverables.

---

## 1. Problem

Touch Block is functionally complete and works on device, but cannot be uploaded to Google Play. Four defects cause rejection before human review, and one asset is missing entirely:

1. `applicationId` is `com.example.dont_touch_2`. Play rejects any package name containing `com.example`.
2. The release build is signed with the debug key. Play rejects debug-signed artifacts.
3. `POST_NOTIFICATIONS` is not declared. On Android 13+ the foreground-service notification is hidden, so the service runs with no visible indicator and no route back to the app.
4. No privacy policy exists. It is mandatory for every app and is cross-checked against the Data safety form.
5. The launcher icon's highest-resolution copy is 192×192. Play requires a 512×512 hi-res icon, and no source file exists.

The app's target API level is already compliant: Flutter 3.41.9 defaults to `targetSdk = 36`, meeting the 2026-08-31 deadline for new submissions.

## 2. Goals

- The app builds as a release-signed Android App Bundle under a permanent, non-`com.example` package name.
- The foreground-service notification is visible on Android 13+.
- The launcher icon has a permanent vector source and renders correctly at every density, including as an adaptive and themed icon.
- All Play Console text requirements are drafted and ready to paste.

## 3. Non-goals

These are explicitly excluded. They are defensible additions later, but they widen the diff without unblocking publication.

- **Any change to blocking behavior.** Single-tap blocks, double-tap unblocks, drag repositions. The user confirmed this works correctly on device. The blocking overlay's geometry, flags, and gesture thresholds are untouched.
- **Surfacing notification-permission state in the Flutter UI.** A third status card would be good polish. It is not a blocker.
- **Screenshots and feature graphic.** These require real device captures and cannot be authored here. Requirements are documented in §8 for the user to execute.
- **iOS, web, or desktop releases.** See §4.6.
- **R8/ProGuard tuning or obfuscation.** Flutter's release defaults are sufficient.

## 4. Design

### 4.1 Package rename

`com.example.dont_touch_2` → **`xyz.arafatpeace.touchblock`**

Chosen as true reverse-DNS of `arafatpeace.xyz`, a domain the developer owns. This keeps Digital Asset Links / App Links verification available later. The value is permanent — it becomes the Play Store URL and can never change after first publish.

Five coupled locations must change together:

| # | Location | Change |
|---|----------|--------|
| 1 | `android/app/build.gradle.kts` | `namespace = "xyz.arafatpeace.touchblock"` |
| 2 | `android/app/build.gradle.kts` | `applicationId = "xyz.arafatpeace.touchblock"`, and delete the stale `// TODO: Specify your own unique Application ID` comment |
| 3 | `android/app/src/main/kotlin/com/example/dont_touch_2/` | `git mv` to `android/app/src/main/kotlin/xyz/arafatpeace/touchblock/`, removing the now-empty `com/` tree |
| 4 | `MainActivity.kt`, `FloatingOverlayService.kt` | `package xyz.arafatpeace.touchblock` declarations |
| 5 | `MainActivity.kt` `CHANNEL` **and** `lib/main.dart` `_channel` | `"xyz.arafatpeace.touchblock/overlay"` |

**Location 5 is the failure mode to design against.** The MethodChannel name is a bare string on both sides. Neither compiler validates it against the other, so a mismatch produces no build error — only a `MissingPluginException` the first time the user taps a button. Both strings must be changed in the same edit and verified together.

Additionally:
- `pubspec.yaml`: `name: dont_touch_2` → `name: touch_block`
- `test/widget_test.dart`: `import 'package:dont_touch_2/main.dart'` → `package:touch_block/main.dart`

**Verification gate.** This command must return zero results:

```bash
grep -rn "com\.example\|dont_touch_2" --exclude-dir=build --exclude-dir=.git .
```

### 4.2 SDK version pinning

Replace inherited `flutter.*` values in `android/app/build.gradle.kts` with literals:

```kotlin
compileSdk = 36
minSdk = 24
targetSdk = 36
```

Rationale: `flutter.targetSdkVersion` currently resolves to 36, which satisfies the 2026-08-31 requirement, but it tracks whatever Flutter SDK is installed. A contributor or CI runner on an older Flutter would silently produce a non-compliant build. `minSdk = 24` matches Flutter's current default — this is a documentation of existing behavior, not a change.

App version stays at `1.0.0+1` in `pubspec.yaml`. This is the first release, so `versionCode` 1 is correct. `versionCode` must increase on every subsequent upload; Play rejects a re-used value.

### 4.3 Release signing

Create `android/key.properties` (untracked):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<absolute path to .jks outside the repo>
```

Keystore generated with:

```bash
keytool -genkey -v -keystore ~/touch-block-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/app/build.gradle.kts` loads it and defines a `release` signing config.

**Deviation from Flutter's documented pattern:** the official snippet casts properties with `as String`, which throws and fails the build when `key.properties` is absent. The release signing config here applies **only when the file exists**, falling back to debug signing otherwise. This keeps `flutter run --release` working on a fresh clone that has no keystore, which matters because the file is deliberately untracked.

`.gitignore` gains:

```
key.properties
android/key.properties
*.jks
*.keystore
```

Note on key custody: Play App Signing is enabled by default for new apps. Google holds the app signing key; the `.jks` created above is the **upload** key. Losing it is recoverable through Play support, but the file should still be backed up outside the repository.

### 4.4 `POST_NOTIFICATIONS`

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Request at runtime in `MainActivity`, on the `startService` method-channel call, when `Build.VERSION.SDK_INT >= 33` and the permission is not already granted.

**The service starts regardless of the user's answer.** Notification permission denial hides the notification but does not prevent a foreground service from running. Blocking the start on a denial would break the app's primary function over a secondary concern.

Implemented with the platform's `requestPermissions()`. No new dependency — `permission_handler` would be a package for what one native call already does.

### 4.5 Manifest cleanup

Remove the `<queries>` block declaring `PROCESS_TEXT`. It is `flutter create` boilerplate; the app has no text-processing feature. It is harmless functionally, but an unexplained declaration in a manifest that a reviewer is already scrutinizing for overlay and foreground-service reasons is a needless question to invite.

### 4.6 Remove unused platform targets

Delete `ios/`, `macos/`, `linux/`, `windows/`, `web/`.

The app's entire function is Android `WindowManager` overlays implemented in Kotlin. It cannot run on any other platform, and the README already states "Platform: Android only." These trees are `flutter create` boilerplate that will never be built.

Reversible via `flutter create --platforms=<p> .` if the position ever changes.

### 4.7 Icon pipeline

**Root problem:** the icon has no source. It was AI-generated once and survives only as five downscaled PNGs, the largest 192×192. Producing a 512×512 by upscaling would be a 2.7× blow-up and visibly soft.

**Design:** author the icon as SVG, rasterize once to a 1024×1024 master, generate everything else from that master.

```
assets/icon/icon.svg              ← source of truth, hand-authored vector
        │  cairosvg
        ▼
assets/icon/icon.png              ← 1024×1024 master (full-bleed)
assets/icon/icon_foreground.png   ← 1024×1024, artwork within 72dp/108dp safe zone
assets/icon/icon_background.png   ← 1024×1024, gradient field only
assets/icon/icon_monochrome.png   ← 1024×1024, white-on-transparent glyph
        │  flutter_launcher_icons
        ▼
mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png
mipmap-anydpi-v26/ic_launcher.xml  (adaptive + monochrome)
        │  sips
        ▼
store/icon-512.png                ← Play Console hi-res icon
```

`cairosvg` is installed via pip as a one-time authoring tool. It is not a runtime or build dependency of the app.

`flutter_launcher_icons` is added as a **dev dependency only** — it runs once via `dart run flutter_launcher_icons`, its outputs are committed, and it is never packaged into the APK.

**Palette**, sampled from the existing 192×192 icon so the redraw matches:

| Role | Value |
|------|-------|
| Gradient start (bottom-left) | `#28216F` |
| Gradient midpoint | `#5C427C` |
| Gradient end (top-right) | `#956E95` |
| Glyph | `#FFFFFF` |

Gradient runs diagonally, bottom-left to top-right.

**Adaptive icon re-composition.** Android masks adaptive icons to a launcher-chosen shape, so artwork must sit inside a 72dp safe zone within the 108dp canvas. The current icon is full-bleed to the rounded-square edge, meaning its glyph would be clipped. The adaptive foreground therefore shrinks the glyph onto a solid gradient field. This is a deliberate visual change to the icon, not a regression.

### 4.8 Analyzer and documentation cleanup

- Five `withOpacity(x)` deprecations in `lib/main.dart` (lines 168, 265, 356, 363, 415) → `withValues(alpha: x)`
- Unused `package:flutter/material.dart` import in `test/widget_test.dart`
- README states "API 21+" in two places; actual `minSdk` is 24
- README claims an MIT license but no `LICENSE` file exists — add one
- README's APK download link points at Google Drive; replace with the Play Store listing once live

`flutter analyze` must report zero issues.

## 5. Text deliverables

### 5.1 Privacy policy

Static HTML page hosted at `https://arafatpeace.xyz/touch-block/privacy`.

Google's requirements: publicly reachable with no login, not geo-blocked, not user-editable, names the app explicitly, and remains live (Google re-checks periodically). The identical URL goes in both the store listing and the Data safety form.

Content is short because the app collects nothing: no analytics, no network access, no persistent storage. The page must state that explicitly and explain why `SYSTEM_ALERT_WINDOW` is required, since a reviewer cross-references this against the permission list.

### 5.2 Store listing copy

- **Title** — ≤30 characters
- **Short description** — ≤80 characters
- **Full description** — ≤4000 characters

Written against Google's metadata policy: no emoji, no ALL CAPS (unless a brand name), no performance claims ("best", "#1", "top"), no price language ("free", "no ads"), no calls to action ("download now"). Violations cause rejection on metadata grounds alone.

The full description leads with the overlay-permission justification rather than burying it.

### 5.3 Foreground service declaration

Justification text for Play Console → App content → Foreground service permissions, covering the three things the reviewer checks:

1. The service is **user-initiated** — it starts only when the user taps "Start Service".
2. It is **user-perceptible** — a persistent notification is shown for its entire lifetime.
3. What breaks **if deferred or interrupted** — the blocking overlay is removed, silently un-blocking the screen mid-call, which is the exact failure the app exists to prevent.

`specialUse` is the correct type here: no standard foreground-service type covers a user-controlled screen overlay. The declaration must also reference the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` value already present in the manifest (`touch_blocking_overlay`).

Requires a demonstration video (unlisted YouTube link) recorded by the user, showing the full user journey: launch → grant permission → start service → tap to block → double-tap to unblock.

### 5.4 Data safety form answers

Exact selections to enter: no data collected, no data shared. The encryption and deletion questions do not apply when nothing is collected.

## 6. Policy risk assessment

The app blocks all touch input via a full-screen overlay. This is structurally similar to behavior the **Device and Network Abuse** policy prohibits: "apps that interfere with, disrupt, damage, or access in an unauthorized manner the user's device."

The existing implementation already carries the right defenses, and this spec must not weaken any of them:

- Service starts only on explicit user action
- No `RECEIVE_BOOT_COMPLETED` — never auto-starts
- **No accessibility service** — the single largest rejection cause for this app category is avoided entirely
- Persistent notification with a `PendingIntent` back to the app
- Launcher icon stays visible; app is never hidden
- Documented, discoverable unlock gesture

`POST_NOTIFICATIONS` (§4.4) directly strengthens this posture: without it, the "user-perceptible" claim in the foreground-service declaration is false on Android 13+.

**Target audience must be set to 18+**, and all listing copy must describe the app as *for parents*, never *for children*. The use case involves toddlers, but the user is the parent. Declaring a child audience triggers Families Policy, under which overlay apps face materially harder scrutiny — for no benefit, since children are not the installers.

## 7. Acceptance criteria

Automated:

```bash
grep -rn "com\.example\|dont_touch_2" --exclude-dir=build --exclude-dir=.git .   # 0 results
flutter analyze                                                                  # 0 issues
flutter test                                                                     # passes
flutter build appbundle --release                                                # succeeds
```

Artifact:

- Built AAB reports `applicationId` = `xyz.arafatpeace.touchblock`
- Built AAB is signed with the upload key, not the debug key
- `git status` shows no `key.properties`, `*.jks`, or `*.keystore`
- `store/icon-512.png` exists at exactly 512×512

Manual, on a physical device, using the **release** build:

1. Grant overlay permission → grant notification permission
2. Start service → floating icon appears → notification appears
3. Single-tap → screen blocks, icon turns red
4. Double-tap → screen unblocks, icon turns white
5. Stop service from the notification
6. Repeat with notification permission **denied** → service must still start and block correctly

## 8. User-executed prerequisites

Outside this implementation, required before submission:

- **Play Console account** with identity verification complete
- **Closed testing**: 12 testers opted in continuously for 14 days, required for personal accounts created after 2023-11-13. This is the longest lead time in the process — start before implementation finishes.
- **Screenshots**: 2–8 phone captures. Existing files are 504×1024, which violates Play's 9:16 minimum ratio and must be re-captured at 1080×1920.
- **Feature graphic**: 1024×500, JPEG or 24-bit PNG, no transparency
- **FGS demonstration video**, per §5.3
- **Privacy policy page published** at the URL in §5.1

## 9. Open risks

- **`specialUse` review is discretionary.** All foreground-service types are reviewed, and `specialUse` receives the most scrutiny because reviewers first check whether a standard type would fit. No standard type applies here, but approval is not guaranteed. Mitigation is the quality of the §5.3 justification and demo video.
- **The icon redraw will not be pixel-identical** to the current AI-generated icon. The palette is sampled to match, and the geometry is simple enough to reproduce closely, but the adaptive-icon safe zone forces re-composition regardless (§4.7).
