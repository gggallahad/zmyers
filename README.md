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
The library provides a single public function, `diff`, which computes the differences between two input strings and returns a slice of `Operation` structs.

### Function Signature
```zig
pub fn diff(allocator: std_.mem.Allocator, a: []const u8, b: []const u8) std_.mem.Allocator.Error![]Operation {
```

- **Parameters**:
  - `allocator`: A Zig allocator for managing memory.
  - `a`: The source string.
  - `b`: The target string.
- **Returns**: A slice of `Operation` structs, where each `Operation` is either:
  - `.delete`: Specifies a position in `a` to remove a character.
  - `.insert`: Specifies a position and a character from `b` to insert.
- **Errors**: Returns an allocation error if memory cannot be allocated.

### Example
The following example demonstrates how to use `zmyers` to compute the differences between `"abc"` and `"fff"`:

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

    const operations = try zmyers.diff(allocator, "abc", "fff");
    defer allocator.free(operations);
    for (0..operations.len) |i| {
        switch (operations[i]) {
            .delete => {
                std.debug.print("delete pos: {d}\n", .{operations[i].delete.pos});
            },
            .insert => {
                std.debug.print("insert pos: {d}, insert_char: {c}\n", .{ operations[i].insert.pos, operations[i].insert.char });
            },
        }
    }
}
```

### Expected Output
For the input strings `"abc"` and `"fff"`, the output will be:
```
delete pos: 0
delete pos: 1
delete pos: 2
insert pos: 0, insert_char: f
insert pos: 1, insert_char: f
insert pos: 2, insert_char: f
```

This indicates that to transform `"abc"` into `"fff"`, you need to:
- Delete the character at position 0 (`a`).
- Delete the character at position 1 (`b`).
- Delete the character at position 2 (`c`).
- Insert `f` at position 0.
- Insert `f` at position 1.
- Insert `f` at position 2.

## Contributing
Contributions are welcome! If you have ideas for optimizations, additional features, or bug fixes, please open an issue or submit a pull request.
