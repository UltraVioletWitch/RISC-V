module uart_rx #(
    parameter DATA_BITS = 8
)(
    input  wire clk,
    input  wire rst,

    input  wire rx,              // serial input
    input  wire baud_tick_rx,   // 16x baud tick enable

    output reg  [DATA_BITS-1:0] data_out,
    output reg  data_valid
);

    // State encoding
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state = IDLE;

    reg [3:0] tick_cnt = 0;   // counts 0-15 (16x oversampling)
    reg [2:0] bit_idx  = 0;   // 0-7 data bits
    reg [DATA_BITS-1:0] rx_shift = 0;

    // synchronize rx (basic 2-flop sync for metastability protection)
    reg rx_meta, rx_sync;

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            tick_cnt   <= 0;
            bit_idx    <= 0;
            rx_shift   <= 0;
            data_out   <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0; // default pulse

            if (baud_tick_rx) begin
                case (state)

                    //--------------------------------------------------
                    // IDLE: wait for start bit (falling edge)
                    //--------------------------------------------------
                    IDLE: begin
                        tick_cnt <= 0;
                        bit_idx  <= 0;

                        if (rx_sync == 1'b0) begin
                            state <= START;
                            tick_cnt <= 0;
                        end
                    end

                    //--------------------------------------------------
                    // START bit validation (sample middle)
                    //--------------------------------------------------
                    START: begin
                        if (tick_cnt == 7) begin
                            // confirm still low (valid start bit)
                            if (rx_sync == 1'b0)
                                state <= DATA;
                            else
                                state <= IDLE;
                        end

                        tick_cnt <= tick_cnt + 1;
                    end

                    //--------------------------------------------------
                    // DATA bits (LSB first)
                    //--------------------------------------------------
                    DATA: begin
                        if (tick_cnt == 15) begin
                            tick_cnt <= 0;

                            // sample in middle of bit (around tick 7-8 region)
                            rx_shift[bit_idx] <= rx_sync;

                            if (bit_idx == DATA_BITS-1) begin
                                state <= STOP;
                            end else begin
                                bit_idx <= bit_idx + 1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end

                    //--------------------------------------------------
                    // STOP bit
                    //--------------------------------------------------
                    STOP: begin
                        if (tick_cnt == 15) begin
                            data_out   <= rx_shift;
                            data_valid <= 1'b1;
                            state      <= IDLE;
                            tick_cnt   <= 0;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end

                endcase
            end
        end
    end

endmodule
