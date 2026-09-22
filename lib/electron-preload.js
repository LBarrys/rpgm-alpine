'use strict';
// NW.js compatibility layer. Runs in the page's own context (contextIsolation: false),
// before any game script.
const { ipcRenderer } = require('electron');
const EventEmitter = require('events');
const Module = require('module');
const fs = require('fs');
const ci = require('./ci');

// Synchronous request to the main process; target = BrowserWindow id, or null for this window.
const callOn = (target, op, ...args) => ipcRenderer.sendSync('nw', target, op, ...args);
const call = (op, ...args) => callOn(null, op, ...args);
const info = call('init');

// --- Case-insensitive fs (plugins often read files with the wrong case) ----------------
const exists = fs.existsSync;
const fixPath = p => (typeof p === 'string' && p && !exists(p) ? ci.resolveWrite(p) : p);
function wrap(obj, names, count = 1) {
  for (const name of names) {
    const fn = obj[name];
    if (typeof fn !== 'function') continue;
    obj[name] = Object.assign(function (...a) {
      for (let i = 0; i < count && i < a.length; i++) a[i] = fixPath(a[i]);
      return fn.apply(this, a);
    }, fn);
  }
}
const oneArg = ['access', 'appendFile', 'lstat', 'mkdir', 'open', 'opendir', 'readFile', 'readdir',
  'rm', 'rmdir', 'stat', 'truncate', 'unlink', 'writeFile'];
wrap(fs, [...oneArg, ...oneArg.map(n => n + 'Sync'), 'existsSync', 'createReadStream', 'createWriteStream']);
wrap(fs, ['rename', 'renameSync', 'copyFile', 'copyFileSync'], 2);
wrap(fs.promises, oneArg);
wrap(fs.promises, ['rename', 'copyFile'], 2);

// --- Globals NW.js provides ---------------------------------------------------------
// MV/MZ derive the save folder from process.mainModule.filename (the index.html path).
Object.defineProperty(process, 'mainModule', {
  value: { filename: info.main, id: '.', exports: {}, loaded: true, children: [], paths: [] },
  configurable: true,
  writable: true,
});

// NW.js reports its version here, and plugins use it to pick code paths (SRD_GameUpgrade takes a
// legacy "move the game to a new window" path when it is missing). Claim a modern NW.js.
const NW_VERSION = '0.90.0';
try {
  Object.assign(process.versions, { nw: NW_VERSION, 'node-webkit': NW_VERSION });
} catch { /* read-only */ }
if (process.versions.nw !== NW_VERSION) {
  try {
    const versions = { ...process.versions, nw: NW_VERSION, 'node-webkit': NW_VERSION };
    Object.defineProperty(process, 'versions', { value: versions, configurable: true, writable: true });
  } catch (e) { console.warn('rpgm: cannot set process.versions.nw', e); }
}

try { // MZ reloads with chrome.runtime.reload() (F5)
  const chrome = window.chrome || (window.chrome = {});
  chrome.runtime = chrome.runtime || {};
  if (!chrome.runtime.reload) chrome.runtime.reload = () => location.reload();
} catch (e) { console.warn('rpgm: no chrome.runtime.reload', e); }

// --- nw.* API -----------------------------------------------------------------------
const windows = new Map(); // BrowserWindow id -> NWWindow, for event delivery
ipcRenderer.on('nw-event', (_e, id, ev) => { const w = windows.get(id); if (w) w.emit(ev); });

class NWWindow extends EventEmitter {
  constructor(id, domWindow) {
    super();
    this.id = id;
    this._dom = domWindow;
    this._isSelf = domWindow === window;
    this.on('newListener', ev => { if (ev === 'close') this._call('hookClose', true); });
    this.on('removeListener', ev => { if (ev === 'close' && !this.listenerCount('close')) this._call('hookClose', false); });
    // NW.js window objects are shared between windows, so games attach their own properties
    // to them (and read them from another window). Keep unknown properties in the main process.
    const proxy = new Proxy(this, {
      get: (t, key, recv) => {
        if (typeof key !== 'string' || key in t) return Reflect.get(t, key, recv);
        const v = t._call('getProp', key);
        return v === null ? undefined : v;
      },
      set: (t, key, value) => {
        if (typeof key !== 'string' || key in t) return Reflect.set(t, key, value);
        try { t._call('setProp', key, value); } catch { t[key] = value; } // not cloneable: keep local
        return true;
      },
    });
    windows.set(id, proxy);
    return proxy;
  }
  _call(op, ...args) { return callOn(this._isSelf ? null : this.id, op, ...args); }
  _bounds() { return this._call('bounds') || { x: 0, y: 0, width: 0, height: 0 }; }
  get window() { return this._dom; }
  get x() { return this._bounds().x; }
  set x(v) { this._call('setBounds', { x: v | 0 }); }
  get y() { return this._bounds().y; }
  set y(v) { this._call('setBounds', { y: v | 0 }); }
  get width() { return this._bounds().width; }
  set width(v) { this._call('setBounds', { width: v | 0 }); }
  get height() { return this._bounds().height; }
  set height(v) { this._call('setBounds', { height: v | 0 }); }
  get title() { return this._call('title'); }
  set title(t) { this._call('setTitle', t); }
  get isFullscreen() { return this._call('isFullscreen'); }
  get isKioskMode() { return this._call('isFullscreen'); }
  get isAlwaysOnTop() { return this._call('isAlwaysOnTop'); }
  get zoomLevel() { return this._call('zoom'); }
  set zoomLevel(z) { this._call('zoom', z); }
  get menu() { return null; }
  set menu(_m) { /* menubars are not supported */ }

  moveTo(x, y) { this._call('setBounds', { x: x | 0, y: y | 0 }); }
  moveBy(dx, dy) { const b = this._bounds(); this.moveTo(b.x + dx, b.y + dy); }
  resizeTo(w, h) { this._call('setBounds', { width: w | 0, height: h | 0 }); }
  resizeBy(dw, dh) { const b = this._bounds(); this.resizeTo(b.width + dw, b.height + dh); }
  setPosition(pos) { if (pos === 'center') this._call('center'); }
  focus() { this._call('focus'); }
  blur() { this._call('blur'); }
  show(visible) { this._call(visible === false ? 'hide' : 'show'); }
  hide() { this._call('hide'); }
  minimize() { this._call('minimize'); }
  maximize() { this._call('maximize'); }
  unmaximize() { this._call('unmaximize'); }
  restore() { this._call('restore'); }
  enterFullscreen() { this._call('fullscreen', true); }
  leaveFullscreen() { this._call('fullscreen', false); }
  toggleFullscreen() { this._call('fullscreen'); }
  enterKioskMode() { this._call('fullscreen', true); }
  leaveKioskMode() { this._call('fullscreen', false); }
  toggleKioskMode() { this._call('fullscreen'); }
  setResizable(v) { this._call('setResizable', v); }
  setAlwaysOnTop(v) { this._call('setAlwaysOnTop', v); }
  setMinimumSize(w, h) { this._call('setMinimumSize', w, h); }
  setMaximumSize(w, h) { this._call('setMaximumSize', w, h); }
  requestAttention(v) { this._call('requestAttention', v); }
  setProgressBar(v) { this._call('setProgressBar', v); }
  setShowInTaskbar() {}
  setVisibleOnAllWorkspaces() {}
  close(force) {
    if (force || !this.listenerCount('close')) this._call('close', true);
    else this.emit('close');
  }
  reload() { this._dom.location.reload(); }
  reloadDev() { this._dom.location.reload(); }
  reloadIgnoringCache() { this._call('reload'); }
  showDevTools(_id, cb) {
    this._call('devtools', true);
    const dev = { moveTo() {}, resizeTo() {}, focus() {}, on() { return dev; }, close: () => this._call('devtools', false) };
    if (typeof cb === 'function') cb(dev);
    return dev;
  }
  closeDevTools() { this._call('devtools', false); }
  isDevToolsOpen() { return this._call('isDevToolsOpen'); }
  eval(frame, code) { return (frame ? frame.contentWindow : this._dom).eval(code); }
}

let mainWindow;
const nwWindow = {
  get: (domWindow) => {
    if (domWindow && domWindow !== window) return undefined; // other windows' objects: not supported
    return mainWindow || (mainWindow = new NWWindow(call('id'), window));
  },
  // Like NW.js: returns a handle for the new window, which also runs with Node.js.
  open(url, opts, cb) {
    if (typeof opts === 'function') { cb = opts; opts = {}; }
    call('nextOpen', opts || {});
    const child = window.open(url, '_blank');
    const id = call('lastOpened');
    const handle = id ? new NWWindow(id, child) : null;
    if (handle && opts && opts.show === false) handle.hide();
    if (typeof cb === 'function') setTimeout(() => cb(handle), 0);
    return handle;
  },
};

const App = Object.assign(new EventEmitter(), {
  argv: info.argv,
  fullArgv: info.argv,
  filteredArgv: [],
  manifest: info.manifest,
  dataPath: info.dataPath,
  startPath: info.root,
  quit: () => call('quit'),
  closeAllWindows: () => call('closeAll'),
  clearCache: () => call('clearCache'),
  clearAppCache() {},
  getProxyForURL: () => 'DIRECT',
  setProxyConfig() {},
  addOriginAccessWhitelistEntry() {},
  removeOriginAccessWhitelistEntry() {},
  registerGlobalHotKey() {},
  unregisterGlobalHotKey() {},
  crashBrowser() {},
  crashRenderer() {},
});

const clip = {
  get: (type = 'text') => call('clipRead', type),
  set(data, type = 'text') {
    const out = {};
    for (const item of Array.isArray(data) ? data : [{ data, type }]) {
      const t = item.type || 'text';
      out[t === 'html' || t === 'rtf' ? t : 'text'] = String(item.data);
    }
    call('clipWrite', out);
  },
  clear: () => call('clipClear'),
  readAvailableTypes: () => call('clipTypes'),
};

const Screen = Object.assign(new EventEmitter(), {
  Init() { return Screen; },
  chooseDesktopMedia: () => false,
});
Object.defineProperty(Screen, 'screens', { get: () => call('screens'), enumerable: true });

class Menu {
  constructor() { this.items = []; }
  append(item) { this.items.push(item); }
  insert(item, i) { this.items.splice(i, 0, item); }
  remove(item) { this.removeAt(this.items.indexOf(item)); }
  removeAt(i) { if (i >= 0) this.items.splice(i, 1); }
  popup() {}
  createMacBuiltin() {}
}
class Stub extends EventEmitter {
  constructor(opts = {}) { super(); Object.assign(this, opts); }
  remove() {}
}

const nw = {
  Window: nwWindow,
  App,
  Clipboard: { get: () => clip },
  Shell: {
    openExternal: url => call('openExternal', url),
    openItem: p => call('openPath', p),
    showItemInFolder: p => call('showItem', p),
  },
  Screen,
  Menu,
  MenuItem: Stub,
  Tray: Stub,
  Shortcut: Stub,
  require,
  process,
};

window.nw = nw;
const load = Module._load;
Module._load = function (request, ...rest) {
  return request === 'nw.gui' ? nw : load.call(this, request, ...rest);
};

// NW.js implemented window.prompt(); Electron throws "prompt() is not supported.",
// which lands on RPG Maker's error screen and stops the game dead. Plugins that ask
// for a name, a file or a number this way are common enough to be worth answering.
//
// prompt() has to return a string synchronously, and Electron offers nothing that
// can block the renderer on a text field, so this shells out to whichever desktop
// dialog is installed. With none of them, it returns the default rather than
// throwing: a plugin handling a cancelled prompt already has to cope with that, and
// a game that keeps running is more useful than one that does not.
const { execFileSync } = require('child_process');
const dialogs = [
  ['zenity', (m, d) => ['--entry', '--title=', `--text=${m}`, `--entry-text=${d}`]],
  ['kdialog', (m, d) => ['--inputbox', m, d]],
  ['yad', (m, d) => ['--entry', `--text=${m}`, `--entry-text=${d}`]],
];
window.prompt = (message = '', defaultValue = '') => {
  const msg = String(message);
  const def = defaultValue == null ? '' : String(defaultValue);
  for (const [cmd, args] of dialogs) {
    try {
      const out = execFileSync(cmd, args(msg, def), { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
      return out.replace(/\r?\n$/, '');
    } catch (e) {
      // A number means the dialog ran and exited non-zero: the user cancelled.
      // Anything else (ENOENT and friends) means it is not installed; try the next.
      if (typeof e.status === 'number') return null;
    }
  }
  console.warn(`rpgm: prompt() with no dialog program installed, returning the default.
rpgm: install zenity (apk add zenity) for a real input box.
rpgm: asked: ${msg}`);
  return def;
};
