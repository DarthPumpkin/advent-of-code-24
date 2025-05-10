const std = @import("std");
const expect = std.testing.expect;

const Number = u64;

const max_size = std.math.maxInt(usize);

fn solve(_: std.mem.Allocator, input_str: []const u8) !Number {
    const left = "mul(";
    const right = ")";
    const comma = ",";

    var sum: Number = 0;
    var enabled = true;
    var left_splits = std.mem.splitSequence(u8, input_str, left);
    const first = left_splits.next().?;
    switch (findChange(first)) {
        .enable => {
            enabled = true;
        },
        .disable => {
            enabled = false;
        },
        .unchanged => {},
    }
    while (left_splits.next()) |match| {
        debugPrintLn("New match: {s}", .{match});
        if (enabled) {
            debugPrintLn("Enabled", .{});
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
                            debugPrintLn("Added {d}", .{lnum * rnum});
                        }
                    }
                }
            }
        }
        const change = findChange(match);
        switch (change) {
            .enable => {
                enabled = true;
            },
            .disable => {
                enabled = false;
            },
            .unchanged => {},
        }
        debugPrintLn("{any}", .{change});
    }
    return sum;
}

fn findChange(str: []const u8) Enable {
    const do = "do()";
    const dont = "don't()";

    var lastDo: ?usize = null;
    var do_windows = std.mem.window(u8, str, do.len, 1);
    var i_do: usize = 0;
    while (do_windows.next()) |window| : (i_do += 1) {
        if (std.mem.eql(u8, window, do)) {
            lastDo = i_do;
        }
    }

    var lastDont: ?usize = null;
    var dont_windows = std.mem.window(u8, str, dont.len, 1);
    var i_dont: usize = 0;
    while (dont_windows.next()) |window| : (i_dont += 1) {
        if (std.mem.eql(u8, window, dont)) {
            lastDont = i_dont;
        }
    }

    if (lastDo == null and lastDont == null)
        return Enable.unchanged;
    if (lastDo != null and lastDont == null)
        return Enable.enable;
    if (lastDo == null and lastDont != null)
        return Enable.disable;
    if (lastDo.? < lastDont.?)
        return Enable.disable;
    if (lastDo.? > lastDont.?)
        return Enable.enable;
    unreachable;
}

const Enable = enum { enable, disable, unchanged };

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
    const solution = 48;
    const example_file_name = "example2.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try expect(sum == solution);
}
