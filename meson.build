project('terminus',
  ['c','vala'],
  version: '2.3.1')

GNOME45 = (get_option('GNOME45') != '')

add_global_arguments('-DGETTEXT_PACKAGE="terminus"',language: 'c')

find_program ('glib-compile-resources')
find_program ('gtk-update-icon-cache', 'gtk-update-icon-cache.3.0')
find_program ('glib-compile-schemas')
gdk_3_0_dep = dependency('gdk-3.0')
gtk_3_0_dep = dependency('gtk+-3.0')
cairo_dep = dependency('cairo')
gee_0_8_dep = dependency('gee-0.8')
gio_2_0_dep = dependency('gio-2.0')
gio_unix_2_0_dep = dependency('gio-unix-2.0')
glib_2_0_dep = dependency('glib-2.0')
gobject_2_0_dep = dependency('gobject-2.0')
harfbuzz_gobject_dep = dependency('harfbuzz-gobject')
keybinder_3_0_dep = dependency('keybinder-3.0')
pango_dep = dependency('pango')
vte_2_91_dep = dependency('vte-2.91')

subdir('po')
cfg_dbus_data = configuration_data()
cfg_dbus_data.set ('DBUS_PREFIX',get_option('prefix'))
meson.add_install_script('meson_scripts/update_icon.sh')
if GNOME45
	meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),'share/gnome-shell/extensions/showTerminusQuakeWindow@rastersoft.com'),join_paths(meson.current_source_dir(),'terminus_gnome_shell45','extension.js'))

	meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),'share/gnome-shell/extensions/showTerminusQuakeWindow@rastersoft.com'),join_paths(meson.current_source_dir(),'terminus_gnome_shell45','metadata.json'))

else
	meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),'share/gnome-shell/extensions/showTerminusQuakeWindow@rastersoft.com'),join_paths(meson.current_source_dir(),'terminus_gnome_shell','extension.js'))

	meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),'share/gnome-shell/extensions/showTerminusQuakeWindow@rastersoft.com'),join_paths(meson.current_source_dir(),'terminus_gnome_shell','metadata.json'))

endif
extras_gresource_xml_generator = generator(find_program('glib-compile-resources'), arguments: [ '--sourcedir=@SOURCE_DIR@/data' , '--generate-source', '--target=@BUILD_DIR@/extras.gresource.xml.c', '@INPUT@'], output: '@PLAINNAME@.c')

extras_gresource_xml_file_c = extras_gresource_xml_generator.process(['data/extras.gresource.xml'])

meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),get_option('datadir'),'terminus'),join_paths(meson.current_source_dir(),'data/local','','*'))

meson.add_install_script(join_paths(meson.current_source_dir(),'meson_scripts','install_data.sh'),join_paths(get_option('prefix'),get_option('datadir'),'doc','terminus'),join_paths(meson.current_source_dir(),'doc','','*'))

installfile_1 = files('data/terminus_showhide')
install_data(installfile_1, install_dir: get_option('bindir'))
install_data('data/terminus.desktop',install_dir:join_paths(get_option('prefix'),get_option('datadir'),'applications'))
if (get_option('prefix').startswith('/home/'))
	message('[33mAutostart file data/terminus_autorun.desktop will not be installed. You must create your own .desktop file and put it at ~/.config/autostart[39m')
else
	install_data('data/terminus_autorun.desktop',install_dir: '/etc/xdg/autostart')
endif
dbus_cfg_com_rastersoft_terminus_service_base = configure_file(input: 'data/dbus/com.rastersoft.terminus.service.base',output: 'com.rastersoft.terminus.service', configuration: cfg_dbus_data)
install_data(dbus_cfg_com_rastersoft_terminus_service_base,install_dir: join_paths(get_option('prefix'),get_option('datadir'),'dbus-1','services'))
install_data('data/org.rastersoft.terminus.gschema.xml', install_dir: join_paths(get_option('prefix'),get_option('datadir'), 'glib-2.0', 'schemas'))
meson.add_install_script('meson_scripts/install_schemas.sh')
install_data('data/icons/terminus.svg',install_dir: join_paths(get_option('prefix'),get_option('datadir'),'icons','hicolor/scalable/apps'))
subdir('src')
