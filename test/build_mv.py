#!/usr/bin/env python3
"""Build a minimal but genuinely playable RPG Maker MV game, for the integration tests.

The static tests only need folders that look like games. These tests need one that
actually boots, because what they are checking is the NW.js compatibility layer:
saves, the mods folder, the clipboard, window handling. So the game is assembled
from a real corescript checkout, with one test plugin dropped in.

    python3 test/build_mv.py OUTDIR --corescript DIR [--font FILE] [--plugin FILE]

--corescript is a checkout of https://github.com/rpgtkoolmv/corescript.
--font is any .ttf; MV blocks on loading GameFont before it will boot, so it needs
one, but which one does not matter.
"""

import argparse
import json
import os
import shutil
import struct
import sys
import zlib

SYSTEM_IMAGES = ['iconset', 'Balloon', 'shadow1', 'Shadow2', 'DAMAGE', 'States',
                 'Weapons1', 'Weapons2', 'Weapons3', 'ButtonSet']
DATA_FILES = ['actors', 'Classes', 'Skills', 'Items', 'Weapons', 'Armors', 'Enemies',
              'Troops', 'States', 'Animations', 'Tilesets', 'CommonEvents', 'MapInfos']


def png(path, w=32, h=32):
    """A valid PNG of a flat colour. MV refuses to finish loading without these."""
    raw = b''.join(b'\0' + b'\x80\x40\x20\xff' * w for _ in range(h))

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data +
                struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    header = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) +
                chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def find_font():
    for root in ('/usr/share/fonts', '/usr/local/share/fonts', os.path.expanduser('~/.fonts')):
        for dirpath, _, names in os.walk(root):
            for n in sorted(names):
                if n.lower().endswith('.ttf'):
                    return os.path.join(dirpath, n)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out', help='folder to build the game in (replaced if it exists)')
    ap.add_argument('--corescript', required=True, help='a corescript checkout')
    ap.add_argument('--font', help='a .ttf to install as GameFont (default: any system one)')
    ap.add_argument('--plugin', help='a .js to install and register as a plugin')
    args = ap.parse_args()

    cs = args.corescript
    if not os.path.isdir(os.path.join(cs, 'js')):
        sys.exit(f'{cs} does not look like a corescript checkout (no js/)')
    font = args.font or find_font()
    if not font or not os.path.isfile(font):
        sys.exit('no .ttf found; pass --font (MV will not boot without GameFont)')

    out = args.out
    shutil.rmtree(out, ignore_errors=True)
    www = os.path.join(out, 'www')
    for d in ['js/libs', 'js/plugins', 'js/loaders', 'fonts', 'Data', 'img/System', 'icon', 'mods']:
        os.makedirs(os.path.join(www, d), exist_ok=True)

    # The corescript ships as one file per class plus a JSON listing the order they
    # concatenate in; modules.json names the bundles.
    with open(os.path.join(cs, 'modules.json')) as f:
        modules = json.load(f)
    for part in modules:
        with open(os.path.join(cs, part + '.json')) as f:
            order = json.load(f)
        with open(os.path.join(www, 'js', part + '.js'), 'w') as dst:
            for name in order:
                with open(os.path.join(cs, name)) as src:
                    dst.write(src.read() + '\n')

    for f in os.listdir(os.path.join(cs, 'js', 'libs')):
        shutil.copy(os.path.join(cs, 'js', 'libs', f), os.path.join(www, 'js', 'libs', f))
    shutil.copy(os.path.join(cs, 'js', 'main.js'), os.path.join(www, 'js', 'main.js'))
    shutil.copy(os.path.join(cs, 'template', 'index.html'), os.path.join(www, 'index.html'))
    shutil.copy(os.path.join(cs, 'template', 'fonts', 'gamefont.css'), os.path.join(www, 'fonts'))
    shutil.copy(font, os.path.join(www, 'fonts', 'mplus-1m-regular.ttf'))

    # Asked for as TEST.WASM: the case-insensitive layer has to find it, and it has to
    # arrive with a MIME type WebAssembly will accept.
    with open(os.path.join(www, 'js', 'libs', 'test.wasm'), 'wb') as f:
        f.write(b'\0asm\1\0\0\0')
    # A mod in the folder a mod loader would look in, with recognisable contents.
    with open(os.path.join(www, 'mods', 'DemoMod.js'), 'w') as f:
        f.write('MOD-OK\n')

    with open(os.path.join(out, 'Game.exe'), 'wb') as f:
        f.write(b'MZ')
    with open(os.path.join(out, 'package.json'), 'w') as f:
        json.dump({'name': '', 'main': 'www/index.html', 'js-flags': '--expose-gc',
                   'window': {'title': '', 'toolbar': False, 'width': 816, 'height': 624,
                              'icon': 'www/icon/icon.png'}}, f)

    for n in SYSTEM_IMAGES:
        png(os.path.join(www, 'img', 'System', n + '.png'))
    png(os.path.join(www, 'img', 'System', 'Window.png'), 192, 192)
    png(os.path.join(www, 'img', 'System', 'Loading.png'))  # drawn while loading
    png(os.path.join(www, 'icon', 'icon.png'))

    for n in DATA_FILES:
        with open(os.path.join(www, 'Data', n + '.json'), 'w') as f:
            json.dump([None], f)

    se = {'name': '', 'pan': 0, 'pitch': 100, 'volume': 90}
    vehicle = {'bgm': se, 'characterIndex': 0, 'characterName': '',
               'startMapId': 0, 'startX': 0, 'startY': 0}
    system = {
        'gameTitle': 'rpgm test', 'versionId': 1, 'locale': 'en_US',
        'startMapId': 1, 'startX': 0, 'startY': 0, 'partyMembers': [],
        'switches': [''], 'variables': [''], 'elements': [''], 'skillTypes': [''],
        'weaponTypes': [''], 'armorTypes': [''], 'equipTypes': ['', 'Weapon'],
        'currencyUnit': 'G', 'boat': vehicle, 'ship': vehicle, 'airship': vehicle,
        'sounds': [se] * 24, 'titleBgm': se, 'battleBgm': se, 'defeatMe': se,
        'gameoverMe': se, 'victoryMe': se, 'title1Name': '', 'title2Name': '',
        'windowTone': [0, 0, 0, 0], 'optDrawTitle': True, 'optFollowers': True,
        'optSideView': False, 'optTransparent': False,
        'terms': {'basic': [''] * 10, 'commands': [''] * 26, 'params': [''] * 10,
                  'messages': {}},
        'testBattlers': [], 'testTroopId': 0,
        'hasEncryptedImages': False, 'hasEncryptedAudio': False,
    }
    # Written in upper case on purpose: MV asks for data/System.json, so finding it
    # at all is the case-insensitive layer doing its job.
    with open(os.path.join(www, 'Data', 'SYSTEM.JSON'), 'w') as f:
        json.dump(system, f)

    plugins = []
    if args.plugin:
        name = os.path.splitext(os.path.basename(args.plugin))[0]
        shutil.copy(args.plugin, os.path.join(www, 'js', 'plugins', name + '.js'))
        plugins.append({'name': name, 'status': True, 'description': '', 'parameters': {}})
    with open(os.path.join(www, 'js', 'plugins.js'), 'w') as f:
        f.write('var $plugins = ' + json.dumps(plugins) + ';\n')

    print(f'built {out}')


if __name__ == '__main__':
    main()
