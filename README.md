# zmyers - Myers Diff Algorithm Library

`zmyers` is a basic implementation of the Myers diff algorithm written in Zig. The Myers diff algorithm is used to compute the shortest edit script (SES) between two sequences, identifying the minimal set of operations (`delete` and `insert`) needed to transform one sequence into another. This library is designed for simplicity and clarity, making it suitable for educational purposes or as a starting point for more advanced diff-based applications.

## Features
- Implements the classic Myers diff algorithm.
- Returns a sequence of operations (`delete` and `insert`) without `equal` operations, focusing only on changes.

## Limitations
- **Basic Implementation**: This is a straightforward implementation based on the original Myers diff algorithm. It does not include optimizations such as grouping operations into ranges (e.g., deleting a range of characters or inserting a slice) or linear space refinements mentioned in the original paper.

## Based On
This implementation is heavily inspired by the following articles by James Coglan, which provide a clear and detailed explanation of the Myers diff algorithm:
- [The Myers Diff Algorithm — Part 1](https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/)
- [The Myers Diff Algorithm — Part 2](https://blog.jcoglan.com/2017/02/15/the-myers-diff-algorithm-part-2/)
- [The Myers Diff Algorithm — Part 3](https://blog.jcoglan.com/2017/02/17/the-myers-diff-algorithm-part-3/)

These articles served as the primary reference for translating the algorithm from its theoretical form into a working Zig implementation.

## Installation
To use `zmyers` in your Zig project:
1. Add the library as a dependency in your `build.zig` file.
2. Import the `zmyers` module in your code.

## Usage
The library provides two main public functions:
- `diff`: Computes the differences between two input strings and returns a `Diff` object containing individual operations.
- `pack`: Groups the operations from a `Diff` object into a more compact `PackedDiff` object, combining consecutive deletions and insertions.

### Function: `diff`
Computes the differences between two input strings using the Myers diff algorithm.

#### Function Signature
```zig
pub fn diff(allocator: std_.mem.Allocator, a: []const u8, b: []const u8) std_.mem.Allocator.Error!Diff
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `a`: The source string.
  - `b`: The target string.
- **Returns**: A `Diff` object that contains a slice of `Operation` structs and an arena allocator for that slice. Each `Operation` is either:
  - `.delete`: Specifies a position in `a` to remove a character.
  - `.insert`: Specifies a position and a character from `b` to insert.
    ```zig
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

### Function: `pack`
Groups a slice of `Operation` structs into a more compact representation by combining consecutive deletions and insertions.

#### Function Signature
```zig
pub fn pack(allocator: std_.mem.Allocator, operations: []Operation) std_.mem.Allocator.Error!PackedDiff
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `operations`: A slice of `Operation` structs, typically obtained from a `Diff` object.
- **Returns**: A `PackedDiff` object that contains a slice of `PackedOperation` structs and an arena allocator for that slice. Each `PackedOperation` is either:
  - `.delete`: Specifies a starting position in `a` and the number of characters to remove.
  - `.insert`: Specifies a starting position and a slice of characters from `b` to insert.
    ```zig
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

### Example
The following example demonstrates how to use `zmyers` to compute the differences between `"abc"` and `"fff"`, and then pack the resulting operations into a more compact form:

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

    var diff = try zmyers.diff(allocator, "abc", "fff");
    defer diff.deinit();

    std.debug.print("diff:\n", .{});
    for (diff.operations) |operation| {
        switch (operation) {
            .delete => |delete| {
                std.debug.print("delete from pos {d}\n", .{delete.pos});
            },
            .insert => |insert| {
                std.debug.print("insert in pos {d} char \"{c}\"\n", .{insert.pos, insert.char});
            },
        }
    }

    std.debug.print("\npacked diff:\n", .{});
    var packed_diff = try zmyers.pack(allocator, diff.operations);
    defer packed_diff.deinit();

    for (packed_diff.operations) |packed_operation| {
        switch (packed_operation) {
            .delete => |delete| {
                std.debug.print("delete from pos {d} {d} chars\n", .{delete.start_pos, delete.len});
            },
            .insert => |insert| {
                std.debug.print("insert in pos {d} chars \"{s}\"\n", .{insert.start_pos, insert.chars});
            },
        }
    }
}
```

### Expected Output
For the input strings `"abc"` and `"fff"`, the output will be:
```
diff:
delete from pos 0
delete from pos 1
delete from pos 2
insert in pos 0 char "f"
insert in pos 1 char "f"
insert in pos 2 char "f"

packed diff:
delete from pos 0 3 chars
insert in pos 0 chars "fff"
```

### Explanation
To transform `"abc"` into `"fff"`, the `diff` function generates the following operations:
- Delete the character at position 0 (`a`).
- Delete the character at position 1 (`b`).
- Delete the character at position 2 (`c`).
- Insert `f` at position 0.
- Insert `f` at position 1.
- Insert `f` at position 2.

The `pack` function then groups these operations into a more compact form:
- Combine the three deletions into a single operation: delete 3 characters starting from position 0.
- Combine the three insertions into a single operation: insert the string `"fff"` at position 0.

This packed representation reduces the memory footprint and simplifies applying the diff in scenarios where consecutive operations can be processed together.

## Contributing
Contributions are welcome! If you have ideas for optimizations, additional features, or bug fixes, please open an issue or submit a pull request.
