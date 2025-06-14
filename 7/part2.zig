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
    const candidates_hint = 50;
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
    var candidates = try std.ArrayList(Solution).initCapacity(allocator, candidates_hint);
    defer candidates.deinit();
    var new_candidates = try std.ArrayList(Solution).initCapacity(allocator, candidates_hint);
    defer new_candidates.deinit();
    try candidates.append(rhs_numbers.items[0]);
    for (rhs_numbers.items[1..]) |next_number| {
        for (candidates.items) |candidate| {
            inline for (comptime std.enums.values(Op)) |op| {
                const new_candidate = switch (op) {
                    .Add => candidate + next_number,
                    .Mult => candidate * next_number,
                    .Concat => try concatDigits(candidate, next_number),
                };

                if (new_candidate <= lhs) {
                    try new_candidates.append(new_candidate);
                }
            }
        }
        std.mem.swap(std.ArrayList(Solution), &candidates, &new_candidates);
        new_candidates.clearRetainingCapacity();
    }
    if (std.mem.indexOfScalar(Solution, candidates.items, lhs) != null)
        return lhs;
    return 0;
}

const Op = enum { Add, Mult, Concat };

fn concatDigits(lnum: Solution, rnum: Solution) !Solution {
    const log_r = std.math.log10_int(rnum) + 1;
    const pow = try std.math.powi(Solution, 10, log_r);
    return lnum * pow + rnum;
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

test "concatDigits" {
    try std.testing.expectEqual(1210, concatDigits(12, 10));
    try std.testing.expectEqual(9899, concatDigits(98, 99));
    try std.testing.expectEqual(11, concatDigits(1, 1));
    try std.testing.expectEqual(7, concatDigits(0, 7));
}
