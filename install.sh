#!/bin/sh
# Déploie Moisson dans les dossiers AddOns de Classic Era :
# l'install Mac, et celle de legioul (le PC de jeu) quand son C: est monté.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)/Moisson/"

deploy() {
	rsync -a --delete "$SRC" "$1"
	echo "Moisson déployé → $1"
}

deploy "/Applications/World of Warcraft/_classic_era_/Interface/AddOns/Moisson/"

LEGIOUL="/Volumes/legioul/Program Files (x86)/World of Warcraft/_classic_era_/Interface/AddOns/Moisson/"
if [ -d "$(dirname "$LEGIOUL")" ]; then
	deploy "$LEGIOUL"
else
	echo "⚠ legioul non monté — pense à copier l'addon sur le PC."
fi
