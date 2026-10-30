`timescale 1ns / 1ps
//============================================================================
// ROM Module (Read-Only Memory)
// Stores pre-computed hashed PINs for 4 users
// This is TRUE read-only - no write port, cannot be modified at runtime
//
// Default PINs and their hashes:
//   User 0: PIN 1234 -> Hash = ((1234 ^ 0xA5F0) <<< 3) + 0x1E3B
//   User 1: PIN 5678 -> Hash = ((5678 ^ 0xA5F0) <<< 3) + 0x1E3B
//   User 2: PIN 1111 -> Hash = ((1111 ^ 0xA5F0) <<< 3) + 0x1E3B
//   User 3: PIN 9999 -> Hash = ((9999 ^ 0xA5F0) <<< 3) + 0x1E3B
//
// Memory Map:
//   Addr 0: User 0 default hashed PIN
//   Addr 1: User 1 default hashed PIN
//   Addr 2: User 2 default hashed PIN
//   Addr 3: User 3 default hashed PIN
//============================================================================

module rom_module(
    input      [1:0] addr,          // 2-bit address (4 users)
    output reg [15:0] data          // Hashed PIN output
);

    // Pre-computed hash values for default PINs
    // These are computed at design time using the same hash algorithm:
    // Hash(PIN) = ((PIN XOR 0xA5F0) <<< 3) + 0x1E3B
    //
    // PIN 1234 (0x04D2): 0x04D2 ^ 0xA5F0 = 0xA122, rotate left 3 = 0x0915, + 0x1E3B = 0x2750
    // PIN 5678 (0x162E): 0x162E ^ 0xA5F0 = 0xB3DE, rotate left 3 = 0x9EF5, + 0x1E3B = 0xBD30
    // PIN 1111 (0x0457): 0x0457 ^ 0xA5F0 = 0xA1A7, rotate left 3 = 0x0D3D, + 0x1E3B = 0x2B78
    // PIN 9999 (0x270F): 0x270F ^ 0xA5F0 = 0x82FF, rotate left 3 = 0x17FC, + 0x1E3B = 0x3637

    always @(*) begin
        case (addr)
            2'd0: data = 16'h2750;   // Hash of PIN 1234
            2'd1: data = 16'hBD30;   // Hash of PIN 5678
            2'd2: data = 16'h2B78;   // Hash of PIN 1111
            2'd3: data = 16'h3637;   // Hash of PIN 9999
            default: data = 16'h0000;
        endcase
    end

endmodule
