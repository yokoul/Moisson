#!/bin/sh
# Zip de release CurseForge — même recette qu'AuberdineExporter :
# version lue depuis le .toc (une seule source de vérité), staging dans
# build/, LICENSE embarquée, zip nommé Moisson-vX.Y.Z.zip.
set -e
cd "$(dirname "$0")"

VERSION="$(sed -n 's/^## Version: //p' Moisson/Moisson.toc | tr -d '[:space:]')"
if [ -z "$VERSION" ]; then
	echo "version introuvable dans Moisson/Moisson.toc" >&2
	exit 1
fi

BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cp -R Moisson "$BUILD_DIR/Moisson"
cp LICENSE "$BUILD_DIR/Moisson/LICENSE"

cd "$BUILD_DIR"
zip -r "Moisson-v${VERSION}.zip" Moisson -x "*.DS_Store*"
cd ..

echo ""
unzip -l "$BUILD_DIR/Moisson-v${VERSION}.zip"
echo ""
echo "prêt pour CurseForge : $(pwd)/$BUILD_DIR/Moisson-v${VERSION}.zip"
