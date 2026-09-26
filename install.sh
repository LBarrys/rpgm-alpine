#!/bin/sh
set -eu

src=$(cd "$(dirname "$0")" && pwd)
prefix=${PREFIX:-/usr/local}
destdir=${DESTDIR:-}
uninstall=

for arg in "$@"; do
	case $arg in
	--user) prefix=$HOME/.local ;;
	--uninstall) uninstall=1 ;;
	-h | --help)
		echo "usage: ./install.sh [--user] [--uninstall]"
		echo "  (no option)   system-wide into /usr/local (run as root)"
		echo "  --user        into ~/.local"
		echo "  --uninstall   remove (combine with --user if installed that way)"
		echo "PREFIX and DESTDIR are honoured for packaging."
		exit 0 ;;
	*) echo "install.sh: unknown option $arg" >&2; exit 1 ;;
	esac
done

app=$destdir$prefix/lib/rpgm
bin=$destdir$prefix/bin

if [ -n "$uninstall" ]; then
	rm -rf "$app" "$bin/rpgm"
	echo "Removed rpgm from $prefix."
	echo "Per-game data (browser storage, unpacked package.nw games and their saves) is kept"
	echo "in ~/.local/share/rpgm; delete it by hand if you really want to."
	exit 0
fi

mkdir -p "$app/lib/rgss" "$bin"
install -m 755 "$src/rpgm" "$app/rpgm"
install -m 644 "$src"/lib/*.js "$src"/lib/package.json "$src"/lib/*.awk "$app/lib/"
install -m 644 "$src"/lib/rgss/*.rb "$app/lib/rgss/"
ln -sf "$prefix/lib/rpgm/rpgm" "$bin/rpgm"

echo "Installed rpgm to $prefix."
[ -z "$destdir" ] || exit 0
if ! command -v electron >/dev/null 2>&1; then
	echo "No runtime found yet: apk add electron (Alpine edge, testing repository)"
fi
case :$PATH: in
*:"$prefix/bin":*) ;;
*) echo "Note: $prefix/bin is not in your PATH." ;;
esac
