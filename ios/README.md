# Aeye iOS — iPhone, widget & Apple Watch

Free companion apps with the **same four-row layout** as the [Alfred workflow](../README.md):

| Row | Source |
|-----|--------|
| Composer / Auto | Cursor spending page (`autoPercentUsed`) |
| Other models | Cursor (`apiPercentUsed`) |
| Hourly | Claude 5-hour session limit |
| Weekly | Claude weekly limit |

Each row shows the **circle meter**, **percentage**, **period suffix**, and pace emoji matching Alfred.

## Surfaces

| Surface | What you get |
|---------|----------------|
| **iPhone app** | Full four-row overview + Settings (tokens, row toggles) |
| **iPhone widget** | Medium (2 rows) or Large (all 4) |
| **Apple Watch app** | Compact four-row list (5-dot meters, short labels) |
| **Watch complications** | Circular / rectangular / inline / corner — focus row % |

The Watch does **not** store Cursor/Claude tokens. The iPhone fetches usage and pushes a snapshot over **WatchConnectivity**; the Watch caches it for offline glances and complications.

## Requirements

- Xcode 15+ (Xcode 16 recommended)
- iPhone on iOS 17+
- Apple Watch on watchOS 10+ (optional)
- Apple Developer account (free personal team works for sideloading)
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the Xcode project

## Setup

### 1. Generate the Xcode project (if needed)

```bash
cd ios
brew install xcodegen   # once
xcodegen generate
open Aeye.xcodeproj
```

### 2. Signing & App Groups

1. Set your **Team** on **Aeye**, **AeyeWidgetExtension**, **AeyeWatch**, and **AeyeWatchWidgets**
2. Confirm App Groups:
   - iPhone + iPhone widget: `group.com.giovanni.aeye`
   - Watch + Watch complications: `group.com.giovanni.aeye.watch`
3. If a group fails to register, change the id in the matching entitlements and in `Shared/SnapshotStore.swift` / `Shared/WatchBridge.swift`

### 3. Install on iPhone (Watch follows)

1. Select your **iPhone** as the run destination (not the Watch alone)
2. **Run** (`⌘R`) — Xcode installs the iPhone app and embeds the Watch app
3. On the Watch, open **Aeye** once after the iPhone has refreshed

### 4. Configure credentials (iPhone)

1. Open **Settings** (gear)
2. Paste Cursor session token + Claude OAuth token
3. Choose which rows to show
4. Tap **Save & Refresh** — this also syncs to the Watch when reachable

### 5. Widgets & complications

**iPhone:** long-press Home Screen → Add Widget → **Aeye** (Medium or Large).

**Watch:** long-press the watch face → Edit → Complications → pick **Aeye**  
(or add the rectangular complication / Smart Stack widget).

## Architecture

```
Aeye/                 iPhone app (settings + overview + WCSession sender)
AeyeWidget/           iPhone WidgetKit extension
AeyeWatch/            watchOS app (overview + WCSession receiver)
AeyeWatchWidgets/     Watch complications (WidgetKit accessory families)
Shared/               Models, formatting, API clients, snapshot + watch bridge
Config/               Entitlements & extension Info.plists
```

- **No backend** — credentials in iPhone Keychain only
- **iPhone App Group** — shared JSON snapshot for the iPhone widget
- **Watch App Group** — last synced snapshot for Watch app + complications
- **WatchConnectivity** — iPhone → Watch push on each refresh
- **Logic port** — `Shared/AeyeFormatting.swift` + `Shared/AeyeService.swift` mirror `src/aieye.py`

## Getting tokens

Same as before — see Cursor cookie / Claude OAuth notes in the Alfred README. Tokens are entered **only on iPhone**.

## Known limitations

- Watch UI depends on a recent iPhone sync; open the iPhone app and refresh if the Watch looks stale
- WatchConnectivity delivery is best-effort while devices are paired and unlocked
- Undocumented Cursor / Anthropic APIs may change without notice
- Complication focus row is currently the first visible row (usually Composer / Auto)
- Claude hourly pace suffix only when a session is marked active (same as Alfred); OAuth API may not report that

## License

Same as the parent [alfred-aeye](../README.md) project.
