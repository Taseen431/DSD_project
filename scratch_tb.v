module tb;
    reg [15:0] a, b;
    reg [2:0] alu_op;
    wire [15:0] result;
    wire zero, neg;
    
    alu uut(.a(a), .b(b), .alu_op(alu_op), .result(result), .zero_flag(zero), .negative_flag(neg));
    
    initial begin
        a = 16'h9111;
        b = 16'h3000;
        alu_op = 3'b011; // ALU_COMPARE
        #1;
        $display("a=%h, b=%h, a>=b=%b (hex format unsigned)", a, b, a>=b);
        $display("neg=%b, result=%h", neg, result);
        
        alu_op = 3'b010; // ALU_SUB
        #1;
        $display("result=%h", result);
        
        a = 16'd9111;
        b = 16'd3000;
        alu_op = 3'b011;
        #1;
        $display("a=%d, b=%d, neg=%b", a, b, neg);
        $finish;
    end
endmodule
