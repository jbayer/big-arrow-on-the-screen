# virtual-display

Test helper that adds a temporary virtual display, so multi-display behaviour can be checked on a
Mac with one screen. Private CoreGraphics classes (`CGVirtualDisplay` and friends, macOS 11+).
Test tool only, not part of the shipped CLI.

## Build

```bash
scripts/virtual-display/build.sh
# -> scripts/virtual-display/.build/virtual-display
# -> scripts/virtual-display/.build/list-displays
```

Plain `swiftc` (Swift 6) with `-import-objc-header CGVirtualDisplayPrivate.h`; no Xcode, no SwiftPM.

## Run

```bash
virtual-display --width 1920 --height 1080 --hidpi 0 --seconds 8 [--origin x,y]
```

- `--width/--height`: the logical size in points. With `--hidpi 1`, the backing mode is 2x in pixels.
- `--origin x,y`: top-left corner in global top-left points (`0,-1080` = above main). Default: right
  of main. macOS may snap it, so trust the printed frame.
- Once the display is up, extended and the old main is still main, it prints one JSON line
  (`CGDisplayBounds`):
  `{"displayID":6,"frame":{"x":1512,"y":0,"width":1920,"height":1080}}`
- Lives for `--seconds` or until SIGINT/SIGTERM/SIGHUP. Diagnostics on stderr.
- Fails hard (exit 1) if the display does not come up, the mode does not exist, or the layout does
  not settle within 5 s.

Smoke test (always in the foreground, with a timeout):

```bash
D=scripts/virtual-display/.build
timeout 20 $D/virtual-display --width 1920 --height 1080 --hidpi 0 --seconds 8 > /tmp/vd.json 2> /tmp/vd.err &
PID=$!; sleep 3
cat /tmp/vd.json; $D/list-displays          # expect 2 online displays
wait $PID; echo "exit=$?"; cat /tmp/vd.err
$D/list-displays                            # expect 1 display again
```

## Safety

- Every change is one `CGCompleteDisplayConfiguration(config, .forSession)` transaction, never
  `kCGConfigurePermanently`.
- macOS brought the new display up as **mirror master and main display**. In the same session-only
  transaction the helper breaks those mirrors, keeps the old main at (0,0) and places the virtual
  display. Expect one short flash on the real screen.
- The display goes away when the process exits (its window-server connection closes), even on
  SIGKILL. Releasing `CGVirtualDisplay` in a running process did not remove it within 5 s.

## Caveats

- Private, undocumented API: may change with any macOS release.
- No TCC permission needed. Screen Recording only matters to capture its pixels (DeskPad uses
  `CGDisplayStream`); it is a blank framebuffer nobody sees.
- `--hidpi 1` picks the mode with `pixelWidth == 2 * width`, as hidpi-mirror does.

## Sources (read for this helper)

- DeskPad by Bastian Andelefski (Stengo), MIT. Private header and usage (descriptor, settings, modes, `setDispatchQueue`):
  https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/CGVirtualDisplayPrivate.h
  https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/Frontend/Screen/ScreenViewController.swift
- KhaosT/CGVirtualDisplay, Apache-2.0, the original example that the DeskPad header comes from (includes `terminationHandler`):
  https://github.com/KhaosT/CGVirtualDisplay/blob/ec72be5f546d1aa1257f9976fea86a2de9dab35c/VirtualDisplayExp/CGVirtualDisplayPrivate.h
  https://github.com/KhaosT/CGVirtualDisplay/blob/ec72be5f546d1aa1257f9976fea86a2de9dab35c/VirtualDisplayExp/ViewController.swift
- pasky/hidpi-mirror, MIT. HiDPI through 2x pixel modes plus `kCGDisplayShowDuplicateLowResolutionModes` mode lookup:
  https://github.com/pasky/hidpi-mirror/blob/13acfaa0ec4b13bfce84554beebc8a09813cc2ae/hidpi-mirror.m
