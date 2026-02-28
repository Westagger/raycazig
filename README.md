# Raycazig

A kinda-3D raycasting engine in [Zig](https://ziglang.org/) + SDL2. Think Wolfenstein 3D, but you wrote it in zig. Yes.

---

## How it works

One ray per screen column. Each ray steps through a 2D grid (DDA algorithm, same trick id Software used in 1992) until it hits a wall, then calculates how tall to draw that column based on distance. Do that 960 times and you've got a fake 3D view with zero actual 3D involved.

The whole frame lives in a flat `u32` pixel buffer that gets uploaded to the GPU via `SDL_UpdateTexture` each tick. No textures, no sprites, just arithmetic and colour values.

---

## Stack

| | |
|---|---|
| Language | Zig 0.15.2 |
| Windowing | SDL2 |
| Build | `build.zig` (no Makefiles, no CMake, no suffering) |
| Memory | `GeneralPurposeAllocator` |

SDL2 is the only external dependency.

---

## Layout

```
src/
├── main.zig     — SDL loop
├── game.zig     — state machine + input
├── renderer.zig — DDA raycaster + overlays
├── player.zig   — movement, rotation, collision
├── map.zig      — 24×24 world grid
├── font.zig     — hand-coded 8×8 bitmap font (yes, by hand)
└── c.zig        — one-line SDL2 import
```

---

## Controls

| Key | Action |
|---|---|
| `W / S` | Move |
| `A / D` | Rotate |
| `SPACE` | Start |
| `ESC` | Pause / quit |

---

## Build & run

**macOS**
```bash
brew install sdl2
zig build run
```
Auto-detects Apple Silicon vs Intel.

**Linux**
```bash
sudo apt install libsdl2-dev
zig build run
```

**Windows** — download SDL2 dev libs from [libsdl.org](https://libsdl.org), then:
```bash
zig build run -Dsdl2=C:\SDL2
```

**Release locally**
```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/raycazig
```

---

## How long did it take?

A long afternoon. The raycasting algorithm itself is well-documented (shoutout to Lodev's tutorial) so that part was fast. The Zig 0.15 build API, on the other hand, had changed enough from older versions to cost a good chunk of time — `root_source_file` is gone, `b.host` is now `b.graph.host`, path concatenation needs `b.pathJoin` at runtime instead of `++`.

The most tedious part was the bitmap font: 26 glyphs, each hand-encoded as 8 bytes. Unglamorous work, but it means no TTF dependency and no file loading at runtime.