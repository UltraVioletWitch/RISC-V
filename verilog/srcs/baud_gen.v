module baud_gen #(
    parameter integer N = 32,
    parameter CLK_FREQ = 12_000_000,
    parameter OVERSAMPLE = 16,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input wire rst,
    output reg baud_tick_tx,
    output wire baud_tick_rx
);
    localparam real INC_REAL = 
        (BAUD_RATE * OVERSAMPLE * (2.0**N)) / CLK_FREQ;
    localparam integer INC = INC_REAL;

    initial begin
        $display("baud_gen: INC=%0d acc overflow at %0d ticks",
                INC, (1<<N)/INC);
        if (INC == 0)
            $error("baud_gen: INC is 0 - check CLK_FREQ and BAUD_RATE parameters");
    end

    reg [N-1:0] acc;

    wire [N-1:0] acc_next = acc + INC;
    wire overflow = acc_next < acc;

    always @(posedge clk) begin
        if (rst)
            acc <= 0;
        else
            acc <= acc_next;
    end

    assign baud_tick_rx = overflow;

    reg [3:0] tx_count;

    always @(posedge clk) begin
        if (rst) begin
            tx_count <= 0;
            baud_tick_tx <= 0;
        end else begin
            baud_tick_tx <= 0;

            if (overflow) begin
                tx_count <= tx_count + 1;

                if (tx_count == 4'd15) begin
                    tx_count <= 0;
                    baud_tick_tx <= 1'b1;
                end
            end
        end
    end

endmodule

