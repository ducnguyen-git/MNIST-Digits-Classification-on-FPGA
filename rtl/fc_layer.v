`timescale 1ns / 1ps

module fc_layer #(
    parameter IN_SIZE = 75,
    parameter OUT_SIZE = 10,
    parameter DATA_WIDTH = 16
)(
    input  wire clk,
    input  wire reset_n,
    input  wire start_fc,
    input  wire data_valid,

    // Serial input
    input  wire signed [DATA_WIDTH-1:0] map_in_serial,
    input  wire signed [DATA_WIDTH-1:0] weight_serial,
    input  wire signed [DATA_WIDTH-1:0] bias_serial,

    // Output
    output reg finish_fc,
    output reg signed [DATA_WIDTH-1:0] predict_out,
    output reg predict_out_valid
);

    // === Internal arrays ===
    (* ramstyle="M4K" *) reg signed [DATA_WIDTH-1:0] map_in_ram [0:IN_SIZE-1];
    (* ramstyle="M4K" *) reg signed [DATA_WIDTH-1:0] weights_ram [0:IN_SIZE*OUT_SIZE-1];
    (* ramstyle="M4K" *) reg signed [DATA_WIDTH-1:0] biases_ram [0:OUT_SIZE-1];

    // FSM states
    localparam IDLE       = 2'd0,
               LOAD_DATA  = 2'd1,
               COMPUTE    = 2'd2,
               FINISH     = 2'd3;

    reg [1:0] state;
    reg [6:0] map_in_counter;   // 7 bits store 75 values
    reg [9:0] weight_counter;   // 10 bits store 750 values
    reg [3:0] bias_counter;     // 4 bits store 10 values

    // Compute phase counters
    reg [3:0] out_idx;
    reg [6:0] in_idx;
    reg signed [DATA_WIDTH*2-1:0] accum; 
    wire signed [DATA_WIDTH*2-1:0] shift_accum;
    
    assign shift_accum = (predict_out_valid) ? accum >>> 13 : shift_accum; // Q2.13 ? Qm.n

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            finish_fc <= 0;
            predict_out <= 0;
            predict_out_valid <= 0;
            map_in_counter <= 0;
            weight_counter <= 0;
            bias_counter <= 0;
            out_idx <= 0;
            in_idx <= 0;
            accum <= 0;
        end else begin
            case (state)
                IDLE: begin
                    finish_fc <= 0;
                    predict_out_valid <= 0;
                    if (start_fc) begin
                        map_in_counter <= 0;
                        weight_counter <= 0;
                        bias_counter <= 0;
                        state <= LOAD_DATA;
                    end
                end

                LOAD_DATA: begin
                    // Serial load each RAM
                  if (data_valid) begin
                    if (map_in_counter < IN_SIZE) begin
                        map_in_ram[map_in_counter] <= map_in_serial;
                        map_in_counter <= map_in_counter + 7'b1;
                    end else if (weight_counter < IN_SIZE*OUT_SIZE) begin
                        weights_ram[weight_counter] <= weight_serial;
                        weight_counter <= weight_counter + 10'b1;
                    end else if (bias_counter < OUT_SIZE) begin
                        biases_ram[bias_counter] <= bias_serial;
                        bias_counter <= bias_counter + 4'b1;
                    end
                  end

                    // Check if all loaded
                    if (map_in_counter == IN_SIZE && weight_counter == IN_SIZE*OUT_SIZE && bias_counter == OUT_SIZE) begin
                        out_idx <= 0;
                        in_idx <= 0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    //----------------------------------------------------------
                    // 1. Combinational math
                    //----------------------------------------------------------                    // Include bias on the very first input
                    accum  <= (in_idx == 0) 
                                    ? (biases_ram[out_idx] + map_in_ram[in_idx] * weights_ram[out_idx*IN_SIZE + in_idx]) 
                                    : (accum + map_in_ram[in_idx] * weights_ram[out_idx*IN_SIZE + in_idx]);

                    //----------------------------------------------------------
                    // 2. Register updates (one write per signal)
                    //----------------------------------------------------------

                      predict_out <= shift_accum[DATA_WIDTH-1:0];
                      predict_out_valid  <= 1'b1;

                    //--------------------------------------------------
                    // 3. Step to next neuron or finish layer
                    //--------------------------------------------------
                    if (in_idx == IN_SIZE-1) begin
                      // Last multiply-add for this neuron
                      if (out_idx == OUT_SIZE-1) begin
                        state   <= FINISH;
                      end else begin
                        out_idx <= out_idx + 1;
                        in_idx  <= 0;
                      end
                    end else begin
                    // More inputs to process for this neuron
                      in_idx            <= in_idx + 1;
                      predict_out_valid <= 1'b0;
                    end
                end

                FINISH: begin
                    predict_out <= shift_accum[DATA_WIDTH-1:0];
                    finish_fc <= 1;
                    predict_out_valid <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

