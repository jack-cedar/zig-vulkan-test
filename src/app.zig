const c = @import("c.zig");
const std = @import("std");
pub const win = @import("window.zig");
const print = std.debug.print;

const Info = struct {
    AppInfo: c.VkApplicationInfo = undefined,
    WinInfo: win.WindowInfoStruct = undefined,
    InstanceInfo: c.VkInstanceCreateInfo = undefined,
    QueueFamilyInfo: c.VkDeviceQueueCreateInfo = undefined,
    DeviceInfo: c.VkDeviceCreateInfo = undefined,
    CmdInfo: c.VkCommandBufferAllocateInfo = undefined,
    CmdPoolInfo: c.VkCommandPoolCreateInfo = undefined,
    SurfaceInfo: c.VkXcbSurfaceCreateInfoKHR = undefined,
};

pub const App = struct {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var device_extensions = [_][*c]const u8{
        "VK_KHR_swapchain",
    };
    var instance_extensions = [_][*c]const u8{
        "VK_KHR_surface",
        "VK_KHR_display",
        "VK_KHR_xcb_surface",
    };
    instance: c.VkInstance = undefined,
    presentQueue: c.VkQueue = undefined,
    window: win.Window = undefined,
    physical_device: c.VkPhysicalDevice = undefined,
    device: c.VkDevice = undefined,
    surface: c.VkSurfaceKHR = undefined,
    device_count: u32 = 0,
    queue_family_index: u32 = 0,
    queue_family_count: u32 = 0,
    queue_priority: f32 = 1.0,
    available_instance_extensions: []c.VkExtensionProperties = undefined,
    available_device_extensions: []c.VkExtensionProperties = undefined,
    running: bool = false,
    cmd: c.VkCommandBuffer = undefined,
    cmd_pool: c.VkCommandPool = undefined,

    // Contains All The Info Structs For The Application
    info: Info = Info{
        .WinInfo = win.WindowInfoStruct{
            .name = "Test Window",
            .width = 800,
            .height = 600,
            .x = 100,
            .y = 100,
            .border_width = 2,
            .depth = 0,
        },
        .AppInfo = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Hello World",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "Test Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_0,
        },

        .InstanceInfo = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = instance_extensions.len,
            .ppEnabledExtensionNames = &instance_extensions,
            .pApplicationInfo = undefined,
        },

        .QueueFamilyInfo = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .queueCount = 1,
            .pQueuePriorities = undefined,
            .queueFamilyIndex = undefined,
            .flags = 0,
        },

        .DeviceInfo = c.VkDeviceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = null,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = undefined,
            .enabledExtensionCount = device_extensions.len,
            .ppEnabledExtensionNames = &device_extensions,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pEnabledFeatures = null,
            .flags = 0,
        },

        .CmdPoolInfo = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .queueFamilyIndex = undefined,
            .flags = 0,
        },

        .CmdInfo = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = undefined,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        },

        .SurfaceInfo = c.VkXcbSurfaceCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,
            .pNext = null,
            .connection = undefined,
            .window = undefined,
            .flags = 0,
        },
    },

    pub fn init(self: *App) !void {
        try self.window.init(self.info.WinInfo);
        try self.window.start();
        try self.start_instance();
        try self.get_device();
        try self.init_cmd();
        try self.create_surface(self.window);
    }
    pub fn terminate(self: *App) void {
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
        self.window.kill();
    }

    pub fn start_instance(self: *App) !void {
        self.info.InstanceInfo.pApplicationInfo = &self.info.AppInfo;
        var result = c.vkCreateInstance(&self.info.InstanceInfo, null, &self.instance);
        if (result == c.VK_ERROR_INCOMPATIBLE_DRIVER) {
            return error.NO_COMPATABLE_VULCAN_ICD;
        } else if (result != 0) {
            print("Result: {}\n", .{result});
            return error.UNKNOWN_ERROR;
        }
    }
    fn get_device(self: *App) !void {
        _ = c.vkEnumeratePhysicalDevices(self.instance, &self.device_count, null);
        var devices = try allocator.alloc(c.VkPhysicalDevice, self.device_count);
        _ = c.vkEnumeratePhysicalDevices(self.instance, &self.device_count, devices.ptr);
        if (self.device_count == 0) {
            return error.VK_ERROR_NO_DEVICES_FOUND;
        }
        var selected_device = devices[0];
        self.physical_device = selected_device;
        _ = c.vkGetPhysicalDeviceQueueFamilyProperties(selected_device, &self.queue_family_count, null);
        var queue_properties = try allocator.alloc(c.VkQueueFamilyProperties, self.queue_family_count);
        _ = c.vkGetPhysicalDeviceQueueFamilyProperties(selected_device, &self.queue_family_count, queue_properties.ptr);
        if (self.queue_family_count == 1) {
            self.queue_family_index = 0;
        }
        self.info.QueueFamilyInfo.pQueuePriorities = &self.queue_priority;
        self.info.QueueFamilyInfo.queueFamilyIndex = self.queue_family_index;
        self.info.DeviceInfo.pQueueCreateInfos = &self.info.QueueFamilyInfo;
        if (c.vkCreateDevice(selected_device, &self.info.DeviceInfo, null, &self.device) != 0) {
            return error.UNABLE_TO_CREATE_DEVICE;
        }
    }
    fn make_swapchain(self: *App) !void {
        var create_info = c.VkSwapchainCreateInfoKHR{};
        create_info.sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        create_info.pNext = null;
        create_info.surface = self.surface;

        create_info.minImageCount = 1;
    }
    fn init_cmd(self: *App) !void {
        self.info.CmdPoolInfo.queueFamilyIndex = self.queue_family_index;
        if (c.vkCreateCommandPool(self.device, &self.info.CmdPoolInfo, null, &self.cmd_pool) != 0) {
            return error.UNABLE_TO_CREATE_CMD_POOL;
        }
        self.info.CmdInfo.commandPool = self.cmd_pool;
        if (c.vkAllocateCommandBuffers(self.device, &self.info.CmdInfo, &self.cmd) != 0) {
            return error.UNABLE_TO_CREATE_CMD_BUFFER;
        }
    }

    pub fn create_surface(self: *App, window: win.Window) !void {
        self.info.SurfaceInfo.connection = window.connection;
        self.info.SurfaceInfo.window = window.id;
        var result = c.vkCreateXcbSurfaceKHR(self.instance, &self.info.SurfaceInfo, null, &self.surface);
        if (result != 0) {
            return error.FAILED_TO_CREATE_SURFACE;
        }
    }
};

fn trimZeros(string: []const u8) ![]const u8 {
    var non_zero_chars: u32 = 0;
    while (string[non_zero_chars] != 0) : (non_zero_chars += 1) {}
    var array = std.ArrayList(u8).init(App.allocator);
    try array.appendSlice(string[0..]);
    try array.resize(non_zero_chars);
    return array.items;
}
