//==============================================================
//  Top-level wrapper for DE1/DE2   – drives all LEDs
//==============================================================
module fpga_top (
    input  wire CLOCK_50,
    input  wire [1:0] SW,       // SW0 = reset_n   SW1 = start
    output wire [9:0] LEDR,
    output wire [7:0] LEDG,
    output wire [6:0] HEX0
);
    //----------------------------------------------------------
    //  Control & status wires
    //----------------------------------------------------------
    wire reset_n = SW[0];
    wire start   = SW[1];
    wire finish;
    wire [3:0] class_out;

    //----------------------------------------------------------
    //  CNN core
    //----------------------------------------------------------
    cnn_top cnn_inst (
        .clk       (CLOCK_50),
        .reset_n   (reset_n),
        .start     (start),
        .finish    (finish),
        .class_out (class_out)
    );

    //----------------------------------------------------------
    //  LED assignments
    //----------------------------------------------------------
    assign LEDR[1:0] = SW[1:0];       // echo switches
    assign LEDR[5:2] = class_out;     // show predicted digit
    assign LEDR[9:6] = 4'b1;          // UNUSED ? drive ‘0’

    assign LEDG[0]   = finish;        // green0 = inference done
    assign LEDG[7:1] = 7'b1;          // UNUSED greens cleared

    //----------------------------------------------------------
    //  Seven-segment display (active-low segments)
    //----------------------------------------------------------
    hex_decoder hex_disp (
        .in      (class_out),
        .hex_out (HEX0)
    );
endmodule


//==============================================================
//  7-segment decoder  (HEX segments are active-low on DE boards)
//==============================================================
module hex_decoder (
    input  wire [3:0] in,
    output reg  [6:0] hex_out   // {g,f,e,d,c,b,a}
);
    always @* begin
        case (in)
            4'h0: hex_out = 7'b100_0000;
            4'h1: hex_out = 7'b111_1001;
            4'h2: hex_out = 7'b010_0100;
            4'h3: hex_out = 7'b011_0000;
            4'h4: hex_out = 7'b001_1001;
            4'h5: hex_out = 7'b001_0010;
            4'h6: hex_out = 7'b000_0010;
            4'h7: hex_out = 7'b111_1000;
            4'h8: hex_out = 7'b000_0000;
            4'h9: hex_out = 7'b001_0000;
            4'hA: hex_out = 7'b000_1000;
            4'hB: hex_out = 7'b000_0011;
            4'hC: hex_out = 7'b100_0110;
            4'hD: hex_out = 7'b010_0001;
            4'hE: hex_out = 7'b000_0110;
            4'hF: hex_out = 7'b000_1110;
            default: hex_out = 7'b111_1111;   // all segments off
        endcase
    end
endmodule
