const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");
});

const WindowInfoStruct = struct {
    name: []const u8,
    width: i32,
    height: i32,
};
const Info = struct {
    WindowInfo: WindowInfoStruct = undefined,
    AppInfo: c.VkApplicationInfo = undefined,
    InstanceInfo: c.VkInstanceCreateInfo = undefined,
    QueueFamilyInfo: c.VkDeviceQueueCreateInfo = undefined,
    DeviceInfo: c.VkDeviceCreateInfo = undefined,
    CmdInfo: c.VkCommandBufferAllocateInfo = undefined,
    CmdPoolInfo: c.VkCommandPoolCreateInfo = undefined,
};

const App = struct {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var extensions = std.ArrayList([]const u8).init(allocator);
    window: *c.GLFWwindow = undefined,
    instance: c.VkInstance = undefined,
    physical_device: c.VkPhysicalDevice = undefined,
    device: c.VkDevice = undefined,
    surface: c.VkSurfaceKHR = undefined,
    device_count: u32 = 0,
    queue_family_index: u32 = 0,
    queue_family_count: u32 = 0,
    queue_priority: f32 = 1.0,
    available_extensions: []c.VkExtensionProperties = undefined,

    cmd: c.VkCommandBuffer = undefined,
    cmd_pool: c.VkCommandPool = undefined,

    // Contains All The Info Structs For The Application
    info: Info = Info{
        .WindowInfo = WindowInfoStruct{
            .name = "My Vulkan Window",
            .width = 500,
            .height = 500,
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
            .enabledExtensionCount = 0,
            .ppEnabledLayerNames = null,
            .ppEnabledExtensionNames = undefined,
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
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
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
    },

    fn init(self: *App) !void {
        _ = self.start_window();
        try self.start_instance();
        try self.get_device();
        try self.init_cmd();
        try self.create_surface();
    }

    fn terminate(self: *App) void {
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }

    fn start_window(self: *App) void {
        _ = c.glfwInit();
        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
        self.window = c.glfwCreateWindow(self.info.WindowInfo.width, self.info.WindowInfo.height, self.info.WindowInfo.name.ptr, null, null).?;
    }

    fn start_instance(self: *App) !void {
        self.info.InstanceInfo.pApplicationInfo = &self.info.AppInfo;
        self.info.InstanceInfo.ppEnabledExtensionNames = @ptrCast([*][*c]const u8, extensions.items.ptr);
        var result = c.vkCreateInstance(&self.info.InstanceInfo, null, &self.instance);
        if (result == c.VK_ERROR_INCOMPATIBLE_DRIVER) {
            return error.NO_COMPATABLE_VULCAN_ICD;
        } else if (result != 0) {
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

    fn create_surface(self: *App) !void {
        if (c.glfwCreateWindowSurface(self.instance, self.window, null, &self.surface) != 0) {
            return error.UNABLE_TO_CREATE_SURFACE;
        }
    }

    fn get_extensions(self: *App) !void {
        var count: u32 = 0;
        _ = c.vkEnumerateInstanceExtensionProperties(null, &count, null);
        var supported_extensions = try allocator.alloc(c.VkExtensionProperties, count);
        _ = c.vkEnumerateInstanceExtensionProperties(null, &count, supported_extensions.ptr);
        self.available_extensions = supported_extensions;
    }
    fn enable_extension(self: *App, name: []const u8) !void {
        for (self.available_extensions) |extension| {
            if (std.mem.eql(u8, try trimZeros(extension.extensionName[0..]), name)) {
                print("Extension: \"{s}\" Enabled\n", .{name});
                try extensions.append(name);
                return;
            }
        }
        print("Extension: \"{s}\" Not Available\n", .{name});
    }
    fn list_extensions(self: *App) !void {
        for (self.available_extensions) |extension| {
            print("Extension: {s}\n", .{trimZeros(extension.extensionName[0..])});
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

pub fn main() !void {
    var app = App{};

    try app.get_extensions();
    try app.list_extensions();
    try app.enable_extension("VK_KHR_display");
    try app.init();
    defer app.terminate();
}
