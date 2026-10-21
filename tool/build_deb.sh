#!/usr/bin/env bash
#
# Builds a Debian package of the Linux bundle of Snigea.
#
# The Flutter template of the Linux target produces a folder and not a
# package, this script assembles the folder into a .deb file with the desktop
# entry, the icon and the launcher of the application.
#
#   tool/build_deb.sh <bundle folder> <version> <output file>
#
# It needs dpkg-deb, it is used by the release workflow of the repository.
#
set -euo pipefail

BUNDLE="${1:-build/linux/x64/release/bundle}"
VERSION="${2:-0.0.0}"
OUTPUT="${3:-snigea.deb}"

NAME="snigea"
MAINTAINER="Snigea contributors <snigea@users.noreply.github.com>"

if [ ! -d "$BUNDLE" ]; then
  echo "The bundle folder '$BUNDLE' does not exist." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

install -d "$STAGE/DEBIAN" \
  "$STAGE/opt/$NAME" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/512x512/apps"

cp -a "$BUNDLE/." "$STAGE/opt/$NAME/"

# The temporary folder is created private, a package needs readable folders.
chmod 0755 "$STAGE"
find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f ! -perm -u+x -exec chmod 0644 {} +

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $NAME
Version: $VERSION
Section: video
Priority: optional
Architecture: amd64
Maintainer: $MAINTAINER
Depends: libgtk-3-0 | libgtk-4-1, libmpv2, libstdc++6, libglu1-mesa
Homepage: https://github.com/MurShidM01/Snigea
Description: Snigea, an open source movie and TV streaming client
 A Flutter client for the MovieBox, 4KHDHub, Dramachi, BDIX and Stremio addon
 providers, with an embedded player, downloads and a local library.
EOF

cat > "$STAGE/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "configure" ]; then
  update-desktop-database -q /usr/share/applications || true
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF

cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
  update-desktop-database -q /usr/share/applications || true
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF

chmod 0755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

cat > "$STAGE/usr/bin/$NAME" <<EOF
#!/bin/sh
exec "/opt/$NAME/$NAME" "\$@"
EOF
chmod 0755 "$STAGE/usr/bin/$NAME"

cat > "$STAGE/usr/share/applications/$NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Snigea
GenericName=Media Player
Comment=An open source movie and TV streaming client
Exec=$NAME
Icon=$NAME
Categories=AudioVideo;Video;Player;
Terminal=false
StartupNotify=true
EOF

ICON="assets/icon/snigea_logo.png"
if [ -f "$ICON" ]; then
  cp "$ICON" "$STAGE/usr/share/icons/hicolor/512x512/apps/$NAME.png"
fi

if dpkg-deb --help 2>&1 | grep -q -- "--root-owner-group"; then
  dpkg-deb --root-owner-group --build "$STAGE" "$OUTPUT"
else
  dpkg-deb --build "$STAGE" "$OUTPUT"
fi

echo "The package $OUTPUT was built."
dpkg-deb --info "$OUTPUT" | head -12
