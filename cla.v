`timescale 1ns / 1ps

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);

   // --- Aggregate Propagate ---
   assign pout = &pin;

   // --- Aggregate Generate ---
   assign gout = gin[3] | 
                 (pin[3] & gin[2]) | 
                 (pin[3] & pin[2] & gin[1]) | 
                 (pin[3] & pin[2] & pin[1] & gin[0]);
                 
   // --- Internal Carries ---
   assign cout[0] = gin[0] | (pin[0] & cin);
   
   assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   
   assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0]) | (pin[2] & pin[1] & pin[0] & cin);

endmodule

/** Same as gp4 but for an 8-bit window instead */
module gp8(input wire [7:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [6:0] cout);

   // --- Aggregate Propagate ---
   assign pout = &pin;

   // --- Aggregate Generate ---
   // For Group Generate, we DO include the pin corresponding to the gin 
   // strictly for the chain. Standard CLA formulation:
   assign gout = gin[7] |
                 (pin[7] & gin[6]) |
                 (pin[7] & pin[6] & gin[5]) |
                 (pin[7] & pin[6] & pin[5] & gin[4]) |
                 (pin[7] & pin[6] & pin[5] & pin[4] & gin[3]) |
                 (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & gin[2]) |
                 (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & gin[1]) |
                 (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0]);

   // --- Internal Carries (C1 to C7) ---
   // FIX: Ensure pin list stops at the bit *above* the gin index.
   
   assign cout[0] = gin[0] | (pin[0] & cin);
   
   assign cout[1] = gin[1] | 
                    (pin[1] & gin[0]) | 
                    (pin[1] & pin[0] & cin);
                  
   assign cout[2] = gin[2] |
                    (pin[2] & gin[1]) | 
                    (pin[2] & pin[1] & gin[0]) | 
                    (pin[2] & pin[1] & pin[0] & cin);

   assign cout[3] = gin[3] | 
                    (pin[3] & gin[2]) | 
                    (pin[3] & pin[2] & gin[1]) |
                    (pin[3] & pin[2] & pin[1] & gin[0]) | 
                    (pin[3] & pin[2] & pin[1] & pin[0] & cin);

   assign cout[4] = gin[4] | 
                    (pin[4] & gin[3]) | 
                    (pin[4] & pin[3] & gin[2]) |
                    (pin[4] & pin[3] & gin[2] & gin[1]) | 
                    (pin[4] & pin[3] & pin[2] & pin[1] & gin[0]) |
                    (pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);

   assign cout[5] = gin[5] | 
                    (pin[5] & gin[4]) |
                    (pin[5] & pin[4] & gin[3]) | 
                    (pin[5] & pin[4] & pin[3] & gin[2]) |
                    (pin[5] & pin[4] & pin[3] & pin[2] & gin[1]) |
                    (pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0]) |
                    (pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
                  
   // This was the specific problematic block in your screenshot
   assign cout[6] = gin[6] |
                    (pin[6] & gin[5]) | 
                    (pin[6] & pin[5] & gin[4]) |                       // <--- Corrected: Removed pin[4]
                    (pin[6] & pin[5] & pin[4] & gin[3]) | 
                    (pin[6] & pin[5] & pin[4] & pin[3] & gin[2]) |
                    (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & gin[1]) |
                    (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0]) |
                    (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
endmodule

module cla
  (input wire [31:0]  a, b,
   input wire         cin,
   output wire [31:0] sum);

   // --- Wires ---
   
   // Level 1: Bit-level g/p signals (32 of each)
   wire [31:0] g, p;
   
   // Level 2: Group g/p signals (8 of each, from gp4 to gp8)
   wire [7:0] g_from_gp4, p_from_gp4;
   
   // Level 3: Block carries (C4, C8, C12, C16, C20, C24, C28)
   wire [6:0] block_carries;
   
   // Internal carries from each gp4 (8 blocks x 3 carries each)
   wire [2:0] internal_carries [7:0];

   // Final stitched 32-bit carry bus
   wire [31:0] c;
   
   // XOR of A and B for final sum
   wire [31:0] p_xor = a ^ b;


   // --- Generate Loops ---
   
   genvar i;
   generate
     // --- Level 1: 32 gp1 Modules ---
     for (i = 0; i < 32; i = i + 1) begin : gen_gp1
       gp1 u_gp1 (
         .a(a[i]),
         .b(b[i]),
         .g(g[i]),
         .p(p[i])
       );
     end

     // --- Level 2: 8 gp4 Modules ---
     for (i = 0; i < 8; i = i + 1) begin : gen_gp4
       localparam base = i * 4;
       gp4 u_gp4 (
         .gin(g[base + 3 : base]),
         .pin(p[base + 3 : base]),
         .cin( (i == 0) ? cin : block_carries[i-1] ), // Use main cin for 1st block
         
         .gout(g_from_gp4[i]),
         .pout(p_from_gp4[i]),
         .cout(internal_carries[i])
       );
     end
     
     // --- Stitch Carry Bus ---
     assign c[0] = cin;
     for (i = 0; i < 8; i = i + 1) begin : gen_stitch_carries
       localparam base = i * 4;
       
       // Internal carries from gp4
       assign c[base+1] = internal_carries[i][0];
       assign c[base+2] = internal_carries[i][1];
       assign c[base+3] = internal_carries[i][2];
       
       // Block carries from gp8 (except for the last block)
       if (i < 7) begin : gen_block_carry_connect // <--- Add this label
         assign c[base+4] = block_carries[i];
       end
     end
   endgenerate

   // --- Level 3: 1 gp8 Module ---
   // Calculates the carries *between* the 4-bit blocks
   /* verilator lint_off PINCONNECTEMPTY */
   gp8 u_gp8 (
     .gin(g_from_gp4),
     .pin(p_from_gp4),
     .cin(cin),
     
     .gout(), // Not needed
     .pout(), // Not needed
     .cout(block_carries) // Outputs C4, C8, C12...
   );
   /* verilator lint_on PINCONNECTEMPTY */

   // --- Final Sum Calculation ---
   // S[i] = (A[i] ^ B[i]) ^ C[i]
   assign sum = p_xor ^ c;

endmodule
