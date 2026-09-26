'use strict';
// Unit tests for lib/ci.js, the case-insensitive path lookup that stands in for the
// original project's FUSE mount. Prints "ok DESC" or "FAIL DESC" per assertion and
// exits non-zero if any failed; test/run.sh folds the tally into its own.

const fs = require('fs');
const os = require('os');
const path = require('path');
const ci = require('../lib/ci.js');

let failed = 0;
function is(desc, got, want) {
  if (got === want) { console.log('ok ' + desc); return; }
  failed++;
  console.log('FAIL ' + desc + ' (got ' + JSON.stringify(got) + ', wanted ' + JSON.stringify(want) + ')');
}

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'rpgm-ci-'));
const www = path.join(root, 'www');
fs.mkdirSync(path.join(www, 'img', 'system'), { recursive: true });
fs.mkdirSync(path.join(www, 'js', 'plugins'), { recursive: true });
fs.writeFileSync(path.join(www, 'img', 'system', 'iconset.png'), 'PNG');
fs.writeFileSync(path.join(www, 'js', 'plugins', 'MixedCase.js'), '//');

const real = path.join(www, 'img', 'system', 'iconset.png');

// The case games actually hit: RPG Maker asks for img/System/IconSet.png.
is('an exact path resolves to itself', ci.resolve(real), real);
is('a wrong-case file name resolves',
  ci.resolve(path.join(www, 'img', 'system', 'IconSet.PNG')), real);
is('a wrong-case directory resolves',
  ci.resolve(path.join(www, 'IMG', 'System', 'iconset.png')), real);
is('every component can be wrong at once',
  ci.resolve(path.join(www, 'IMG', 'SYSTEM', 'ICONSET.PNG')), real);
is('a file that is really missing returns null',
  ci.resolve(path.join(www, 'img', 'system', 'nothing.png')), null);
is('an exact mixed-case name is not mangled',
  ci.resolve(path.join(www, 'js', 'plugins', 'MixedCase.js')),
  path.join(www, 'js', 'plugins', 'MixedCase.js'));

// Saves: the file does not exist yet, but its folder may still be the wrong case.
is('a new file in a wrong-case folder gets the real folder',
  ci.resolveWrite(path.join(www, 'IMG', 'System', 'new.png')),
  path.join(www, 'img', 'system', 'new.png'));
is('a new file in a missing folder is returned unchanged',
  ci.resolveWrite(path.join(www, 'nope', 'new.png')),
  path.join(www, 'nope', 'new.png'));

// resolveIn serves the game over app://, so a request must not be able to climb out
// of the game folder - with or without the case fixing helping it along.
is('a URL-style path resolves inside the root',
  ci.resolveIn(www, '/img/System/IconSet.png'), real);
is('.. cannot escape the root', ci.resolveIn(www, '/../../etc/passwd'), null);
is('.. cannot escape the root case-insensitively',
  ci.resolveIn(www, '/IMG/../../secret'), null);
is('the root itself resolves', ci.resolveIn(www, '/'), www);

// A directory listed once is cached; a file appearing later must still be found.
fs.writeFileSync(path.join(www, 'img', 'system', 'Late.PNG'), 'PNG');
is('a file created after the first listing is still found',
  ci.resolve(path.join(www, 'img', 'system', 'late.png')),
  path.join(www, 'img', 'system', 'Late.PNG'));

fs.rmSync(root, { recursive: true, force: true });
process.exit(failed ? 1 : 0);
