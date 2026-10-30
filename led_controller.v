`timescale 1ns / 1ps
//============================================================================
// LED Controller Module
// Manages all 16 LEDs on Basys 3 board
// Provides visual feedback for:
//   - Current FSM state (lower LEDs)
//   - Transaction status (upper LEDs)
//   - Error indicators
//   - Dispense animation
//============================================================================

module led_controller(
    input             clk,
    input             reset,
    input      [ 3:0] current_state,   // FSM state from CU
    input      [ 3:0] led_mode,        // LED display mode from CU
    output reg [15:0] led_out          // Physical LED outputs
);

    // LED Modes
    localparam LED_IDLE         = 4'd0;  // Single LED[0]
    localparam LED_STATE        = 4'd1;  // State indicator on lower LEDs
    localparam LED_SUCCESS      = 4'd2;  // Lower 8 LEDs on
    localparam LED_ERROR        = 4'd3;  // Upper 4 LEDs on
    localparam LED_DISPENSE     = 4'd4;  // Upper 8 LEDs flash (cash out)
    localparam LED_EJECT        = 4'd5;  // LED[0] + LED[15] (bookend)
    localparam LED_CHANGE_PIN   = 4'd6;  // Alternating pattern
    localparam LED_TX_DEPOSIT   = 4'd7;  // Lower 4 Alternate Pattern
    localparam LED_TX_WITHDRAW  = 4'd8;  // Upper 4 Alternate Pattern

    // Animation counter for flashing effects
    reg [23:0] anim_counter;
    wire       anim_tick;

    always @(posedge clk or posedge reset) begin
        if (reset)
            anim_counter <= 24'd0;
        else
            anim_counter <= anim_counter + 1'b1;
    end

    assign anim_tick = anim_counter[23]; // ~6 Hz blink

    // LED output logic
    always @(*) begin
        case (led_mode)
            LED_IDLE: begin
                led_out = 16'h0001;  // Only LED[0]
            end

            LED_STATE: begin
                // Light up LED corresponding to current state number
                led_out = 16'd1 << current_state;
            end

            LED_SUCCESS: begin
                led_out = 16'h00FF;  // Lower 8 LEDs all on
            end

            LED_ERROR: begin
                led_out = anim_tick ? 16'hF000 : 16'h0000; // Flash upper 4
            end

            LED_DISPENSE: begin
                // Scrolling animation on upper 8 LEDs
                led_out = anim_tick ? 16'hFF00 : 16'h00FF;
            end

            LED_EJECT: begin
                led_out = 16'h8001;  // LED[0] + LED[15]
            end

            LED_CHANGE_PIN: begin
                led_out = anim_tick ? 16'hAAAA : 16'h5555; // Alternating
            end

            LED_TX_DEPOSIT: begin
                led_out = 16'h000F; // Solid lowest 4 LEDs indicate Deposit
            end

            LED_TX_WITHDRAW: begin
                led_out = 16'hF000; // Solid highest 4 LEDs indicate Withdrawal
            end

            default: begin
                led_out = 16'h0000;
            end
        endcase
    end

endmodule
