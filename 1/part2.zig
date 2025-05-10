const std = @import("std");
const expect = std.testing.expect;

const Number = u64;

const max_size = std.math.maxInt(usize);

fn solve(alloc: std.mem.Allocator, input_str: []const u8) !Number {
    var list1 = std.ArrayList(Number).init(alloc);
    defer list1.deinit();
    var list2 = std.ArrayList(Number).init(alloc);
    defer list2.deinit();

    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        var number_strings = std.mem.tokenizeAny(u8, line, " \t");
        const str1 = number_strings.next().?;
        const str2 = number_strings.next().?;
        const num1 = try std.fmt.parseUnsigned(Number, str1, 0);
        const num2 = try std.fmt.parseUnsigned(Number, str2, 0);
        try list1.append(num1);
        try list2.append(num2);
    }
    debugPrintLn("Parsed:\n{any}\n{any}", .{ list1.items, list2.items });

    // How many times each left number occurs in the right list
    var counts = std.hash_map.AutoHashMap(Number, Number).init(alloc);
    defer counts.deinit();

    // Create entries for all left numbers
    for (list1.items) |left_num| {
        const count = try counts.getOrPut(left_num);
        if (!count.found_existing) {
            count.value_ptr.* = 0;
        }
    }

    // Now count the right numbers that have been initialized
    for (list2.items) |right_num| {
        const maybe_count = counts.getPtr(right_num);
        if (maybe_count) |count| {
            count.* += 1;
        }
    }

    var sum: Number = 0;
    for (list1.items) |left_num| {
        const maybe_count = counts.get(left_num);
        if (maybe_count) |count| {
            sum += left_num * count;
            debugPrintLn("{d}: {d}", .{ left_num, count });
        }
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

    try expect(sum == 31);
}
