`timescale 1ns / 1ps

module tb_conv2_layer;
    parameter IN_CHANNELS = 2;   // Input channel number
    parameter OUT_CHANNELS = 3;	// Output channel number
    parameter IN_IMG_SIZE = 12;	// Input image size
	 parameter OUT_IMG_SIZE = 10;// Output image size
    parameter KERNEL_SIZE = 3; // Kernel size
    parameter DATA_WIDTH = 16;	// 32-bit width
    
	 localparam TOTAL_PIXELS  = IN_IMG_SIZE * IN_IMG_SIZE * IN_CHANNELS;
    localparam TOTAL_WEIGHTS = KERNEL_SIZE * KERNEL_SIZE * IN_CHANNELS * OUT_CHANNELS;
    localparam TOTAL_BIASES  = OUT_CHANNELS;
	 
    reg clk = 0;
    reg reset_n = 0;
    reg start_conv2 = 0;
	 reg data_valid = 0;
	 reg signed [DATA_WIDTH-1:0] partial_image_in;
    reg signed [DATA_WIDTH-1:0] partial_weights_in;
    reg signed [DATA_WIDTH-1:0] partial_biases_in;

    // Linear inputs
    wire finish_conv2;
    wire signed [DATA_WIDTH - 1 : 0] map;
	 wire result_valid;

    // RAMs Instantiate
    reg signed [DATA_WIDTH - 1 : 0] image_ram [0 : TOTAL_PIXELS - 1];
    reg signed [DATA_WIDTH - 1 : 0] weights_ram [0 : TOTAL_WEIGHTS - 1];
    reg signed [DATA_WIDTH - 1 : 0] biases_ram [0 : TOTAL_BIASES - 1];

    // DUT
    conv_layer_2 dut (
        .clk(clk),
        .reset_n(reset_n),
        .start_conv2(start_conv2),
        .data_valid(data_valid),
        .partial_image_in(partial_image_in),
        .partial_weights_in(partial_weights_in),
        .partial_biases_in(partial_biases_in),
        .finish_conv2(finish_conv2),
        .map(map),
        .result_valid(result_valid)
    );
  
    integer i=0;

    // Clock generation
    always #5 clk = ~clk;
	 
    initial begin
        // Reset
		  reset_n = 1'b0;
        #20 reset_n = 1'b1;

        // Load image, weights, biases
        $readmemh("C:/Users/Acer/Downloads/CNN-FPGA-Implementation-main/src/IntelHEX/wb16/img_in_for_conv2_16bit.hex", image_ram);
        $readmemh("C:/Users/Acer/Downloads/CNN-FPGA-Implementation-main/src/IntelHEX/wb16/conv2_weight_16.hex", weights_ram);
        $readmemh("C:/Users/Acer/Downloads/CNN-FPGA-Implementation-main/src/IntelHEX/wb16/conv2_bias_16.hex", biases_ram);

        // Start convolution
        // Start signal
        #10 start_conv2 = 1; #10 start_conv2 = 0;
        
		  // Send image data
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            @(posedge clk);
            data_valid <= 1;
            partial_image_in <= image_ram[i];
        end

        // Send weights
        for (i = 0; i < TOTAL_WEIGHTS; i = i + 1) begin
            @(posedge clk);
            data_valid <= 1;
            partial_weights_in <= weights_ram[i];
        end

        // Send biases
        for (i = 0; i < TOTAL_BIASES; i = i + 1) begin
            @(posedge clk);
            data_valid <= 1;
            partial_biases_in <= biases_ram[i];
        end
		  
		  @(posedge clk);
        data_valid <= 0;
		  
        // Wait for conv_done
        wait (finish_conv2);
        $display("Second Convolutional Layer done.");
		  #100 $stop;
    end
	 
	 always @(posedge clk) begin
        if (result_valid)
            $display("Result = %d", map);
    end

endmodule