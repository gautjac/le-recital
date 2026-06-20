#!/usr/bin/env bash
# Build Le Récital (Release) and install it to a connected iPhone/iPad.
#
# Why this script exists (two traps the Atelier native apps hit):
#   1. iCloud xattrs: build output must stay OUT of iCloud or `codesign` refuses
#      to sign a bundle ("resource fork, Finder information, or similar detritus
#      not allowed"). FIX: DerivedData in /tmp. (This repo lives in ~/Claude,
#      which is Obsidian-synced, so the rule still applies.)
#   2. Debug "debug dylib": modern Debug builds produce a stub that loads a
#      *.debug.dylib and expects to be launched by Xcode. FIX: build RELEASE.
#
# Requirements: device connected & unlocked, Developer Mode ON, signed in to
# Jac's Apple Developer account (team 9WZ66DZ69J).
set -euo pipefail
cd "$(dirname "$0")"

DD="${RECITAL_DD:-/tmp/le-recital-rel-dd}"   # DerivedData OUTSIDE iCloud (critical)

echo "==> Generating project…"
./gen.sh >/dev/null

echo "==> Building Release for device…"
xcodebuild -project LeRecital.xcodeproj -scheme "LeRecital" \
  -configuration Release -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates -derivedDataPath "$DD" build

APP="$DD/Build/Products/Release-iphoneos/Le Récital.app"
[[ -d "$APP" ]] || { echo "Build product not found at $APP" >&2; exit 1; }

# Find the first *connected* iPhone/iPad (devicectl identifier).
PHONE="$(xcrun devicectl list devices 2>/dev/null \
  | awk -F'  +' '/(iPhone|iPad)/ && /connected/ {print $3; exit}')"
[[ -n "${PHONE:-}" ]] || { echo "No connected device found (connect & unlock it)." >&2; exit 1; }
echo "==> Installing to device $PHONE …"

xcrun devicectl device uninstall app --device "$PHONE" app.atelier.lerecital >/dev/null 2>&1 || true
xcrun devicectl device install app --device "$PHONE" "$APP"

echo
echo "==> Le Récital (Release) installed. Open it and learn a poem by heart."
