# zmyers - Myers Diff Algorithm Library

`zmyers` is a basic implementation of the Myers diff algorithm written in Zig. The Myers diff algorithm is used to compute the shortest edit script (SES) between two sequences, identifying the minimal set of operations (`delete` and `insert`) needed to transform one sequence into another. This library is designed for simplicity and clarity, making it suitable for educational purposes or as a starting point for more advanced diff-based applications.

## Based On
This implementation is heavily inspired by the following articles by James Coglan, which provide a clear and detailed explanation of the Myers diff algorithm:
- [The Myers Diff Algorithm — Part 1](https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/)
- [The Myers Diff Algorithm — Part 2](https://blog.jcoglan.com/2017/02/15/the-myers-diff-algorithm-part-2/)
- [The Myers Diff Algorithm — Part 3](https://blog.jcoglan.com/2017/02/17/the-myers-diff-algorithm-part-3/)

These articles served as the primary reference for translating the algorithm from its theoretical form into a working Zig implementation.

## Features
- Implements the classic Myers diff algorithm for computing the minimal set of operations to transform one string into another. Returns a sequence of operations (`delete` and `insert`) without `equal` operations, focusing only on changes.
- Supports applying computed differences to transform the source string into the target string.
- Provides grouping of operations into a compact `PackedDiff` format, combining consecutive deletions and insertions for efficiency.

## Limitations
- **Basic Implementation**: This is a straightforward implementation based on the original Myers diff algorithm. It does not include optimizations such linear space refinements mentioned in the original paper.

## Usage
The library provides six main public functions:
- `diff`: Computes the differences between two input strings and returns a `Diff` object containing individual operations.
- `apply`: Applies a sequence of `Operation` structs to a source string, producing the transformed string.
- `packedDiff`: Computes the differences between two input strings and returns a `PackedDiff` object containing grouped operations.
- `packedApply`: Applies a sequence of `PackedOperation` structs to a source string, producing the transformed string.
- `pack`: Groups a sequence of `Operation` structs into a more compact `PackedDiff` object.
- `unpack`: Converts a sequence of `PackedOperation` structs back into a `Diff` object with individual operations.

### Function: `diff`

#### Function Signature
```zig
pub fn diff(allocator: std_.mem.Allocator, a: []const u8, b: []const u8) std_.mem.Allocator.Error!Diff
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `a`: The source string.
  - `b`: The target string.
- **Returns**: A `Diff` object containing an arena allocator and a slice of `Operation` structs. Each `Operation` is either:
  - `.delete`: Specifies a position in `a` to remove a character.
  - `.insert`: Specifies a position and a character from `b` to insert.
    ```zig
    pub const Diff = struct {
        arena_allocator: *std_.heap.ArenaAllocator,
        operations: []Operation,

        pub fn deinit(self: *Diff) void {
            ...
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
    ```
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Function: `apply`

#### Function Signature
```zig
pub fn apply(allocator: std_.mem.Allocator, a: []const u8, operations: []Operation) std_.mem.Allocator.Error![]const u8
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `a`: The source string.
  - `operations`: A slice of `Operation` structs, typically obtained from a `Diff` object.
- **Returns**: The transformed string after applying all operations.
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Function: `packedDiff`

#### Function Signature
```zig
pub fn packedDiff(allocator: std_.mem.Allocator, a: []const u8, b: []const u8) std_.mem.Allocator.Error!PackedDiff
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `a`: The source string.
  - `b`: The target string.
- **Returns**: A `PackedDiff` object containing an arena allocator and a slice of `PackedOperation` structs. Each `PackedOperation` is either:
  - `.delete`: Specifies a starting position in `a` and the number of characters to remove.
  - `.insert`: Specifies a starting position and a slice of characters from `b` to insert.
    ```zig
    pub const PackedDiff = struct {
        arena_allocator: *std_.heap.ArenaAllocator,
        operations: []PackedOperation,
        
        pub fn deinit(self: *PackedDiff) void {
            ...
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
    ```
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Function: `packedApply`

#### Function Signature
```zig
pub fn packedApply(allocator: std_.mem.Allocator, a: []const u8, operations: []PackedOperation) std_.mem.Allocator.Error![]const u8
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `a`: The source string.
  - `operations`: A slice of `PackedOperation` structs, typically obtained from a `PackedDiff` object.
- **Returns**: The transformed string after applying all packed operations.
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Function: `pack`

#### Function Signature
```zig
pub fn pack(allocator: std_.mem.Allocator, operations: []Operation) std_.mem.Allocator.Error!PackedDiff
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `operations`: A slice of `Operation` structs, typically obtained from a `Diff` object.
- **Returns**: A `PackedDiff` object containing an arena allocator and a slice of `PackedOperation` structs, as described in `packedDiff`.
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Function: `unpack`

#### Function Signature
```zig
pub fn unpack(allocator: std_.mem.Allocator, packed_operations: []PackedOperation) std_.mem.Allocator.Error!Diff
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `packed_operations`: A slice of `PackedOperation` structs, typically obtained from a `PackedDiff` object.
- **Returns**: A `Diff` object containing an arena allocator and a slice of `Operation` structs, as described in `diff`.
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Example
The following example demonstrates how to use `zmyers` to compute the differences between `"abcde"` and `"ffaffcffeff"`:

```zig
const std = @import("std");
const zmyers = @import("zmyers");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer {
        const gpa_status = debug_allocator.deinit();
        if (gpa_status == .leak) {
            std.debug.print("leak found\n", .{});
        }
    }
    const allocator = debug_allocator.allocator();

    const a = "abcde";
    std.debug.print("a: {s}\n", .{a});
    const b = "ffaffcffeff";
    std.debug.print("b: {s}\n", .{b});

    var diff = try zmyers.diff(allocator, a, b);
    defer diff.deinit();
    std.debug.print("\ndiff:\n", .{});
    for (diff.operations) |operation| {
        switch (operation) {
            .delete => |delete| {
                std.debug.print("delete from pos {d}\n", .{delete.pos});
            },
            .insert => |insert| {
                std.debug.print("insert in pos {d} char \"{c}\"\n", .{ insert.pos, insert.char });
            },
        }
    }

    var packed_diff = try zmyers.packedDiff(allocator, a, b);
    defer packed_diff.deinit();
    std.debug.print("\npacked diff:\n", .{});
    for (packed_diff.operations) |packed_operation| {
        switch (packed_operation) {
            .delete => |delete| {
                std.debug.print("delete from pos {d} {d} chars\n", .{ delete.start_pos, delete.len });
            },
            .insert => |insert| {
                std.debug.print("insert in pos {d} chars \"{s}\"\n", .{ insert.start_pos, insert.chars });
            },
        }
    }

    const apply = try zmyers.apply(allocator, a, diff.operations);
    defer allocator.free(apply);
    std.debug.print("\napply:\n", .{});
    std.debug.print("{s}\n", .{apply});

    const packed_apply = try zmyers.packedApply(allocator, a, packed_diff.operations);
    defer allocator.free(packed_apply);
    std.debug.print("\npacked_apply:\n", .{});
    std.debug.print("{s}\n", .{packed_apply});

    var pack = try zmyers.pack(allocator, diff.operations);
    defer pack.deinit();
    std.debug.print("\npack:\n", .{});
    for (pack.operations) |pack_operation| {
        switch (pack_operation) {
            .delete => |delete| {
                std.debug.print("delete from pos {d} {d} chars\n", .{ delete.start_pos, delete.len });
            },
            .insert => |insert| {
                std.debug.print("insert in pos {d} chars \"{s}\"\n", .{ insert.start_pos, insert.chars });
            },
        }
    }

    var unpack = try zmyers.unpack(allocator, packed_diff.operations);
    defer unpack.deinit();
    std.debug.print("\nunpack:\n", .{});
    for (unpack.operations) |operation| {
        switch (operation) {
            .delete => |delete| {
                std.debug.print("delete from pos {d}\n", .{delete.pos});
            },
            .insert => |insert| {
                std.debug.print("insert in pos {d} char \"{c}\"\n", .{ insert.pos, insert.char });
            },
        }
    }
}
```

## Contributing
Contributions are welcome! If you have ideas for optimizations, additional features, or bug fixes, please open an issue or submit a pull request.
