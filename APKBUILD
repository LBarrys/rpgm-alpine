# Contributor: LBarrys <201232108+LBarrys@users.noreply.github.com>
# Maintainer: LBarrys <201232108+LBarrys@users.noreply.github.com>
pkgname=rpgm
pkgver=0.1.0
pkgrel=0
pkgdesc="Run Windows RPG Maker games natively, without Wine"
url="https://github.com/LBarrys/rpgm-alpine"
arch="noarch"
license="GPL-3.0-or-later"
depends="electron"
checkdepends="nodejs ruby"
source="$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz"
builddir="$srcdir/rpgm-alpine-$pkgver"
build() {
	:
}

check() {
	./test/run.sh static
	./test/run.sh unit
}

package() {
	PREFIX=/usr DESTDIR="$pkgdir" ./install.sh
}

sha512sums=""
