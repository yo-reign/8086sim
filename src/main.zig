/// This is a simple disassembler for the 8086 instruction set.
/// Takes in executable files and outputs the assembly code.
/// It takes advantage of zig's debug print vs standard out which allows the ability to pipe the output to a file (eg: file.asm).
/// NOTE: Currently only supports the mov instruction.
const std = @import("std");

/// They are the most significant bits of the first byte
const OpCodes = enum(u6) {
    mov = 0b100010,
    // TODO: add more opcodes
};

/// Use when W bit is set to  1
const WordRegisters = enum(u3) {
    ax = 0b000,
    cx = 0b001,
    dx = 0b010,
    bx = 0b011,
    sp = 0b100,
    bp = 0b101,
    si = 0b110,
    di = 0b111,
};

/// Use when W bit is set to 0
const ByteRegisters = enum(u3) {
    al = 0b000,
    cl = 0b001,
    dl = 0b010,
    bl = 0b011,
    ah = 0b100,
    ch = 0b101,
    dh = 0b110,
    bh = 0b111,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("leaked!", .{});
    }

    const stdout = std.io.getStdOut().writer();

    // Get the args (through an iterator)
    var arg_iter = try std.process.argsWithAllocator(allocator);
    defer arg_iter.deinit();

    // Skip the first arg, which is the program name
    _ = arg_iter.skip();

    // Get the asm file path
    const asm_file_path = arg_iter.next();
    if (asm_file_path == null) {
        std.debug.panic("no executable file provided!", .{});
    } // NOTE: This ignores the rest of the args (if any)

    std.debug.print("{s} disassembly:\n\n\"\"\"\n", .{asm_file_path.?});

    // Open the asm file
    const asm_file_bytes = try std.fs.cwd().readFileAlloc(allocator, asm_file_path.?, 0x100010);
    defer allocator.free(asm_file_bytes);

    // Prefix the asm output/file with "bits 16"
    try stdout.print("bits 16\n\n", .{});

    // Get the total number of instructions
    const total_instructions = try if (asm_file_bytes.len % 2 == 0) asm_file_bytes.len / 2 else error.OddLength;

    // Decode each instruction
    for (0..total_instructions) |i| {
        const first_byte: u8 = asm_file_bytes[i * 2];
        const second_byte: u8 = asm_file_bytes[i * 2 + 1];

        // If this is false, assume it's a byte register instruction.
        const is_word: bool = first_byte & 0b00000001 == 0b00000001;
        const op_code: OpCodes = @enumFromInt(first_byte >> 2);

        // TODO: Not needed for now, but for completeness this should be completed in the future
        // const register_mode: bool = second_byte & 0b11000000 == 0b11000000;
        // const direction:

        // Taking advantave of zig's great built-in capabilities
        if (is_word) {
            const destination_register: WordRegisters = @enumFromInt(second_byte & 0b00000111);
            const source_register: WordRegisters = @enumFromInt(second_byte >> 3 & 0b00111);
            try stdout.print("{s} {s}, {s}\n", .{ @tagName(op_code), @tagName(destination_register), @tagName(source_register) });
        } else {
            const destination_register: ByteRegisters = @enumFromInt(second_byte & 0b00000111);
            const source_register: ByteRegisters = @enumFromInt(second_byte >> 3 & 0b00111);
            try stdout.print("{s} {s}, {s}\n", .{ @tagName(op_code), @tagName(destination_register), @tagName(source_register) });
        }
    }

    std.debug.print("\"\"\"\n\nTotal assembly instructions: {}\n", .{total_instructions});
}
