# Contributor: LBarrys <201232108+LBarrys@users.noreply.github.com>
# Maintainer: LBarrys <201232108+LBarrys@users.noreply.github.com>
pkgname=rpgm
pkgver=0.1.0
pkgrel=0
pkgdesc="Run Windows RPG Maker games natively, without Wine"
url="https://github.com/LBarrys/rpgm-alpine"
arch="noarch"
license="GPL-3.0-or-later"
# electron is what stands in for NW.js; it lives in testing, which is why this
# package does too. unzip is only needed for games shipped as package.nw, and
# mkxp-z (not packaged by Alpine) only for XP/VX/VX Ace, so both stay optional.
depends="electron"
checkdepends="nodejs ruby"
source="$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz"
builddir="$srcdir/rpgm-alpine-$pkgver"
build() {
	: # nothing to build: shell, JavaScript and Ruby
}

check() {
	# The static and unit tiers only; the integration tier plays a real game under
	# Electron and needs a display, which a build host does not have.
	./test/run.sh static
	./test/run.sh unit
}

package() {
	PREFIX=/usr DESTDIR="$pkgdir" ./install.sh
}

sha512sums="" # filled in by `abuild checksum`
