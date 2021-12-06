DayZ Linux workshop setup
====

This is an expermental and still work-in-progress setup+launcher script for workshop mods of DayZ standalone when running the game via Proton on Linux.

Proton is currently unable to start the game's own regular launcher application which sets up mods and launch parameters for the game client. The game however does work fine when launching the client directly, so mods can be set up and configured manually, which is what this script tries to do, similar to what the launcher would do.

## Usage

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

In order for the game to actually run on Linux via Proton, the [`vm.max_map_count`][vm.max_map_count] kernel parameter needs to be increased, because otherwise the game will freeze while loading the main menu or after playing for a couple of minutes. Some custom kernels like TK-Glitch for example already increase this value from its [default value of `64*1024-6`][vm.max_map_count-default] to `512*1024`, but even this won't work reliably. Increasing it to `1024*1024` seems to work.

```sh
​sudo sysctl -w vm.max_map_count=1048576
```

or applied permanently:

```sh
​echo 'vm.max_map_count=1048576' | sudo tee /etc/sysctl.d/vm.max_map_count.conf
```


  [vm.max_map_count]: https://github.com/torvalds/linux/blob/v5.15/Documentation/admin-guide/sysctl/vm.rst#max_map_count
  [vm.max_map_count-default]: https://github.com/torvalds/linux/blob/v5.15/include/linux/mm.h#L185-L202
