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

    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ptr = try allocator.alloc(u64, 512);
    defer allocator.free(ptr);

    const jmax = 1024;
    const imax = 1024;

    var e = try ArrayClassic2D(allocator, f64, jmax, imax);
    defer ArrayClassic2DFree(allocator, e);
    e[0][0] = 1.0;
    e[jmax-1][imax-1] = 1.0;
    
    var f = try ArrayContiguous2D(allocator, f64, jmax, imax);
    defer ArrayContiguous2DFree(allocator, f);
    f[0][0] = 1.0;
    f[jmax-1][imax-1] = 1.0;

    try testing.expectEqual(e[0][0], f[0][0]);
    try testing.expectEqual(e[jmax-1][imax-1], f[jmax-1][imax-1]);

    var g = try ArrayContiguous2DOne(allocator, f64, jmax, imax);
    defer ArrayContiguous2DOneFree(allocator, g);

    g[0][0] = 1.0;
    g[jmax-1][imax-1] = 1.0;


    try testing.expectEqual(e[0][0], g[0][0]);
    try testing.expectEqual(e[jmax-1][imax-1], g[jmax-1][imax-1]);

}

//------------------------------------------------------------------------------

// TODO, Geert: put the functions in separate structs for convenience.

// Conventional way of allocating a 2D array.

pub fn ArrayClassic2D(allocator: Allocator, comptime T: type, jmax: usize, imax: usize) ![][]T {
    
    const array = try allocator.alloc([]T, jmax);

    for (array) |*row| {
        row.* = try allocator.alloc(T, imax);
    }

    return array;
}

pub fn ArrayClassic2DFree(allocator: Allocator, array: anytype) void {
    
    for (array) |row| {
        allocator.free(row);
    }

    allocator.free(array);
}


// Allocating a contiguous 2D array.

pub fn ArrayContiguous2D(allocator: Allocator, comptime T: type, jmax: usize, imax: usize) ![][]T {
    
    const array: [][]T = try allocator.alloc([]T, jmax);
    // Note, Geert: this is actually wrong, array[0] should not point to the full memory slice!!
    // Needs to be fixed in the future, see your ArrayContiguous2DOne implementation.
    array[0] = try allocator.alloc(T, jmax * imax);

    for (array[1..]) |*row, idx| {
        row.* = array[0][idx*imax..(idx+1) * imax];
    }
    
    return array;
}


pub fn ArrayContiguous2DFree(allocator: Allocator, array: anytype) void {
    
    allocator.free(array[0]);
    allocator.free(array);
}

// Allocating a contiguous 2D array with one allocation.

pub fn ArrayContiguous2DOne(allocator: Allocator, comptime T: type, jmax: usize, imax: usize) ![][]T {
    
    const runtime_allignment = 1;
    const number_of_bytes = jmax * @sizeOf(*f64) + jmax * imax * @sizeOf(f64);
    var array_of_bytes: []u8 = try allocator.allocBytes(runtime_allignment, number_of_bytes, 0, @returnAddress());
    var array = @ptrCast([][]T, @alignCast(@alignOf([][]T),array_of_bytes));
    
    array[0] = @ptrCast([]T, array_of_bytes[jmax * @sizeOf(*f64)..jmax * @sizeOf(*f64) + imax * @sizeOf(f64)]); 
    
    var j: usize = 1;
    while (j <  jmax) : (j+=1) {
        array[j].ptr = array[j-1].ptr + imax;
        array[j].len = imax;
    }

    return array;
}

pub fn ArrayContiguous2DOneFree(allocator: Allocator, array: anytype) void {
    
    allocator.free(@ptrCast([]u8,array));
}
