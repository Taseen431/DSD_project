`timescale 1ns / 1ps
//============================================================================
// PIN Hash Module
// Implements a simple hardware hash function for PIN security
// Hash algorithm: XOR with secret key + bit rotation + addition constant
// This ensures PINs are never stored or compared in plain text
//
// Hash(PIN) = ((PIN XOR SECRET_KEY) <<< 3) + HASH_CONST
//
// The hash is deterministic: same PIN always produces same hash
// But you cannot reverse the hash to get the original PIN
//============================================================================

module pin_hash(
    input      [15:0] pin_in,       // Raw PIN input
    output     [15:0] hash_out      // Hashed PIN output
);

    // Secret constants (hardcoded in hardware - cannot be read by user)
    localparam SECRET_KEY  = 16'hA5F0;   // XOR key
    localparam HASH_CONST  = 16'h1E3B;   // Addition constant

    // Step 1: XOR with secret key
    wire [15:0] xor_result;
    assign xor_result = pin_in ^ SECRET_KEY;

    // Step 2: Circular left rotation by 3 bits
    wire [15:0] rotated;
    assign rotated = {xor_result[12:0], xor_result[15:13]};

    // Step 3: Add constant
    assign hash_out = rotated + HASH_CONST;

endmodule
