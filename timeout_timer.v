`timescale 1ns / 1ps
//============================================================================
// Timeout Timer (Syncs to 10ms Tick)
// Reduced to 12-Bit Counter (3000 ticks) instead of 32-Bit
//============================================================================

module timeout_timer(
    input clk,
    input reset,
    input tick_10ms,
    input timer_reset,
    output reg expired
);
    reg [11:0] counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 12'd0;
            expired <= 1'b0;
        end else if (timer_reset) begin
            counter <= 12'd0;
            expired <= 1'b0;
        end else if (tick_10ms) begin
            if (counter == 12'd3000) begin // 3000 ticks * 10ms = 30s
                expired <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
                expired <= 1'b0;
            end
        end
    end
endmodule
