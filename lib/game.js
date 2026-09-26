'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const ci = require('./ci');

function load(dir) {
  const root = fs.realpathSync(dir);
  let pkg = {};
  const pj = ci.resolve(path.join(root, 'package.json'));
  if (pj) {
    try { pkg = JSON.parse(fs.readFileSync(pj, 'utf8').replace(/^﻿/, '')); }
    catch (e) { console.warn(`rpgm: ignoring unreadable package.json (${e.message})`); }
  }
  const candidates = [pkg.main, 'www/index.html', 'index.html'].filter(m => /\.html?$/i.test(m || ''));
  const html = candidates.map(m => ci.resolveIn(root, m)).find(Boolean);
  if (!html) throw new Error(`no index.html in ${root}`);

  const id = crypto.createHash('sha1').update(root).digest('hex').slice(0, 12);
  const share = process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
  const win = pkg.window || {};
  return {
    root,
    pkg,
    win,
    main: path.relative(root, html).split(path.sep).join('/'),
    id,
    data: path.join(share, 'rpgm', id),
    title: win.title || pkg.name || path.basename(root),
    test: !!process.env.RPGM_TEST,
  };
}

const urlPath = main => '/' + main.split('/').map(encodeURIComponent).join('/');

module.exports = { load, urlPath };
