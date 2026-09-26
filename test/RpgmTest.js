(function () {
  var r = {};
  var step = function (name, fn) { try { r[name] = fn(); } catch (e) { r[name] = 'ERR ' + e; } };
  Scene_Boot.prototype.start = function () {
    Scene_Base.prototype.start.call(this);
    step('isNwjs', function () { return Utils.isNwjs(); });
    step('localMode', function () { return StorageManager.isLocalMode(); });
    step('title', function () { return $dataSystem.gameTitle; });
    step('iconSet', function () { return ImageManager.loadSystem('IconSet').width; });
    step('preexisting', function () { return StorageManager.exists(1); });
    if (r.preexisting === true) {
      step('preLoad', function () { return DataManager.loadGame(1); });
      step('preSaveCount', function () { return $gameSystem.saveCount(); });
    } else {
      DataManager.setupNewGame();
    }
    step('save', function () { $gameSystem.onBeforeSave(); return DataManager.saveGame(1); });
    step('exists', function () { return StorageManager.exists(1); });
    step('load', function () { return DataManager.loadGame(1); });
    step('saveCount', function () { return $gameSystem.saveCount(); });
    step('config', function () { ConfigManager.bgmVolume = 40; ConfigManager.save(); ConfigManager.bgmVolume = 100; ConfigManager.load(); return ConfigManager.bgmVolume; });
    if (Utils.isNwjs()) {
      var fs = require('fs'), path = require('path'), gui = require('nw.gui'), win = gui.Window.get();
      step('cwd', function () { return process.cwd(); });
      step('mainModule', function () { return process.mainModule.filename; });
      step('modsViaMainModule', function () { return path.resolve(path.dirname(process.mainModule.filename), 'mods'); });
      step('modsViaCwdFallback', function () { return path.resolve(path.dirname(''), 'mods'); });
      step('modsFolderExists', function () { return fs.existsSync(path.resolve(path.dirname(''), 'mods')); });
      step('modFileReadable', function () { return fs.readFileSync(path.resolve(path.dirname(''), 'mods', 'DemoMod.js'), 'utf8').trim(); });
      step('loadersFolder', function () { return path.resolve(path.dirname(''), 'js', 'loaders'); });
      step('fsWrongCase', function () { return fs.readFileSync('data/ACTORS.json', 'utf8'); });
      step('nwGui', function () { return gui === nw && typeof win.on; });
      step('winWidth', function () { return typeof win.width === 'number' && win.width > 0; });
      step('clipboard', function () { gui.Clipboard.get().set('rpgm-clip', 'text'); return gui.Clipboard.get().get('text'); });
      step('versions', function () { return process.versions['node-webkit']; });
      step('dataPath', function () { return typeof nw.App.dataPath; });
    }
    fetch('js/libs/TEST.WASM')
      .then(function (res) { return WebAssembly.instantiateStreaming(res); })
      .then(function () { r.wasmFetch = true; }, function (e) { r.wasmFetch = 'ERR ' + e; })
      .then(function () {
        console.log('RPGM-RESULT ' + JSON.stringify(r));
        if (Utils.isNwjs()) {
          require('nw.gui').Window.get().on('close', function () { console.log('RPGM-CLOSE-EVENT'); this.close(true); });
        }
        SceneManager.exit();
      });
  };
})();
