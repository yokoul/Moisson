#!/bin/sh
# Déploie Moisson dans le dossier AddOns de Classic Era.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)/Moisson/"
DST="/Applications/World of Warcraft/_classic_era_/Interface/AddOns/Moisson/"
rsync -a --delete "$SRC" "$DST"
echo "Moisson déployé → $DST"
