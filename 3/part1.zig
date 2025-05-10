const std = @import("std");
const expect = std.testing.expect;

const Number = u64;

const max_size = std.math.maxInt(usize);

fn solve(_: std.mem.Allocator, input_str: []const u8) !Number {
    const left = "mul(";
    const right = ")";
    const comma = ",";

    var sum: Number = 0;
    var left_splits = std.mem.splitSequence(u8, input_str, left);
    _ = left_splits.next(); // skip everything to the left of the first mul(
    while (left_splits.next()) |match| {
        var right_splits = std.mem.splitSequence(u8, match, right);
        if (right_splits.next()) |middle| {
            var comma_tokenizer = std.mem.splitSequence(u8, middle, comma);

            const maybe_lnum = comma_tokenizer.next();
            const maybe_rnum = comma_tokenizer.next();
            if (comma_tokenizer.next() != null) { // this means there is more than one comma
                continue;
            }
            if (maybe_lnum) |lnum_str| {
                if (maybe_rnum) |rnum_str| {
                    if (lnum_str.len <= 3 and rnum_str.len <= 3) {
                        const lnum = std.fmt.parseUnsigned(Number, lnum_str, 0) catch 0;
                        const rnum = std.fmt.parseUnsigned(Number, rnum_str, 0) catch 0;
                        sum += lnum * rnum;
                    }
                }
            }
        }
    }
    return sum;
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
    const solution = 161;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try expect(sum == solution);
}
