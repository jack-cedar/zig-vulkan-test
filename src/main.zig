const std = @import("std");
const print = std.debug.print;
pub const vk = @import("app.zig");
pub fn main() !void {
    var app = vk.App{};

    try app.init();

    defer app.terminate();

    while (app.window.await_event()) |event| {
        switch (event.response_type) {
            2 => print("Keyboard Event\n", .{}),
            4 => print("Mouse Event\n", .{}),
            else => {},
        }
    }
}
