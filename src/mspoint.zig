const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;
const brushes = @import("brushes.zig");

const CLEAR = "\x1b[2J";
const CURSOR_00 = "\x1b[H";
const CURSOR_ON = "\x1b[?25h";
const CURSOR_OFF = "\x1b[?25l";
const PIXEL_ON = "\x1b[41m";
const PIXEL_OFF = "\x1b[0m";
const ENABLE_MOUSE = "\x1b[?1003h\x1b[?1015h\x1b[?1006h\x1b[?1001h";
const DISABLE_MOUSE = "\x1b[?1003l\x1b[?1015l\x1b[?1006l\x1b[?1001l";
const BOX_TOP = 0x2550;
const BOX_BOTTOM = 0x2500;
const BOX_LEFT = 0x2502;
const BOX_RIGHT = 0x2502;
const BOX_BOTTOM_RIGHT = 0x256F;
const BOX_BOTTOM_LEFT = 0x2570;
const BOX_TOP_LEFT = 0x2552;
const BOX_TOP_RIGHT = 0x2555;
const DIM = "\x1b[2m";
const NOSTYLE = "\x1b[0m";

fn moveCursor(x: u16, y: u16) void {
    std.debug.print("\x1b[{d};{d}H", .{ y, x });
}
fn charToInt(char: u8) u8 {
    return switch (char) {
        '0' => 0,
        '1' => 1,
        '2' => 2,
        '3' => 3,
        '4' => 4,
        '5' => 5,
        '6' => 6,
        '7' => 7,
        '8' => 8,
        '9' => 9,
        else => 0,
    };
}

fn charIsInt(char: u8) bool {
    for ("0123456789") |item| {
        if (char == item) {
            return true;
        }
    }
    return false;
}

fn inSlice(comptime value: type, comptime slice: []type) bool {
    for (slice) |item| {
        if (item == value) {
            return true;
        }
    }
    return false;
}

const Mouse = struct {
    mouse_down: bool = false,
    x: u16 = 0,
    y: u16 = 0,
};

fn getInput(mouse: *Mouse) void {
    var button: u8 = 0;
    var buff: [16]u8 = undefined;
    var section: u8 = 0;

    _ = std.os.read(0, &buff) catch {};
    for (buff) |char, index| {
        if (index == 0) {
            section = 0;
            mouse.x = 0;
            mouse.y = 0;
        }

        switch (section) {
            0 => {
                switch (char) {
                    ';' => {
                        section += 1;
                    },
                    '0' => {
                        button |= 0b010;
                    },
                    '1' => {
                        button |= 0b100;
                    },
                    else => {},
                }
            },
            1 => {
                switch (charIsInt(char)) {
                    true => {
                        if (mouse.x == 0) {
                            mouse.x = charToInt(char);
                        } else {
                            mouse.x *= 10;
                            mouse.x += charToInt(char);
                        }
                    },
                    false => {
                        section += 1;
                    },
                }
            },
            2 => {
                switch (charIsInt(char)) {
                    true => {
                        if (mouse.y == 0) {
                            mouse.y = charToInt(char);
                        } else {
                            mouse.y *= 10;
                            mouse.y += charToInt(char);
                        }
                    },
                    false => {
                        //technically section 3
                        switch (char) {
                            'M' => {
                                button |= 0b001;
                            },
                            'm' => {
                                button |= ~@as(u8, 0b001);
                            },
                            else => {},
                        }
                    },
                }
            },
            else => {},
        }
    }

    if (button & 0b011 == 0b011 and !mouse.mouse_down) {
        mouse.mouse_down = true;
    } else if (button & 0b010 == 0b010 and mouse.mouse_down) {
        mouse.mouse_down = false;
    }
}

pub fn main() !void {
    var terminal = Terminal{};
    terminal.setup();
    // whoops!, this doesn't work if you ctrl-c
    defer terminal.reset();

    std.debug.print("{s}{s}", .{ CLEAR, CURSOR_OFF });
    std.debug.print("{s}", .{ENABLE_MOUSE});
    defer std.debug.print("{s}", .{DISABLE_MOUSE});
    defer std.debug.print("{s}", .{CURSOR_ON});

    var brush = brushes.BRAILLE;
    var stroke: bool = false;
    var i: u16 = brush[0];
    var bi: u16 = 0;
    var mouse = Mouse{};

    var button_clear: u16 = 2;
    var brush_ofs: u16 = 0;

    while (true) {
        var terminal_size: [2]u16 = terminal.size();
        border(1, 1, terminal_size[0], 2);
        moveCursor(2, 2);
        if (stroke) {
            std.debug.print("x        {u} -> < ", .{i});
        } else {
            std.debug.print("x        {u} OO < ", .{i});
        }

        var b: u16 = 0;
        while (b < terminal_size[0] - 3 - 18) : (b += 1) {
            if (b + brush_ofs < brush.len) {
                if (i == brush[b + brush_ofs]) {
                    std.debug.print("{u}", .{brush[b + brush_ofs]});
                } else {
                    std.debug.print("{s}{u}{s}", .{ DIM, brush[b + brush_ofs], NOSTYLE });
                }
            } else {
                break;
            }
        }

        std.debug.print(" >", .{});

        getInput(&mouse);
        if (mouse.y == 2) {
            if (mouse.mouse_down) {
                if (mouse.x == button_clear) {
                    std.debug.print("{s}", .{CLEAR});
                } else if (mouse.x == 16 and brush_ofs > 0) {
                    brush_ofs -= 1;
                } else if (mouse.x == terminal_size[0] - 2 and brush_ofs < brush.len - 1) {
                    brush_ofs += 1;
                } else if (mouse.x >= 18 and mouse.x < terminal_size[0] - 4) {
                    i = brush[brush_ofs + mouse.x - 18];
                } else if (mouse.x == 13 or mouse.x == 14) {
                    stroke = !stroke;
                }
            }
        } else {
            if (mouse.mouse_down and mouse.y > 3) {
                moveCursor(mouse.x, mouse.y);

                std.debug.print("{u}", .{i});
                if (stroke and bi < brush.len - 1) {
                    bi += 1;
                    i = brush[bi];
                }
            } else if (stroke) {
                bi = 0;
                i = brush[bi];
            }
        }
    }
}

fn border(x: u16, y: u16, width: u16, height: u16) void {
    var i: u16 = 1;
    moveCursor(x, y);
    std.debug.print("{u}", .{BOX_TOP_LEFT});

    // x top
    while (i < width - 1) : (i += 1) {
        std.debug.print("{u}", .{BOX_TOP});
    }
    std.debug.print("{u}", .{BOX_TOP_RIGHT});

    i = 1;
    moveCursor(x, y + height);
    std.debug.print("{u}", .{BOX_BOTTOM_LEFT});

    // x bottom
    while (i < width - 1) : (i += 1) {
        std.debug.print("{u}", .{BOX_BOTTOM});
    }

    std.debug.print("{u}", .{BOX_BOTTOM_RIGHT});

    i = 1;
    // y left
    while (i < height) : (i += 1) {
        moveCursor(x, y + i);
        std.debug.print("{u}", .{BOX_LEFT});

        moveCursor(x + width - 1, y + i);
        std.debug.print("{u}", .{BOX_RIGHT});
    }
}

fn rgbColor(r: u8, g: u8, b: u8) void {
    std.debug.print("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
}
