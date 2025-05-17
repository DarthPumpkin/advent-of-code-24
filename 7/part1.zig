const std = @import("std");
const expect = std.testing.expect;

const Solution = u64;

const max_size = std.math.maxInt(usize);

fn solve(base_alloc: std.mem.Allocator, input_str: []u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var sum: Solution = 0;
    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        sum += try solveLine(arena_alloc, line);
    }
    return sum;
}

fn solveLine(_: std.mem.Allocator, line: []const u8) !Solution {
    const max_rhs = 12;
    var sides = std.mem.tokenizeSequence(u8, line, ": ");
    const lhs_str = sides.next().?;
    const rhs_str = sides.next().?;
    const lhs = try std.fmt.parseUnsigned(Solution, lhs_str, 10);
    // var rhs_buffer: [max_rhs]Solution = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(rhs_buffer);
    // const fba_allocator = fba.allocator();
    var fbal = FixedBufferArrayList(Solution, max_rhs).init();
    var rhs_numbers = fbal.arrayList();
    var rhs_number_strs = std.mem.tokenizeScalar(u8, rhs_str, ' ');
    while (rhs_number_strs.next()) |rhs_number_str| {
        const rhs_number = try std.fmt.parseUnsigned(Solution, rhs_number_str, 10);
        try rhs_numbers.append(rhs_number);
    }
    const slots = rhs_numbers.items.len - 1;
    const slots_u4 = @as(u4, @intCast(slots));
    const combinations = try std.math.powi(u12, 2, slots_u4);
    for (0..combinations) |combo| {
        const combo_u12 = @as(u12, @intCast(combo));
        var rhs_result = rhs_numbers.items[0];
        for (0..slots) |slot| {
            const slot_u4 = @as(u4, @intCast(slot));
            const op = (combo_u12 >> slot_u4) & 1;
            if (op == 1) {
                rhs_result *= rhs_numbers.items[slot + 1];
            } else {
                rhs_result += rhs_numbers.items[slot + 1];
            }
        }
        if (lhs == rhs_result)
            return lhs;
    }
    return 0;
}

// Re-use from Day 5
fn FixedBufferArrayList(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity * @sizeOf(T)]u8,

        pub fn init() @This() {
            return .{ .buffer = undefined };
        }

        pub fn arrayList(self: *@This()) std.ArrayList(T) {
            var fba = std.heap.FixedBufferAllocator.init(&self.buffer);
            return std.ArrayList(T).initCapacity(fba.allocator(), capacity) catch unreachable;
        }
    };
}

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
    const solution = 3749;
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
