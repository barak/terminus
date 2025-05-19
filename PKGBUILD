pkgname=terminus-rastersoft
pkgver=3.5.0
pkgrel=2
pkgdesc="X & Wayland terminal that mixes the capabilities of Guake and Terminator"
license=('GPL3')
arch=('i686' 'x86_64')
depends=( 'atk' 'glib2' 'cairo' 'gtk4' 'pango' 'gdk-pixbuf2' 'libgee' 'vte4' 'zlib' 'gnutls' 'libx11' )
makedepends=( 'vala' 'glibc' 'atk' 'cairo' 'gtk4' 'gdk-pixbuf2' 'libgee' 'glib2' 'pango' 'vte4' 'libx11' 'cmake' 'gettext' 'pkg-config' 'gcc' 'make' 'intltool' )
build() {
	rm -rf ${startdir}/install
	mkdir ${startdir}/install
	cd ${startdir}/install
	cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib
	make -j1
}

package() {
	cd ${startdir}/install
	make DESTDIR="$pkgdir/" install
}
