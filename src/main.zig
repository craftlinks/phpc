const std = @import("std");
const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const testing = std.testing;

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

    // TODO, Geert: implement multidimensional array.
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ptr = try allocator.alloc(u64, 512);
    defer allocator.free(ptr);

    
    
    const jmax = 2;
    const imax = 2;

    var e = try ArrayClassic2D(allocator, f64, jmax, imax);
    defer ArrayClassic2DFree(allocator, e, jmax);
    e[0][0] = 1.0;
    e[jmax-1][imax-1] = 1.0;
    
    var f = try ArrayContiguous2D(allocator, f64, jmax, imax);
    defer ArrayContiguous2DFree(allocator, f);
    f[0][0] = 1.0;
    f[jmax-1][imax-1] = 1.0;

    try testing.expectEqual(e[0][0], f[0][0]);

}

// TODO, Geert: can these functions be put in structures?


// Conventional way of allocating a 2D array.

pub fn ArrayClassic2D(allocator: Allocator, comptime T: type, jmax: usize, imax: usize) ![][]T {
    
    const array = try allocator.alloc([]T, jmax);

    // TODO, Geert: you can just (for) loop over the slice instead of jmax.
    var j: usize = 0;
    while (j < jmax) : (j+=1) {
        array[j] = try allocator.alloc(T, imax);
    }

    return array;

}
// TODO, Geert: you don't need the jmax, because this is a slice.
pub fn ArrayClassic2DFree(allocator: Allocator, array: anytype, jmax: usize) void {
    var j: usize = 0;
    while (j < jmax) : (j+=1) {
        allocator.free(array[j]);
    }
    allocator.free(array);
}


// Allocating a contiguous 2D array.

pub fn ArrayContiguous2D(allocator: Allocator, comptime T: type, jmax: usize, imax: usize) ![][]T {
    
    const array: [][]T = try allocator.alloc([]T, jmax);

    array[0] = try allocator.alloc(T, jmax * imax);

    var j: usize = 1;
    while (j < jmax) : (j+=1) {
        array[j] = array[0][(j-1)..(j-1 + imax)];
    }
    
    return array;

}

pub fn ArrayContiguous2DFree(allocator: Allocator, array: anytype) void {
    
    allocator.free(array[0]);
    allocator.free(array);
}

// Allocating a single contiguous 2D array.
// TODO, Geert: implement multidimensional array.

test "expectEqual nested array" {}
