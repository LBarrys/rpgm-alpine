#!/bin/sh
# Install or remove rpgm.
#   ./install.sh               system-wide into /usr/local (run as root)
#   ./install.sh --user        into ~/.local
#   ./install.sh --uninstall   remove (combine with --user if installed that way)
# PREFIX and DESTDIR are honoured for packaging.
set -eu

src=$(cd "$(dirname "$0")" && pwd)
prefix=${PREFIX:-/usr/local}
destdir=${DESTDIR:-}
uninstall=

for arg in "$@"; do
	case $arg in
	--user) prefix=$HOME/.local ;;
	--uninstall) uninstall=1 ;;
	-h | --help) sed -n '2,6p' "$0" | cut -c3-; exit 0 ;;
	*) echo "install.sh: unknown option $arg" >&2; exit 1 ;;
	esac
done

app=$destdir$prefix/lib/rpgm # not share/rpgm: that is where per-game data lives
bin=$destdir$prefix/bin
apps=$destdir$prefix/share/applications

if [ -n "$uninstall" ]; then
	rm -rf "$app" "$bin/rpgm" "$apps/rpgm.desktop"
	echo "Removed rpgm from $prefix."
	echo "Per-game data (browser storage, unpacked package.nw games and their saves) is kept"
	echo "in ~/.local/share/rpgm; delete it by hand if you really want to."
	exit 0
fi

mkdir -p "$app/lib/rgss" "$bin" "$apps"
install -m 755 "$src/rpgm" "$app/rpgm"
install -m 644 "$src"/lib/*.js "$src"/lib/package.json "$src"/lib/*.awk "$app/lib/"
install -m 644 "$src"/lib/rgss/*.rb "$app/lib/rgss/" # mkxp-z preload scripts
install -m 644 "$src/rpgm.desktop" "$apps/rpgm.desktop"
ln -sf "$prefix/lib/rpgm/rpgm" "$bin/rpgm"
if [ -z "$destdir" ] && command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database -q "$apps" 2>/dev/null || true
fi

echo "Installed rpgm to $prefix."
if ! command -v electron >/dev/null 2>&1; then
	echo "No runtime found yet: apk add electron (Alpine edge, testing repository)"
fi
case :$PATH: in
*:"$prefix/bin":*) ;;
*) echo "Note: $prefix/bin is not in your PATH." ;;
esac
