`timescale 1ns/1ps
module tb_maxpool2_layer;

    // ------------------------------------------------------------------
    // DUT parameters
    // ------------------------------------------------------------------
    localparam IMG_SIZE   = 10;
    localparam CHANNELS   = 3;
    localparam POOL_SIZE  = 2;
    localparam DATA_WIDTH = 16;
    localparam IN_PIXELS  = CHANNELS * IMG_SIZE * IMG_SIZE;   // 300

    // ------------------------------------------------------------------
    // Testbench signals
    // ------------------------------------------------------------------
    reg  clk = 0;
    reg  reset_n = 0;
    reg  start_max2 = 0;
    reg  data_valid = 0;
    reg  signed [DATA_WIDTH-1:0] data_in = 0;

    wire finish_max2;
    wire result_valid;
    wire signed [DATA_WIDTH-1:0] data_out;

    // Pixel counter for display
    integer pooled_cnt = 0;

    // 50-MHz equivalent clock (period 20 ns)
    always #10 clk = ~clk;

    // ------------------------------------------------------------------
    // Device Under Test
    // ------------------------------------------------------------------
    maxpool_layer_2 #(
        .IMG_SIZE   (IMG_SIZE),
        .CHANNELS   (CHANNELS),
        .POOL_SIZE  (POOL_SIZE),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk         (clk),
        .reset_n     (reset_n),
        .start_max2  (start_max2),
        .data_valid  (data_valid),
        .data_in     (data_in),
        .finish_max2 (finish_max2),
        .result_valid(result_valid),
        .data_out    (data_out)
    );

    // ------------------------------------------------------------------
    // Stimulus + load all 300 pixels once
    // ------------------------------------------------------------------
    integer i;
    initial begin
        // global reset
        reset_n = 0;
        repeat (3) @(posedge clk);
        reset_n = 1;

        // pulse start
        @(posedge clk);
        start_max2 <= 1;
        @(posedge clk);
        start_max2 <= 0;

        // feed 300 signed Q2.13 values
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
        wait (finish_max2);
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
