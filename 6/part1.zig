const std = @import("std");
const expect = std.testing.expect;

const Solution = usize;

const max_size = std.math.maxInt(usize);

fn solve(base_alloc: std.mem.Allocator, input_str: []const u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    const first_line = lines.next().?;
    const width = first_line.len;
    var height: usize = 1;
    while (lines.next()) |_| {
        height += 1;
    }
    const index = Index2D.initCustomStrides(height, width, width + 1, 1);
    const startPosLin = std.mem.indexOfScalar(u8, input_str, '^').?;
    const startRow = startPosLin / (width + 1);
    const startCol = startPosLin % (width + 1);
    var state = State{ .i = startRow, .j = startCol, .direction = .Up };
    var visited = try arena_alloc.alloc(bool, width * height);
    const visited_index = Index2D.initRowMajor(height, width);
    while (true) {
        visited[visited_index.linearIndex(state.i, state.j).?] = true;
        const within_bounds = step(&state, input_str, index);
        if (!within_bounds)
            break;
    }
    var sum: usize = 0;
    for (visited) |v| {
        if (v)
            sum += 1;
    }
    return sum;
}

fn step(state: *State, map: []const u8, index: Index2D) bool {
    const dir_vec = state.direction.asVector();
    const new_ii = @as(isize, @intCast(state.i)) + dir_vec[0];
    const new_ji = @as(isize, @intCast(state.j)) + dir_vec[1];
    if (new_ii < 0 or new_ji < 0)
        return false;
    const new_i: usize = @intCast(new_ii);
    const new_j: usize = @intCast(new_ji);
    const lin = index.linearIndex(new_i, new_j);
    if (lin == null)
        return false;
    const new_symb = map[lin.?];
    switch (new_symb) {
        '#' => {
            state.direction = state.direction.turnRight();
        },
        '.', '^' => {
            state.i = new_i;
            state.j = new_j;
            state.direction = state.direction;
        },
        else => unreachable,
    }
    return true;
}

const Direction = enum {
    Up,
    Right,
    Down,
    Left,

    pub fn asVector(self: Direction) struct { isize, isize } {
        return switch (self) {
            .Up => .{ -1, 0 },
            .Right => .{ 0, 1 },
            .Down => .{ 1, 0 },
            .Left => .{ 0, -1 },
        };
    }

    pub fn turnRight(self: Direction) Direction {
        return switch (self) {
            .Up => .Right,
            .Right => .Down,
            .Down => .Left,
            .Left => .Up,
        };
    }
};

const State = struct { i: usize, j: usize, direction: Direction };

// Re-use from Day 4
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
    const solution = 41;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try std.testing.expectEqual(solution, sum);
}
