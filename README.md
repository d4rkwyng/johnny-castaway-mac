# Johnny Castaway for macOS

A native Swift recreation of **Screen Antics: Johnny Castaway** — the classic
1992 Sierra On-Line / Dynamix screensaver — for modern macOS (Sonoma and
later). Johnny lives on his tiny desert island, builds his raft over an
11-day story arc, fishes, gets visited by mermaids, and generally never
quite escapes.

This project is a from-scratch Swift port of the reverse-engineered engine,
rendering the original 640×480 pixel art crisply scaled on Retina displays,
packaged both as a `.saver` screensaver bundle and a standalone demo app.

## Status

Work in progress. See the issue tracker for the current phase.

- [x] Asset extraction & verification (`jctool verify`)
- [x] Resource layer (MAP/001 containers, RLE + LZW decompression, SCR/BMP/PAL/TTM/ADS parsers)
- [ ] Software renderer + sprite export (`jctool extract --png`)
- [ ] TTM animation interpreter + demo app
- [ ] ADS scene scheduler + sound
- [ ] Island, walking, story progression
- [ ] `.saver` bundle with Sonoma+ lifecycle workarounds
- [ ] Signed/notarized releases

## You must supply the original game files

The original artwork and animation scripts are **still copyrighted by
Sierra/Dynamix** and are not included in this repository. You need the two
resource files from an original copy of the screensaver:

| File         | Size (bytes) | MD5                                |
|--------------|--------------|------------------------------------|
| RESOURCE.MAP | 1,461        | `374e6d05c5e0acd88fb5af748948c899` |
| RESOURCE.001 | 1,175,645    | `8bb6c99e9129806b5089a39d24228a36` |

They ship with every release of the original product, including the 2005
re-release installer (`Setup.exe`, a Nullsoft installer), where they are
embedded as PE resources inside the bundled `Screen Antics.scr` (UPX-packed):

```sh
brew install sevenzip upx
7zz x Setup.exe -oextracted
cd extracted && upx -d "Screen Antics.scr"
7zz x "Screen Antics.scr" -opayload .rsrc/1043/RCDATA/SCREENANTICSMAPFILE .rsrc/1043/RCDATA/SCREENANTICSDATAFILE
cp payload/.rsrc/1043/RCDATA/SCREENANTICSMAPFILE  RESOURCE.MAP
cp payload/.rsrc/1043/RCDATA/SCREENANTICSDATAFILE RESOURCE.001
```

For development, drop them into `Assets/` at the repo root (gitignored).
The installed screensaver imports them through its configure sheet.

## Building

Only the Xcode **Command Line Tools** are required — no Xcode:

```sh
swift build                            # engine + jctool
./Scripts/test.sh                      # synthetic-fixture tests (no assets needed)
JC_ASSET_DIR=Assets ./Scripts/test.sh  # full test suite against your resource files
swift run jctool verify Assets         # check your resource files
swift run jctool dump Assets           # list every resource
```

(`Scripts/test.sh` wraps `swift test` with the framework paths needed when
only the Command Line Tools are installed; with full Xcode, plain
`swift test` works too.)

## Credits

This port stands on the shoulders of the people who reverse-engineered the
Dynamix formats and engine behavior:

- [**jc_reborn**](https://github.com/jno6809/jc_reborn) (C/SDL2, GPL-3) — the
  primary reference for this port: TTM/ADS interpreters, walking, story logic.
- [**Johnny-Castaway-Open-Source (JCOS)**](https://github.com/nivs1978/Johnny-Castaway-Open-Source) (C#)
  — resource format parsing, sound files.
- [**castaway**](https://github.com/xesf/castaway) (JS) — DGDS format documentation.
- [**Johnny**](https://github.com/bailli/Johnny) (C++/SDL).
- [**Aerial**](https://github.com/JohnCoates/Aerial) — the canonical source of
  macOS screensaver lifecycle workarounds.

Original game © 1992–1993 Sierra On-Line / Dynamix. This project contains no
original assets and is not affiliated with Sierra, Dynamix, or Activision.

## License

[GPL-3.0](LICENSE) (inherited from jc_reborn, from which the engine logic is
ported).
