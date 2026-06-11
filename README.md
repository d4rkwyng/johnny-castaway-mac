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

All engine phases complete — the full screensaver works.

- [x] Asset extraction & verification (`jctool verify`)
- [x] Resource layer (MAP/001 containers, RLE + LZW decompression, SCR/BMP/PAL/TTM/ADS parsers — byte-identical dumps vs. the reference C engine)
- [x] Software renderer + sprite export (`jctool extract --png`)
- [x] TTM animation interpreter (all 41 scripts play to completion)
- [x] ADS scene scheduler + sound
- [x] Island, walking, story progression (3-seed × 1M-tick soak tested)
- [x] Story choreography invariant tests (day gating, walk connectivity, scene-flag rules)
- [x] `.saver` bundle with Sonoma+ lifecycle workarounds
- [x] [Releases](https://github.com/d4rkwyng/johnny-castaway-mac/releases) — `.saver` + `.app` zips built by CI
- [x] Developer ID signed + notarized releases, Homebrew tap

## Install

```sh
brew install --cask d4rkwyng/tap/johnny-castaway
```

installs **both** the app and the screensaver. Launch **Johnny Castaway**
from Applications once — on first run it asks for your
RESOURCE.MAP/RESOURCE.001 ([see below](#you-must-supply-the-original-game-files)):
drag the folder (or the files) onto the window, or click **Choose Folder…**.
That single import provisions the screensaver too. Then open
**System Settings → Screen Saver**, click **Show All** under "Other", and
select **Johnny Castaway**.

Screensaver only: `brew install --cask d4rkwyng/tap/johnny-castaway-saver`,
then import the resource files via the saver's **Options…** sheet.

All zips (combined, app-only, saver-only) are on the
[latest release](https://github.com/d4rkwyng/johnny-castaway-mac/releases/latest)
(signed + notarized), or build from source:

```sh
./Scripts/build-app.sh --install     # → /Applications/Johnny Castaway.app
./Scripts/build-saver.sh --install   # → ~/Library/Screen Savers
```

## The app

Double-click it (or `swift run -c release JohnnyDemo` from the repo) and
Johnny does his thing in a window. Press **H** for the key reference:

| Key | Action |
|-----|--------|
| H or ? | show/hide help overlay |
| Space | pause / resume |
| Return | advance one frame while paused |
| − / + | step speed down / up (0.25×–50×) |
| M | toggle 50× max speed |
| D | skip to the next story day (1–11) |
| T | set date & time (preview holidays / night) |
| F | toggle fullscreen |
| Q / Esc | quit |

Other modes:

```sh
swift run -c release JohnnyDemo --fullscreen   # start fullscreen
swift run -c release JohnnyDemo list           # list scenes
swift run -c release JohnnyDemo ads FISHING.ADS 1 --island
swift run -c release JohnnyDemo ttm MJJOG.TTM
```

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
The app imports them on first launch (drag & drop or Choose Folder…);
the screensaver alone can import them through its **Options…** sheet.

### Sound

The resource containers hold no audio — the original played separate WAV
samples. Both the app and the saver look for `sound0.wav` … `sound24.wav`
next to RESOURCE.MAP and play them when present (the import copies them
too; the saver's Options… sheet has a "Play sounds" toggle). The same
files jc_reborn uses are in the
[JCOS repository](https://github.com/nivs1978/Johnny-Castaway-Open-Source/tree/master/JCOS/Resources).

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
