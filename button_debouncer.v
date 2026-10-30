`timescale 1ns / 1ps
//============================================================================
// Button Debouncer (Syncs to external 10ms Tick)
// Reduced to 2-Bit counters to optimize hardware space
//============================================================================

module button_debouncer(
    input clk,
    input reset,
    input tick_10ms,
    input btn_in,
    output btn_out
);
    reg btn_sync_0, btn_sync_1, btn_stable, btn_prev;
    reg [1:0] counter; // Uses just 2 bits instead of 20!

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_sync_0 <= 1'b0; 
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in; 
            btn_sync_1 <= btn_sync_0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 2'd0;
            btn_stable <= 1'b0;
        end else begin
            if (btn_sync_1 != btn_stable) begin
                if (tick_10ms) begin
                    if (counter == 2'd2) begin
                        btn_stable <= btn_sync_1;
                        counter <= 2'd0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end
            end else begin
                counter <= 2'd0;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) btn_prev <= 1'b0;
        else btn_prev <= btn_stable;
    end

    assign btn_out = btn_stable & ~btn_prev;
endmodule
