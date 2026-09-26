(function () {
  Scene_Boot.prototype.start = function () {
    Scene_Base.prototype.start.call(this);
    var r = {}, bad = [];
    var t = function (name, fn) { try { r[name] = fn(); } catch (e) { bad.push(name + ': ' + e.message); } };
    if (!Utils.isNwjs()) { console.log('OPS-RESULT ' + JSON.stringify({ skipped: 'not nwjs' })); return; }
    var gui = require('nw.gui'), win = gui.Window.get();
    t('id', function () { return typeof win.id; });
    t('xywh', function () { return [typeof win.x, typeof win.y, win.width > 0, win.height > 0].join(','); });
    t('title', function () { win.title = 'ops test'; return win.title; });
    t('flags', function () { return [typeof win.isFullscreen, typeof win.isKioskMode, typeof win.isAlwaysOnTop].join(','); });
    t('zoomLevel', function () { win.zoomLevel = 0; return win.zoomLevel; });
    t('menu', function () { win.menu = new gui.Menu({ type: 'menubar' }); return win.menu; });
    t('moveResize', function () { win.moveTo(40, 40); win.moveBy(5, 5); win.resizeTo(820, 630); win.resizeBy(-4, -6); win.setPosition('center'); return win.width; });
    t('focusBlur', function () { win.focus(); win.blur(); win.focus(); return true; });
    t('showHide', function () { win.hide(); win.show(); win.show(false); win.show(true); return true; });
    t('minMaxRestore', function () { win.minimize(); win.restore(); win.maximize(); win.unmaximize(); return true; });
    t('fullscreen', function () { win.enterFullscreen(); win.leaveFullscreen(); win.toggleFullscreen(); win.toggleFullscreen(); return true; });
    t('kiosk', function () { win.enterKioskMode(); win.leaveKioskMode(); win.toggleKioskMode(); win.toggleKioskMode(); return true; });
    t('setters', function () { win.setResizable(true); win.setAlwaysOnTop(false); win.setMinimumSize(300, 200); win.setMaximumSize(3000, 2000); win.requestAttention(false); win.setProgressBar(0.5); win.setProgressBar(-1); win.setShowInTaskbar(true); win.setVisibleOnAllWorkspaces(false); return true; });
    t('devTools', function () { win.showDevTools(); return typeof win.isDevToolsOpen(); });
    t('eval', function () { return win.eval(null, '1+1'); });
    t('expandoProp', function () { win['my marker'] = { a: 1 }; return JSON.stringify(gui.Window.get()['my marker']); });
    t('expandoMissing', function () { return typeof win['never set']; });
    t('appFields', function () { return [Array.isArray(nw.App.argv), typeof nw.App.dataPath, typeof nw.App.manifest, typeof nw.App.startPath].join(','); });
    t('appCalls', function () { nw.App.clearCache(); nw.App.clearAppCache(); nw.App.registerGlobalHotKey({}); nw.App.unregisterGlobalHotKey({}); return nw.App.getProxyForURL('http://x/'); });
    t('clipboard', function () { var c = gui.Clipboard.get(); c.set('ops-clip', 'text'); var v = c.get('text'); c.readAvailableTypes(); return v; });
    t('screens', function () { return gui.Screen.Init().screens.length; });
    t('menuStubs', function () { var m = new gui.Menu(); var i = new gui.MenuItem({ label: 'x' }); m.append(i); m.insert(i, 0); m.remove(i); m.removeAt(0); m.popup(); m.createMacBuiltin('x'); new gui.Tray({}); new gui.Shortcut({}); return m.items.length; });
    t('shell', function () { return [typeof nw.Shell.openExternal, typeof nw.Shell.openItem, typeof nw.Shell.showItemInFolder].join(','); });
    t('nwRequire', function () { return typeof nw.require === 'function' && typeof nw.process === 'object'; });
    var child = gui.Window.open('index.html', { width: 400, height: 300, show: false });
    t('childOpen', function () { return !!child && typeof child.id === 'number' && child.id !== win.id; });
    t('childProps', function () { child.marker = 42; return child.marker; });
    t('childOps', function () { child.show(); child.focus(); child.hide(); child.resizeTo(420, 320); return child.width; });
    t('childLoadedEvent', function () { child.on('loaded', function () { r.childLoaded = true; }); return true; });
    setTimeout(function () {
      t('devToolsLater', function () { var o = win.isDevToolsOpen(); win.closeDevTools(); return o; });
      t('childClose', function () { child.close(true); return true; });
      setTimeout(function () {
        r.errors = bad;
        console.log('OPS-RESULT ' + JSON.stringify(r));
        win.on('close', function () { this.close(true); });
        SceneManager.exit();
      }, 2000);
    }, 4000);
  };
})();
