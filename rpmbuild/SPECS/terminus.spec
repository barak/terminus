Name: terminus
Version: 3.7.1
Release: 1
License: GPL-3.0-only
Summary: X and Wayland terminal that mixes the capabilities of Guake and Terminator

BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: vala
BuildRequires: glibc-headers
BuildRequires: gtk4-devel
BuildRequires: libgee-devel
BuildRequires: glib2-devel
BuildRequires: vte291-gtk4-devel
BuildRequires: meson
BuildRequires: ninja-build
BuildRequires: gettext
BuildRequires: pkgconf-pkg-config
BuildRequires: make
BuildRequires: intltool

Requires: gtk4
Requires: pango
Requires: gdk-pixbuf2
Requires: cairo-gobject
Requires: cairo
Requires: glib2
Requires: atk
Requires: libgee
Requires: vte291-gtk4
Requires: zlib
Requires: pcre2
Requires: gnutls

%description
A new terminal for XWindows and Wayland
.
![Terminus screenshot](terminus.png)
.

%files
*

%build
mkdir -p ${RPM_BUILD_DIR}
cd ${RPM_BUILD_DIR}; meson setup _build --prefix=/usr -DGSETTINGS_COMPILE=OFF -DICON_UPDATE=OFF
meson compile -C ${RPM_BUILD_DIR}/_setup

%install
meson install -C $(BUILDDIR)/_build --destdir=%{buildroot}

%post
glib-compile-schemas /usr/share/glib-2.0/schemas

%postun
glib-compile-schemas /usr/share/glib-2.0/schemas

%clean
rm -rf %{buildroot}

