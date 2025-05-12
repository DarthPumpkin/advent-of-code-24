const std = @import("std");
const expect = std.testing.expect;

const Number = usize;

const max_size = std.math.maxInt(usize);

fn solve(base_alloc: std.mem.Allocator, input_str: []const u8) !Number {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    var splits = std.mem.tokenizeSequence(u8, input_str, "\n\n");
    const rules_str = splits.next().?;
    const updates_str = splits.next().?;
    // Parse rules
    var rules_map = std.hash_map.AutoHashMap(u8, std.ArrayList(u8)).init(alloc);
    var rules_splits = std.mem.tokenizeAny(u8, rules_str, "\r\n");
    while (rules_splits.next()) |rule_str| {
        var rule_parts = std.mem.splitScalar(u8, rule_str, '|');
        const from = try std.fmt.parseUnsigned(u8, rule_parts.next().?, 0);
        const to = try std.fmt.parseUnsigned(u8, rule_parts.next().?, 0);
        const entry = try rules_map.getOrPut(from);
        if (entry.found_existing) {
            try entry.value_ptr.*.append(to);
        } else {
            var new_list = std.ArrayList(u8).init(alloc);
            try new_list.append(to);
            entry.value_ptr.* = new_list;
        }
    }
    // Check updates
    var sum: Number = 0;
    var update_splits = std.mem.tokenizeAny(u8, updates_str, "\r\n");
    var pages_so_far = std.ArrayList(u8).init(alloc); // re-use
    defer pages_so_far.deinit();
    while (update_splits.next()) |update_str| {
        pages_so_far.clearRetainingCapacity();
        var page_splits = std.mem.splitScalar(u8, update_str, ',');
        var valid = true;
        update: while (page_splits.next()) |page_str| {
            const page = try std.fmt.parseUnsigned(u8, page_str, 0);
            // Check order
            if (rules_map.get(page)) |successors| {
                for (pages_so_far.items) |prev_page| {
                    for (successors.items) |s| {
                        if (s == prev_page) {
                            valid = false;
                            debugPrintLn("{any}", .{pages_so_far.items});
                            debugPrintLn("Invalid: {d}|{d}", .{ page, prev_page });
                            break :update;
                        }
                    }
                }
            }
            try pages_so_far.append(page);
        }
        if (valid) {
            const middle_idx = pages_so_far.items.len / 2;
            sum += pages_so_far.items[middle_idx];
            debugPrintLn("{any}", .{pages_so_far.items});
            debugPrintLn("Middle: {d}", .{pages_so_far.items[middle_idx]});
            // debugPrintLn("Successors:", .{});
            // for (pages_so_far.items) |page| {
            //     if (rules_map.get(page)) |successors| {
            //         debugPrintLn("{d}: {any}", .{ page, successors.items });
            //     } else {
            //         debugPrintLn("{d}: none", .{page});
            //     }
            // }
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
    const solution = 143;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try std.testing.expectEqual(solution, sum);
}
