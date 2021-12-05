DayZ Linux workshop setup
====

This is an expermental and still work-in-progress setup script for workshop mods of DayZ standalone when running the game via Proton on Linux.

Proton is currently unable to start the game's own regular launcher application which sets up mods and launch parameters of the game client.

Mods can be loaded via the `-mod=@MOD_NAME1;@MOD_NAME2;@MOD_NAME3` DayZ client launch parameter after they've been correctly set up in the game's root directory.

----

In order for the game to actually run on Linux via Proton, the [`vm.max_map_count`][vm.max_map_count] kernel parameter ([original definition][definition]) needs to be set, otherwise the game will freeze while loading or after playing for a couple of minutes:

```sh
​sudo sysctl -w vm.max_map_count=1048576
```

or applied permanently:

```sh
​echo 'vm.max_map_count=1048576' | sudo tee /etc/sysctl.d/vm.max_map_count.conf
```


  [vm.max_map_count]: https://github.com/torvalds/linux/blob/v5.15/Documentation/admin-guide/sysctl/vm.rst#max_map_count
  [definition]: https://github.com/torvalds/linux/blob/v5.15/include/linux/mm.h#L185-L202
