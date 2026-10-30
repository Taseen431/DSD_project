`timescale 1ns / 1ps
//============================================================================
// ATM Machine - Top Level Module (Basys 3) - Version 2
// Updated with: PIN Hashing, ROM, Register File, LED Controller,
//               Change PIN, Transaction Inquiry
// CSE 4224: Digital System Design
//============================================================================

module atm_top(
    input         clk,          // 100 MHz Basys 3 clock
    input  [15:0] sw,           // Switches for PIN/amount/user_id
    input         btnC,         // Confirm / Enter
    input         btnU,         // Navigate Up
    input         btnD,         // Navigate Down
    input         btnL,         // Cancel / Back
    input         btnR,         // Card Insertion simulation
    output [15:0] led,          // Status LEDs
    output [ 6:0] seg,          // 7-segment cathode (active low)
    output        dp,           // Decimal point (active low)
    output [ 3:0] an            // 7-segment anode (active low)
);

    //------------------------------------------------------------------------
    // Power-on Reset Generator (~10ms)
    //------------------------------------------------------------------------
    reg [19:0] reset_cnt = 20'd0;
    wire reset = ~reset_cnt[19];

    always @(posedge clk) begin
        if (!reset_cnt[19])
            reset_cnt <= reset_cnt + 1'b1;
    end

    //------------------------------------------------------------------------
    // Internal Wires
    //------------------------------------------------------------------------
    // Debounced buttons
    wire btnC_db, btnU_db, btnD_db, btnL_db, btnR_db;

    // CU <-> Memory (RAM)
    wire        mem_read, mem_write;
    wire [ 4:0] mem_addr;
    wire [15:0] mem_wdata, mem_rdata;

    // CU <-> ALU
    wire [ 2:0] alu_op;
    wire [15:0] alu_a, alu_b, alu_result;
    wire        zero_flag, negative_flag;

    // CU <-> PIN Hash
    wire [15:0] hash_pin_in, hash_out;

    // CU <-> Register File
    wire        rf_wr_entered_pin, rf_wr_stored_hash, rf_wr_balance;
    wire        rf_wr_tx_amount, rf_wr_alu_result, rf_wr_new_hash;
    wire [15:0] rf_din_entered_pin, rf_din_stored_hash, rf_din_balance;
    wire [15:0] rf_din_tx_amount, rf_din_alu_result, rf_din_new_hash;
    wire [15:0] rf_entered_pin, rf_stored_hash, rf_current_balance;
    wire [15:0] rf_tx_amount, rf_alu_result_reg, rf_new_pin_hash;
    wire        rf_clear;

    // CU -> Display
    wire [ 3:0] display_mode;
    wire [15:0] display_data;

    // CU -> LED Controller
    wire [ 3:0] led_mode;
    wire [ 3:0] current_state;

    // Timeout
    wire        timeout_reset, timeout_expired;

    // ROM outputs
    wire [15:0] rom_pin_0, rom_pin_1, rom_pin_2, rom_pin_3;

    //------------------------------------------------------------------------
    // 10ms Tick Generator for Debouncers
    //------------------------------------------------------------------------
    reg [19:0] tick_counter = 20'd0;
    reg tick_10ms = 1'b0;
    always @(posedge clk) begin
        if (tick_counter >= 20'd999_999) begin
            tick_counter <= 20'd0;
            tick_10ms <= 1'b1;
        end else begin
            tick_counter <= tick_counter + 1'b1;
            tick_10ms <= 1'b0;
        end
    end

    //------------------------------------------------------------------------
    // Button Debouncers (5 instances)
    //------------------------------------------------------------------------
    button_debouncer debC (.clk(clk), .reset(reset), .tick_10ms(tick_10ms), .btn_in(btnC), .btn_out(btnC_db));
    button_debouncer debU (.clk(clk), .reset(reset), .tick_10ms(tick_10ms), .btn_in(btnU), .btn_out(btnU_db));
    button_debouncer debD (.clk(clk), .reset(reset), .tick_10ms(tick_10ms), .btn_in(btnD), .btn_out(btnD_db));
    button_debouncer debL (.clk(clk), .reset(reset), .tick_10ms(tick_10ms), .btn_in(btnL), .btn_out(btnL_db));
    button_debouncer debR (.clk(clk), .reset(reset), .tick_10ms(tick_10ms), .btn_in(btnR), .btn_out(btnR_db));

    //------------------------------------------------------------------------
    // ROM - Default Hashed PINs (Read-Only)
    //------------------------------------------------------------------------
    rom_module ROM_PIN0 (.addr(2'd0), .data(rom_pin_0));
    rom_module ROM_PIN1 (.addr(2'd1), .data(rom_pin_1));
    rom_module ROM_PIN2 (.addr(2'd2), .data(rom_pin_2));
    rom_module ROM_PIN3 (.addr(2'd3), .data(rom_pin_3));

    //------------------------------------------------------------------------
    // PIN Hash Module (Combinational)
    //------------------------------------------------------------------------
    pin_hash HASH (
        .pin_in     (hash_pin_in),
        .hash_out   (hash_out)
    );

    //------------------------------------------------------------------------
    // Register File (Temporary Storage)
    //------------------------------------------------------------------------
    register_file REGFILE (
        .clk            (clk),
        .reset          (reset),
        .clear          (rf_clear),
        .wr_entered_pin (rf_wr_entered_pin),
        .wr_stored_hash (rf_wr_stored_hash),
        .wr_balance     (rf_wr_balance),
        .wr_tx_amount   (rf_wr_tx_amount),
        .wr_alu_result  (rf_wr_alu_result),
        .wr_new_hash    (rf_wr_new_hash),
        .din_entered_pin(rf_din_entered_pin),
        .din_stored_hash(rf_din_stored_hash),
        .din_balance    (rf_din_balance),
        .din_tx_amount  (rf_din_tx_amount),
        .din_alu_result (rf_din_alu_result),
        .din_new_hash   (rf_din_new_hash),
        .entered_pin    (rf_entered_pin),
        .stored_hash    (rf_stored_hash),
        .current_balance(rf_current_balance),
        .tx_amount      (rf_tx_amount),
        .alu_result_reg (rf_alu_result_reg),
        .new_pin_hash   (rf_new_pin_hash)
    );

    //------------------------------------------------------------------------
    // Control Unit (FSM)
    //------------------------------------------------------------------------
    control_unit CU (
        .clk            (clk),
        .reset          (reset),
        .sw             (sw),
        .btnC           (btnC_db),
        .btnU           (btnU_db),
        .btnD           (btnD_db),
        .btnL           (btnL_db),
        .btnR           (btnR_db),
        // ALU
        .alu_result     (alu_result),
        .zero_flag      (zero_flag),
        .negative_flag  (negative_flag),
        .alu_a          (alu_a),
        .alu_b          (alu_b),
        .alu_op         (alu_op),
        // Memory
        .mem_rdata      (mem_rdata),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        // PIN Hash
        .hash_out       (hash_out),
        .hash_pin_in    (hash_pin_in),
        // Register File
        .rf_wr_entered_pin (rf_wr_entered_pin),
        .rf_wr_stored_hash (rf_wr_stored_hash),
        .rf_wr_balance     (rf_wr_balance),
        .rf_wr_tx_amount   (rf_wr_tx_amount),
        .rf_wr_alu_result  (rf_wr_alu_result),
        .rf_wr_new_hash    (rf_wr_new_hash),
        .rf_din_entered_pin(rf_din_entered_pin),
        .rf_din_stored_hash(rf_din_stored_hash),
        .rf_din_balance    (rf_din_balance),
        .rf_din_tx_amount  (rf_din_tx_amount),
        .rf_din_alu_result (rf_din_alu_result),
        .rf_din_new_hash   (rf_din_new_hash),
        .rf_entered_pin    (rf_entered_pin),
        .rf_stored_hash    (rf_stored_hash),
        .rf_current_balance(rf_current_balance),
        .rf_tx_amount      (rf_tx_amount),
        .rf_alu_result_reg (rf_alu_result_reg),
        .rf_new_pin_hash   (rf_new_pin_hash),
        .rf_clear          (rf_clear),
        // Display
        .display_mode   (display_mode),
        .display_data   (display_data),
        // LED Controller
        .led_mode       (led_mode),
        .current_state_out(current_state),
        // Timeout
        .timeout_expired(timeout_expired),
        .timeout_reset  (timeout_reset)
    );

    //------------------------------------------------------------------------
    // ALU
    //------------------------------------------------------------------------
    alu ALU (
        .a              (alu_a),
        .b              (alu_b),
        .alu_op         (alu_op),
        .result         (alu_result),
        .zero_flag      (zero_flag),
        .negative_flag  (negative_flag)
    );

    //------------------------------------------------------------------------
    // Memory Module (RAM)
    //------------------------------------------------------------------------
    memory_module MEM (
        .clk            (clk),
        .reset          (reset),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .addr           (mem_addr),
        .wdata          (mem_wdata),
        .rdata          (mem_rdata),
        .rom_pin_0      (rom_pin_0),
        .rom_pin_1      (rom_pin_1),
        .rom_pin_2      (rom_pin_2),
        .rom_pin_3      (rom_pin_3)
    );

    //------------------------------------------------------------------------
    // Timeout Timer (30s auto-logout)
    //------------------------------------------------------------------------
    timeout_timer TIMER (
        .clk            (clk),
        .reset          (reset),
        .tick_10ms      (tick_10ms),
        .timer_reset    (timeout_reset),
        .expired        (timeout_expired)
    );

    //------------------------------------------------------------------------
    // LED Controller (separate module as per architecture)
    //------------------------------------------------------------------------
    led_controller LED_CTRL (
        .clk            (clk),
        .reset          (reset),
        .current_state  (current_state),
        .led_mode       (led_mode),
        .led_out        (led)
    );

    //------------------------------------------------------------------------
    // Seven Segment Display Controller
    //------------------------------------------------------------------------
    seven_seg_controller DISP (
        .clk            (clk),
        .reset          (reset),
        .display_mode   (display_mode),
        .display_data   (display_data),
        .current_state  (current_state),
        .seg            (seg),
        .dp             (dp),
        .an             (an)
    );

endmodule
