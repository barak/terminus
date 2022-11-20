# History of versions #

* Version 1.20.0 (2022-11-20)
  * Fixed Guake window zero height on first run
  * Fixed Guake keybinding failing until re-set
  * Added hotkeys to close a tile and a tab
  * Now asks for confirmation when trying to close a terminal with a running program
  * Fixed color scheme selection
  * Allows to change the top bar colors
  * Cleaned the color management code
* Version 1.19.1 (2022-10-13)
  * Added support for Gnome Shell 43
* Version 1.19.0 (2022-09-28)
  * Added shortcuts for horizontal and vertical split
* Version 1.18.0 (2022-07-02)
  * Now the window doesn't get stuck in maximized mode when resized too much
  * Close the tabs with the central button
  * If there are too much tabs, show scroll buttons
* Version 1.17.0 (2022-06-05)
  * Now the extension doesn't loose the connection with Terminus when the computer locks
* Version 1.16.0 (2022-05-12)
  * Set a right value for the TERM environment variable
  * Use the user-defined terminal instead of /bin/bash by default
* Version 1.15.1 (2022-04-29)
  * Add unofficial support for 1.14.1 parameters
* Version 1.15.0 (2022-04-28)
  * Migrated to GtkApplication
  * Don't relaunch terminus if the extension is disabled
  * Added zoom capabilities
  * Added key for showing the menu
* Version 1.14.1 (2022-03-29)
  * Support for Gnome Shell 42
* Version 1.14.0 (2021-09-12)
  * Support for Gnome Shell 40
  * Now it uses again a true menu for right-click
  * Removed "bold" property (is deprecated)
* Version 1.13.0 (2020-11-23)
  * Now the guake mode REALLY gets the focus under X11 in gnome shell
  * If there is already a terminus instance when the extension is launched, it only shows the notification once
  * Fixed several warnings
* Version 1.12.0 (2020-04-24)
  * Fix popup menu translations
* Version 1.11.0 (2020-04-16)
  * Fix resize and freeze under Wayland
* Version 1.10.0 (2020-04-15)
  * Now it receives the focus under X11
* Version 1.9.0 (2020-04-09)
  * Now guarantees under Wayland that occupies the whole width
  * Added --version parameter
  * Changed license to GPLv3 only
  * Fixed Debian files
* Version 1.8.0 (2019-12-26)
  * Now, under wayland, opens guake window in the mouse monitor
  * Fixed red color spilling outside the window
* Version 1.7.0 (2019-10-11)
  * Fixed the right-click menu under Wayland
  * Fixed several compiling warnings
  * Removed deprecated calls
* Version 1.6.0 (2019-09-23)
  * Now the Wayland version (under gnome shell) works like the X11 one (is shown over all windows, and in all workspaces)
  * Now the "guake" terminal is show always in the primary monitor
* Version 1.5.0 (2019-05-06)
  * Now PASTE works with clipboard managers
* Version 1.4.1 (2019-03-26)
  * Fixed COPY keybinding
* Version 1.4.0 (2019-02-28)
  * Added keybindings for COPY and PASTE
  * Added keybindings to move focus between terminals in the same tab
* Version 1.3.0 (2019-02-06)
  * Added the -e and -x parameters to create a new window an launch a command inside
  * Added the --working-directory parameter
  * Fixed the .desktop file to fully follow the standard
  * Added an screenshot in the README.md file
* Version 1.2.0 (2018-10-19)
  * Fixes Guake hotkey don't working on X11 with another terminus open
  * Added missing parameter in the help
* Version 1.1.0 (2018-09-13)
  * Fixes empty title bar
  * Updated spanish translation
* Version 1.0.0 (2018-06-12)
  * Now includes a close button in each terminal
* Version 0.11.0 (2018-03-25)
  * Now the CAPS LOCK state doesn't interfere with the hot keys
  * Several fixes to the Debian packaging files (thanks to Barak)
* Version 0.10.0 (2017-12-03)
  * Now guake mode works better under Wayland
* Version 0.9.1 (2017-10-13)
  * Now doesn't lock gnome shell under wayland for 20 seconds when there are no instances of terminus running and the user presses the key to show the guake terminal
* Version 0.9.0 (2017-10-12)
  * Now the guake-style window won't get stuck in maximized mode when resized too big
  * Now the guake mode works fine if all terminus sessions are killed and is relaunched via D-Bus
  * Now, when closing the terminal in an split window, the other terminal will receive the focus
* Version 0.8.1 (2017-09-18)
  * Fixed the install path when creating packages
  * Fixed the gnome shell extension, now it works on gnome shell 3.24 and 3.26
  * Forced GTK version to 3, to avoid compiling with GTK 4
* Version 0.8.0 (2017-08-01)
  * Fixed some startup bugs
* Version 0.7.0 (2016-12-24)
  * Added full palette support
  * Added all palette styles from gnome-terminal
  * Added Solarized palette
  * Allows to set the preferred shell
  * Allows to configure more details (cursor shape, using bolds, rewrap on resize, and terminal bell)
* Version 0.6.0 (2016-12-17)
  * Added a Gnome Shell extension, to allow to use the quake-terminal mode under Wayland with Gnome Shell
  * Fixed the top bar (sometimes it didn't show the focus)
  * Removed several deprecated functions
* Version 0.5.0 (2016-12-12)
  * Added Wayland support
  * Added DBus remote control
* Version 0.4.0 (2016-09-17)
  * Fixed the window size during startup
  * Fixed resize bug when moving the mouse too fast
  * Fixed the "Copy" function. Now it copies the text to the clipboard
* Version 0.3.0 (2016-08-24)
  * Fixed compilation paths
  * Now can be compiled with valac-0.30
  * Added package files
* Version 0.2.0 (2016-08-24)
  * Fixed resizing
  * Cyclic jump from tab to tab using Page Down and Page Up
  * Added note in the README to fix the focus problem in Gnome Shell
* Version 0.1.0 (2016-08-23)
  * First public version
