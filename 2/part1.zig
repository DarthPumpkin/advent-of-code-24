const std = @import("std");
const expect = std.testing.expect;

const Number = u64;

const max_size = std.math.maxInt(usize);

fn solve(alloc: std.mem.Allocator, input_str: []const u8) !Number {
    var report = std.ArrayList(Number).init(alloc);
    defer report.deinit();

    var sum: Number = 0;
    debugPrintLn("Reports:", .{});
    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        report.clearRetainingCapacity();
        var number_strings = std.mem.tokenizeAny(u8, line, " \t");
        while (number_strings.next()) |num_str| {
            const num = try std.fmt.parseUnsigned(Number, num_str, 0);
            try report.append(num);
        }
        debugPrintLn("{any}", .{report.items});

        const should_increase = (report.items[0] < report.items[1]);
        const len = report.items.len;
        var valid = true;
        for (report.items[0 .. len - 1], report.items[1..len], 0..) |l1, l2, i| {
            const does_increase = l1 < l2;
            const equal = l1 == l2;
            if (equal or (should_increase != does_increase) or absDiff(l1, l2) > 3) {
                valid = false;
                debugPrintLn("Invalid at index {d}", .{i});
                break;
            }
        }
        if (valid)
            sum += 1;
    }
    return sum;
}

fn absDiff(x: anytype, y: anytype) @TypeOf(x + y) {
    return if (x > y) x - y else y - x;
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
    defer _ = gpa.deinit();

    const fileContent = try std.fs.cwd().readFileAlloc(alloc, "input.txt", max_size);
    defer alloc.free(fileContent);
    const sum = try solve(alloc, fileContent);
    try printLn("Input answer: {d}", .{sum});
}

test "Example" {
    const alloc = std.testing.allocator;

    const example_file_name = "example.txt";
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try expect(sum == 2);
}
