const c = @import("c.zig");

const KeyboardEvent = 2;
const MouseEvent = 4;

//pub fn keyPressed()

pub const WindowInfoStruct = struct {
    name: []const u8,
    width: u16,
    height: u16,
    x: i16,
    y: i16,
    border_width: u16,
    depth: u8,
};
pub const Window = struct {
    info: WindowInfoStruct = undefined,
    connection: *c.xcb_connection_t = undefined,
    win: *c.xcb_window_t = undefined,
    screen: *c.xcb_screen_t = undefined,
    id: u32 = undefined,

    fn connect(self: *Window) !void {
        self.connection = c.xcb_connect(null, null).?;
        if (c.xcb_connection_has_error(self.connection) == 1) {
            return error.ERROR_OPENING_DISPLAY;
        }
    }
    pub fn init(self: *Window, info: WindowInfoStruct) !void {
        self.info = info;
        try self.connect();

        var setup = c.xcb_get_setup(self.connection);
        self.screen = c.xcb_setup_roots_iterator(setup).data;
        self.id = c.xcb_generate_id(self.connection);

        var value_mask: u32 = c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK;
        var value_list: [2]u32 = undefined;
        value_list[0] = self.screen.white_pixel;
        value_list[1] =
            c.XCB_EVENT_MASK_EXPOSURE |
            c.XCB_EVENT_MASK_BUTTON_PRESS |
            c.XCB_EVENT_MASK_KEY_PRESS;

        _ = value_list;

        _ = c.xcb_create_window(
            self.connection,
            self.screen.root_depth,
            self.id,
            self.screen.root,
            self.info.x,
            self.info.y,
            self.info.width,
            self.info.height,
            self.info.border_width,
            c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            self.screen.root_visual,
            value_mask,
            &value_list,
        );
    }
    pub fn start(self: *Window) !void {
        _ = c.xcb_map_window(self.connection, self.id);
        _ = c.xcb_flush(self.connection);
    }
    pub fn kill(self: *Window) void {
        c.xcb_disconnect(self.connection);
    }
    pub fn await_event(self: *Window) ?*c.xcb_generic_event_t {
        var event = c.xcb_wait_for_event(self.connection);
        if (event == null) {
            return null;
        } else {
            return event;
        }
    }
};
