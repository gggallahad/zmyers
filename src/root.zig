const std_ = @import("std");

pub fn diff(allocator: std_.mem.Allocator, a: []const u8, b: []const u8) std_.mem.Allocator.Error!Diff {
    const arena_allocator = try Diff.createArenaAllocator(allocator);
    errdefer Diff.destroyArenaAllocator(arena_allocator);

    const n = @as(isize, @intCast(a.len));
    const m = @as(isize, @intCast(b.len));
    const max: isize = n + m;

    var v = try allocator.alloc(isize, 2 * @as(usize, @intCast(max)) + 1);
    defer allocator.free(v);
    @memset(v, -1);
    v[@as(usize, @intCast(max)) + 1] = 0;

    var trace = std_.ArrayList([]isize).init(allocator);
    defer {
        for (0..trace.items.len) |i| {
            allocator.free(trace.items[i]);
        }
        trace.deinit();
    }

    var d: isize = 0;

    shortest_edit: {
        while (d <= max) : (d += 1) {
            const v_copy = try allocator.dupe(isize, v);
            try trace.append(v_copy);

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
                    break :shortest_edit;
                }
            }
        }
    }

    var x = @as(isize, @intCast(a.len));
    var y = @as(isize, @intCast(b.len));

    var operations = std_.ArrayList(Operation).init(arena_allocator.allocator());
    errdefer operations.deinit();

    while (d > 0) : (d -= 1) {
        const v_copy: []isize = trace.items[@as(usize, @intCast(d))];

        const k: isize = x - y;
        const v_index = @as(usize, @intCast(max + k));

        const prev_k: isize = prev_k: {
            if ((k == -d) or (k != d and v_copy[v_index - 1] < v_copy[v_index + 1])) {
                break :prev_k k + 1;
            } else {
                break :prev_k k - 1;
            }
        };

        const prev_x: isize = v_copy[@as(usize, @intCast(max + prev_k))];
        const prev_y: isize = prev_x - prev_k;

        while (x > prev_x and y > prev_y) {
            x -= 1;
            y -= 1;
        }

        if (y == prev_y and x > prev_x) {
            const operation_delete = Operation{
                .delete = .{
                    .pos = @as(usize, @intCast(x - 1)),
                },
            };
            try operations.append(operation_delete);

            x -= 1;
        } else if (x == prev_x and y > prev_y) {
            const operation_insert = Operation{
                .insert = .{
                    .pos = @as(usize, @intCast(y - 1)),
                    .char = b[@as(usize, @intCast(y - 1))],
                },
            };
            try operations.append(operation_insert);

            y -= 1;
        }
    }

    const operations_slice = try operations.toOwnedSlice();
    std_.mem.reverse(Operation, operations_slice);

    const result = Diff.init(arena_allocator, operations_slice);
    return result;
}

pub const Diff = struct {
    arena_allocator: *std_.heap.ArenaAllocator,
    operations: []Operation,

    fn createArenaAllocator(allocator: std_.mem.Allocator) !*std_.heap.ArenaAllocator {
        const arena_allocator = try allocator.create(std_.heap.ArenaAllocator);
        arena_allocator.* = std_.heap.ArenaAllocator.init(allocator);
        return arena_allocator;
    }

    fn destroyArenaAllocator(arena_allocator: *std_.heap.ArenaAllocator) void {
        const allocator = arena_allocator.child_allocator;
        arena_allocator.deinit();
        allocator.destroy(arena_allocator);
    }

    fn init(arena_allocator: *std_.heap.ArenaAllocator, operations: []Operation) Diff {
        return Diff{
            .arena_allocator = arena_allocator,
            .operations = operations,
        };
    }

    pub fn deinit(self: *Diff) void {
        const allocator = self.arena_allocator.child_allocator;
        self.arena_allocator.deinit();
        allocator.destroy(self.arena_allocator);
    }
};

pub const Operation = union(enum) {
    delete: Delete,
    insert: Insert,

    pub const Delete = struct {
        pos: usize,
    };

    pub const Insert = struct {
        pos: usize,
        char: u8,
    };
};
