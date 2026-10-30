`timescale 1ns / 1ps
//============================================================================
// Register File (Temporary Storage)
// Stores intermediate data during ATM operations:
//   - Entered PIN (raw and hashed)
//   - Transaction amount
//   - Current balance (working copy)
//   - Stored hashed PIN (from memory/ROM)
//   - ALU result temporary storage
//
// This module sits between the CU, ALU, and Memory Module,
// holding temporary values during multi-cycle operations.
// All data here is volatile - lost on reset or card ejection.
//============================================================================

module register_file(
    input             clk,
    input             reset,
    input             clear,         // Clear all registers (on card eject)

    // Write control from CU
    input             wr_entered_pin,
    input             wr_stored_hash,
    input             wr_balance,
    input             wr_tx_amount,
    input             wr_alu_result,
    input             wr_new_hash,

    // Write data inputs
    input      [15:0] din_entered_pin,
    input      [15:0] din_stored_hash,
    input      [15:0] din_balance,
    input      [15:0] din_tx_amount,
    input      [15:0] din_alu_result,
    input      [15:0] din_new_hash,

    // Read outputs (always available)
    output reg [15:0] entered_pin,
    output reg [15:0] stored_hash,
    output reg [15:0] current_balance,
    output reg [15:0] tx_amount,
    output reg [15:0] alu_result_reg,
    output reg [15:0] new_pin_hash
);

    always @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            entered_pin    <= 16'd0;
            stored_hash    <= 16'd0;
            current_balance <= 16'd0;
            tx_amount      <= 16'd0;
            alu_result_reg <= 16'd0;
            new_pin_hash   <= 16'd0;
        end else begin
            if (wr_entered_pin)  entered_pin    <= din_entered_pin;
            if (wr_stored_hash)  stored_hash    <= din_stored_hash;
            if (wr_balance)      current_balance <= din_balance;
            if (wr_tx_amount)    tx_amount      <= din_tx_amount;
            if (wr_alu_result)   alu_result_reg <= din_alu_result;
            if (wr_new_hash)     new_pin_hash   <= din_new_hash;
        end
    end

endmodule
