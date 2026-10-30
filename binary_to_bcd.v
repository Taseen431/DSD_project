`timescale 1ns / 1ps
//============================================================================
// Binary to BCD Converter (Double Dabble Algorithm)
//============================================================================

module binary_to_bcd(
    input      [15:0] binary,
    output reg [ 3:0] thousands,
    output reg [ 3:0] hundreds,
    output reg [ 3:0] tens,
    output reg [ 3:0] ones
);

    integer i;
    reg [31:0] scratch;

    always @(*) begin
        scratch = 32'd0;
        scratch[15:0] = binary;

        for (i = 0; i < 16; i = i + 1) begin
            if (scratch[19:16] >= 5) scratch[19:16] = scratch[19:16] + 3;
            if (scratch[23:20] >= 5) scratch[23:20] = scratch[23:20] + 3;
            if (scratch[27:24] >= 5) scratch[27:24] = scratch[27:24] + 3;
            if (scratch[31:28] >= 5) scratch[31:28] = scratch[31:28] + 3;
            scratch = scratch << 1;
        end

        ones      = scratch[19:16];
        tens      = scratch[23:20];
        hundreds  = scratch[27:24];
        thousands = scratch[31:28];
    end

endmodule
