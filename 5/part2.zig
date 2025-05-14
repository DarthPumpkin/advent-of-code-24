const std = @import("std");
const expect = std.testing.expect;

const Page = u8;
const Solution = usize;

const max_size = std.math.maxInt(usize);

fn solve(base_alloc: std.mem.Allocator, input_str: []const u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    var splits = std.mem.tokenizeSequence(u8, input_str, "\n\n");
    const rules_str = splits.next().?;
    const updates_str = splits.next().?;
    // Parse rules
    var rules = std.hash_map.AutoHashMap(Page, std.ArrayList(Page)).init(alloc);
    var rules_splits = std.mem.tokenizeAny(u8, rules_str, "\r\n");
    while (rules_splits.next()) |rule_str| {
        var rule_parts = std.mem.splitScalar(u8, rule_str, '|');
        const from = try std.fmt.parseUnsigned(Page, rule_parts.next().?, 0);
        const to = try std.fmt.parseUnsigned(Page, rule_parts.next().?, 0);
        const entry = try rules.getOrPut(from);
        if (entry.found_existing) {
            try entry.value_ptr.*.append(to);
        } else {
            var new_list = std.ArrayList(Page).init(alloc);
            try new_list.append(to);
            entry.value_ptr.* = new_list;
        }
    }
    // Find invalid sequences
    var sum: Solution = 0;
    var update_splits = std.mem.tokenizeAny(u8, updates_str, "\r\n");
    var fbal = FixedBufferArrayList(Page, 100).init();
    while (update_splits.next()) |update_str| {
        var pages_so_far = fbal.arrayList(); // re-use buffer
        var page_splits = std.mem.splitScalar(u8, update_str, ',');
        var valid = true;
        while (page_splits.next()) |page_str| {
            const page = try std.fmt.parseUnsigned(u8, page_str, 0);
            // Check order
            if (rules.get(page)) |successors| {
                for (pages_so_far.items) |prev_page| {
                    for (successors.items) |s| {
                        if (s == prev_page) {
                            valid = false;
                        }
                    }
                }
            }
            try pages_so_far.append(page);
        }
        if (!valid) {
            const report = pages_so_far.items;
            debugPrintLn("Invalid: {any}", .{report});
            // Sort update topologically
            var buffer: [100]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            var subgraph_ = try subgraph(&rules, report);
            const sorted = try topologicalSort(fba.allocator(), &subgraph_);
            const lessThan = struct {
                pub fn lessThanContext(context: []Page, p1: Page, p2: Page) bool {
                    const i1_ = std.mem.indexOfScalar(Page, context, p1).?;
                    const i2_ = std.mem.indexOfScalar(Page, context, p2).?;
                    return i1_ < i2_;
                }
            }.lessThanContext;
            std.mem.sortUnstable(Page, report, sorted, lessThan);
            debugPrintLn("Fixed: {any}", .{report});
            const middle_idx = report.len / 2;
            sum += report[middle_idx];
        }
    }
    return sum;
}

// Kahn's algorithm: repeatedly remove pages from the DAG that don't have successors
// Allocates exactly 100 Bytes.
fn topologicalSort(alloc: std.mem.Allocator, dag: *std.hash_map.AutoHashMap(Page, std.ArrayList(Page))) ![]Page {
    var no_outgoing_edges = std.bit_set.ArrayBitSet(u64, 100).initEmpty();
    for (0..100) |page_| {
        const page = @as(Page, @intCast(page_));
        if (!dag.contains(page)) {
            no_outgoing_edges.set(page);
        }
    }

    var sorted = try std.ArrayList(Page).initCapacity(alloc, 100);
    while (no_outgoing_edges.findFirstSet()) |page_to_| {
        no_outgoing_edges.unset(page_to_);
        const page_to = @as(Page, @intCast(page_to_));
        try sorted.append(page_to);
        for (0..100) |page_from_| {
            const page_from = @as(Page, @intCast(page_from_));
            if (dag.getPtr(page_from)) |successors| {
                if (std.mem.indexOfScalar(Page, successors.items, page_to)) |i| {
                    _ = successors.swapRemove(i);
                }
                if (successors.items.len == 0) {
                    _ = dag.remove(page_from);
                    no_outgoing_edges.set(page_from);
                }
            }
        }
    }
    if (dag.count() > 0) {
        debugPrintLn("Sorted: {any}", .{sorted.items});
        debugPrintLn("Remaining edges:", .{});
        var edges = dag.iterator();
        while (edges.next()) |edge| {
            debugPrintLn("{d}: {any}", .{ edge.key_ptr.*, edge.value_ptr.items });
        }
        @panic("DAG not empty after Kahn's algorithm.");
    }
    return sorted.toOwnedSlice();
}

fn subgraph(graph: *const std.hash_map.AutoHashMap(Page, std.ArrayList(Page)), report: []const Page) !std.hash_map.AutoHashMap(Page, std.ArrayList(Page)) {
    const alloc = graph.allocator;
    var subgraph_ = std.hash_map.AutoHashMap(Page, std.ArrayList(Page)).init(alloc);
    for (report) |page_from| {
        if (graph.get(page_from)) |successors| {
            var sub_successors = std.ArrayList(Page).init(alloc);
            for (report) |page_to| {
                if (std.mem.indexOfScalar(Page, successors.items, page_to) != null) {
                    try sub_successors.append(page_to);
                }
            }
            if (sub_successors.items.len > 0) {
                try subgraph_.put(page_from, sub_successors);
            }
        }
    }
    return subgraph_;
}

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
    const solution = 123;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try std.testing.expectEqual(solution, sum);
}
