const std = @import("std");

pub fn diff(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !usize {
    const n = @as(isize, @intCast(a.len));
    const m = @as(isize, @intCast(b.len));
    const max: isize = n + m;

    var v = try allocator.alloc(isize, 2 * @as(usize, @intCast(max)) + 1);
    defer allocator.free(v);
    @memset(v, -1);

    v[@as(usize, @intCast(max)) + 1] = 0;

    var d: isize = 0;
    while (d <= max) : (d += 1) {
        var k: isize = -d;
        while (k <= d) : (k += 2) {
            const v_index = @as(usize, @intCast(max + k));
            var x: isize = x: {
                if ((k == -d) or (k != d and v[v_index - 1] < v[v_index + 1])) {
                    break :x v[v_index + 1];
                } else {
                    break :x v[v_index - 1] + 1;
                }
            };

            var y: isize = x - k;

            while (x < n and y < m and a[@as(usize, @intCast(x))] == b[@as(usize, @intCast(y))]) {
                x += 1;
                y += 1;
            }

            v[v_index] = x;

            if (x >= n and y >= m) {
                return @as(usize, @intCast(d));
            }
        }
    }

    return DiffError.Unreachable;
}

const DiffError = error{
    Unreachable,
};
