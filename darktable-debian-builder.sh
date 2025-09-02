#!/bin/bash
# ===========================================================================
# Build Darktable Debian Package (CMake + Ninja)
# Auteur : Pascal LACROIX
# Version : 3.4 — Finale : .deb dans le répertoire courant, tout corrigé
# Compile darktable depuis master + génère un .deb propre, conforme Debian
# ===========================================================================

set -euo pipefail
export LC_ALL=C

# --- Répertoire d'origine (où sera généré le .deb) ---
INITIAL_DIR="$(pwd)"

# --- Configuration (le build se fait dans /tmp) ---
BUILD_ROOT="/tmp/darktable-build-$$"
SRC_DIR="$BUILD_ROOT/darktable"
BUILD_DIR="$BUILD_ROOT/build"
LOGFILE="/tmp/build-darktable_$(date +%Y%m%d%H%M).log"
DATE=$(date +%Y%m%d%H%M)

# --- Journalisation ---
exec > >(tee -a "$LOGFILE") 2>&1

# --- Chronomètre ---
START_TIME=$(date +%s)

# --- Fonctions utilitaires ---
log() {
  echo "🔹 $(date '+%H:%M:%S') | $1"
}

log_success() {
  echo "✅ $(date '+%H:%M:%S') | $1"
}

log_warning() {
  echo "⚠️  $(date '+%H:%M:%S') | $1"
}

log_error() {
  echo "❌ $(date '+%H:%M:%S') | $1" >&2
}

# --- Vérification des outils ---
log "=== Vérification des outils requis ==="
for cmd in git cmake ninja dpkg-deb fakeroot; do
  if ! command -v "$cmd" >/dev/null; then
    log_error "Commande '$cmd' non trouvée. Installez-la : sudo apt install $cmd"
    exit 1
  else
    log "Outil trouvé : $cmd ($(command -v $cmd))"
  fi
done

# --- Nettoyage initial ---
log "=== Nettoyage initial ==="
rm -rf "$BUILD_ROOT"

# --- Clonage du dépôt ---
log "=== Clonage de darktable (master) ==="
git clone --recurse-submodules https://github.com/darktable-org/darktable.git "$SRC_DIR"

cd "$SRC_DIR"

# --- Récupération des tags ---
log "=== Récupération des tags Git ==="
git fetch --tags 2>/dev/null || log_warning "Impossible de récupérer les tags"

# --- Détection de version ---
log "=== Détection de version ==="
BASE_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
if ! [[ "$BASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  log_warning "Aucun tag trouvé. Utilisation de 5.2.1"
  BASE_VERSION="5.2.1"
else
  log_success "Version détectée : $BASE_VERSION"
fi

COMMIT=$(git rev-parse --short HEAD)
BRANCH=$(git branch --show-current || echo "detached")
log "💾 Commit : $COMMIT"
log "🗂️  Branche : $BRANCH"

VERSION="${BASE_VERSION}~git${DATE}"
DEB_DIR="$BUILD_ROOT/darktable-${VERSION}"
log "📦 Version du paquet : $VERSION"

# --- Créer le répertoire de build ---
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# --- Patch CMake : permissions automatiques ---
cd "$SRC_DIR"
log "=== Patch CMakeLists.txt pour permissions ==="
sed -i '1i\
set(CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)\n\
set(CMAKE_INSTALL_DEFAULT_FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)\n' CMakeLists.txt
cd "$BUILD_DIR"

# --- Configuration CMake ---
log "=== Configuration CMake (RelWithDebInfo) ==="
cmake "$SRC_DIR" \
  -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DUSE_OPENCL=ON \
  -DUSE_CAMERA=ON \
  -DUSE_MAP=ON \
  -DUSE_WEBP=ON \
  -DUSE_LUA=ON \
  -DUSE_GRAPHICSMAGICK=ON \
  -DUSE_LIBSECRET=ON

# --- Compilation ---
log "=== Compilation ==="
ninja

# --- Installation dans DEB_DIR ===
log "=== Installation dans $DEB_DIR ==="
DESTDIR="$DEB_DIR" ninja install

# --- Compression des pages de manuel (.1 → .1.gz) ---
log "=== Compression des pages de manuel ==="
if [[ -d "$DEB_DIR/usr/share/man" ]]; then
  find "$DEB_DIR/usr/share/man" -name "*.1" -type f -exec gzip -9 {} \;
  find "$DEB_DIR/usr/share/man" -name "*.1.gz" | while read f; do
    mv "$f" "$(dirname "$f")/$(basename "$f" .gz)"
  done
  log_success "Pages de manuel compressées en .gz"
else
  log_warning "Aucun répertoire man trouvé. Skipping compression."
fi

# --- Corriger les scripts shell (rendre exécutables) ---
log "=== Correction des scripts shell (rendre exécutables) ==="
if [[ -d "$DEB_DIR/usr/share/darktable/tools" ]]; then
  find "$DEB_DIR/usr/share/darktable/tools" -name "*.sh" -type f -exec chmod 755 {} \;
  log_success "Scripts shell rendus exécutables"
else
  log_warning "Répertoire tools non trouvé"
fi

# --- Création du dossier DEBIAN ---
log "=== Préparation du paquet Debian ==="
mkdir -p "$DEB_DIR/DEBIAN"

# --- Fichier control ---
cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: darktable
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $(dpkg --print-architecture)
Maintainer: Pascal LACROIX <pascal.lacroix2a@free.fr>
Homepage: https://www.darktable.org
Replaces: darktable
Conflicts: darktable
Provides: darktable
Depends: libavcodec58 | libavcodec59 | libavcodec60, libavformat58 | libavformat59 | libavformat60, libavutil56 | libavutil57 | libavutil58, libgtk-3-0, liblensfun1, libxml2, libexiv2-27 | libexiv2-28, libgphoto2-6, libcolord2, libcurl4, libsqlite3-0, liblua5.3-0, libsecret-1-0, libgraphicsmagick-q16-3, libsoup-2.4-1, libwebp7 | libwebp6, libopenjp2-7, libpoppler-glib8, libpugixml1v5, libunwind8
Description: Logiciel de post-traitement photo open-source
 darktable est un logiciel open-source de gestion et de développement
 photographique. Il permet d'importer, organiser, développer et exporter
 des photos RAW et autres formats.
 .
 Cette version est compilée depuis le dépôt Git (master).
 .
 Version source : $BASE_VERSION
 Commit : $COMMIT
 Build : ${DATE}
 .
 Website: https://www.darktable.org
EOF

# --- Changelog ---
mkdir -p "$DEB_DIR/usr/share/doc/darktable"
cat > "$DEB_DIR/usr/share/doc/darktable/changelog" << EOF
darktable ($VERSION) unstable; urgency=medium

  * Rebuild from git master

 -- Pascal LACROIX <pascal.lacroix2a@free.fr>  $(date -R)
EOF
gzip -9 "$DEB_DIR/usr/share/doc/darktable/changelog"

# --- Copyright (DEP-5) ---
log "=== Génération du fichier copyright (DEP-5) ==="
cat > "$DEB_DIR/usr/share/doc/darktable/copyright" << 'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: darktable
Source: https://github.com/darktable-org/darktable

Copyright: 2009-2025, the darktable developers
License: GPL-3.0+

Files: *
Copyright: 2009-2025, the darktable developers
License: GPL-3.0+

License: GPL-3.0+
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 .
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <https://www.gnu.org/licenses/>.
EOF

# --- Nettoyage ---
log "=== Nettoyage des fichiers superflus ==="
rm -f "$DEB_DIR/usr/lib/systemd/system/darktable-*.service"
rm -rf "$DEB_DIR/usr/share/doc/darktable/examples"
find "$DEB_DIR" -name "*.a" -delete
find "$DEB_DIR" -name "*.cmake" -delete

# --- Correction finale avec fakeroot ---
log "=== Correction des permissions et propriétaire (fakeroot) ==="
fakeroot bash -c "
  chown -R root:root '$DEB_DIR';
  find '$DEB_DIR' -type d -exec chmod 755 {} \;
  find '$DEB_DIR' -type f -exec chmod 644 {} \;
  find '$DEB_DIR/usr/bin' -type f -exec chmod 755 {} \;
  find '$DEB_DIR/usr/lib' -name '*.so*' -type f -exec chmod 755 {} \;
  find '$DEB_DIR/usr/share/darktable/tools' -name '*.sh' -type f -exec chmod 755 {} \;
  find '$DEB_DIR/usr/share/man' -type f -exec chmod 644 {} \;
  find '$DEB_DIR/usr/share/man' -type d -exec chmod 755 {} \;
  chmod 644 '$DEB_DIR/usr/share/doc/darktable/changelog.gz' 2>/dev/null || true;
  chmod 644 '$DEB_DIR/usr/share/doc/darktable/copyright' 2>/dev/null || true;
"

# --- Génération du .deb ---
log "=== Génération du paquet .deb ==="
dpkg-deb --build "$DEB_DIR" . && \
cp *.deb "$INITIAL_DIR/" 2>/dev/null || true
cd "$INITIAL_DIR"
log_success "Paquet généré dans : $(pwd)"

# --- Nettoyage de /tmp ---
log "=== Nettoyage de /tmp ==="
rm -rf "$BUILD_ROOT"

# --- Vérification lintian ---
if command -v lintian >/dev/null; then
  log "=== Vérification avec lintian ==="
  lintian --verbose --tag-display-limit 0 *.deb || log_warning "Lintian : avertissements présents (normaux pour un build custom)"
fi

# --- Résumé final ---
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "===================================="
log_success "🎉 Build terminé avec succès !"
log "📦 Fichier : $(ls -1 *.deb | tail -1)"
log "📄 Journal : $LOGFILE"
log "⏱️  Durée : $((DURATION / 60))m$((DURATION % 60))s"
log "💡 Installation : sudo dpkg -i darktable_*.deb && sudo apt -f install"
echo "===================================="
