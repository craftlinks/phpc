const std = @import("std");
const mem = @import("std").mem;
const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const testing = std.testing;
const Instant = std.time.Instant;

//
// Multidimensional array implementations from naive to using a flat array.
// Author: Craft Links (Geert Depuydt)
// 2022-06-23
//

// ===========================================================================
// Run tests with: `zig build test`

test "tests" {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ptr = try allocator.alloc(u64, 512);
    defer allocator.free(ptr);

    const jmax = 10;
    const imax = 10;

    var e = try ArrayClassic2D(f64).new(allocator, jmax, imax);
    defer e.free(allocator);
    e.array[0][0] = 1.0;
    e.array[jmax - 1][imax - 1] = 1.0;

    var f = try ArrayContiguous2D(f64).new(allocator, jmax, imax);
    defer f.free(allocator);
    f.array[0][0] = 1.0;
    f.array[jmax - 1][imax - 1] = 1.0;

    try expectEqual(@TypeOf(e.array), e.array, f.array);

    var g = try ArrayContiguous2DOne(f64).new(allocator, jmax, imax);
    defer g.free(allocator);

    g.array[0][0] = 1.0;
    g.array[jmax - 1][imax - 1] = 1.0;

    try expectEqual(@TypeOf(f.array), f.array, g.array);
}

// Test function for the 2D arrays.

fn expectEqual(comptime T: type, expected: T, actual: T) !void {
    for (expected) |row, row_index| {
        for (row) |cell, column_index| {
            if (!std.meta.eql(cell, actual[row_index][column_index])) {
                std.debug.print("index [{}][{}] incorrect. expected {any}, found {any}\n", .{ row_index, column_index, cell, actual[row_index][column_index] });
                return error.TestExpectedEqual;
            }
        }
    }
}

// ===========================================================================
// Conventional way of allocating a 2D array.

pub fn ArrayClassic2D(comptime T: type) type {
    return struct {
        array: [][]T,
        const Self = @This();

        fn new(allocator: Allocator, jmax: usize, imax: usize) !Self {

            // allocate memory for row pointers
            const array = try allocator.alloc([]T, jmax);

            // allocate memory for the actual row data
            for (array) |*row| {
                row.* = try allocator.alloc(T, imax);
            }

            for (array) |*row| {
                for (row.*) |*cell| {
                    cell.* = 0.0;
                }
            }

            return Self{
                .array = array,
            };
        }

        fn free(self: Self, allocator: Allocator) void {
            for (self.array) |row| {
                allocator.free(row);
            }

            allocator.free(self.array);
        }
    };
}

// ===========================================================================
// Allocating a contiguous 2D array.

pub fn ArrayContiguous2D(comptime T: type) type {
    return struct {
        array: [][]T,
        data: []T,
        const Self = @This();

        fn new(allocator: Allocator, jmax: usize, imax: usize) !Self {

            // allocate memory for row pointers
            const array: [][]T = try allocator.alloc([]T, jmax);

            // allocate memory for row data
            var data = try allocator.alloc(T, jmax * imax);

            // fill in the row pointers
            for (array[0..]) |*row, idx| {
                row.* = data[idx * imax .. (idx + 1) * imax];
            }

            for (array) |*row| {
                for (row.*) |*cell| {
                    cell.* = 0.0;
                }
            }

            return Self{
                .array = array,
                .data = data,
            };
        }

        fn free(self: Self, allocator: Allocator) void {
            allocator.free(self.data);
            allocator.free(self.array);
        }
    };
}

// ===========================================================================
// Allocating a contiguous 2D array with one allocation.

pub fn ArrayContiguous2DOne(comptime T: type) type {
    return struct {
        array: [][]T,
        const Self = @This();

        fn new(allocator: Allocator, jmax: usize, imax: usize) !Self {
            const runtime_allignment = 2;
            const number_of_bytes = jmax * @sizeOf([]f64) + jmax * imax * @sizeOf(f64);
            std.debug.print("alloc bytes: {}\n", .{number_of_bytes});
            var array_of_bytes: []u8 = try allocator.allocBytes(runtime_allignment, number_of_bytes, 0, @returnAddress());
            var array = @ptrCast([][]T, @alignCast(@alignOf([][]T), array_of_bytes));
            array.len = jmax;

            array[0] = @ptrCast([]T, array_of_bytes[jmax * @sizeOf([]f64) .. jmax * @sizeOf([]f64) + imax * @sizeOf(f64)]);
            array[0].len = imax;
            var j: usize = 1;
            while (j < jmax) : (j += 1) {
                array[j].ptr = array[j - 1].ptr + imax;
                array[j].len = imax;
            }

            for (array) |*row| {
                for (row.*) |*cell| {
                    cell.* = 0.0;
                }
            }

            return Self{
                .array = array,
            };
        }

        fn free(self: Self, allocator: Allocator) void {
            allocator.free(@ptrCast([]u8, self.array));
        }
    };
}


// !! Not recommended because allocated on the stack -> stack overflows 
pub fn ZigMulti(comptime T: type) type {
    const IMAX = 52;
    const JMAX = 52;
    
    return struct {
        array: [JMAX][IMAX]T,
        const Self = @This();
        
        fn new() Self {
            const zero_row = [_]T{0.0}**IMAX;
            return Self{
                .array = [_][IMAX]T{zero_row}**JMAX,
            };
        }
    };
} 


pub fn bench(comptime T: type) !void {
    // array dimensions
    const IMAX = 2002;
    const JMAX = 2002;

    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // zero intialize 2D arrays
    var x = try T.new(allocator, JMAX, IMAX);
    defer x.free(allocator);
    var xnew = try T.new(allocator, JMAX, IMAX);
    defer xnew.free(allocator);
    var flush = try ArrayList(f64).initCapacity(allocator, JMAX * IMAX * 10);
    defer flush.deinit();


     // set center block of memory to a larger value
    for (x.array[JMAX/2-5..JMAX/2+5]) |*array| {
        for (array.*[IMAX/2 - 5..IMAX/2+5]) |*el| {
            el.* = 400.0;
        }
    }

    // ITERATION
    var it: usize = 0;
    const start = try Instant.now();
    while (it <= 10000) : (it += 1) {
        
        // Flushing the cache
        for (flush.items) |*el| {
            el.* = 1.0;
        }

        var j: usize = 1;
        while (j < JMAX-1) : (j += 1) {
            var i: usize = 1;
            while (i < IMAX-1) : (i += 1) {
                // Calculation kernel
                xnew.array[j][i] = ( x.array[j][i] + x.array[j][i-1] + x.array[j][i+1] + x.array[j-1][i] + x.array[j+1][i]) / 5.0;
            }
        }

        var xtmp = x.array;
        x.array = xnew.array;
        xnew.array = xtmp;

        if (it % 1000 == 0) {
            std.debug.print("Iter {}\n", .{it});
        }
    }
    const end = try Instant.now();
    const elapsed = end.since(start) / 1000_000_000;
    std.debug.print("Elapsed (s) {}", .{elapsed});

}

// ===========================================================================
// Run with: `zig build run`

pub fn main() anyerror!void {
    const a = [2][2]f32{
        [_]f32{ 1.0, 0.0 },
        [_]f32{ 0.0, 1.0 },
    };

    const b = [2][2]f32{
        [_]f32{ 1.0, 0.0 },
        [_]f32{ 0.0, 1.0 },
    };

    try testing.expectEqual(a, b);

    var c = init: {
        var _initial: [2][2]f32 = undefined;
        for (_initial) |*row, row_index| {
            for (row.*) |*cell, column_index| {
                if (row_index == column_index) {
                    cell.* = 1.0;
                } else {
                    cell.* = 0.0;
                }
            }
        }
        break :init _initial;
    };

    var d: [2][2]f32 = undefined;
    for (d) |*row, row_index| {
        for (row.*) |*cell, column_index| {
            if (row_index == column_index) {
                cell.* = 1.0;
            } else {
                cell.* = 0.0;
            }
        }
    }

    try testing.expectEqual(c, d);

    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ptr = try allocator.alloc(u64, 512);
    defer allocator.free(ptr);

    const jmax = 2002;
    const imax = 2002;

    var e = try ArrayClassic2D(f64).new(allocator, jmax, imax);
    defer e.free(allocator);
    e.array[0][0] = 1.0;
    e.array[jmax - 1][imax - 1] = 1.0;

    var f = try ArrayContiguous2D(f64).new(allocator, jmax, imax);
    defer f.free(allocator);
    f.array[0][0] = 1.0;
    f.array[jmax - 1][imax - 1] = 1.0;

    try expectEqual(@TypeOf(e.array), e.array, f.array);

    var g = try ArrayContiguous2DOne(f64).new(allocator, jmax, imax);
    defer g.free(allocator);

    g.array[0][0] = 1.0;
    g.array[jmax - 1][imax - 1] = 1.0;

    try expectEqual(@TypeOf(f.array), f.array, g.array);

    // =========================================================================
    // Benchmarks
    // zig build run -Drelease-fast=true

    std.debug.print("\nArrayClassic2D\n", .{});
    const classic = ArrayClassic2D(f64);
    try bench(classic);


    std.debug.print("\nArrayContiguous2D\n", .{});
    const ac2d = ArrayContiguous2D(f64);
    try bench(ac2d);

    std.debug.print("\nArrayContiguous2DOne\n", .{});
    const ac2d_one = ArrayContiguous2DOne(f64);
    try bench(ac2d_one);

    // TODO, Geert: Benchmark the Zig ArrayList
    // ArrayList(comptime T: type), so: 
    const zig2d = ArrayList(ArrayList(f64));
    var x = try zig2d.initCapacity(allocator, jmax);
    // memory freeing situation unclear atm... tip: see toOwnedSlice
    defer x.deinit();
    var xnew = try zig2d.initCapacity(allocator, jmax);
    defer xnew.deinit();

    try zeroInit(x, imax, allocator);
    try zeroInit(xnew, imax, allocator);


    // set center block of memory to a larger value
    // for (x.items[jmax/2-5..jmax/2+5]) |*array| {
    //     for (array.*.items[imax/2 - 5..imax/2+5]) |*el| {
    //         el.* = 400.0;
    //     }
    // }

}

// END ========================================================================        

pub fn zeroInit(x: anytype, imax: usize, allocator: Allocator) !void {
    for (x.items) |*array| {
        const array1d = ArrayList(f64);
        const _array = try array1d.initCapacity(allocator, imax);
        for (_array.items) |*item| {
            item.* = 0.0;
        }
        array.* = _array;
    }
}