const std = @import("std");
const expect = std.testing.expect;

const Number = usize;

const max_size = std.math.maxInt(usize);

fn solve(_: std.mem.Allocator, input_str: []const u8) !Number {
    const mas = "MAS";

    // Build index
    var row_iter = std.mem.tokenizeScalar(u8, input_str, '\n');
    const cols = row_iter.next().?.len;
    var rows: usize = 1;
    while (row_iter.next() != null) {
        rows += 1;
    }
    const rstride = cols + 1; // to ignore the newline characters
    const cstride = 1;
    const index = Index2D{ .rows = rows, .cols = cols, .rstride = rstride, .cstride = cstride, .offset = 0 };
    debugPrintLn("{any}", .{index});

    var sum: Number = 0;
    var patches = Patches.init(index);
    while (patches.next()) |patch| {
        // Check diagonal (down-right)
        // Check forward
        var diagforwardMatch = true;
        for (0..mas.len) |k| {
            if (input_str[patch.linearIndex(k, k).?] != mas[k]) {
                diagforwardMatch = false;
                break;
            }
        }
        // Check backward
        var diagbackwardMatch = true;
        for (0..mas.len) |k| {
            if (input_str[patch.linearIndex(k, k).?] != mas[mas.len - k - 1]) {
                diagbackwardMatch = false;
                break;
            }
        }
        // Check counter-diagonal (down-left)
        // Check forward
        var counterforwardMatch = true;
        for (0..mas.len) |k| {
            if (input_str[patch.linearIndex(mas.len - 1 - k, k).?] != mas[k]) {
                counterforwardMatch = false;
                break;
            }
        }
        // Check backward
        var counterbackwardMatch = true;
        for (0..mas.len) |k| {
            if (input_str[patch.linearIndex(mas.len - 1 - k, k).?] != mas[mas.len - k - 1]) {
                counterbackwardMatch = false;
                break;
            }
        }
        const diagMatch = diagforwardMatch or diagbackwardMatch;
        const counterMatch = counterforwardMatch or counterbackwardMatch;
        if (diagMatch and counterMatch) {
            sum += 1;
            debugPrintLn("Match (offset={d})", .{patch.offset});
        }
    }
    return sum;
}

const Index2D = struct {
    rows: usize,
    cols: usize,
    rstride: usize,
    cstride: usize,
    offset: usize,

    fn linearIndex(self: *const Index2D, i: usize, j: usize) ?usize {
        if (i >= self.rows or j >= self.cols)
            return null;
        return i * self.rstride + j * self.cstride + self.offset;
    }

    fn initRowMajor(rows: usize, cols: usize) Index2D {
        const rstride = cols;
        const cstride = 1;
        return .{ .rows = rows, .cols = cols, .rstride = rstride, .cstride = cstride, .offset = 0 };
    }

    fn initColMajor(rows: usize, cols: usize) Index2D {
        const rstride = 1;
        const cstride = rows;
        return Index2D{ rows, cols, rstride, cstride, 0 };
    }
};

/// Iterator over 2D sliding windows (submatrices) of a matrix.
/// Each submatrix is given by an `Index2D`, i.e., as a view into the same slice.
const Patches = struct {
    index: Index2D,
    patch_rows: usize,
    patch_cols: usize,
    // buffer: *[]const u8,
    next_i: usize,
    next_j: usize,

    fn init(index: Index2D) Patches {
        return .{ .index = index, .patch_rows = 3, .patch_cols = 3, .next_i = 0, .next_j = 0 };
    }

    fn next(self: *Patches) ?Index2D {
        const last_i = self.index.rows - self.patch_rows;
        const last_j = self.index.cols - self.patch_cols;
        if (self.next_i > last_i)
            return null;

        const offset = self.index.linearIndex(self.next_i, self.next_j).?;
        const sub_index = Index2D{
            .rows = self.patch_rows,
            .cols = self.patch_cols,
            .rstride = self.index.rstride,
            .cstride = self.index.cstride,
            .offset = offset,
        };

        if (self.next_j < last_j) {
            self.next_j += 1;
        } else {
            self.next_i += 1;
            self.next_j = 0;
        }
        return sub_index;
    }
};

fn debugPrintLn(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

fn printLn(comptime fmt: []const u8, args: anytype) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(fmt ++ "\n", args);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        debugPrintLn("Memory check: {any}", .{deinit_status});
    }

    const fileContent = try std.fs.cwd().readFileAlloc(alloc, "input.txt", max_size);
    defer alloc.free(fileContent);
    const sum = try solve(alloc, fileContent);
    try printLn("Input answer: {d}", .{sum});
}

test "Patches" {
    const index = Index2D.initRowMajor(4, 3);
    const expected_num_patches = 6;

    var actual_num_patches: usize = 0;
    var patches = Patches{
        .index = index,
        .patch_cols = 2,
        .patch_rows = 2,
        .next_i = 0,
        .next_j = 0,
    };
    while (patches.next()) |_| {
        actual_num_patches += 1;
    }

    try std.testing.expectEqual(expected_num_patches, actual_num_patches);
}

test "Example" {
    const solution = 9;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try std.testing.expectEqual(solution, sum);
}
