DayZ Linux CLI Launcher
====

## About

This is an experimental launcher script for DayZ standalone on Linux when running the game via Proton.

Proton is currently unable to start the game's own regular launcher application which sets up mods and launch parameters for the game client. The game however does work fine when launching the client directly, so mods can be set up and configured manually, which is what this script does, similar to what the launcher would do.

Automatic Steam workshop mod downloads are currently unsupported due to a limitation of Steam's CLI. Workshop mods will therefore need to be subscribed manually via the web browser. A URL for each missing mod will be printed to the output.

Please see the "Install DayZ" section down below on how to get the game running on Linux.

## Usage

```
Usage: dayz-launcher.sh [OPTION]... [MODID]... [-- [GAME-PARAM]...]

Automatically set up mods for DayZ, launch the game and connect to a server,
or print the game's -mod command line argument for custom configuration.

Command line options:

  -h
  --help
    Print this help text.

  -d
  --debug
    Print debug messages to output.

  --steam <"" | flatpak | /path/to/steam/executable>
    If set to flatpak, use the flatpak version of Steam (com.valvesoftware.Steam).
    Steam needs to already be running in the flatpak container.
    Default is: "" (automatic detection - prefers flatpak if available)

  -l
  --launch
    Launch DayZ after resolving and setting up mods instead of
    printing the game's -mod command line argument.
    Any custom game parameters that come after the first double-dash (--) will
    be appended to the overall launch command line. This implies --launch.

  -n <name>
  --name <name>
    Set the profile name when launching the game via --launch.
    Some community servers require a profile name when trying to connect.

  -s <address[:port]>
  --server <address[:port]>
    Retrieve a server's mod list and add it to the remaining input.
    Uses the daemonforge.dev DayZ server JSON API.
    If --launch is set, it will automatically connect to the server.

  -p <port>
  --port <port>
    The server's query port, not to be confused with the server's game port.
    Default is: 27016

Environment variables:

  STEAM_ROOT
    Set a custom path to Steam's root directory. Default is:
    ${XDG_DATA_HOME:-${HOME}/.local/share}/Steam
    which defaults to ~/.local/share/Steam

    If the flatpak package is being used, then the default is:
    ~/.var/app/com.valvesoftware.Steam/data/Steam

    If the game is stored in a different Steam library directory, then this
    environment variable needs to be set/changed.

    For example, if the game has been installed in the game library located in
      /media/games/SteamLibrary/steamapps/common/DayZ
    then the STEAM_ROOT env var needs to be set like this:
      STEAM_ROOT=/media/games/SteamLibrary
```

## Examples

```sh
# configure mods by ID
./dayz-launcher.sh -d 123 456 789

# retrieve mods list from server, configure mods and launch the game
./dayz-launcher.sh -d -l -s address:gameport -p queryport -n nickname

# configure mods by ID and connect
./dayz-launcher.sh -d 123 456 789 -- -connect=address -name=nickname

# run game from a different Steam games library path
STEAM_ROOT=/media/games/SteamLibrary ./dayz-launcher.sh -l -s address
```

## Known issues

### Third party server query API

The third party JSON API for querying server data is unfortunately not perfectly reliable. This can't be fixed here, so if there are issues with querying the server data, then please try running the launcher again. Some servers also return invalid data, so manual mods setup via mod IDs is required.

### Steam doesn't launch the game

Sometimes the game doesn't launch despite the launcher correctly passing the right parameters to Steam. This is usually caused by a broken singleton process detection of Steam, where it passes the game's launch parameters to the original Steam process and then terminates. Restarting Steam and re-running the launcher fixes the issue.

### Case sensitivity of mod-internal file paths

Due to mods being developed on Windows and Windows not differentiating between file paths with different cases, mod developers sometimes don't care about case sensitivity of file names and directories. This can lead to loading issues on Linux when a file system without case insensitivity support is being used.

In case of ext4, which is the default file system on most distros, case insensitivity has only been implemented in kernel 5.2, which was released in July 2019 (later improved for encrypted file systems in kernel 5.13, released in June 2021). The requirements for enabling case insensitivity are an ext4 filesystem created with at least kernel version 5.2 while the `casefold` option was set, as well as the `+F` flag being set on one of the parent directories.

Please refer to your distro's documentation or search engine of choice for how to properly enable case folding/insensitivity on your file system and whether it's supported.

## Future ideas

- Rewrite in Python
- Don't use a third party server query API and query the server directly
- Install mods automatically  
  Unfortunately, Steam doesn't support downloading workshop mods via the CLI and only the `steamcmd` CLI utility seems to be able to do this from a command line shell context, but this requires a Steam login via CLI parameters, which is a bit unpractical.
- If possible, resolve mod dependencies

## Install

To install the launcher script, simply clone the git repository:

```sh
git clone https://github.com/bastimeyer/dayz-linux-cli-launcher.git
cd dayz-linux-cli-launcher
./dayz-launcher.sh ...
```

or download the raw script file from GitHub and make it executable (check the script file contents first before running it):

```sh
curl -SL -o dayz-launcher.sh 'https://github.com/bastimeyer/dayz-linux-cli-launcher/raw/master/dayz-launcher.sh'
chmod +x dayz-launcher.sh
./dayz-launcher.sh ...
```

## Install DayZ

[Support for BattlEye anti-cheat for Proton on Linux has been officially announced by Valve on 2021-12-03.][battleye-announcement]

In order to get the game running on Linux, you first have to install the Steam beta client (see Steam's settings menu). Then install `Proton Experimental` and the `Proton BattlEye Runtime` (filter by "tools" in your games library). After that, set the "Steam play compatibility tool" for DayZ to "Proton Experimental" (right-click the game and go to properties).

### Important notes

In order for the game to actually run on Linux via Proton, the [`vm.max_map_count`][vm.max_map_count] kernel parameter needs to be increased, because otherwise the game will freeze while loading the main menu or after playing for a couple of minutes. Some custom kernels like TK-Glitch for example already increase this value from its [default value of `64*1024-6`][vm.max_map_count-default] to [`512*1024`][tkg-kernel-patch], but even this won't work reliably. Increasing it to `1024*1024` seems to work.

```sh
​sudo sysctl -w vm.max_map_count=1048576
```

Or apply it permanently:

```sh
​echo 'vm.max_map_count=1048576' | sudo tee /etc/sysctl.d/vm.max_map_count.conf
```


  [battleye-announcement]: https://store.steampowered.com/news/group/4145017/view/3104663180636096966
  [vm.max_map_count]: https://github.com/torvalds/linux/blob/v5.15/Documentation/admin-guide/sysctl/vm.rst#max_map_count
  [vm.max_map_count-default]: https://github.com/torvalds/linux/blob/v5.15/include/linux/mm.h#L185-L202
  [tkg-kernel-patch]: https://github.com/Frogging-Family/linux-tkg/blob/db405096bd7fb52656fc53f7c5ee87e7fe2f99c9/linux-tkg-patches/5.15/0003-glitched-base.patch#L477-L534
