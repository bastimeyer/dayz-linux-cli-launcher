DayZ Linux workshop setup
====

This is an experimental and still work-in-progress setup+launcher script for workshop mods of DayZ standalone when running the game via Proton on Linux.

Proton is currently unable to start the game's own regular launcher application which sets up mods and launch parameters for the game client. The game however does work fine when launching the client directly, so mods can be set up and configured manually, which is what this script tries to do, similar to what the launcher would do.

## Usage

```
Usage: dayz-mods.sh [OPTION]... [MODID]...

Automatically set up mods for the DayZ client
and print the game's -mod command line argument.

Command line options:

  -h
  --help
    Print this help text.

  -d
  --debug
    Print debug messages to output.

  -l
  --launch
    Launch DayZ after resolving and setting up mods
    instead of printing the game's -mod command line argument.

  -s <address[:port]>
  --server <address[:port]>
    Retrieve a server's mod list and add it to the remaining input.
    Uses the daemonforge.dev DayZ server JSON API.
    If --launch is set, it will automatically connect to the server.

  -p <port>
  --port <port>
    The server's query port (not to be confused with the server's game port).
    Default is: 27016

Environment variables:

  STEAM_ROOT
    Set a custom path to Steam's root directory. Default is:
    ${XDG_DATA_HOME:-${HOME}/.local/share}/Steam
    which defaults to ~/.local/share/Steam

    If the game is stored in a different Steam library directory, then this
    environment variable needs to be set/changed.
```

## Examples

```sh
./dayz-mods.sh MODID1 MODID2 MODID3...
./dayz-mods.sh --server ADDRESS
./dayz-mods.sh --launch --server ADDRESS
```

## TODO

- Don't use a custom server query API and query the server directly
- Install mods automatically (only the `steamcmd` CLI utility seems to be able to do this from a command line shell context)
- If possible, resolve mod dependencies

## Known Issues

- Mod names which contain special characters like `'` for example don't get interpreted correctly by Steam as launch argument, meaning the `--launch` parameter won't work

## Important notes

In order for the game to actually run on Linux via Proton, the [`vm.max_map_count`][vm.max_map_count] kernel parameter needs to be increased, because otherwise the game will freeze while loading the main menu or after playing for a couple of minutes. Some custom kernels like TK-Glitch for example already increase this value from its [default value of `64*1024-6`][vm.max_map_count-default] to [`512*1024`][tkg-kernel-patch], but even this won't work reliably. Increasing it to `1024*1024` seems to work.

```sh
​sudo sysctl -w vm.max_map_count=1048576
```

Or apply it permanently:

```sh
​echo 'vm.max_map_count=1048576' | sudo tee /etc/sysctl.d/vm.max_map_count.conf
```


  [vm.max_map_count]: https://github.com/torvalds/linux/blob/v5.15/Documentation/admin-guide/sysctl/vm.rst#max_map_count
  [vm.max_map_count-default]: https://github.com/torvalds/linux/blob/v5.15/include/linux/mm.h#L185-L202
  [tkg-kernel-patch]: https://github.com/Frogging-Family/linux-tkg/blob/db405096bd7fb52656fc53f7c5ee87e7fe2f99c9/linux-tkg-patches/5.15/0003-glitched-base.patch#L477-L534
