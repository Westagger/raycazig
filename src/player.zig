const std = @import("std");
const map = @import("map.zig");

const MARGIN: f64 = 0.2; // collision skin width in map units

pub const Player = struct {
    pos_x: f64,
    pos_y: f64,
    dir_x: f64,
    dir_y: f64,
    plane_x: f64,
    plane_y: f64, // camera plane — |plane| ≈ tan(FOV/2)
    move_speed: f64,
    rot_speed: f64,

    pub fn init() Player {
        return .{
            .pos_x = 3.5,
            .pos_y = 3.5,
            .dir_x = 1.0,
            .dir_y = 0.0,
            .plane_x = 0.0,
            .plane_y = 0.66,
            .move_speed = 4.0,
            .rot_speed = 2.0,
        };
    }

    pub fn moveForward(self: *Player, dt: f64) void {
        self.slide(self.move_speed * dt);
    }
    pub fn moveBackward(self: *Player, dt: f64) void {
        self.slide(-self.move_speed * dt);
    }

    fn slide(self: *Player, step: f64) void {
        const nx = self.pos_x + self.dir_x * step;
        const ny = self.pos_y + self.dir_y * step;
        if (!map.isSolid(@intFromFloat(nx + std.math.sign(self.dir_x) * MARGIN), @intFromFloat(self.pos_y)))
            self.pos_x = nx;
        if (!map.isSolid(@intFromFloat(self.pos_x), @intFromFloat(ny + std.math.sign(self.dir_y) * MARGIN)))
            self.pos_y = ny;
    }

    pub fn rotateLeft(self: *Player, dt: f64) void {
        self.rotate(-self.rot_speed * dt);
    }
    pub fn rotateRight(self: *Player, dt: f64) void {
        self.rotate(self.rot_speed * dt);
    }

    // 2D rotation matrix, no trig in movement hot-path
    fn rotate(self: *Player, a: f64) void {
        const c = @cos(a);
        const s = @sin(a);
        const dx = self.dir_x;
        self.dir_x = dx * c - self.dir_y * s;
        self.dir_y = dx * s + self.dir_y * c;
        const px = self.plane_x;
        self.plane_x = px * c - self.plane_y * s;
        self.plane_y = px * s + self.plane_y * c;
    }
};
