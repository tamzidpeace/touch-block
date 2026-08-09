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

Verified against the release build: the shipped APK declares only
SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE,
VIBRATE and POST_NOTIFICATIONS. It does not declare INTERNET, so the
"does not connect to the internet" claim in the privacy policy is accurate.
(INTERNET appears only in debug and profile builds, where Flutter injects it
for hot reload.)

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

## Build facts (verified from the release artifact)

| Field | Value |
|---|---|
| Package name | `xyz.arafatpeace.touchblock` |
| Version | `1.0.0` (versionCode `1`) |
| minSdk / targetSdk | 24 (Android 7.0) / 36 (Android 16) |
| Signing certificate | `CN=Arafat Kamal, C=BD`, valid to Dec 2053 |
| Artifact | `build/app/outputs/bundle/release/app-release.aab` |

`versionCode` must increase on every subsequent upload. Play rejects a
re-used value.

---

## Pre-submission checklist

- [ ] Privacy policy deployed and reachable at the URL above
- [ ] Screenshots re-captured at 1080x1920 (the repository copies are
      504x1024, which violates Play's 9:16 minimum ratio)
- [ ] Feature graphic produced at 1024x500, no transparency
- [ ] Hi-res icon uploaded from `store/icon-512.png`
- [ ] Demonstration video recorded and uploaded
- [ ] Closed testing running with 12 testers opted in for 14 continuous days
