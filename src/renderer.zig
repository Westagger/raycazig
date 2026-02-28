const std = @import("std");
const map = @import("map.zig");
const Player = @import("player.zig").Player;
const font = @import("font.zig");

const COLOR_CEILING: u32 = 0xFF_20_20_20;
const COLOR_FLOOR: u32 = 0xFF_60_60_60;
const COLOR_MENU_BG: u32 = 0xFF_00_00_60;
const COLOR_TEXT: u32 = 0xFF_FF_FF_FF;
const COLOR_ACCENT: u32 = 0xFF_FF_CC_00;

pub const Renderer = struct {
    pixel_buffer: []u32,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Renderer {
        const buf = try allocator.alloc(u32, width * height);
        @memset(buf, 0xFF_00_00_00);
        return .{
            .pixel_buffer = buf,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.pixel_buffer);
    }

    pub fn drawMenuScreen(self: *Renderer) void {
        @memset(self.pixel_buffer, COLOR_MENU_BG);

        self.fillRect(0, self.height / 4 - 2, self.width, 4, COLOR_ACCENT);
        self.fillRect(0, self.height * 3 / 4 - 2, self.width, 4, COLOR_ACCENT);

        const title = "RAYCAZIG";
        const title_scale: usize = 4;
        const title_w = title.len * (8 * title_scale + title_scale);
        const title_x = if (self.width > title_w) (self.width - title_w) / 2 else 0;
        const title_y = self.height / 4 + 20;
        font.drawString(self.pixel_buffer, self.width, self.height, title_x, title_y, title, COLOR_ACCENT, title_scale);

        const prompt = "PRESS SPACE TO START";
        const prompt_scale: usize = 2;
        const prompt_w = prompt.len * (8 * prompt_scale + prompt_scale);
        const prompt_x = if (self.width > prompt_w) (self.width - prompt_w) / 2 else 0;
        const prompt_y = self.height / 2 + 20;
        font.drawString(self.pixel_buffer, self.width, self.height, prompt_x, prompt_y, prompt, COLOR_TEXT, prompt_scale);

        const hint = "ESC  QUIT";
        const hint_scale: usize = 1;
        const hint_w = hint.len * (8 * hint_scale + hint_scale);
        const hint_x = if (self.width > hint_w) (self.width - hint_w) / 2 else 0;
        const hint_y = self.height * 3 / 4 + 10;
        font.drawString(self.pixel_buffer, self.width, self.height, hint_x, hint_y, hint, 0xFF_AA_AA_AA, hint_scale);
    }

    pub fn drawScene(self: *Renderer, player: *const Player) void {
        self.castRays(player);
    }

    pub fn drawPauseOverlay(self: *Renderer) void {
        // Dark-multiply pass: keep alpha, halve each 8-bit channel
        for (self.pixel_buffer) |*px| {
            px.* = 0xFF_00_00_00 | ((px.* & 0x00_FE_FE_FE) >> 1);
        }

        self.fillRect(0, self.height / 2 - 30, self.width, 60, 0xAA_00_00_00);

        const text = "PAUSED";
        const scale: usize = 3;
        const text_w = text.len * (8 * scale + scale);
        const text_x = if (self.width > text_w) (self.width - text_w) / 2 else 0;
        const text_y = self.height / 2 - 12;
        font.drawString(self.pixel_buffer, self.width, self.height, text_x, text_y, text, COLOR_ACCENT, scale);
    }

    fn castRays(self: *Renderer, player: *const Player) void {
        const w = self.width;
        const h = self.height;
        const fw: f64 = @floatFromInt(w);
        const fh: f64 = @floatFromInt(h);

        var x: usize = 0;
        while (x < w) : (x += 1) {
            // camera_x ranges from −1 (left edge) to +1 (right edge)
            const camera_x: f64 = 2.0 * @as(f64, @floatFromInt(x)) / fw - 1.0;
            const ray_dir_x: f64 = player.dir_x + player.plane_x * camera_x;
            const ray_dir_y: f64 = player.dir_y + player.plane_y * camera_x;

            var map_x: i32 = @intFromFloat(player.pos_x);
            var map_y: i32 = @intFromFloat(player.pos_y);

            // IEEE 754: 1/0 = +inf, which is the correct sentinel for an axis-
            // aligned ray (it will never cross a grid line on that axis).
            const delta_dist_x: f64 = @abs(1.0 / ray_dir_x);
            const delta_dist_y: f64 = @abs(1.0 / ray_dir_y);

            var step_x: i32 = undefined;
            var step_y: i32 = undefined;
            var side_dist_x: f64 = undefined;
            var side_dist_y: f64 = undefined;

            if (ray_dir_x < 0) {
                step_x = -1;
                side_dist_x = (player.pos_x - @as(f64, @floatFromInt(map_x))) * delta_dist_x;
            } else {
                step_x = 1;
                side_dist_x = (@as(f64, @floatFromInt(map_x)) + 1.0 - player.pos_x) * delta_dist_x;
            }

            if (ray_dir_y < 0) {
                step_y = -1;
                side_dist_y = (player.pos_y - @as(f64, @floatFromInt(map_y))) * delta_dist_y;
            } else {
                step_y = 1;
                side_dist_y = (@as(f64, @floatFromInt(map_y)) + 1.0 - player.pos_y) * delta_dist_y;
            }

            // side == 0, ray hit an EW wall (X-axis grid line)
            // side == 1, ray hit an NS wall (Y-axis grid line)
            var side: u1 = 0;
            var wall_cell: u8 = 0;

            while (true) {
                if (side_dist_x < side_dist_y) {
                    side_dist_x += delta_dist_x;
                    map_x += step_x;
                    side = 0;
                } else {
                    side_dist_y += delta_dist_y;
                    map_y += step_y;
                    side = 1;
                }

                // Out-of-bounds guard — treat the void as a grey wall
                if (map_x < 0 or map_y < 0 or
                    map_x >= @as(i32, map.WIDTH) or
                    map_y >= @as(i32, map.HEIGHT))
                {
                    wall_cell = 0xFF; // sentinel
                    break;
                }

                const cell = map.world[@intCast(map_y)][@intCast(map_x)];
                if (cell != 0) {
                    wall_cell = cell;
                    break;
                }
            }

            const perp_wall_dist: f64 = @max(
                if (side == 0) side_dist_x - delta_dist_x else side_dist_y - delta_dist_y,
                0.001, // avoid division by zero / inf line height
            );

            const line_height: i32 = @intFromFloat(fh / perp_wall_dist);
            const half_h: i32 = @intCast(h / 2);

            const draw_start_i = half_h - @divTrunc(line_height, 2);
            const draw_end_i = half_h + @divTrunc(line_height, 2);

            const draw_start: usize = if (draw_start_i < 0) 0 else @intCast(draw_start_i);
            const draw_end: usize = if (draw_end_i >= @as(i32, @intCast(h))) h - 1 else @intCast(draw_end_i);

            var wall_color: u32 = if (wall_cell == 0xFF)
                0xFF_88_88_88 // out-of-bounds colour
            else
                map.wallColor(wall_cell);

            // NS walls (side == 1) are darkened for fake ambient shading
            if (side == 1) wall_color = darken(wall_color);

            var y: usize = 0;
            // Ceiling
            while (y < draw_start) : (y += 1) {
                self.pixel_buffer[y * w + x] = COLOR_CEILING;
            }
            // Wall stripe
            while (y <= draw_end) : (y += 1) {
                self.pixel_buffer[y * w + x] = wall_color;
            }
            // Floor
            while (y < h) : (y += 1) {
                self.pixel_buffer[y * w + x] = COLOR_FLOOR;
            }
        }
    }

    fn darken(color: u32) u32 {
        return 0xFF_00_00_00 | ((color & 0x00_FE_FE_FE) >> 1);
    }

    fn fillRect(self: *Renderer, rx: usize, ry: usize, rw: usize, rh: usize, color: u32) void {
        const x_end = @min(rx + rw, self.width);
        const y_end = @min(ry + rh, self.height);
        var row = ry;
        while (row < y_end) : (row += 1) {
            var col = rx;
            while (col < x_end) : (col += 1) {
                self.pixel_buffer[row * self.width + col] = color;
            }
        }
    }
};
