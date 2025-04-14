const std_ = @import("std");
const zmyers_ = @import("zmyers_lib");

pub fn main() !void {
    var debug_allocator = std_.heap.DebugAllocator(.{}).init;
    defer {
        const gpa_status = debug_allocator.deinit();
        if (gpa_status == .leak) {
            std_.debug.print("leak found\n", .{});
        }
    }
    const allocator = debug_allocator.allocator();

    const n = try zmyers_.diff(allocator, "abc", "111");
    std_.debug.print("{d}\n", .{n});
}
