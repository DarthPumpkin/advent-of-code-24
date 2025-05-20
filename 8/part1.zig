const std = @import("std");
const expect = std.testing.expect;

const Solution = usize;

const max_size = std.math.maxInt(usize);

fn solve(base_alloc: std.mem.Allocator, input_str: []u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    const first_line = lines.next().?;
    const width = first_line.len;
    const height = input_str.len / (width + 1);
    const map_index = Index2D.initCustomStrides(height, width, width + 1, 1);

    const V = std.ArrayList(struct { usize, usize });
    var locations = std.hash_map.AutoHashMap(u8, V).init(arena_alloc);
    for (0..height) |i| {
        for (0..width) |j| {
            const symb = input_str[map_index.linearIndex(i, j).?];
            if (symb != '.') {
                const entry = try locations.getOrPutValue(symb, V.init(arena_alloc));
                try entry.value_ptr.append(.{ i, j });
            }
        }
    }

    var unique_locations = std.hash_map.AutoHashMap(struct { isize, isize }, void).init(arena_alloc);
    var entries = locations.valueIterator();
    while (entries.next()) |list| {
        for (list.items, 0..) |l1, idx1| {
            for (list.items[idx1 + 1 ..]) |l2| {
                const l1i: isize, const l1j: isize = .{ @intCast(l1[0]), @intCast(l1[1]) };
                const l2i: isize, const l2j: isize = .{ @intCast(l2[0]), @intCast(l2[1]) };
                const l3i = 2 * l1i - l2i;
                const l3j = 2 * l1j - l2j;
                const l4i = 2 * l2i - l1i;
                const l4j = 2 * l2j - l1j;
                if (l3i >= 0 and l3i < height and l3j >= 0 and l3j < width)
                    try unique_locations.put(.{ l3i, l3j }, {});
                if (l4i >= 0 and l4i < height and l4j >= 0 and l4j < width)
                    try unique_locations.put(.{ l4i, l4j }, {});
            }
        }
    }
    return unique_locations.count();
}

// Copied from Day 6
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

    fn initCustomStrides(rows: usize, cols: usize, rstride: usize, cstride: usize) Index2D {
        return .{
            .rows = rows,
            .cols = cols,
            .rstride = rstride,
            .cstride = cstride,
            .offset = 0,
        };
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
    const solution = 14;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try std.testing.expectEqual(solution, sum);
}

test "Benchmark" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        debugPrintLn("Memory check: {any}", .{deinit_status});
    }

    const tic = std.time.milliTimestamp();
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, "input.txt", max_size);
    defer alloc.free(fileContent);

    const tac = std.time.milliTimestamp();
    defer {
        const toc = std.time.milliTimestamp();
        printLn("readFile took {d}ms", .{tac - tic}) catch {
            debugPrintLn("Failed to print to stdout", .{});
        };
        printLn("solve took {d}ms", .{toc - tac}) catch {
            debugPrintLn("Failed to print to stdout", .{});
        };
    }

    _ = try solve(alloc, fileContent);
}
