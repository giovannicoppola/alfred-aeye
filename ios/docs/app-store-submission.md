# Aeye — App Store submission runbook

Everything needed to take `ios/` from source to a review submission, plus the two things that
can get this particular app rejected.

Current release target: **1.0.0 (build 1)** — `ios/project.yml`, `MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION`.

---

## 0. Read this first — the two real risks

**1. App Review has no way to see data (Guideline 2.1 — App Completeness) — handled.**
Aeye shows nothing until you sign in to Cursor and/or Claude, and a reviewer has neither account.
This is now solved in the app rather than by sharing credentials: **Settings → Sample data → "Use
sample data"** fills every row with representative numbers, and it ships in Release builds (the old
`--screenshot` seed was `#if DEBUG` and could not reach a reviewer). The setup card also offers
"See it with sample data" as a one-tap way in.

The sample is labelled everywhere it appears — an orange "Sample data" chip in the app, a "Sample"
chip in the widget and on the Watch, and a footer line saying these are not your real numbers — so
it cannot be mistaken for live usage. Signing in turns it off automatically.

Make sure the review notes (template at the end of this file) point at the toggle. Providing demo
Cursor/Anthropic accounts is no longer necessary; if a reviewer insists on seeing live data, that
is the fallback, and it means handing over credentials to your paid plans.

**2. Third-party service access (Guideline 5.2.1 — Legal / Intellectual Property).**
Aeye talks to undocumented Cursor and Anthropic endpoints and authenticates with Claude Code's own
OAuth client id. The UI uses the names *Claude*, *Cursor*, and *Grok*. Review may ask for written
permission from those companies to use their service and marks. Mitigations that help:

- Keep the "not affiliated with Cursor, Anthropic, or Alfred" disclaimer visible in-app (Settings
  footer) as well as on the landing page.
- Use the names only as plain-text row labels — no third-party logos or wordmark art in the icon,
  screenshots, app name, or subtitle.
- In review notes, state that the app only reads the signed-in user's own usage numbers with their
  own credentials, and stores nothing off-device.
- Have a reply ready: if asked for authorization and you have none, the fallback is TestFlight
  distribution rather than public App Store release.

Neither risk blocks *building and uploading* — resolve them before you hit **Submit for Review**.

---

## 1. One-time Apple Developer setup

Team: `VDG762YNX9` (Giovanni Coppola).

Register these on [developer.apple.com](https://developer.apple.com/account/resources):

| Kind | Identifier |
|------|-----------|
| App ID | `com.giovanni.aeye` |
| App ID | `com.giovanni.aeye.widget` |
| App ID | `com.giovanni.aeye.watchkitapp` |
| App ID | `com.giovanni.aeye.watchkitapp.widgets` |
| App Group | `group.com.giovanni.aeye` |
| App Group | `group.com.giovanni.aeye.watch` |

**Status: already done.** Verified on 12 September 2026 — the exported distribution build carries
`group.com.giovanni.aeye` (app, widget) and `group.com.giovanni.aeye.watch` (Watch app,
complications) in its signed entitlements, which means both groups are registered and enabled on
the App IDs. Nothing to do here unless you switch teams.

For the record: App Groups are what let the iPhone widget and the Watch complications read the
shared snapshot — without them the app runs but both widget surfaces stay empty. And
`-allowProvisioningUpdates` (used by `scripts/archive.sh`) will create distribution *profiles* for
you, but it will not invent App Groups; those are registered by hand.

---

## 2. Create the App Store Connect record

App Store Connect → **Apps** → **+** → New App.

| Field | Value |
|-------|-------|
| Platform | iOS |
| Name | Aeye (fall back to *Aeye — Usage Meter* if taken) |
| Primary language | English (U.S.) |
| Bundle ID | `com.giovanni.aeye` |
| SKU | `aeye-ios-001` |
| User access | Full |

Then fill in:

- **Category** — Primary: Developer Tools. Secondary: Utilities.
- **Price** — Free.
- **Age rating** — 4+ (no objectionable content; answer "No" throughout).
- **Privacy policy URL** — `https://giovannicoppola.github.io/alfred-aeye/ios-landing/privacy.html`
  (source: `ios/docs/landing/privacy.html`). **Required** — you cannot submit without it.
- **Support URL** — `https://github.com/giovannicoppola/alfred-aeye/issues`
- **Marketing URL** — `https://giovannicoppola.github.io/alfred-aeye/ios-landing/`

Copy for the listing lives in [`app-store-metadata.md`](app-store-metadata.md).

---

## 3. Privacy — nutrition labels

App Store Connect → **App Privacy**. Aeye collects nothing, so:

> **Data Collection: No, we do not collect data from this app.**

That answer is truthful here: credentials stay in the iPhone Keychain, the snapshot stays in the
App Group container, and the only network calls carry the user's own token to Cursor/Anthropic.
There is no analytics SDK, no crash reporter, no backend.

The machine-readable half is `ios/Config/PrivacyInfo.xcprivacy`, copied into all four bundles. It
declares no tracking, no collected data, and one required-reason API:

| API category | Reason | Why |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `1C8F.1` | App Group `UserDefaults` shared between the app, the widget, and the Watch |

If you add a dependency or start reading file timestamps / disk space, the manifest must grow to
match, or the upload gets an ITMS-91053 warning email.

---

## 4. Screenshots

Required sets (App Store Connect will not let you submit without the iPhone ones):

| Display | Size | File |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | `docs/screenshots/iphone-overview.png` |
| Apple Watch Ultra | 410 × 502 | `docs/screenshots/watch-overview-ultra2.png` |
| Apple Watch Ultra 3 | 422 × 514 | `docs/screenshots/watch-overview.png` |

A 6.9" set is accepted for the 6.5" slot, so one iPhone set covers modern devices. Because the
Watch app ships inside the bundle, **Watch screenshots are mandatory too**.

Regenerate them from the simulator with the commands in [`../README.md`](../README.md#screenshots)
— an iOS 18.x runtime, not iOS 26 (that runtime has no Apple Color Emoji, so every meter dot
renders as a placeholder box).

The widget shot (`docs/screenshots/widget-medium.png`) is not submittable on its own; fold it into
a framed marketing screenshot if you want the widget in the listing.

---

## 5. Build and upload

```bash
cd ios
./scripts/archive.sh            # archive + export -> build/export/Aeye.ipa
./scripts/archive.sh --upload   # …and send it to App Store Connect
```

Upload needs an App Store Connect API key:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# private key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8
```

Create it under App Store Connect → **Users and Access** → **Integrations** → **App Store Connect
API**, role *App Manager*. The `.p8` downloads exactly once.

Signing settings are already in place — `DEVELOPMENT_TEAM: VDG762YNX9`, automatic signing,
`ExportOptions.plist` with `method: app-store-connect`.

Export compliance is answered in the bundle: `ITSAppUsesNonExemptEncryption = false` in
`Aeye/Info.plist`. Aeye only uses HTTPS/TLS through the system, which is exempt, so App Store
Connect stops asking on every upload.

Processing takes roughly 5–15 minutes before the build appears in TestFlight.

---

## 6. Before hitting Submit

- [ ] App Groups registered and enabled on all four App IDs (§1)
- [ ] Review notes point at Settings → Sample data (§0); verified the toggle works in a Release build
- [ ] Privacy policy URL live and reachable (§2)
- [ ] App Privacy answered "No data collected" (§3)
- [ ] iPhone + Watch screenshots uploaded (§4)
- [ ] Build processed and selected on the version
- [ ] Tested from TestFlight on a clean device: sign in to Claude, sign in to Cursor, add the
      Home Screen widget, open the Watch app, add a complication
- [ ] "Not affiliated with Cursor, Anthropic, or Alfred" visible in-app
- [ ] Version/build bumped if this is a resubmission (build numbers cannot repeat)

## Review notes template

Paste into App Store Connect → *App Review Information* → *Notes*:

> Aeye is a read-only viewer for the usage limits of the accounts the user already has with
> Cursor and Anthropic (Claude). It has no backend and no account of its own: the user signs in to
> each service in Safari via that service's own OAuth flow, the resulting token is stored in the
> iPhone Keychain, and it is used only to read that user's own plan-usage percentages. Nothing is
> collected, transmitted to us, or shared.
>
> To see the app fully populated without signing in, open Settings, scroll to "Sample data", and
> turn on "Use sample data". Every row then shows representative numbers, clearly labelled as a
> sample. The same sample appears in the Home Screen widget and the Apple Watch app. No account of
> any kind is needed to review the app.
>
> Aeye is an independent companion app and is not affiliated with, endorsed by, or sponsored by
> Cursor, Anthropic, or Alfred. Those names appear only as plain-text labels identifying which of
> the user's own accounts each row refers to.
