`timescale 1ns / 1ps

module cnn_top #(
    parameter IMG_SIZE = 28,
    parameter DATA_WIDTH = 16,
    parameter CONV1_OUT_CHANNELS = 2,
    parameter CONV2_OUT_CHANNELS = 3,
    parameter CONV1_KERNEL = 5,
    parameter CONV2_KERNEL = 3
)(
    input wire clk,
    input wire reset_n,
    input wire start,
    input wire data_valid,
	  input wire signed [DATA_WIDTH - 1 : 0] img_data_in,  // Data to write (if uploading image from host)
    input wire signed [DATA_WIDTH - 1 : 0] weights_conv1_in,
    input wire signed [DATA_WIDTH - 1 : 0] biases_conv1_in,
    input wire signed [DATA_WIDTH - 1 : 0] weights_conv2_in,
    input wire signed [DATA_WIDTH - 1 : 0] biases_conv2_in,
    input wire signed [DATA_WIDTH - 1 : 0] weights_fc_in,
    input wire signed [DATA_WIDTH - 1 : 0] biases_fc_in,
    output reg finish,
    output reg [3:0] class_out
);
	// ------------ memory depths -------------
	localparam CONV1_OUT_SIZE = 24;
	localparam MAXRELU1_OUT_SIZE = 12;
	localparam CONV2_OUT_SIZE = 10;
	localparam MAXRELU2_OUT_SIZE = 5;
	localparam FLATTEN_SIZE = 75;
	localparam FC_OUT_SIZE = 10;
	localparam IMG_PIXELS      = IMG_SIZE*IMG_SIZE; // 784
	localparam W1_WORDS        = CONV1_OUT_CHANNELS*CONV1_KERNEL*CONV1_KERNEL; // 50
	localparam B1_WORDS        = CONV1_OUT_CHANNELS; // 2
	localparam W2_WORDS        = CONV2_OUT_CHANNELS*CONV1_OUT_CHANNELS*CONV2_KERNEL*CONV2_KERNEL; // 54
	localparam B2_WORDS        = CONV2_OUT_CHANNELS; // 3
	localparam WFC_WORDS       = FLATTEN_SIZE*CONV2_OUT_SIZE;// 750 
	localparam BFC_WORDS       = FC_OUT_SIZE; // 10
	
	
    // === Wires ===
    wire signed [DATA_WIDTH - 1 : 0] conv1_out;
	  wire conv1_finish;
	   
	  wire signed [DATA_WIDTH - 1 : 0] max1_out;
	  wire max1_finish;
	 
    wire signed [DATA_WIDTH - 1 : 0] conv2_out;
	  wire conv2_finish;
	 
	  wire signed [DATA_WIDTH - 1 : 0] max2_out;
	  wire max2_finish;
	 
    wire signed [DATA_WIDTH - 1 : 0] fc_out;
	  wire fc_finish;
	 
	  wire argmax_finish;
    
    reg [3:0] state;
    wire [3:0] class_predict;
    
    // === FSM VARS ===
    localparam 	S_IDLE 		= 4'd0,
				S_CONV1 	= 4'd1,
				S_MAX1 	 	= 4'd2,
				S_CONV2 	= 4'd3,
				S_MAX2 	 	= 4'd4,
				S_FC 		= 4'd5,
				S_ARGMAX 	= 4'd6,
				S_FINISH 	= 4'd7;
							
		// === Data validation signals ===
		wire data_valid_conv1 = (state == S_CONV1);
		wire result_valid_conv1;
		wire result_valid_max1;
		wire result_valid_conv2;
		wire result_valid_max2;
		wire result_valid_fc;
		integer i;
    
		// === Instantiate modules ===
		wire start_conv1  = (state == S_CONV1);
		wire start_max1   = (state == S_MAX1);
		wire start_conv2  = (state == S_CONV2);
		wire start_max2   = (state == S_MAX2);
		wire start_fc     = (state == S_FC);
		wire start_argmax = (state == S_ARGMAX);
		
		// === Module instances ===
    conv_layer_1 cv1 (
        .clk(clk),
        .reset_n(reset_n),
        .start_conv1(start_conv1),
        .data_valid(data_valid),
        .partial_image_in(img_data_in),
        .partial_weights_in(weights_conv1_in),
        .partial_biases_in(biases_conv1_in),
        .finish_conv1(conv1_finish),
        .map(conv1_out),
        .result_valid(result_valid_conv1)
    );
    
    maxpool_layer_1 max1 (
        .clk(clk),
        .reset_n(reset_n),
        .start_max1(result_valid_conv1),
        .data_valid(result_valid_conv1),
        .data_in(conv1_out),
        .finish_max1(max1_finish),
        .result_valid(result_valid_max1),
        .data_out(max1_out)
    );
    
    conv_layer_2 cv2 (
        .clk(clk),
        .reset_n(reset_n),
        .start_conv2(conv1_finish),
        .data_valid(result_valid_max1),
        .partial_image_in(max1_out),
        .partial_weights_in(weights_conv2_in),
        .partial_biases_in(biases_conv2_in),
        .finish_conv2(conv2_finish),
        .map(conv2_out),
        .result_valid(result_valid_conv2)
    );
    
    maxpool_layer_2 max2 (
        .clk(clk),
        .reset_n(reset_n),
        .start_max2(result_valid_conv2),
        .data_valid(result_valid_conv2),
        .data_in(conv2_out),
        .finish_max2(max2_finish),
        .result_valid(result_valid_max2),
        .data_out(max2_out)
    );
    
    fc_layer fc (
			.clk(clk),
      .reset_n(reset_n),
      .start_fc(conv2_finish),
      .data_valid(result_valid_max2),

      // Serial input
      .map_in_serial(max2_out),
      .weight_serial(weights_fc_in),
      .bias_serial(biases_fc_in),

      // Output
      .finish_fc(fc_finish),
      .predict_out(fc_out),
      .predict_out_valid(result_valid_fc)
			);
	 
	 argmax_layer arg (
			.clk(clk),
			.reset_n(reset_n),
			.start_argmax(result_valid_fc),
			.data_valid(result_valid_fc),
      .class_in(fc_out),
		  .finish_argmax(argmax_finish),
      .index_out(class_predict)
    );
			
			
    
    // === FSM process ===
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_IDLE;
            class_out <= 0;
            finish <= 0;
        end else begin
            case (state)
                S_IDLE:   if (start) state <= S_CONV1;
                S_CONV1:  if (result_valid_conv1) state <= S_MAX1;
                S_MAX1:   if (result_valid_max1) state <= S_CONV2;
				        S_CONV2:  if (result_valid_conv2) state <= S_MAX2;
				        S_MAX2:   if (result_valid_max2) state <= S_FC;
                S_FC:     if (result_valid_fc) state <= S_ARGMAX;
				        S_ARGMAX:	if (argmax_finish) state <= S_FINISH;
                S_FINISH:   begin
					         class_out <= class_predict;
					         finish <= 1;
					         state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
        
endmodule
