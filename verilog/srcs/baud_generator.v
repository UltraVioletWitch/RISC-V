module baud_generator #(
    parameter CLOCK_RATE         = 12000000,
    parameter BAUD_RATE          = 9600,
    parameter RX_OVERSAMPLE_RATE = 16
)(
    input wire clk,
    output reg rxClk,
    output reg txClk
);

    localparam RX_ACC_MAX = CLOCK_RATE / (2 * BAUD_RATE * RX_OVERSAMPLE_RATE);
    localparam RX_ACC_MAX = CLOCK_RATE / (2 * BAUD_RATE);
    localparam RX_ACC_WIDTH = $clog2(RX_ACC_MAX);
    localparam TX_ACC_WIDTH = $clog2(TX_ACC_MAX);

    reg [RX_ACC_WIDTH-1:-] rx_counter = 0;
    reg [TX_ACC_WIDTH-1:-] tx_counter = 0;

    initial begin
        rxClk = 1'b0;
        txClk = 1'b0;
    end

    always @(posedge clk) begin
        // rx clock
        if (rx_counter == RX_ACC_MAX[RX_ACC_WIDTH-1:0]) begin
            rx_counter <= 0;
            rxClk      <= ~rxClk;
        end else begin
            rx_counter <= rx_counter + 1'b1;
        end

        // tx clock
        if (tx_counter == TX_ACC_MAX[RX_ACC_WIDTH-1:0]) begin
            tx_counter <= 0;
            txClk      <= ~txClk;
        end else begin
            tx_counter <= tx_counter + 1'b1;
        end
    end

endmodule
