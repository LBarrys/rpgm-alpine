#!/bin/sh
# Build and install mkxp-z (RPG Maker XP / VX / VX Ace player) on Alpine Linux.
#
#   ./build-mkxp-z.sh           build, then install into /usr/local (needs root for the last step)
#   ./build-mkxp-z.sh --user    install into ~/.local instead
#
# Alpine has no mkxp-z package, and upstream ships only glibc binaries, so it has to be
# compiled. The build first compiles its own SDL2, OpenAL, Ruby 3.1 and friends (that is
# the slow part - tens of minutes), then mkxp-z itself.
#
# Build files stay in ~/.cache/mkxp-z-build; delete that folder afterwards to reclaim space.
# Needs network access throughout: the build clones ~15 repositories and Ruby downloads
# its bundled gems from rubygems.org.
set -eu

die() { printf 'build-mkxp-z: %s\n' "$*" >&2; exit 1; }

prefix=${PREFIX:-/usr/local}
case ${1:-} in
--user) prefix=$HOME/.local ;;
'') ;;
*) die "usage: $0 [--user]" ;;
esac
src=${MKXPZ_BUILD_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/mkxp-z-build}
ref=${MKXPZ_REF:-dev}
arch=$(uname -m)

deps='bash git build-base cmake meson ninja-build autoconf automake libtool pkgconf ruby bison
xxd perl linux-headers zlib-dev bzip2-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev
libxi-dev libxinerama-dev libxscrnsaver-dev libxkbcommon-dev libxfixes-dev wayland-dev
wayland-protocols libdecor-dev mesa-dev alsa-lib-dev pulseaudio-dev'
missing=
for p in $deps; do apk info -e "$p" >/dev/null 2>&1 || missing="$missing $p"; done
[ -z "$missing" ] || die "install the build dependencies first, as root:
  apk add$missing"

# --- source ------------------------------------------------------------------
if [ ! -d "$src/.git" ]; then
	mkdir -p "$(dirname "$src")"
	git clone --depth 1 --branch "$ref" https://github.com/mkxp-z/mkxp-z.git "$src"
fi
cd "$src"

# freetype's own makefile checks out its `dlg` submodule with an invalid git command
# ("git --git-dir=. submodule init"), which current git rejects and the build dies.
# It only does that when subprojects/dlg is empty, so clone freetype ourselves with
# submodules; the build then reuses this checkout instead of making its own.
ft=$src/linux/downloads/$arch/freetype
if [ ! -e "$ft/autogen.sh" ]; then
	mkdir -p "$(dirname "$ft")"
	git clone -q --depth 1 --recurse-submodules --shallow-submodules \
		https://github.com/mkxp-z/freetype2 "$ft"
fi
# The repo ships a top-level `configure` wrapper, so the build skips autogen.sh and then
# fails on the missing builds/unix/configure. Generate it here.
[ -f "$ft/builds/unix/configure" ] || (cd "$ft" && ./autogen.sh >/dev/null)

# --- 1. bundled dependencies (SDL2, OpenAL, Ruby 3.1, OpenSSL, ...) ----------
# The Makefile normally hides the system's pkg-config files, which makes SDL2 build
# without Wayland support. Its own prefix stays first, so its static libs still win.
# No -j here on purpose: the top-level rules are not parallel-safe (vorbis configures
# before ogg is built and fails to find it). Each library's own build already runs in
# parallel across all cores, which is what upstream's CI relies on.
echo "==> building bundled dependencies; this takes a long while"
cd "$src/linux"
make PKG_CONFIG_LIBDIR="$PWD/build-$arch/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"

sdlconf="build-$arch/include/SDL2/SDL_config.h"
if grep -q '#define SDL_VIDEO_DRIVER_WAYLAND 1' "$sdlconf" 2>/dev/null; then
	echo "==> SDL2: Wayland and X11 support"
else
	echo "==> WARNING: SDL2 was built without Wayland; mkxp-z will need Xwayland" >&2
fi

# --- 2. mkxp-z itself --------------------------------------------------------
echo "==> building mkxp-z"
cd "$src"
# vars.sh is a bash script and must be sourced into the same shell as meson/ninja.
bash -c 'set -e; . linux/vars.sh; [ -d build/meson-info ] || meson setup build; ninja -C build'
bin="build/mkxp-z.$arch"
[ -x "$bin" ] || die "build finished but $src/$bin is missing"

# --- 3. stage a self-contained folder ---------------------------------------
# Upstream's own install script copies glibc-only libraries, so stage by hand instead.
# The binary looks for its Ruby library in lib64/ next to itself.
stage=$src/stage
rm -rf "$stage"
mkdir -p "$stage/lib64"
cp "$bin" "$stage/"
cp linux/build-"$arch"/lib/libruby.so.3.1* "$stage/lib64/"
[ -e "$stage/lib64/libruby.so.3.1" ] || die "libruby.so.3.1 was not staged; the build is incomplete"
# meson only applies its $ORIGIN/lib64 rpath during "ninja install", and this copies
# the binary straight out of the build tree, so it still points at the build folder.
# Left alone, mkxp-z stops finding its Ruby the moment that folder is deleted - which
# this script tells you to do at the end. patchelf fixes it properly; the launcher
# below sets LD_LIBRARY_PATH either way.
if command -v patchelf >/dev/null 2>&1; then
	# shellcheck disable=SC2016 # $ORIGIN is for the dynamic loader, not the shell
	patchelf --set-rpath '$ORIGIN/lib64' "$stage/mkxp-z.$arch" 2>/dev/null || true
fi
cp -r linux/build-"$arch"/lib/ruby/3.1.0 "$stage/stdlib"
cp -r scripts "$stage/"
cp mkxp.json "$stage/mkxp.json.example"
cp assets/LICENSE.mkxp-z-with-https.txt "$stage/" 2>/dev/null || true

# --- 4. install --------------------------------------------------------------
mkdir -p "$prefix/lib" "$prefix/bin"
# The install below replaces the whole folder, which would destroy anything extra
# dropped into scripts/preload - rpgm's compatibility shims, your own wrappers - and
# leave the games that load them pointing at files that no longer exist. Keep them.
keep=$src/.keep-preload
rm -rf "$keep"
old=$prefix/lib/mkxp-z/scripts/preload
if [ -d "$old" ]; then
	mkdir -p "$keep"
	for f in "$old"/*; do
		[ -e "$f" ] || continue
		[ -e "$stage/scripts/preload/$(basename "$f")" ] || cp -R "$f" "$keep/"
	done
fi
rm -rf "$prefix/lib/mkxp-z"
cp -r "$stage" "$prefix/lib/mkxp-z"
if [ -d "$keep" ] && [ -n "$(ls -A "$keep" 2>/dev/null)" ]; then
	cp -R "$keep"/. "$prefix/lib/mkxp-z/scripts/preload/"
	printf '==> kept %s extra file(s) already in scripts/preload\n' \
		"$(find "$keep" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
fi
rm -rf "$keep"
# mkxp-z switches to its own folder at startup unless SRCDIR names the game, so
# default SRCDIR to the directory you run the command from.
cat >"$prefix/bin/mkxp-z" <<EOF
#!/bin/sh
# LD_LIBRARY_PATH points at the bundled Ruby: see the note about rpath above.
exec env SRCDIR="\${SRCDIR:-\$PWD}" \\
	LD_LIBRARY_PATH="$prefix/lib/mkxp-z/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}" \\
	"$prefix/lib/mkxp-z/mkxp-z.$arch" "\$@"
EOF
chmod 755 "$prefix/bin/mkxp-z"

cat <<EOF

Installed to $prefix/lib/mkxp-z (command: $prefix/bin/mkxp-z).

Run a game:
  cd /path/to/game && mkxp-z          # or: rpgm /path/to/game
  mkxp-z test                         # playtest mode

If a game needs the Ruby standard library (Pokemon Essentials games do), add this to
that game's mkxp.json - mkxp-z reads it from the game folder, not from the install:
  "rubyLoadpath": ["$prefix/lib/mkxp-z/stdlib"]

If it starts with a modal "Could not detect an available audio device" and goes no
further, there is no working sound output; install pipewire-pulse (or pulseaudio), or
run headless with ALSOFT_DRIVERS=null.

Build files are still in $src (several GB); delete that folder to reclaim the space - the
installed copy no longer depends on it.
EOF
