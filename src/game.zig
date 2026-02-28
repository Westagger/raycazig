const std = @import("std");
const sdl = @import("c.zig").c;
const Player = @import("player.zig").Player;
const Renderer = @import("renderer.zig").Renderer;

const State = enum { main_menu, playing, paused };
const Keys = struct {
    w: bool = false,
    a: bool = false,
    s: bool = false,
    d: bool = false,
    fn clear(k: *Keys) void {
        k.* = .{};
    }
};

pub const Game = struct {
    state: State,
    player: Player,
    renderer: Renderer,
    keys: Keys,
    should_quit: bool,

    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize) !Game {
        return .{
            .state = .main_menu,
            .player = Player.init(),
            .renderer = try Renderer.init(allocator, w, h),
            .keys = .{},
            .should_quit = false,
        };
    }

    pub fn deinit(self: *Game) void {
        self.renderer.deinit();
    }

    pub fn handleEvent(self: *Game, ev: sdl.SDL_Event) !void {
        switch (ev.type) {
            sdl.SDL_KEYDOWN => self.keyDown(ev.key.keysym.sym),
            sdl.SDL_KEYUP => self.keyUp(ev.key.keysym.sym),
            else => {},
        }
    }

    fn keyDown(self: *Game, sym: sdl.SDL_Keycode) void {
        switch (sym) {
            sdl.SDLK_ESCAPE => switch (self.state) {
                .main_menu => self.should_quit = true,
                .playing => self.state = .paused,
                .paused => self.state = .playing,
            },
            sdl.SDLK_SPACE => if (self.state == .main_menu) {
                self.player = Player.init();
                self.keys.clear();
                self.state = .playing;
            },
            sdl.SDLK_w => self.keys.w = true,
            sdl.SDLK_s => self.keys.s = true,
            sdl.SDLK_a => self.keys.a = true,
            sdl.SDLK_d => self.keys.d = true,
            else => {},
        }
    }

    fn keyUp(self: *Game, sym: sdl.SDL_Keycode) void {
        switch (sym) {
            sdl.SDLK_w => self.keys.w = false,
            sdl.SDLK_s => self.keys.s = false,
            sdl.SDLK_a => self.keys.a = false,
            sdl.SDLK_d => self.keys.d = false,
            else => {},
        }
    }

    pub fn update(self: *Game, dt: f64) !void {
        if (self.state != .playing) return;
        if (self.keys.w) self.player.moveForward(dt);
        if (self.keys.s) self.player.moveBackward(dt);
        if (self.keys.a) self.player.rotateLeft(dt);
        if (self.keys.d) self.player.rotateRight(dt);
    }

    pub fn render(self: *Game) !void {
        switch (self.state) {
            .main_menu => self.renderer.drawMenuScreen(),
            .playing => self.renderer.drawScene(&self.player),
            .paused => {
                self.renderer.drawScene(&self.player);
                self.renderer.drawPauseOverlay();
            },
        }
    }
};
