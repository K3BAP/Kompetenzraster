#!/usr/bin/env bash
# Schreibt die Versionsdatei, die neben dem ZIP am Release hängt.
# Die App lädt genau diese Datei, um zu erkennen, ob es etwas Neueres gibt.
set -euo pipefail

VERSION="$1"
BUILD="$2"
ZIEL="$3"
BENUTZER="${GITHUB_REPOSITORY_OWNER:-K3BAP}"
PROJEKT="${GITHUB_REPOSITORY##*/}"
PROJEKT="${PROJEKT:-Kompetenzraster}"

cat > "$ZIEL" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "veroeffentlichtAm": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "download": "https://github.com/$BENUTZER/$PROJEKT/releases/download/latest/Kompetenzraster.zip",
  "hinweise": "Automatischer Build aus main"
}
JSON

echo "manifest: $ZIEL (Version $VERSION, Build $BUILD)"
