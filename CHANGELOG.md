Changelog
====

## 0.5.1 - 2022-05-25

- Fixed error when querying unmodded servers

## 0.5.0 - 2022-04-10

- Shortened the mod directory link names in the DayZ game directory.  
  This fixes the issue of Steam not launching the game and becoming unresponsive to further launch attempts.  
  See [#9](https://github.com/bastimeyer/dayz-linux-cli-launcher/issues/9) and [ValveSoftware/steam-for-linux#5753](https://github.com/ValveSoftware/steam-for-linux/issues/5753).

## 0.4.0 - 2022-02-19

- Switched from daemonforge.dev JSON API to dayzsalauncher.com JSON API

## 0.3.0 - 2021-12-21

- Added support for optional custom game launch parameters
- Added examples and known issues to readme

## 0.2.2 - 2021-12-17

- Fixed mod symlink path check

## 0.2.1 - 2021-12-17

- Added `STEAM_ROOT` example to `--help`.
- Added output messages when not doing anything (missing mod-IDs, server address or launch parameter).

## 0.2.0 - 2021-12-15

- Changed mod symlinks to the `modid-modname` format

## 0.1.2 - 2021-12-08

- Fixed launcher not working when `--debug` was not set due to incorrect return value of debug log function

## 0.1.1 - 2021-12-08

- Fixed `stderr` redirection of various commands

## 0.1.0 - 2021-12-06

- Implemented flatpak support. Tries to use flatpak by default, if available.
- Added `--steam` parameter for overriding flatpak mode or choosing a different steam executable.

## 0.0.1 - 2021-12-06

- Initial release
