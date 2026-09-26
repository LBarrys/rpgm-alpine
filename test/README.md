# Tests

```sh
./test/run.sh              # everything whose prerequisites are present
./test/run.sh static       # detection, --info, --setup, the JSON5 tools
./test/run.sh unit         # lib/ under node
./test/run.sh integration  # a real MV game under Electron
```

Three tiers, because they cost very different things to run.

**static** needs only a shell and awk. It builds skeleton game folders (`fixtures.sh`)
— enough of each engine's tell-tale files for detection to fire — and asserts on what
`rpgm --info`, `--setup` and `--version` say about them. This is where most of the
value is: nearly every bug in this project has been something reported wrongly or not
at all, and each of those is one line here.

**unit** runs `test/ci-test.js` under node: the case-insensitive path lookup in
`lib/ci.js`, including that a URL-style request cannot climb out of the game folder.
It also syntax-checks every file in `lib/`.

**integration** builds an actual playable MV game from the RPG Maker MV corescript and
plays it under Electron, with a test plugin that exercises the NW.js shim from inside
the running game: saves, `ConfigManager`, where a mod loader resolves `www/mods`,
`nw.Window` and its child windows, the clipboard, and a `fetch` of a wrong-case asset.
It needs more than the others:

| | |
|---|---|
| `electron` | `apk add electron` (Alpine edge, testing) |
| `python3` | builds the game |
| `$RPGM_CORESCRIPT` | a checkout of [corescript](https://github.com/rpgtkoolmv/corescript) |
| `$RPGM_TEST_FONT` | any `.ttf`; MV blocks on GameFont before it boots. Found automatically if unset |
| a display | or run the whole thing under `xvfb-run` |

Each is reported as a skip, not a failure, when it is missing — so `./test/run.sh` is
safe to run anywhere, and CI runs the first two tiers.

```sh
RPGM_CORESCRIPT=~/src/corescript xvfb-run ./test/run.sh
```

## Adding a test

Static assertions read as a command and what its output must or must not contain:

```sh
run 'MV is detected' "$rpgm" --info "$fx/mv"
has_line 'engine:  mv'
desc='MV plugin counts'; has_line 'plugins: 1 registered, 1 enabled, 1 files'
```

`run` sets both the description and `$out`; `has_line`/`lacks_line` assert against
`$out` and report under the current `$desc`. Reuse a captured `$out` for several
assertions rather than running the command again.

New fixtures go in `fixtures.sh`. Keep them minimal: they exist to make one code path
fire, and a fixture that carries more than that quietly becomes something to maintain.
