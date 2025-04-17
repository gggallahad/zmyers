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
        for (trace.items) |item| {
            allocator.free(item);
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

pub fn apply(allocator: std_.mem.Allocator, a: []const u8, operations: []Operation) std_.mem.Allocator.Error![]const u8 {
    var b = try std_.ArrayList(u8).initCapacity(allocator, a.len);
    errdefer b.deinit();

    try b.appendSlice(a);

    var delete_pos_offset: isize = 0;

    for (operations) |operation| {
        switch (operation) {
            .delete => |delete| {
                const pos = @as(usize, @intCast(@as(isize, @intCast(delete.pos)) + delete_pos_offset));
                _ = b.orderedRemove(pos);
                delete_pos_offset -= 1;
            },
            .insert => |insert| {
                try b.insert(insert.pos, insert.char);
                delete_pos_offset += 1;
            },
        }
    }

    const result = try b.toOwnedSlice();
    return result;
}

pub fn packedDiff(allocator: std_.mem.Allocator, a: []const u8, b: []const u8) std_.mem.Allocator.Error!PackedDiff {
    var diff_result = try diff(allocator, a, b);
    defer diff_result.deinit();

    const result = try pack(allocator, diff_result.operations);
    return result;
}

pub fn packedApply(allocator: std_.mem.Allocator, a: []const u8, operations: []PackedOperation) std_.mem.Allocator.Error![]const u8 {
    var b = try std_.ArrayList(u8).initCapacity(allocator, a.len);
    errdefer b.deinit();

    try b.appendSlice(a);

    var delete_pos_offset: isize = 0;

    for (operations) |operation| {
        switch (operation) {
            .delete => |delete| {
                for (0..delete.len) |_| {
                    const pos = @as(usize, @intCast(@as(isize, @intCast(delete.start_pos)) + delete_pos_offset));
                    _ = b.orderedRemove(pos);
                    delete_pos_offset -= 1;
                }
            },
            .insert => |insert| {
                try b.insertSlice(insert.start_pos, insert.chars);
                delete_pos_offset += @as(isize, @intCast(insert.chars.len));
            },
        }
    }

    const result = try b.toOwnedSlice();
    return result;
}

pub fn pack(allocator: std_.mem.Allocator, operations: []Operation) std_.mem.Allocator.Error!PackedDiff {
    const arena_allocator = try PackedDiff.createArenaAllocator(allocator);
    errdefer PackedDiff.destroyArenaAllocator(arena_allocator);

    var packed_operations = std_.ArrayList(PackedOperation).init(arena_allocator.allocator());
    errdefer packed_operations.deinit();

    var insert_start_pos: usize = 0;
    var insert_chars = std_.ArrayList(u8).init(arena_allocator.allocator());
    defer insert_chars.deinit();

    var delete_start_pos: usize = 0;
    var delete_len: usize = 0;

    var prev_operation_delete: bool = true;

    for (operations, 0..) |operation, i| {
        switch (operation) {
            .delete => |delete| {
                if (i == 0) {
                    delete_start_pos = delete.pos;
                    delete_len = 1;
                    prev_operation_delete = true;
                } else if (prev_operation_delete and delete.pos == delete_start_pos + delete_len) {
                    delete_len += 1;
                } else {
                    if (prev_operation_delete and delete_len > 0) {
                        const packed_operation_delete = PackedOperation{
                            .delete = .{
                                .start_pos = delete_start_pos,
                                .len = delete_len,
                            },
                        };
                        try packed_operations.append(packed_operation_delete);
                    } else if (!prev_operation_delete and insert_chars.items.len > 0) {
                        const chars_slice = try insert_chars.toOwnedSlice();
                        const packed_operation_insert = PackedOperation{
                            .insert = .{
                                .start_pos = insert_start_pos,
                                .chars = chars_slice,
                            },
                        };
                        try packed_operations.append(packed_operation_insert);
                    }
                    delete_start_pos = delete.pos;
                    delete_len = 1;
                    prev_operation_delete = true;
                }
            },
            .insert => |insert| {
                if (i == 0) {
                    insert_start_pos = insert.pos;
                    try insert_chars.append(insert.char);
                    prev_operation_delete = false;
                } else if (!prev_operation_delete and insert.pos == insert_start_pos + insert_chars.items.len) {
                    try insert_chars.append(insert.char);
                } else {
                    if (prev_operation_delete and delete_len > 0) {
                        const packed_operation_delete = PackedOperation{
                            .delete = .{
                                .start_pos = delete_start_pos,
                                .len = delete_len,
                            },
                        };
                        try packed_operations.append(packed_operation_delete);
                    } else if (!prev_operation_delete and insert_chars.items.len > 0) {
                        const chars_slice = try insert_chars.toOwnedSlice();
                        const packed_operation_insert = PackedOperation{
                            .insert = .{
                                .start_pos = insert_start_pos,
                                .chars = chars_slice,
                            },
                        };
                        try packed_operations.append(packed_operation_insert);
                    }
                    insert_start_pos = insert.pos;
                    insert_chars.clearRetainingCapacity();
                    try insert_chars.append(insert.char);
                    prev_operation_delete = false;
                }
            },
        }
    }

    if (prev_operation_delete and delete_len > 0) {
        const packed_operation_delete = PackedOperation{
            .delete = .{
                .start_pos = delete_start_pos,
                .len = delete_len,
            },
        };
        try packed_operations.append(packed_operation_delete);
    } else if (!prev_operation_delete and insert_chars.items.len > 0) {
        const chars_slice = try insert_chars.toOwnedSlice();
        const packed_operation_insert = PackedOperation{
            .insert = .{
                .start_pos = insert_start_pos,
                .chars = chars_slice,
            },
        };
        try packed_operations.append(packed_operation_insert);
    }

    const packed_operations_slice = try packed_operations.toOwnedSlice();

    const result = PackedDiff.init(arena_allocator, packed_operations_slice);
    return result;
}

pub const Diff = struct {
    arena_allocator: *std_.heap.ArenaAllocator,
    operations: []Operation,

    fn createArenaAllocator(allocator: std_.mem.Allocator) std_.mem.Allocator.Error!*std_.heap.ArenaAllocator {
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

pub const PackedDiff = struct {
    arena_allocator: *std_.heap.ArenaAllocator,
    operations: []PackedOperation,

    fn createArenaAllocator(allocator: std_.mem.Allocator) std_.mem.Allocator.Error!*std_.heap.ArenaAllocator {
        const arena_allocator = try allocator.create(std_.heap.ArenaAllocator);
        arena_allocator.* = std_.heap.ArenaAllocator.init(allocator);
        return arena_allocator;
    }

    fn destroyArenaAllocator(arena_allocator: *std_.heap.ArenaAllocator) void {
        const allocator = arena_allocator.child_allocator;
        arena_allocator.deinit();
        allocator.destroy(arena_allocator);
    }

    fn init(arena_allocator: *std_.heap.ArenaAllocator, operations: []PackedOperation) PackedDiff {
        return PackedDiff{
            .arena_allocator = arena_allocator,
            .operations = operations,
        };
    }

    pub fn deinit(self: *PackedDiff) void {
        const allocator = self.arena_allocator.child_allocator;
        self.arena_allocator.deinit();
        allocator.destroy(self.arena_allocator);
    }
};

pub const PackedOperation = union(enum) {
    delete: Delete,
    insert: Insert,

    pub const Delete = struct {
        start_pos: usize,
        len: usize,
    };

    pub const Insert = struct {
        start_pos: usize,
        chars: []const u8,
    };
};
