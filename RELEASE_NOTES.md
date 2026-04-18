# Wired Client — Release Notes

## Version 2.7 (Build 104)

### What's New (Build 104)

- **Split user list** — the user list panel is now divided into two independent sections: **Online** (top) and **Offline** (bottom), each with its own scrollbar. Both sections display a live user count in their header (e.g. „Online (3)" / „Offline (2)"). Online users are shown at full opacity; offline users remain grayed out at 40% opacity.

---

## Version 2.7 (Build 103)

### What's New (Build 103)

- **Offline user cache from server** — when logging into a Wired Server 2.5.8+ server, the client now receives a list of recently active users (`wired.user.known_users`) directly from the server. This ensures the offline user list is populated correctly even on a new installation or a different machine, without requiring admin access.

### Bug Fixes (Build 103)

- **MMTabBarView build fix** — resolved a linker error caused by Xcode 26 removing `libarclite_macosx.a`. Set `CLANG_LINK_OBJC_RUNTIME = NO` and `MACOSX_DEPLOYMENT_TARGET = 13.0` in the MMTabBarView build configurations.

---

## Version 2.7 (Build 100)

### Bug Fixes (Build 100)

- **Auto-Update (Sparkle)** — the update check now works correctly. The cached legacy feed URL (`wired.read-write.fr`) was still stored in the app's preferences domain and overrode the Info.plist value. The programmatic `setFeedURL:` override has been removed; Sparkle now reads the URL exclusively from Info.plist (`raw.githubusercontent.com/martinmarsian/WiredClient/master/appcast.xml`).
- **Archive configuration** — the default Xcode scheme now correctly archives with the **Release** build configuration, ensuring the released binary uses the production bundle ID `fr.read-write.WiredClient` (not `fr.read-write.WiredClientDebug`).

### Migration Note for Testers / Developers

If you previously ran a **Debug build** of Wired Client, your bookmarks and preferences are stored under the debug bundle ID. To migrate your settings to the Release build, rename the preferences file before launching Release 100 for the first time:

```bash
cp ~/Library/Preferences/fr.read-write.WiredClientDebug.plist \
   ~/Library/Preferences/fr.read-write.WiredClient.plist
```

---

## Version 2.7 (Build 98)

### Bug Fixes (Build 98)

- **Auto-Update feed** — the Sparkle update feed URL was pointing to the old `wired.read-write.fr` server. Updated to the GitHub raw URL (`raw.githubusercontent.com/martinmarsian/WiredClient/master/appcast.xml`) so "Check for Updates" works correctly.

---

## Version 2.7 (Build 97)

### Bug Fixes (Build 97)

- **Boards toolbar** — action icons (New Thread, Delete Thread, Post Reply, Mark as Read, Mark All as Read) were invisible or hidden in the overflow menu (`>>`) on macOS 26 Liquid Glass. Fixed by converting all items to view-based `NSButton` with a fixed 32×32 frame, preventing Liquid Glass from expanding the capsule width.
- **Boards post panel** — the compose area was split in two; the preview pane is now collapsed so only the editor is visible by default.
- **Toolbar customize sheet — oversized icons** — Dateien (512×512 PNG), Es spielt gerade and Chat Verlauf (256×256 PNG), Bann-Liste (64×64 PNG) and Trennen (PDF vector) all rendered at full resolution in the Customize Toolbar sheet. Converted to view-based `NSButton` items with fixed 32×32 frames.
- **Toolbar customize sheet — Banner placeholder** — the Banner item showed as an empty dashed box when no server is connected. Now falls back to the built-in `Banner` asset (200×32) correctly.

---

## Version 2.7 (Build 94)

### What's New

---

### Offline Messaging

Private messages can now be sent to users who are not currently connected. The server stores the message and delivers it the next time the recipient logs in.

**How it works:**

- Offline users appear as **grayed-out entries** in the chat user list (40% opacity)
- Clicking an offline user opens the private message window as usual — the message is delivered when the recipient reconnects
- Pending messages stored on the server are displayed automatically on your next login
- The offline user list is cached per server, so known users remain visible even after they disconnect

**Requirements:** Wired Server 2.5.8 or later is required for offline message storage and delivery. The offline user display in the chat list works with any server that sends login names (Wired Server 2.5.8+).

---

### macOS 26 Liquid Glass Toolbar

The Public Chat toolbar has been redesigned for macOS 26 (Tahoe) with the new **Liquid Glass** appearance:

- Toolbar items use `NSToolbarItemGroup` with `.automaticPopup` display mode, adapting cleanly to window width
- The topic bar now has a proper separator line at its bottom edge
- All toolbar icons and layout are optimised for both light and dark appearance on macOS 26

---

### TLS Security Hardening

- **TLS 1.2 minimum** — connections to Wired servers now require TLS 1.2 or higher. The legacy `TLSv1_client_method()` and `TLSv1_1_*` APIs have been removed in favour of `TLS_client_method()` with an explicit minimum version of TLS 1.2
- **Strongest cipher enforced** — the encryption is always AES-256 with SHA-512, the strongest combination supported by the Wired protocol
- **Weak ciphers removed** — Blowfish and 3DES have been removed from the cipher list entirely; any server-side selection is silently remapped to AES-256

---

### Cipher Selection Hidden

The cipher selection dropdown in the Bookmark editor and Connect dialog has been hidden. The client always negotiates the strongest available cipher (AES-256/SHA-512) automatically — manual selection was confusing and offered no security benefit.

---

### Bug Fixes

- **Crash on reconnect** — fixed a crash that occurred when reconnecting to a server where a private message conversation was already open
- **Checksum algorithm** — corrected a mismatch between the checksum algorithm used for file transfers (SHA-256) and what was declared in the protocol handshake

---

### Release Infrastructure

- **`release.sh`** — new shell script automates the post-archive release pipeline: re-signing with Developer ID Application, creating ZIP (for Sparkle auto-update) and DMG (for manual download), notarizing both with Apple, stapling the DMG, computing the Sparkle EdDSA signature, and updating `appcast.xml`
- **`appcast.xml`** — Sparkle feed updated for 2.7, pointing to the GitHub release assets

---

### Modernization (macOS 13+ / Xcode 26 / Apple Silicon)

This fork has been comprehensively modernized from the original Wired Client codebase:

| Area | Change |
|---|---|
| **Deployment target** | Raised from macOS 10.10 to **macOS 13.0 Ventura** |
| **Architecture** | Universal Binary (Apple Silicon arm64 + Intel x86_64) |
| **OpenSSL** | Upgraded from OpenSSL 1.x to **OpenSSL 3.3** (opaque struct APIs, `DH_set0_pqg`, `EVP_PKEY_base_id`) |
| **Notifications** | Migrated from deprecated Growl/`NSUserNotification` to **`UNUserNotificationCenter`** |
| **Auto-update** | Migrated from Sparkle v1 (`SUUpdater`) to **Sparkle v2** (`SPUStandardUpdaterController`) with EdDSA signatures |
| **Xcode 26 fixes** | `@import Darwin.Availability` → `#import <Availability.h>`; `objc_msgSend` casts for arm64 strict SDK |
| **Build** | Removed custom "Code Sign" build phase that required a specific Developer ID certificate |

---

### System Requirements

| | |
|---|---|
| **macOS** | 13.0 Ventura or later |
| **Architecture** | Universal (Apple Silicon + Intel) |
| **Server** | Wired Server 2.5.7 or later recommended; 2.5.8+ required for offline messaging |

---

### Distribution

- **`WiredClient-2.7.zip`** — used by Sparkle for in-app auto-update. Notarized by Apple.
- **`WiredClient-2.7.dmg`** — for manual download and installation. Notarized and stapled.

---

*Based on the original Wired Client by Rafaël Warnault / nark. Fork maintained by Joerg Maertin.*
