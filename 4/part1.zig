const std = @import("std");
const expect = std.testing.expect;

const Number = usize;

const max_size = std.math.maxInt(usize);

fn solve(_: std.mem.Allocator, input_str: []const u8) !Number {
    const xmas = "XMAS";

    // Build index
    var row_iter = std.mem.tokenizeScalar(u8, input_str, '\n');
    const cols = row_iter.next().?.len;
    var rows: usize = 1;
    while (row_iter.next() != null) {
        rows += 1;
    }
    const rstride = cols + 1; // to ignore the newline characters
    const cstride = 1;
    const index = Index2D{ .rows = rows, .cols = cols, .rstride = rstride, .cstride = cstride };
    debugPrintLn("{any}", .{index});

    var sum: Number = 0;
    // Check horizontal
    for (0..rows) |i| {
        for (0..cols - xmas.len + 1) |j| {
            // Check forward
            var forwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i, j + k).?] != xmas[k]) {
                    forwardMatch = false;
                    break;
                }
            }
            // Check backward
            var backwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i, j + k).?] != xmas[xmas.len - k - 1]) {
                    backwardMatch = false;
                    break;
                }
            }
            if (forwardMatch or backwardMatch) {
                sum += 1;
                debugPrintLn("Horizontal ({d}, {d})", .{ i, j });
            }
        }
    }
    // Check vertical
    for (0..rows - xmas.len + 1) |i| {
        for (0..cols) |j| {
            // Check forward
            var forwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i + k, j).?] != xmas[k]) {
                    forwardMatch = false;
                    break;
                }
            }
            // Check backward
            var backwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i + k, j).?] != xmas[xmas.len - k - 1]) {
                    backwardMatch = false;
                    break;
                }
            }
            if (forwardMatch or backwardMatch) {
                sum += 1;
                debugPrintLn("Vertical ({d}, {d})", .{ i, j });
            }
        }
    }
    // Check diagonal (down-right)
    for (0..rows - xmas.len + 1) |i| {
        for (0..cols - xmas.len + 1) |j| {
            // Check forward
            var forwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i + k, j + k).?] != xmas[k]) {
                    forwardMatch = false;
                    break;
                }
            }
            // Check backward
            var backwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i + k, j + k).?] != xmas[xmas.len - k - 1]) {
                    backwardMatch = false;
                    break;
                }
            }
            if (forwardMatch or backwardMatch) {
                sum += 1;
                debugPrintLn("Diagonal ({d}, {d})", .{ i, j });
            }
        }
    }
    // Check counter-diagonal (down-left)
    for (0..rows - xmas.len + 1) |i| {
        for (xmas.len - 1..cols) |j| {
            // Check forward
            var forwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i + k, j - k).?] != xmas[k]) {
                    forwardMatch = false;
                    break;
                }
            }
            // Check backward
            var backwardMatch = true;
            for (0..xmas.len) |k| {
                if (input_str[index.linearIndex(i + k, j - k).?] != xmas[xmas.len - k - 1]) {
                    backwardMatch = false;
                    break;
                }
            }
            if (forwardMatch or backwardMatch) {
                sum += 1;
                debugPrintLn("Counter-Diagonal ({d}, {d})", .{ i, j });
            }
        }
    }
    return sum;
}

const Index2D = struct {
    rows: usize,
    cols: usize,
    rstride: usize,
    cstride: usize,

    fn linearIndex(self: *const Index2D, i: usize, j: usize) ?usize {
        if (i >= self.rows or j >= self.cols)
            return null;
        return i * self.rstride + j * self.cstride;
    }

    fn initRowMajor(rows: usize, cols: usize) Index2D {
        const rstride = cols;
        const cstride = 1;
        return Index2D{ rows, cols, rstride, cstride };
    }

    fn initColMajor(rows: usize, cols: usize) Index2D {
        const rstride = 1;
        const cstride = rows;
        return Index2D{ rows, cols, rstride, cstride };
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

test "Example" {
    const solution = 18;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try expect(sum == solution);
}
