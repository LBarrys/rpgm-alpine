'use strict';
// Case-insensitive path lookup. Windows games often reference "Img/Faces/Actor1.PNG"
// when the file on disk is "img/faces/actor1.png"; this finds the real file without
// a FUSE mount. Functions are captured up front so callers may monkey-patch `fs` later.
const { existsSync, readdirSync } = require('fs');
const path = require('path');

const dirs = new Map(); // dir -> Map(lowercase name -> real name)

function lookup(dir, name, fresh) {
  let names = dirs.get(dir);
  if (!names || fresh) {
    names = new Map();
    try {
      for (const n of readdirSync(dir)) if (!names.has(n.toLowerCase())) names.set(n.toLowerCase(), n);
    } catch { /* not a directory */ }
    dirs.set(dir, names);
  }
  return names.get(name.toLowerCase());
}

// Real path of `p`, matching every component case-insensitively; null if absent.
function resolve(p) {
  p = path.resolve(p);
  if (existsSync(p)) return p;
  let cur = path.parse(p).root;
  for (const part of p.slice(cur.length).split(path.sep)) {
    if (!part) continue;
    const next = path.join(cur, part);
    if (existsSync(next)) { cur = next; continue; }
    const hit = lookup(cur, part) || lookup(cur, part, true); // retry: dir may have changed
    if (!hit) return null;
    cur = path.join(cur, hit);
  }
  return cur;
}

// Like resolve(), but for a file that may not exist yet: fixes the parent directory's case.
function resolveWrite(p) {
  p = path.resolve(p);
  const dir = resolve(path.dirname(p));
  return resolve(p) || (dir ? path.join(dir, path.basename(p)) : p);
}

// Resolve URL-style `rel` ("/www/img/x.png") inside `root`, refusing to escape it.
function resolveIn(root, rel) {
  const p = path.resolve(root, '.' + path.sep + rel);
  if (p !== root && !p.startsWith(root + path.sep)) return null;
  return resolve(p);
}

module.exports = { resolve, resolveWrite, resolveIn };
