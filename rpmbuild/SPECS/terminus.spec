Name: terminus
Version: 3.8.0
Release: 1%{?dist}
License: GPL-3.0-only
Summary: X and Wayland terminal that mixes the capabilities of Guake and Terminator

URL: https://gitlab.com/rastersoft/terminus
Source0: https://gitlab.com/rastersoft/terminus/-/archive/%{version}/terminus-%{version}.tar.gz

BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: vala
BuildRequires: glibc-headers
BuildRequires: gtk4-devel
BuildRequires: libgee-devel
BuildRequires: glib2-devel
BuildRequires: vte291-gtk4-devel
BuildRequires: harfbuzz-devel
BuildRequires: cairo-devel
BuildRequires: pango-devel
BuildRequires: meson
BuildRequires: ninja-build
BuildRequires: gettext
BuildRequires: pkgconf-pkg-config
BuildRequires: desktop-file-utils

Requires: gtk4%{?_isa}
Requires: pango%{?_isa}
Requires: gdk-pixbuf2%{?_isa}
Requires: cairo-gobject%{?_isa}
Requires: cairo%{?_isa}
Requires: glib2%{?_isa}
Requires: libgee%{?_isa}
Requires: vte291-gtk4%{?_isa}

%global _description %{expand:
A terminal for X11 and Wayland that combines the capabilities of Guake and
Terminator into a single application.}

%description
%{_description}

%prep
%autosetup -n %{name}-%{version}

%build
%meson
%meson_build

%install
%meson_install
%find_lang %{name}

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/com.rastersoft.terminus.desktop

%files -f %{name}.lang
%license LICENSE
%{_bindir}/terminus
%{_bindir}/terminus_showhide
%{_datadir}/applications/com.rastersoft.terminus.desktop
%{_datadir}/dbus-1/services/com.rastersoft.terminus.service
%{_datadir}/glib-2.0/schemas/org.rastersoft.terminus.gschema.xml
%{_datadir}/icons/hicolor/scalable/apps/terminus.svg
%{_datadir}/doc/terminus/
%{_datadir}/terminus/
%{_datadir}/gnome-shell/extensions/showTerminusQuakeWindow@rastersoft.com/
%{_sysconfdir}/xdg/autostart/terminus_autorun.desktop

%changelog
%autochangelog
