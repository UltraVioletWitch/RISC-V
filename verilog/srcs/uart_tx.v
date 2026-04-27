module uart_tx (
    input  wire       clk,        // System Clock
    input  wire       reset,    // Active Low Reset
    input  wire       baud_tick,  // Pulse active for 1 clk cycle at desired baud rate
    input  wire       tx_start,   // Pulse high to start transmission
    input  wire [7:0] tx_data,    // 8-bit data to send
    output reg        tx_line,    // Serial TX output
    output reg        tx_busy,     // High when transmission is in progress
    output reg        tx_done
);

    // State Encoding
    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    reg [1:0] state, next_state;
    reg [2:0] bit_idx;
    reg [7:0] tx_buffer;

    // FSM State Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            tx_line   <= 1'b1; // Idle high
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            bit_idx   <= 3'b0;
            tx_buffer <= 8'b0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                IDLE: begin
                    tx_line <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_buffer  <= tx_data;
                        tx_busy    <= 1'b1;
                        state      <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        tx_line <= 1'b0; // Start bit
                        state   <= DATA;
                        bit_idx <= 3'b0;
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        tx_line <= tx_buffer[bit_idx];
                        if (bit_idx == 7)
                            state <= STOP;
                        else
                            bit_idx <= bit_idx + 1;
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        tx_line <= 1'b1; // Stop bit
                        state   <= IDLE;
                        tx_done <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule

