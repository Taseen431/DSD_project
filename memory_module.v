`timescale 1ns / 1ps
//============================================================================
// Memory Module (RAM - Read/Write Memory)
// Stores balances and updated hashed PINs for 4 users
// Also stores transaction history (last 4 transactions)
//
// Memory Map:
//   Addr 0: User 0 Hashed PIN (initialized from ROM, can be updated)
//   Addr 1: User 0 Balance
//   Addr 2: User 1 Hashed PIN
//   Addr 3: User 1 Balance
//   Addr 4: User 2 Hashed PIN
//   Addr 5: User 2 Balance
//   Addr 6: User 3 Hashed PIN
//   Addr 7: User 3 Balance
//   Addr 8-11: Transaction history (last 4 transactions)
//   Addr 12: Transaction history write pointer
//
// NOTE: PINs are stored as HASHED values, never in plain text.
// On reset, hashed PINs are loaded from ROM defaults.
//============================================================================

module memory_module(
    input             clk,
    input             reset,
    input             mem_read,
    input             mem_write,
    input      [ 4:0] addr,       // 5-bit address for 32 locations
    input      [15:0] wdata,      // Write data
    output reg [15:0] rdata,      // Read data

    // ROM interface for initial PIN loading
    input      [15:0] rom_pin_0,  // Hashed PIN from ROM for user 0
    input      [15:0] rom_pin_1,  // Hashed PIN from ROM for user 1
    input      [15:0] rom_pin_2,  // Hashed PIN from ROM for user 2
    input      [15:0] rom_pin_3   // Hashed PIN from ROM for user 3
);

    // 32 x 16-bit RAM array
    reg [15:0] mem [0:31];

    integer i;

    // Initialize from ROM on reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Clear entire memory first
            for (i = 0; i < 32; i = i + 1)
                mem[i] <= 16'd0;

            // Load explicit base profiles mapping per User
            mem[0]  <= rom_pin_0;
            mem[1]  <= 16'd5000;     // User 0 balance
            
            mem[8]  <= rom_pin_1;
            mem[9]  <= 16'd3000;     // User 1 balance
            
            mem[16] <= rom_pin_2;
            mem[17] <= 16'd8000;     // User 2 balance
            
            mem[24] <= rom_pin_3;
            mem[25] <= 16'd1500;     // User 3 balance
        end else begin
            if (mem_write) begin
                mem[addr] <= wdata;
            end
        end
    end

    // Synchronous read
    always @(posedge clk) begin
        if (mem_read) begin
            rdata <= mem[addr];
        end
    end

endmodule
