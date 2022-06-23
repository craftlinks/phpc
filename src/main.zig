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

    
}

//------------------------------------------------------------------------------

// Conventional way of allocating a 2D array.

pub fn ArrayClassic2D(comptime T: type) type {

    return struct {
        array: [][]T,
        const Self = @This();

        fn new(allocator: Allocator , jmax: usize, imax: usize) !Self {
            
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

            return Self {
                .array =  array,
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
                row.* = data[idx*imax..(idx+1)*imax];
            }

            for (array) |*row| {
                for (row.*) |*cell| {
                    cell.* = 0.0;
                }
            }
            
            return Self {
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


// Allocating a contiguous 2D array with one allocation.

pub fn ArrayContiguous2DOne(comptime T: type) type {
    return struct {
        array: [][]T,
        const Self = @This();

        fn new(allocator: Allocator, jmax: usize, imax: usize) !Self {

            const runtime_allignment = 1;
            const number_of_bytes = jmax * @sizeOf(*f64) + jmax * imax * @sizeOf(f64);
            var array_of_bytes: []u8 = try allocator.allocBytes(runtime_allignment, number_of_bytes, 0, @returnAddress());
            var array = @ptrCast([][]T, @alignCast(@alignOf([][]T),array_of_bytes));
            
            //TODO, Geert: there's an error in the implementation to fix!
            array[0] = @ptrCast([]T, array_of_bytes[jmax * @sizeOf(*f64)..jmax * @sizeOf(*f64) + imax * @sizeOf(f64)]);
            array[0].len = imax; 
            std.debug.print("{s}\n", .{@TypeOf(array[0])});
            var j: usize = 1;
            while (j <  jmax) : (j+=1) {
                array[j].ptr = array[j-1].ptr + imax;
                array[j].len = imax;
            }

            for (array) |*row, row_idx| {
                for (row.*) |*cell, col_idx| {
                    std.debug.print("init [{}][{}]\n", .{row_idx, col_idx});
                    cell.* = 0.0;
                }
            } 

            return Self {
                .array = array,
            };
        }

        fn free(self: Self, allocator: Allocator) void {
            allocator.free(@ptrCast([]u8,self.array));
        }
    };
}

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
    e.array[jmax-1][imax-1] = 1.0;
    
    var f = try ArrayContiguous2D(f64).new(allocator, jmax, imax);
    defer f.free(allocator);
    f.array[0][0] = 1.0;
    f.array[jmax-1][imax-1] = 1.0;

    try expectEqual(@TypeOf(e.array), e.array, f.array);

    var g = try ArrayContiguous2DOne(f64).new(allocator, jmax, imax);
    defer g.free(allocator);

    g.array[0][0] = 1.0;
    g.array[jmax-1][imax-1] = 1.0;

    try expectEqual(@TypeOf(f.array), f.array, g.array);
}

// Test function for the 2D arrays.

fn expectEqual(comptime T: type, expected: T, actual: T) !void {
    for (expected) |row, row_index| {
        for (row) |cell, column_index| {
            if(!std.meta.eql(cell, actual[row_index][column_index])) {
                std.debug.print("index [{}][{}] incorrect. expected {any}, found {any}\n", .{ row_index, column_index, cell, actual[row_index][column_index] });
                return error.TestExpectedEqual;
            }
        }
    }
}


// /// This function is intended to be used only in tests. When the two slices are not
// /// equal, prints diagnostics to stderr to show exactly how they are not equal,
// /// then returns a test failure error.
// /// If your inputs are UTF-8 encoded strings, consider calling `expectEqualStrings` instead.
// pub fn expectEqualSlices(comptime T: type, expected: []const T, actual: []const T) !void {
//     // TODO better printing of the difference
//     // If the arrays are small enough we could print the whole thing
//     // If the child type is u8 and no weird bytes, we could print it as strings
//     // Even for the length difference, it would be useful to see the values of the slices probably.
//     if (expected.len != actual.len) {
//         std.debug.print("slice lengths differ. expected {d}, found {d}\n", .{ expected.len, actual.len });
//         return error.TestExpectedEqual;
//     }
//     var i: usize = 0;
//     while (i < expected.len) : (i += 1) {
//         if (!std.meta.eql(expected[i], actual[i])) {
//             std.debug.print("index {} incorrect. expected {any}, found {any}\n", .{ i, expected[i], actual[i] });
//             return error.TestExpectedEqual;
//         }
//     }
// }