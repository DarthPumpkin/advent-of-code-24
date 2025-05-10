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

        const undampened_result = eval_report(report.items);
        var valid: bool = undefined;
        switch (undampened_result) {
            .valid => {
                valid = true;
                debugPrintLn("Safe without dampening", .{});
            },
            .invalid => |i| {
                var report_without_i0 = try report.clone();
                defer report_without_i0.deinit();
                _ = report_without_i0.orderedRemove(i);
                var report_without_i1 = try report.clone();
                defer report_without_i1.deinit();
                _ = report_without_i1.orderedRemove(i + 1);
                var report_without_i2 = try report.clone();
                defer report_without_i2.deinit();
                _ = report_without_i2.orderedRemove(i + 2);
                const v0 = eval_report(report_without_i0.items) == ReportResult.valid;
                const v1 = eval_report(report_without_i1.items) == ReportResult.valid;
                const v2 = eval_report(report_without_i2.items) == ReportResult.valid;
                valid = v0 or v1 or v2;
                if (valid) {
                    var idx: usize = undefined;
                    if (v0) {
                        idx = i;
                    } else if (v1) {
                        idx = i + 1;
                    } else {
                        idx = i + 2;
                    }
                    debugPrintLn("Safe by dampening {d}", .{idx});
                } else debugPrintLn("Unsafe", .{});
            },
        }
        if (valid)
            sum += 1;
    }
    return sum;
}

/// Evaluate the safety of a report without dampening
fn eval_report(levels: []const Number) ReportResult {
    const len = levels.len;
    for (levels[0 .. len - 2], levels[1 .. len - 1], levels[2..], 0..) |l1, l2, l3, i| {
        const anyEq = (l1 == l2) or (l2 == l3);
        const inc1 = l1 < l2;
        const inc2 = l2 < l3;
        const abs1 = absDiff(l1, l2) > 3;
        const abs2 = absDiff(l2, l3) > 3;
        if (anyEq or inc1 != inc2 or abs1 or abs2) {
            return ReportResult{ .invalid = i };
        }
    }
    return ReportResult{ .valid = {} };
}

const ReportResult = union(enum) {
    valid: void,
    invalid: usize,
};

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

    try expect(sum == 4);
}

test "Invalid first" {
    const levels = [_]Number{ 83, 81, 82, 83, 85, 87, 90, 92 };
    const expected_report = ReportResult{ .invalid = 0 };
    const actual_report = eval_report(&levels);
    debugPrintLn("{any}", .{actual_report});
    try expect(std.meta.eql(expected_report, actual_report));
}
