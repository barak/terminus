pkgname=terminus-rastersoft
pkgver=3.9.0
pkgrel=2
pkgdesc="X & Wayland terminal that mixes the capabilities of Guake and Terminator"
license=('GPL3')
arch=('i686' 'x86_64')
depends=( 'atk' 'glib2' 'cairo' 'gtk4' 'pango' 'gdk-pixbuf2' 'libgee' 'vte4' 'zlib' 'gnutls' 'libx11' )
makedepends=( 'vala' 'glibc' 'atk' 'cairo' 'gtk4' 'gdk-pixbuf2' 'libgee' 'glib2' 'pango' 'vte4' 'libx11' 'cmake' 'gettext' 'pkg-config' 'gcc' 'make' 'intltool' )
build() {
	rm -rf ${startdir}/_build
	cd ${startdir}
	meson setup _build --prefix=/usr -DGSETTINGS_COMPILE=OFF -DICON_UPDATE=OFF
	meson compile -C ${startdir}/_setup
}

package() {
	cd ${startdir}
	meson install -C $(startdir)/_build --destdir="$pkgdir/"
}
