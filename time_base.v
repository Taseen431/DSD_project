`timescale 1ns / 1ps
//============================================================================
// Unified Time Base Generator
// Replaces massive 100MHz FSM counters with single prescaler for all components
//============================================================================

module time_base(
    input clk,
    input reset,
    output reg tick_10ms
);
    // 100 MHz clock => 10 ms = 1_000_000 cycles
    reg [19:0] counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 20'd0;
            tick_10ms <= 1'b0;
        end else if (counter == 20'd999_999) begin
            counter <= 20'd0;
            tick_10ms <= 1'b1;
        end else begin
            counter <= counter + 1'b1;
            tick_10ms <= 1'b0;
        end
    end
endmodule
