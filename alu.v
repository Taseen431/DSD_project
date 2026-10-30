`timescale 1ns / 1ps
//============================================================================
// Arithmetic Logic Unit (ALU) - STRUCTURAL IMPLEMENTATION
// Strict Datapath RTL logic mapped manually
//============================================================================

module alu(
    input      [15:0] a,           // Operand A 
    input      [15:0] b,           // Operand B 
    input      [ 2:0] alu_op,      // Operation Code
    output reg [15:0] result,      // 16-bit Result
    output reg        zero_flag,   // High if result is exactly zero
    output reg        negative_flag// High if result went negative (for unsiged A < B)
);

    localparam ALU_NOP     = 3'b000;
    localparam ALU_ADD     = 3'b001;
    localparam ALU_SUB     = 3'b010;
    localparam ALU_COMPARE = 3'b011;
    localparam ALU_EQUAL   = 3'b100;

    // Structural ALU Add/Sub Core
    // Extracts subtract/compare instructions to drive mode bit
    wire       mode = (alu_op == ALU_SUB || alu_op == ALU_COMPARE); 
    
    // Complement B if in subtraction mode (B XOR MODE)
    wire [15:0] b_mux = mode ? ~b : b; 
    
    // Manual Ripple Carry Adder Variables
    reg [16:0] adder_sum;
    reg [16:0] carries;
    integer i;

    always @(*) begin
        // Perform purely manual gate-level structural addition loop
        // No '+' or '-' mathematical operators are used!
        carries[0] = mode;
        for (i = 0; i < 16; i = i + 1) begin
            // 1-bit Full Adder logic
            adder_sum[i] = a[i] ^ b_mux[i] ^ carries[i];
            carries[i+1] = (a[i] & b_mux[i]) | (carries[i] & (a[i] ^ b_mux[i]));
        end
        adder_sum[16] = carries[16];

        case (alu_op)
            ALU_NOP: begin
                result = 16'd0;
                zero_flag = 1'b0;
                negative_flag = 1'b0;
            end
            
            ALU_ADD: begin
                result = adder_sum[15:0];
                zero_flag = (result == 16'd0);
                negative_flag = 1'b0;
            end
            
            ALU_SUB: begin
                result = adder_sum[15:0];
                zero_flag = (result == 16'd0);
                // In purely unsigned manual arithmetic: 
                // A + (~B) + 1 yields carry out == 1 if A >= B
                // Thus if CarryOut is 0, A < B, triggering a "negative" outcome.
                negative_flag = ~adder_sum[16]; 
            end
            
            ALU_COMPARE: begin
                // Result outputs exactly 1 if true (A >= B), 0 if false (A < B)
                result = {15'd0, adder_sum[16]}; 
                zero_flag = (adder_sum[15:0] == 16'd0);
                negative_flag = ~adder_sum[16]; 
            end
            
            ALU_EQUAL: begin
                // Structural Equalizer (XNOR reduction)
                result = {15'd0, &(~(a ^ b))};
                zero_flag = &(~(a ^ b));
                negative_flag = 1'b0;
            end
            
            default: begin
                result = 16'd0;
                zero_flag = 1'b0;
                negative_flag = 1'b0;
            end
        endcase
    end

endmodule
