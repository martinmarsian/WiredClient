#!/bin/bash
# release.sh — App aus xcarchive extrahieren, Developer-ID re-signieren,
#              ZIP (für Sparkle) + DMG (für manuellen Download) erstellen,
#              DMG notarisieren/stapeln, ZIP EdDSA-signieren (Sparkle 2.x),
#              appcast.xml aktualisieren.
#
# Voraussetzung: Archiv wurde in Xcode mit Product → Archive erstellt.
#
# Aufruf:
#   ./release.sh <xcarchive-Pfad> <version> <build> <github-tag>
#
# Beispiel:
#   ./release.sh ~/Library/Developer/Xcode/Archives/2026-04-11/Wired\ Client.xcarchive 2.6 94 v2.6
#
# Nächste Version:
#   ./release.sh ~/Library/Developer/Xcode/Archives/.../Wired\ Client.xcarchive 2.7 95 v2.7

set -euo pipefail

# ── Konfiguration ─────────────────────────────────────────────────────────────
# Werte als Umgebungsvariablen setzen, z.B. in ~/.zshrc oder ~/.bash_profile:
#   export WC_APPLE_ID="your@apple.id"
#   export WC_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # appleid.apple.com → App-Specific Passwords
#   export WC_TEAM_ID="XXXXXXXXXX"
#   export WC_SIGN_ID="<SHA1 des Developer ID Application Zertifikats>"
#   export WC_GITHUB_REPO="user/repo"
SIGN_ID="${WC_SIGN_ID:?WC_SIGN_ID nicht gesetzt}"
GITHUB_REPO="${WC_GITHUB_REPO:?WC_GITHUB_REPO nicht gesetzt}"
# Notarization uses a Keychain profile (stored once via:
#   xcrun notarytool store-credentials "WiredClientRelease" --apple-id ... --team-id ... --password ...)
NOTARY_PROFILE="${WC_NOTARY_PROFILE:-WiredClientRelease}"
# ──────────────────────────────────────────────────────────────────────────────

SRCROOT="$(cd "$(dirname "$0")" && pwd)"
SIGN_UPDATE="$SRCROOT/Pods/Sparkle/bin/sign_update"
APPCAST="$SRCROOT/appcast.xml"

# ── Argumente prüfen ──────────────────────────────────────────────────────────
if [ $# -ne 4 ]; then
    echo "Aufruf: $0 <xcarchive-Pfad> <version> <build> <github-tag>"
    echo "Aktuell: $0 ~/Library/Developer/Xcode/Archives/.../Wired\\ Client.xcarchive 2.6 94 v2.6"
    exit 1
fi

XCARCHIVE="$1"; VERSION="$2"; BUILD="$3"; TAG="$4"
XCARCHIVE="${XCARCHIVE/#\~/$HOME}"

[ -d "$XCARCHIVE" ]   || { echo "ERROR: xcarchive nicht gefunden: $XCARCHIVE"; exit 1; }
[ -f "$SIGN_UPDATE" ] || { echo "ERROR: sign_update nicht gefunden: $SIGN_UPDATE"; exit 1; }
[ -f "$APPCAST" ]     || { echo "ERROR: appcast.xml nicht gefunden"; exit 1; }

ZIP_BASENAME="WiredClient-${VERSION}.zip"
DMG_BASENAME="WiredClient-${VERSION}.dmg"
ZIP="$SRCROOT/${ZIP_BASENAME}"
DMG="$SRCROOT/${DMG_BASENAME}"
WORK_DIR="/tmp/wcrelease_$$"

# ── App aus xcarchive kopieren ─────────────────────────────────────────────────
echo "=== App aus xcarchive extrahieren ==="
APP_SRC="$XCARCHIVE/Products/Applications/Wired Client.app"
[ -d "$APP_SRC" ] || { echo "ERROR: App nicht im xcarchive: $APP_SRC"; exit 1; }
mkdir -p "$WORK_DIR"
APP="$WORK_DIR/Wired Client.app"
ditto "$APP_SRC" "$APP"
echo "Kopiert nach: $APP"

# ── Entitlements-Datei schreiben ──────────────────────────────────────────────
ENTITLEMENTS="$WORK_DIR/entitlements.plist"
cat >"$ENTITLEMENTS" <<'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENTEOF

# ── Re-signieren mit Developer ID Application ─────────────────────────────────
echo "=== Re-signieren mit Developer ID Application ==="

sign_fw() {
    local fw="$1"
    local name
    name=$(basename "$fw")
    if [ -d "$fw/Versions" ]; then
        local ver
        ver=$(readlink "$fw/Versions/Current" 2>/dev/null || echo "A")
        if [ "$name" = "Sparkle.framework" ]; then
            codesign --force --sign "$SIGN_ID" --options runtime --timestamp \
                "$fw/Versions/$ver"
        else
            codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$fw"
        fi
    else
        codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$fw"
    fi
}

# 1. Sparkle fileop
echo "  Signing: Sparkle fileop"
find "$APP/Contents/Frameworks/Sparkle.framework" -name "fileop" \
    > "$WORK_DIR/fileops.txt" 2>/dev/null || true
while IFS= read -r fp; do
    [ -z "$fp" ] && continue
    codesign --force --sign "$SIGN_ID" --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" "$fp"
done < "$WORK_DIR/fileops.txt"

# 2. Nested .app bundles in Frameworks (Sparkle Autoupdate.app)
echo "  Signing: nested .app bundles in Frameworks"
find "$APP/Contents/Frameworks" -name "*.app" \
    > "$WORK_DIR/nested_apps.txt" 2>/dev/null || true
while IFS= read -r nested; do
    [ -z "$nested" ] && continue
    echo "    $(basename "$nested")"
    codesign --force --sign "$SIGN_ID" --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" "$nested"
done < "$WORK_DIR/nested_apps.txt"

# 3. Sparkle 2.x: Autoupdate binary + XPC services
echo "  Signing: Sparkle 2.x Autoupdate + XPC services"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE_VER=$(readlink "$SPARKLE/Versions/Current" 2>/dev/null || echo "B")
SPARKLE_B="$SPARKLE/Versions/$SPARKLE_VER"
if [ -d "$SPARKLE_B" ]; then
    if [ -f "$SPARKLE_B/Autoupdate" ]; then
        codesign --force --sign "$SIGN_ID" --options runtime --timestamp \
            "$SPARKLE_B/Autoupdate"
    fi
    for xpc in "$SPARKLE_B/XPCServices/"*.xpc; do
        [ -d "$xpc" ] || continue
        echo "    $(basename "$xpc")"
        codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$xpc"
    done
fi

# 4. Sparkle.framework
echo "  Signing: Sparkle.framework"
[ -d "$SPARKLE" ] && sign_fw "$SPARKLE"

# 4b. Frameworks nested inside other frameworks (e.g. WiredFoundation inside WiredNetworking)
echo "  Signing: nested frameworks"
for nested_fw in "$APP/Contents/Frameworks/"*.framework/Versions/*/Frameworks/*.framework; do
    [ -d "$nested_fw" ] || continue
    echo "    $(basename "$nested_fw") (nested)"
    sign_fw "$nested_fw"
done

# 5. Weitere Frameworks
echo "  Signing: app frameworks"
for fw in "$APP/Contents/Frameworks/"*.framework; do
    [ -d "$fw" ] || continue
    name=$(basename "$fw")
    [ "$name" = "Sparkle.framework" ] && continue
    echo "    $name"
    sign_fw "$fw"
done

# 6. Haupt-App
echo "  Signing: Wired Client.app"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" "$APP"

codesign --verify --deep --strict "$APP" && echo "Signatur verifiziert."
codesign -dvv "$APP" 2>&1 | grep "^Authority="

# ── ZIP erstellen (für Sparkle auto-update) ───────────────────────────────────
echo "=== ZIP erstellen (Sparkle auto-update) ==="
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "ZIP erstellt: $ZIP"

# ── DMG erstellen (für manuellen Download) ────────────────────────────────────
echo "=== DMG erstellen (manueller Download) ==="
hdiutil create \
    -volname "Wired Client ${VERSION}" \
    -srcfolder "$APP" \
    -ov -format UDZO \
    "$DMG"
echo "DMG erstellt: $DMG"

rm -rf "$WORK_DIR"

PUBDATE=$(LC_TIME=en_US date -u "+%a, %d %b %Y %T +0000")

notarize() {
    local file="$1"
    local label="$2"
    echo "=== ${label} Notarisierung ==="
    local out rc
    set +e
    out=$(xcrun notarytool submit "$file" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1)
    rc=$?
    set -e
    echo "$out"
    if [ $rc -ne 0 ] || ! echo "$out" | grep -q "status: Accepted"; then
        local nid
        nid=$(echo "$out" | grep -o 'id: [0-9a-f-]*' | head -1 | awk '{print $2}')
        echo "ERROR: Notarisierung fehlgeschlagen!"
        if [ -n "$nid" ]; then
            echo "Log: xcrun notarytool log $nid --keychain-profile \"$NOTARY_PROFILE\""
        fi
        exit 1
    fi
    echo "${label} Notarisierung abgeschlossen."
}

# ── ZIP notarisieren ──────────────────────────────────────────────────────────
notarize "$ZIP" "ZIP"

# ── DMG notarisieren und stapeln ──────────────────────────────────────────────
notarize "$DMG" "DMG"

echo "=== DMG Stapling ==="
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG" && echo "Staple OK."

# ── ZIP EdDSA-Signatur für Sparkle 2.x ───────────────────────────────────────
echo "=== Sparkle EdDSA-Signatur (ZIP) ==="
ED_SIG=$("$SIGN_UPDATE" -p "$ZIP" | tr -d '\n')
echo "EdDSA: $ED_SIG"

# ── Dateigrößen ───────────────────────────────────────────────────────────────
ZIP_SIZE=$(wc -c < "$ZIP" | tr -d ' ')
DMG_SIZE=$(wc -c < "$DMG" | tr -d ' ')
echo "ZIP: ${ZIP_SIZE} Bytes"
echo "DMG: ${DMG_SIZE} Bytes"

# ── appcast.xml aktualisieren (ZIP als Sparkle-Enclosure) ─────────────────────
echo "=== appcast.xml aktualisieren ==="
ZIP_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${ZIP_BASENAME}"

python3 <<PYEOF
import re

path = "$APPCAST"
new_item = """
    <item>
      <title>Wired Client $VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:releaseNotesLink>
        https://github.com/$GITHUB_REPO/releases/tag/$TAG
      </sparkle:releaseNotesLink>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$ZIP_URL"
        sparkle:version="$BUILD"
        sparkle:shortVersionString="$VERSION"
        type="application/zip"
        length="$ZIP_SIZE"
        sparkle:edSignature="${ED_SIG}"/>
    </item>"""

with open(path) as f:
    content = f.read()

content = re.sub(
    r'\s*<item>.*?REPLACE_WITH_BASE64_SIGNATURE.*?</item>',
    '',
    content,
    flags=re.DOTALL
)

content = content.replace('  </channel>', new_item + '\n\n  </channel>', 1)

with open(path, 'w') as f:
    f.write(content)

print("appcast.xml aktualisiert.")
PYEOF

echo ""
echo "========================================"
echo " Fertig! Nächste Schritte:"
echo "========================================"
echo " 1. Beide Dateien auf GitHub hochladen:"
echo "    Release ${TAG} → Assets:"
echo "      ${ZIP_BASENAME}  (${ZIP_SIZE} Bytes)  ← Sparkle auto-update"
echo "      ${DMG_BASENAME}  (${DMG_SIZE} Bytes)  ← manueller Download"
echo " 2. appcast.xml committen und pushen:"
echo "    git add appcast.xml"
echo "    git commit -m 'release: appcast ${VERSION}'"
echo "    git push fork master"
echo " 3. GitHub Release veröffentlichen"
echo "========================================"
