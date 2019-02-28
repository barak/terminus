### CMakeLists automatically created with AutoVala
### Do not edit

project (terminus)
cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.8)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
enable_testing ()
option(ICON_UPDATE "Update the icon cache after installing" ON)
option(BUILD_VALADOC "Build API documentation if Valadoc is available" OFF)
option(GTK_3_20 "GTK_3_20" OFF)

if( NOT CMAKE_BUILD_TYPE )
	set(CMAKE_BUILD_TYPE Release)
endif()

include(GNUInstallDirs)
if( ( ${CMAKE_INSTALL_PREFIX} MATCHES "^/usr/local" ) )
	# A workaround to ensure that works 'out of the box' in Debian-based systems
	set(CMAKE_INSTALL_LIBDIR lib)
endif()

set(HAVE_VALADOC OFF)
if(BUILD_VALADOC)
	find_package(Valadoc)
	if(VALADOC_FOUND)
		set(HAVE_VALADOC ON)
		include(Valadoc)
	else()
		message("Valadoc not found, will not build documentation")
	endif()
endif()

find_package(PkgConfig)

set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gdk-3.0)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gtk+-3.0)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gee-0.8)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gio-2.0)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} glib-2.0)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gobject-2.0)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} keybinder-3.0)
set(MODULES_TO_CHECK ${MODULES_TO_CHECK} vte-2.91)

pkg_check_modules(DEPS REQUIRED ${MODULES_TO_CHECK})


find_program ( WHERE_glib_compile_resources glib-compile-resources )
if ( NOT WHERE_glib_compile_resources )
	MESSAGE(FATAL_ERROR "Error! external program 'glib-compile-resources' is not installed.")
endif()

find_program ( WHERE_gtk_update_icon_cache gtk-update-icon-cache )
if ( NOT WHERE_gtk_update_icon_cache )
	find_program ( WHERE_gtk_update_icon_cache gtk-update-icon-cache.3.0 )
	if ( NOT WHERE_gtk_update_icon_cache )
		MESSAGE(FATAL_ERROR "Error! none of the external programs 'gtk-update-icon-cache', 'gtk-update-icon-cache.3.0',  are installed.")
	endif()
endif()

find_program ( WHERE_glib_compile_schemas glib-compile-schemas )
if ( NOT WHERE_glib_compile_schemas )
	MESSAGE(FATAL_ERROR "Error! external program 'glib-compile-schemas' is not installed.")
endif()

add_subdirectory(po)
add_subdirectory(data/local)
add_subdirectory(terminus_gnome_shell)
add_subdirectory(data)
add_subdirectory(data/dbus)
add_subdirectory(src/vapidir)
add_subdirectory(data/icons)
add_subdirectory(data/interface)
add_subdirectory(src)

