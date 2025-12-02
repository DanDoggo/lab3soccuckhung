`timescale 1ns / 1ns

// divider_unsigned.v
module divider_unsigned (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

    // Wire arrays to connect the 32 stages.
    // Index 0 holds the initial inputs.
    // Indices 1-32 hold the outputs of each stage.
    wire [31:0] dividend_chain  [32:0];
    wire [31:0] divisor_chain   [32:0];
    wire [31:0] remainder_chain [32:0];
    wire [31:0] quotient_chain  [32:0];

    // --- INITIALIZATION (Input to the 1st stage) ---
    assign dividend_chain[0]  = i_dividend;
    assign divisor_chain[0]   = i_divisor;
    assign remainder_chain[0] = 32'b0;      // Initial remainder is 0
    assign quotient_chain[0]  = 32'b0;      // Initial quotient is 0

    // --- GENERATE LOOP (Instantiate 32 stages) ---
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_div_stages
            divu_1iter u_iter (
                .i_dividend  (dividend_chain[i]),
                .i_divisor   (divisor_chain[i]),
                .i_remainder (remainder_chain[i]),
                .i_quotient  (quotient_chain[i]),
                
                .o_dividend  (dividend_chain[i+1]),
                .o_divisor   (divisor_chain[i+1]),
                .o_remainder (remainder_chain[i+1]),
                .o_quotient  (quotient_chain[i+1])
            );
        end
    endgenerate

    // --- FINAL OUTPUT (Output of the 32nd stage) ---
    assign o_remainder = remainder_chain[32];
    assign o_quotient  = quotient_chain[32];

endmodule

