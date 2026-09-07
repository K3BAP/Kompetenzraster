#!/usr/bin/env bash
# Erzeugt das App-Symbol neu: zeichnet das 1024er Master und rendert daraus
# alle Größen, die das AppIcon-Set braucht. Aufruf über `make icon`.
set -euo pipefail

WURZEL="$(cd "$(dirname "$0")/.." && pwd)"
SET="$WURZEL/Kompetenzraster/Resources/Assets.xcassets/AppIcon.appiconset"

: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$WURZEL"
swift scripts/make_icon.swift

cd "$SET"
erzeuge() { sips -z "$1" "$1" icon_1024.png --out "$2" >/dev/null; }
erzeuge 16  icon_16.png
erzeuge 32  icon_16@2x.png
erzeuge 32  icon_32.png
erzeuge 64  icon_32@2x.png
erzeuge 128 icon_128.png
erzeuge 256 icon_128@2x.png
erzeuge 256 icon_256.png
erzeuge 512 icon_256@2x.png
erzeuge 512 icon_512.png
cp icon_1024.png icon_512@2x.png

echo "icon: $(ls icon_*.png | wc -l | tr -d ' ') Bilder im AppIcon-Set erneuert"
