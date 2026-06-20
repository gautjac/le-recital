#!/usr/bin/env bash
# Regenerate LeRecital.xcodeproj from project.yml (and refresh the app icon set).
#
# Le Récital is iOS/iPadOS (no watch/mac target), so the single iOS scheme
# resolves a simulator destination directly.
set -euo pipefail
cd "$(dirname "$0")"

# Keep the opaque app-icon set fresh (a missing/alpha icon = install failure).
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/gen-appicon.py >/dev/null || echo "warn: icon gen skipped"
fi

/opt/homebrew/bin/xcodegen generate --spec project.yml
echo "Generated LeRecital.xcodeproj"
