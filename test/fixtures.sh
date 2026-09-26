#!/bin/sh
# Build the fixture game folders the static tests run against, under $1.
#
# These are skeletons, not playable games: just enough of each engine's tell-tale
# files for rpgm's detection and its --info reports to have something to say. The
# real MV game used by the integration tier is built by build_mv.py instead.
set -eu

root=${1:?usage: fixtures.sh DIR}
rm -rf "$root"
mkdir -p "$root"

core() { # a stand-in rpg_core.js carrying the two lines --info reads out of it
	mkdir -p "$(dirname "$1")"
	cat >"$1" <<-EOF
		Utils.RPGMAKER_NAME = '$2';
		Utils.RPGMAKER_VERSION = '$3';
	EOF
}

plugins() { # $1 = plugins.js path, rest = name:status pairs
	f=$1
	shift
	mkdir -p "$(dirname "$f")"
	out='' first=1
	for spec in "$@"; do
		[ -n "$first" ] || out="$out,"
		first=
		out="$out
{\"name\":\"${spec%:*}\",\"status\":${spec#*:},\"description\":\"\",\"parameters\":{}}"
	done
	# shellcheck disable=SC2016 # $plugins is JavaScript, not a shell variable
	printf 'var $plugins = [%s\n];\n' "$out" >"$f"
}

# --- MV: the ordinary case -----------------------------------------------------
mv=$root/mv
core "$mv/www/js/rpg_core.js" MV 1.6.1
plugins "$mv/www/js/plugins.js" OnePlugin:true
mkdir -p "$mv/www/js/plugins" "$mv/www/mods"
echo '// plugin' >"$mv/www/js/plugins/OnePlugin.js"
echo 'MOD-OK' >"$mv/www/mods/DemoMod.js"
printf 'MZ' >"$mv/Game.exe"

# --- MZ ------------------------------------------------------------------------
mz=$root/mz
core "$mz/js/rmmz_core.js" MZ 1.8.0
plugins "$mz/js/plugins.js" OnePlugin:true
mkdir -p "$mz/js/plugins"
echo '// plugin' >"$mz/js/plugins/OnePlugin.js"

# --- MV with every plugin problem at once --------------------------------------
# Unlisted.js present but not registered; Ghost.js registered but absent; OffOne
# switched off; and a second copy of a plugin differing only in letter case, which
# on Windows would have replaced the first and here is simply ignored.
dup=$root/dup
core "$dup/www/js/rpg_core.js" MV 1.6.1
plugins "$dup/www/js/plugins.js" Listed:true Ghost:true OffOne:false
mkdir -p "$dup/www/js/plugins" "$dup/www/mods"
echo '// plugin' >"$dup/www/js/plugins/Listed.js"
echo '// plugin' >"$dup/www/js/plugins/listed.js"
echo '// plugin' >"$dup/www/js/plugins/Unlisted.js"
echo '// plugin' >"$dup/www/js/plugins/OffOne.js"
echo 'MOD-OK' >"$dup/www/mods/DemoMod.js"

# --- MV whose mods do have a loader registered ---------------------------------
loader=$root/loader
core "$loader/www/js/rpg_core.js" MV 1.6.1
plugins "$loader/www/js/plugins.js" ModLoader:true
mkdir -p "$loader/www/js/plugins" "$loader/www/mods"
echo '// plugin' >"$loader/www/js/plugins/ModLoader.js"
echo 'MOD-OK' >"$loader/www/mods/DemoMod.js"

# --- a game shipped as package.nw ----------------------------------------------
mkdir -p "$root/zip"
printf 'PK\003\004' >"$root/zip/package.nw"

# --- a plain Electron game -----------------------------------------------------
mkdir -p "$root/eapp/resources/app"
echo '{"name":"eapp","main":"main.js"}' >"$root/eapp/resources/app/package.json"

# --- RGSS: a config that parses, with the shims loaded -------------------------
ok=$root/rgss-ok
mkdir -p "$ok/Data"
printf '[Game]\nLibrary=RGSS301.dll\nScripts=Data\\Scripts.rvdata2\n' >"$ok/Game.ini"
: >"$ok/Data/Scripts.rvdata2"
cat >"$ok/mkxp.json" <<'EOF'
{
	// A live setting and a commented one, to prove the reader tells them apart:
	// a naive grep would see "smoothScaling": 4 here and report xBRZ.
	// "smoothScaling": 4,
	"smoothScaling": 1,
	"enableReset": false,
	"preloadScript": ["/nonexistent/lib/rgss/all.rb"],
}
EOF

# --- RGSS: a config mkxp-z will throw away whole --------------------------------
bad=$root/rgss-bad
mkdir -p "$bad/Data"
printf '[Game]\nLibrary=RGSS202E.dll\nScripts=Data\\Scripts.rvdata\n' >"$bad/Game.ini"
: >"$bad/Data/Scripts.rvdata"
printf '{\n\t"a": 1\n\t"b": 2\n}\n' >"$bad/mkxp.json"

# --- RGSS: settings that combine into nothing ----------------------------------
gfx=$root/rgss-gfx
mkdir -p "$gfx/Data"
printf '[Game]\nLibrary=RGSS301.dll\n' >"$gfx/Game.ini"
: >"$gfx/Data/Scripts.rvdata2"
cat >"$gfx/mkxp.json" <<'EOF'
{
	"smoothScaling": 4,
	"xbrzScalingFactor": 1.0,
	"smoothScalingMipmaps": true,
	"enableHires": true,
	"subImageFix": true,
	"enableReset": true,
}
EOF

# --- RGSS: no config at all, and everything that silently breaks ---------------
raw=$root/rgss-raw
mkdir -p "$raw/Data" "$raw/Scripts"
printf '[Game]\nLibrary=RGSS104E.dll\nScripts=Data\\Scripts.rxdata\n' >"$raw/Game.ini"
: >"$raw/Data/Scripts.rxdata"
: >"$raw/System.dll"
echo 'Win32API.new("user32", "GetCursorPos", "p", "i")' >"$raw/Scripts/Mouse.rb"
printf '{"a":1}\r\n' >"$raw/Data/Lang.json" # CRLF, which Windows strips and Linux does not
printf "WS = [' ', \"\\\\n\", \"\\\\t\"]\n" >"$raw/Scripts/101_jsonEnDecoder.rb"

# --- folders rpgm cannot run, one per hint ------------------------------------
mkdir -p "$root/wolf/Data" && printf 'MZ' >"$root/wolf/Game.exe" &&
	: >"$root/wolf/Data/BasicData.wolf"
mkdir -p "$root/rt2k" && : >"$root/rt2k/RPG_RT.exe" && : >"$root/rt2k/RPG_RT.ldb"
mkdir -p "$root/xp3" && : >"$root/xp3/data.xp3"
mkdir -p "$root/renpy/game" && : >"$root/renpy/game/archive.rpa"
mkdir -p "$root/godot" && : >"$root/godot/game.pck"
mkdir -p "$root/enigma" && printf 'MZ' >"$root/enigma/Game.exe"
mkdir -p "$root/empty"
mkdir -p "$root/junk" && echo hello >"$root/junk/readme.txt"
