`timescale 1ns/1ps

module argmax_layer #(
    parameter IN_SIZE = 10,
    parameter DATA_WIDTH = 16
)(
    input  wire clk,
    input  wire reset_n,
    input  wire start_argmax,
    input  wire data_valid,
    input  wire signed [DATA_WIDTH - 1 : 0] class_in,
    output reg finish_argmax,
    output reg [3:0] index_out // 4 bits for 10 digits 
);

    reg [3:0] i;
    reg [3:0] load_i;
	 localparam IDLE_STATE = 0;
	 localparam PREPARE_STATE = 1;
	 localparam PROCESS_STATE = 2;
	 localparam FINISH_STATE = 3;
	 reg [1:0] state;
	
    (* ramstyle="M4K" *) reg signed [DATA_WIDTH - 1 : 0] val_array [0 : IN_SIZE - 1];
    (* ramstyle="M4K" *) reg signed [DATA_WIDTH - 1 : 0] max_val;
    reg [3:0] max_idx;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            finish_argmax <= 0;
            index_out <= 0;
            max_val <= 0;
            max_idx <= 0;
            load_i <= 0;
            i <= 0;
            state <= IDLE_STATE;
        end else begin
            case (state)
                IDLE_STATE: begin // IDLE
                    finish_argmax <= 0;
                    if (start_argmax) begin
                        state <= PREPARE_STATE;
                    end
                end

                PREPARE_STATE: begin // PREPARE
                    if (data_valid) begin
                        if (load_i < IN_SIZE) begin
                            val_array[load_i] <= class_in[DATA_WIDTH - 1 : 0];
                            load_i <= load_i + 4'b1;
                        end 
                    end
                    if (load_i == IN_SIZE) begin
                      max_val <= val_array[0];
                      max_idx <= 0;
                      i <= 1;
                      state <= PROCESS_STATE;
                    end
                end

                PROCESS_STATE: begin // PROCESS
                    if (i < IN_SIZE) begin
                        if (val_array[i] > max_val) begin
                            max_val <= val_array[i];
                            max_idx <= i[3:0];
                        end
                        i <= i + 4'b1;
                    end else begin
                        index_out <= max_idx;
                        finish_argmax <= 1;
                        state <= FINISH_STATE;
                    end
                end

                FINISH_STATE: begin // FINISH
                    finish_argmax <= 0;
                    state <= IDLE_STATE;
                end
            endcase
        end
    end
endmodule
