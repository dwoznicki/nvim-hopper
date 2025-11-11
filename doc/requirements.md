# Requirements

## Neovim

Neovim must be v0.10.0 or greater.

# SQLite

## MacOS, Linux
sqlite3 must be installed, and ideally available on the $PATH for nvim-hopper to work out of the box.

To check, run

```bash
sqlite3 --version
```

## Windows

On Windows, nvim-hopper will attempt to download the library. The executable will be placed in the standard Neovim cache directory; probably something like

```sh
C:\Users\$YourUsername\AppData\Local\Temp\nvim\sqlite3.dll
```

Note that Windows supports is best effort for now.
