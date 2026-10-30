`timescale 1ns / 1ps
//============================================================================
// Seven Segment Display Controller
// Updated with 5 menu items + Change PIN + Transaction Inquiry displays
// Display Modes:
//   0: Blank
//   1: PIN entry (shows "----")
//   2: Balance display (numeric)
//   3: Amount entry (numeric)
//   4: Menu options (5 items)
//   5: Error display ("Err")
//   6: Success display ("donE")
//   7: IDLE display ("IdLE")
//   8: User ID entry ("U_xx")
//   9: New PIN entry ("nPin")
//  10: Transaction history display (numeric)
//============================================================================

module seven_seg_controller(
    input             clk,
    input             reset,
    input      [ 3:0] display_mode,
    input      [15:0] display_data,
    input      [ 3:0] current_state,
    output reg [ 6:0] seg,
    output reg        dp,
    output reg [ 3:0] an
);

    reg [16:0] refresh_counter;
    wire [1:0] digit_select;
    reg [4:0] digit3, digit2, digit1, digit0;
    reg [4:0] current_digit;

    always @(posedge clk or posedge reset) begin
        if (reset)
            refresh_counter <= 17'd0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_select = refresh_counter[16:15];

    // BCD conversion
    wire [3:0] bcd_thou, bcd_hund, bcd_tens, bcd_ones;

    binary_to_bcd bcd_conv(
        .binary(display_data),
        .thousands(bcd_thou),
        .hundreds(bcd_hund),
        .tens(bcd_tens),
        .ones(bcd_ones)
    );

    // Char definitions
    localparam C_0 = 5'h00;
    localparam C_1 = 5'h01;
    localparam C_2 = 5'h02;
    localparam C_3 = 5'h03;
    localparam C_4 = 5'h04;
    localparam C_5 = 5'h05;
    localparam C_6 = 5'h06;
    localparam C_7 = 5'h07;
    localparam C_8 = 5'h08;
    localparam C_9 = 5'h09;
    localparam C_DASH = 5'h0A;
    localparam C_BLNK = 5'h0B;
    localparam C_A = 5'h0C;
    localparam C_b = 5'h0D;
    localparam C_C = 5'h0E;
    localparam C_d = 5'h0F;
    localparam C_E = 5'h10;
    localparam C_H = 5'h11;
    localparam C_L = 5'h12;
    localparam C_n = 5'h13;
    localparam C_o = 5'h14;
    localparam C_P = 5'h15;
    localparam C_r = 5'h16;
    localparam C_t = 5'h17;
    localparam C_U = 5'h18;

    // Digit content based on display mode
    always @(*) begin
        digit3 = C_BLNK;
        digit2 = C_BLNK;
        digit1 = C_BLNK;
        digit0 = C_BLNK;

        case (display_mode)
            4'd0: begin // Blank
                digit3 = C_BLNK; digit2 = C_BLNK; digit1 = C_BLNK; digit0 = C_BLNK;
            end

            4'd1: begin // PIN entry "----"
                digit3 = C_DASH; digit2 = C_DASH; digit1 = C_DASH; digit0 = C_DASH;
            end

            4'd2, 4'd3, 4'd10: begin // Balance / Amount / History
                digit3 = {1'b0, bcd_thou}; 
                digit2 = {1'b0, bcd_hund}; 
                digit1 = {1'b0, bcd_tens}; 
                digit0 = {1'b0, bcd_ones};
            end

            4'd4: begin // Menu display (6 items)
                case (display_data[2:0])
                    3'd0: begin // "bAL "
                        digit3 = C_b; digit2 = C_A; digit1 = C_L; digit0 = C_BLNK;
                    end
                    3'd1: begin // "dEP "
                        digit3 = C_d; digit2 = C_E; digit1 = C_P; digit0 = C_BLNK;
                    end
                    3'd2: begin // " Udr"
                        digit3 = C_BLNK; digit2 = C_U; digit1 = C_d; digit0 = C_r;
                    end
                    3'd3: begin // "HISt"
                        digit3 = C_H; digit2 = C_1; digit1 = C_5; digit0 = C_t;
                    end
                    3'd4: begin // "CPIn"
                        digit3 = C_C; digit2 = C_P; digit1 = C_1; digit0 = C_n;
                    end
                    3'd5: begin // "EHIt" -> Exit 
                        digit3 = C_E; digit2 = C_H; digit1 = C_1; digit0 = C_t;
                    end
                    default: begin
                        digit3 = C_BLNK; digit2 = C_BLNK; digit1 = C_BLNK; digit0 = C_BLNK;
                    end
                endcase
            end

            4'd5: begin // Error "Err "
                digit3 = C_E; digit2 = C_r; digit1 = C_r; digit0 = C_BLNK;
            end

            4'd6: begin // Success "donE"
                digit3 = C_d; digit2 = C_o; digit1 = C_n; digit0 = C_E;
            end

            4'd7: begin // IDLE "IdLE"
                digit3 = C_1; digit2 = C_d; digit1 = C_L; digit0 = C_E;
            end

            4'd8: begin // User ID "U_xx"
                digit3 = C_U; digit2 = C_DASH; digit1 = {1'b0, bcd_tens}; digit0 = {1'b0, bcd_ones};
            end

            4'd9: begin // New PIN entry "nPIn"
                digit3 = C_n; digit2 = C_P; digit1 = C_1; digit0 = C_n;
            end

            default: begin
                digit3 = C_BLNK; digit2 = C_BLNK; digit1 = C_BLNK; digit0 = C_BLNK;
            end
        endcase
    end

    // Digit multiplexer
    always @(*) begin
        case (digit_select)
            2'd0: begin an = 4'b1110; current_digit = digit0; end
            2'd1: begin an = 4'b1101; current_digit = digit1; end
            2'd2: begin an = 4'b1011; current_digit = digit2; end
            2'd3: begin an = 4'b0111; current_digit = digit3; end
            default: begin an = 4'b1111; current_digit = C_BLNK; end
        endcase
    end

    // Seven-segment decoder (active low)
    //   seg[6:0] = {g, f, e, d, c, b, a}
    always @(*) begin
        dp = 1'b1;
        case (current_digit)
            C_0: seg = 7'b100_0000;  // 0
            C_1: seg = 7'b111_1001;  // 1 (also I)
            C_2: seg = 7'b010_0100;  // 2
            C_3: seg = 7'b011_0000;  // 3
            C_4: seg = 7'b001_1001;  // 4
            C_5: seg = 7'b001_0010;  // 5 (also S)
            C_6: seg = 7'b000_0010;  // 6
            C_7: seg = 7'b111_1000;  // 7
            C_8: seg = 7'b000_0000;  // 8
            C_9: seg = 7'b001_0000;  // 9
            C_DASH: seg = 7'b011_1111;  // -
            C_BLNK: seg = 7'b111_1111;  // null
            C_A: seg = 7'b000_1000;  // A
            C_b: seg = 7'b000_0011;  // b
            C_C: seg = 7'b100_0110;  // C
            C_d: seg = 7'b010_0001;  // d
            C_E: seg = 7'b000_0110;  // E
            C_H: seg = 7'b000_1001;  // H (also used for x)
            C_L: seg = 7'b100_0111;  // L
            C_n: seg = 7'b010_1011;  // n
            C_o: seg = 7'b010_0011;  // o (small)
            C_P: seg = 7'b000_1100;  // P
            C_r: seg = 7'b010_1111;  // r
            C_t: seg = 7'b000_0111;  // t
            C_U: seg = 7'b100_0001;  // U
            default: seg = 7'b111_1111;
        endcase
    end

endmodule
