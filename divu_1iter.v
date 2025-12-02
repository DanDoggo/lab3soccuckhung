`timescale 1ns / 1ns

module divu_1iter (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    input  wire [31:0] i_remainder,
    input  wire [31:0] i_quotient,
    
    output wire [31:0] o_dividend,
    output wire [31:0] o_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

    // Fix: Change 1'b1 to 32'd1 to match the 32-bit width of the signals
    wire [31:0] rem_shifted;
    assign rem_shifted = (i_remainder << 1) | ((i_dividend >> 31) & 32'd1);

    // Fix: Change 1'b1 to 32'd1 here as well
    assign o_remainder = (rem_shifted >= i_divisor) ? (rem_shifted - i_divisor) : rem_shifted;
    assign o_quotient  = (rem_shifted >= i_divisor) ? ((i_quotient << 1) | 32'd1) : (i_quotient << 1);

    assign o_dividend = i_dividend << 1;
    assign o_divisor = i_divisor;

endmodule
// IMPORTANT: Make sure there is an empty line here!
