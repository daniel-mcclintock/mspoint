const std = @import("std");

pub const Terminal = struct {
    current: std.os.linux.termios = undefined,
    old: std.os.linux.termios = undefined,
    pub fn setup(self: *Terminal) void {
        _ = std.os.linux.tcgetattr(0, &self.old);
        self.current = self.old;

        // Disable echo, non-blocking reads
        self.current.lflag &= ~std.os.linux.ECHO;
        self.current.lflag &= ~std.os.linux.ICANON;

        _ = std.os.linux.tcsetattr(0, std.os.linux.TCSA.NOW, &self.current);
    }
    pub fn reset(self: *Terminal) void {
        _ = std.os.linux.tcsetattr(0, std.os.linux.TCSA.NOW, &self.old);
    }
    pub fn size(_: *Terminal) [2]u16 {
        var w: std.os.linux.winsize = std.os.linux.winsize{
            //
            .ws_row = undefined,
            .ws_col = undefined,
            .ws_ypixel = undefined,
            .ws_xpixel = undefined,
        };
        _ = std.c.ioctl(0, std.os.linux.T.IOCGWINSZ, &w);

        return [_]u16{ w.ws_col, w.ws_row };
    }
};
