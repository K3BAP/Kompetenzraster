#!/usr/bin/env bash
# Schreibt die Versionsdatei, die neben dem ZIP am Release hängt.
# Die App lädt genau diese Datei, um zu erkennen, ob es etwas Neueres gibt –
# und prüft damit auch, dass das heruntergeladene Paket unversehrt ist.
set -euo pipefail

VERSION="$1"
BUILD="$2"
ZIEL="$3"
PAKET="$4"

BENUTZER="${GITHUB_REPOSITORY_OWNER:-K3BAP}"
PROJEKT="${GITHUB_REPOSITORY##*/}"
PROJEKT="${PROJEKT:-Kompetenzraster}"

PRUEFSUMME="$(shasum -a 256 "$PAKET" | awk '{print $1}')"
GROESSE="$(stat -f%z "$PAKET")"

cat > "$ZIEL" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "veroeffentlichtAm": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "download": "https://github.com/$BENUTZER/$PROJEKT/releases/download/latest/$(basename "$PAKET")",
  "sha256": "$PRUEFSUMME",
  "groesse": $GROESSE,
  "hinweise": "Automatischer Build aus main"
}
JSON

echo "manifest: $ZIEL (Version $VERSION, Build $BUILD, $GROESSE Bytes)"
