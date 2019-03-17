Name: terminus
Version: 1.4.0
Release: 1
License: Unknown/not set
Summary: A new terminal for XWindows and Wayland

BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: vala
BuildRequires: glibc-headers
BuildRequires: gtk3-devel
BuildRequires: libgee-devel
BuildRequires: glib2-devel
BuildRequires: keybinder3-devel
BuildRequires: vte291-devel
BuildRequires: cmake
BuildRequires: gettext
BuildRequires: pkgconf-pkg-config
BuildRequires: make
BuildRequires: intltool

Requires: gtk3
Requires: pango
Requires: gdk-pixbuf2
Requires: cairo-gobject
Requires: cairo
Requires: glib2
Requires: atk
Requires: libgee
Requires: keybinder3
Requires: vte291
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
cd ${RPM_BUILD_DIR}; cmake -DCMAKE_INSTALL_PREFIX=/usr -DGSETTINGS_COMPILE=OFF -DICON_UPDATE=OFF ../..
make -C ${RPM_BUILD_DIR}

%install
make install -C ${RPM_BUILD_DIR} DESTDIR=%{buildroot}

%post
glib-compile-schemas /usr/share/glib-2.0/schemas

%postun
glib-compile-schemas /usr/share/glib-2.0/schemas

%clean
rm -rf %{buildroot}

