`timescale 1ns / 1ps

module maxpool_layer_1 #(
    parameter IMG_SIZE = 24,
    parameter CHANNELS = 2,
    parameter POOL_SIZE = 2,
    parameter DATA_WIDTH = 16
)(
    input  wire clk,
    input  wire reset_n,
    input  wire start_max1,
    input  wire data_valid,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    output reg  finish_max1,
    output reg  result_valid,
    output reg  signed [DATA_WIDTH-1:0] data_out
);

    localparam IN_SIZE  = CHANNELS * IMG_SIZE * IMG_SIZE; // 1152

    (* ramstyle="M4K" *) reg signed [DATA_WIDTH-1:0] ram [0:IN_SIZE-1];
    reg [10:0] ram_addr; // enough for 2*24*24 = 1152
    reg [1:0] channel;
    reg [4:0] row, col; // 5 bits for 0-23
    reg stage;

    // FSM states
    localparam S_IDLE = 0, S_LOAD = 1, S_POOL = 2, S_OUT = 3;
    reg [2:0] state;

    // Pipelined registers for RAM outputs
    reg signed [DATA_WIDTH-1:0] d00_r, d01_r, d10_r, d11_r;
    
    //reg [8:0] out_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state        <= S_IDLE;
            stage        <= 0;
            finish_max1  <= 0;
            result_valid <= 0;
            channel      <= 0;
            row          <= 0;
            col          <= 0;
            ram_addr     <= 0;
            d00_r        <= 0;
            d01_r        <= 0;
            d10_r        <= 0;
            d11_r        <= 0;
				    data_out     <= 0;
				//out_count <= 9'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    finish_max1  <= 0;
                    // result_valid <= 0;
                    if (start_max1) begin
                        ram_addr <= 0;
                        state    <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (ram_addr < IN_SIZE) begin
                        if (ram_addr == 0) begin
                            ram[ram_addr] <= data_in;
                            ram_addr <= ram_addr + 1'b1;
                        end
                        if (!data_valid) begin
                            ram[ram_addr] <= data_in;
                            ram_addr <= ram_addr + 1'b1;
                        end
                    end else begin
                        channel  <= 0;
                        row      <= 0;
                        col      <= 0;
                        stage    <= 0;
                        state    <= S_POOL;
                    end
                end

                S_POOL: begin
                  if (!stage) begin
                    // Read from RAM, next cycle outputs are valid
                    d00_r <= ram[channel*IMG_SIZE*IMG_SIZE + row*IMG_SIZE + col];
                    d01_r <= ram[channel*IMG_SIZE*IMG_SIZE + row*IMG_SIZE + col + 1];
                    d10_r <= ram[channel*IMG_SIZE*IMG_SIZE + (row+1)*IMG_SIZE + col];
                    d11_r <= ram[channel*IMG_SIZE*IMG_SIZE + (row+1)*IMG_SIZE + col + 1];
                    stage <= 1'b1;
                    result_valid <= 1'b0;
                  end else begin
                    data_out <= (d00_r > d01_r ? d00_r : d01_r) >
                                (d10_r > d11_r ? d10_r : d11_r)
                                ? (d00_r > d01_r ? d00_r : d01_r)
                                : (d10_r > d11_r ? d10_r : d11_r);
                                
                    result_valid <= 1'b1;  
                    stage <= 1'b0;
                    //out_count <= out_count + 9'b1;
                       
                    // Step through window positions
                      if (col < IMG_SIZE - POOL_SIZE) begin
                        col <= col + POOL_SIZE;
                      end else begin
                        col <= 0;
                        if (row < IMG_SIZE - POOL_SIZE) begin
                            row <= row + POOL_SIZE;
                        end else begin
                            row <= 0;
                            if (channel < CHANNELS-1)
                              channel <= channel + 1'b1;
                            else begin
                              // all windows done
                              state <= S_OUT;
                            end
                        end
                      end
                  end
                end
					 
                S_OUT: begin
                    finish_max1 <= 1;
                    result_valid <= 1;
                    ram_addr     <= 0;      // ready for next load (fix #5)
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
