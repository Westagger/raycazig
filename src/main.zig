const std = @import("std");
const sdl = @import("c.zig").c;
const Game = @import("game.zig").Game;

const W: usize = 960;
const H: usize = 540;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) return error.SDLInitFailed;
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "Raycazig",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        @intCast(W),
        @intCast(H),
        sdl.SDL_WINDOW_SHOWN,
    ) orelse return error.SDLWindowFailed;
    defer sdl.SDL_DestroyWindow(window);

    const rdr = sdl.SDL_CreateRenderer(
        window,
        -1,
        sdl.SDL_RENDERER_ACCELERATED | sdl.SDL_RENDERER_PRESENTVSYNC,
    ) orelse return error.SDLRendererFailed;
    defer sdl.SDL_DestroyRenderer(rdr);

    // ARGB8888 streaming texture — pixel buffer is pushed each frame
    const tex = sdl.SDL_CreateTexture(
        rdr,
        sdl.SDL_PIXELFORMAT_ARGB8888,
        sdl.SDL_TEXTUREACCESS_STREAMING,
        @intCast(W),
        @intCast(H),
    ) orelse return error.SDLTextureFailed;
    defer sdl.SDL_DestroyTexture(tex);

    var game = try Game.init(gpa.allocator(), W, H);
    defer game.deinit();

    var last: u64 = sdl.SDL_GetTicks64();
    outer: while (true) {
        const now = sdl.SDL_GetTicks64();
        const dt: f64 = @as(f64, @floatFromInt(now - last)) / 1000.0;
        last = now;

        var ev: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&ev) != 0) {
            if (ev.type == sdl.SDL_QUIT) break :outer;
            try game.handleEvent(ev);
            if (game.should_quit) break :outer;
        }

        try game.update(dt);
        try game.render();

        _ = sdl.SDL_UpdateTexture(tex, null, game.renderer.pixel_buffer.ptr, @intCast(W * @sizeOf(u32)));
        _ = sdl.SDL_RenderClear(rdr);
        _ = sdl.SDL_RenderCopy(rdr, tex, null, null);
        sdl.SDL_RenderPresent(rdr);
    }
}
