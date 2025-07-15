`timescale 1ns/1ps
module tb_maxpool1_layer;

    // ------------------------------------------------------------------
    // DUT parameters
    // ------------------------------------------------------------------
    localparam IMG_SIZE   = 24;
    localparam CHANNELS   = 2;
    localparam POOL_SIZE  = 2;
    localparam DATA_WIDTH = 16;
    localparam IN_PIXELS  = CHANNELS * IMG_SIZE * IMG_SIZE;   // 1152

    // ------------------------------------------------------------------
    // Testbench signals
    // ------------------------------------------------------------------
    reg  clk = 0;
    reg  reset_n = 0;
    reg  start_max1 = 0;
    reg  data_valid = 0;
    reg  signed [DATA_WIDTH-1:0] data_in = 0;

    wire finish_max1;
    wire result_valid;
    wire signed [DATA_WIDTH-1:0] data_out;

    // Pixel counter for display
    integer pooled_cnt = 0;

    // 50-MHz equivalent clock (period 20 ns)
    always #10 clk = ~clk;

    // ------------------------------------------------------------------
    // Device Under Test
    // ------------------------------------------------------------------
    maxpool_layer_1 #(
        .IMG_SIZE   (IMG_SIZE),
        .CHANNELS   (CHANNELS),
        .POOL_SIZE  (POOL_SIZE),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk         (clk),
        .reset_n     (reset_n),
        .start_max1  (start_max1),
        .data_valid  (data_valid),
        .data_in     (data_in),
        .finish_max1 (finish_max1),
        .result_valid(result_valid),
        .data_out    (data_out)
    );

    // ------------------------------------------------------------------
    // Stimulus + load all 1152 pixels once
    // ------------------------------------------------------------------
    integer i;
    initial begin
        // global reset
        reset_n = 0;
        repeat (3) @(posedge clk);
        reset_n = 1;

        // pulse start
        @(posedge clk);
        start_max1 <= 1;
        @(posedge clk);
        start_max1 <= 0;

        // feed 1 152 signed Q2.13 values
        for (i = 0; i < IN_PIXELS; i = i + 1) begin
            @(posedge clk);
            data_valid <= 1'b1;
            // random value in ?8192 .. +8191 (Q2.13 range)
            data_in <= $signed($urandom_range(0, 16383)) - 8192;
        end
        // de-assert data_valid
        @(posedge clk);
        data_valid <= 1'b0;

        // wait for pooler to finish
        wait (finish_max1);
        pooled_cnt <= 0;
        $display("=== MAXPOOL complete ? %0t ===", $time);
        #50;
        $stop;
    end

    // ------------------------------------------------------------------
    // Monitor pooled outputs
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (result_valid) begin
            $display("out[%0d] = %0d  (hex %04h)", pooled_cnt, data_out, data_out);
            pooled_cnt <= pooled_cnt + 1;
        end
    end

endmodule
