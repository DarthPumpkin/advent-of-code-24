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
        sum += try solveLineFast(arena_alloc, line);
    }
    return sum;
}

fn solveLineSmall(allocator: std.mem.Allocator, line: []const u8) !Solution {
    const max_digits = 20; // number of digits of 2^64
    const base = 3;
    const rhs_numbers_hint = 12;
    var sides = std.mem.tokenizeSequence(u8, line, ": ");
    const lhs_str = sides.next().?;
    const rhs_str = sides.next().?;
    const lhs = try std.fmt.parseUnsigned(Solution, lhs_str, 10);
    var rhs_numbers = try std.ArrayList(Solution).initCapacity(allocator, rhs_numbers_hint);
    defer rhs_numbers.deinit();
    var rhs_number_strs = std.mem.tokenizeScalar(u8, rhs_str, ' ');
    while (rhs_number_strs.next()) |rhs_number_str| {
        const rhs_number = try std.fmt.parseUnsigned(Solution, rhs_number_str, 10);
        try rhs_numbers.append(rhs_number);
    }
    const slots = rhs_numbers.items.len - 1;
    const combinations = try std.math.powi(usize, base, slots);
    for (0..combinations) |combo| {
        var rhs_result = rhs_numbers.items[0];
        var remaining = combo;
        for (0..slots) |slot| {
            const op = remaining % base;
            remaining /= base;
            const next_number = rhs_numbers.items[slot + 1];
            if (op == 2) { // concatenate digits
                var ldigits_buf: [max_digits]u8 = undefined;
                var rdigits_buf: [max_digits]u8 = undefined;
                const llen = std.fmt.formatIntBuf(&ldigits_buf, rhs_result, 10, .lower, .{});
                const rlen = std.fmt.formatIntBuf(&rdigits_buf, next_number, 10, .lower, .{});
                std.mem.copyForwards(u8, ldigits_buf[llen..], rdigits_buf[0..rlen]);
                rhs_result = try std.fmt.parseUnsigned(Solution, ldigits_buf[0 .. llen + rlen], 10);
            } else if (op == 1) {
                rhs_result *= next_number;
            } else {
                rhs_result += next_number;
            }
            if (lhs < rhs_result)
                break;
        }
        if (lhs == rhs_result)
            return lhs;
    }
    return 0;
}

fn solveLineFast(allocator: std.mem.Allocator, line: []const u8) !Solution {
    const rhs_numbers_hint = 12;
    var sides = std.mem.tokenizeSequence(u8, line, ": ");
    const lhs_str = sides.next().?;
    const rhs_str = sides.next().?;
    const lhs = try std.fmt.parseUnsigned(Solution, lhs_str, 10);
    var rhs_numbers = try std.ArrayList(Solution).initCapacity(allocator, rhs_numbers_hint);
    defer rhs_numbers.deinit();
    var rhs_number_strs = std.mem.tokenizeScalar(u8, rhs_str, ' ');
    while (rhs_number_strs.next()) |rhs_number_str| {
        const rhs_number = try std.fmt.parseUnsigned(Solution, rhs_number_str, 10);
        try rhs_numbers.append(rhs_number);
    }
    var candidates = std.ArrayList(Solution).init(allocator);
    defer candidates.deinit();
    try candidates.append(rhs_numbers.items[0]);
    for (rhs_numbers.items[1..]) |next_number| {
        var new_candidates = std.ArrayList(Solution).init(allocator);
        defer {
            candidates.deinit();
            candidates = new_candidates;
        }
        for (candidates.items) |candidate| {
            for (0..3) |op| {
                const new_candidate = if (op == 2)
                    try concatDigits(candidate, next_number)
                else if (op == 1)
                    candidate * next_number
                else
                    candidate + next_number;
                // Optimization: we're doing the lowest op first, so we can break early if we're above
                if (new_candidate > lhs)
                    break;
                if (new_candidate == lhs) {
                    return lhs;
                }
                try new_candidates.append(new_candidate);
            }
        }
    }
    return 0;
}

fn concatDigits(lnum: usize, rnum: usize) !usize {
    const log_r = std.math.log10_int(rnum);
    // log10_int rounds down, but we want to round up.
    var pow = try std.math.powi(usize, 10, log_r);
    if (pow < rnum) {
        pow *= 10;
    }
    return lnum * pow + rnum;
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
    const solution = 11387;
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
