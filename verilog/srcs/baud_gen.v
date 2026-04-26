module baud_gen #(
    parameter CLOCK_RATE         = 12000000,
    parameter BAUD_RATE          = 115200
)(
    input wire clk,
    input wire reset,
    output reg baud_tick,
    output reg baud_tick_16x
);

    localparam CLKS_PER_BIT = CLOCK_RATE / BAUD_RATE;
    localparam CLKS_PER_16X = CLOCK_RATE / (BAUD_RATE * 16);

    localparam CNT_BITS    = $clog2(CLKS_PER_BIT);
    localparam CNT_16X_BITS = $clog2(CLKS_PER_16X);

    reg [CNT_BITS-1:0]    cnt_baud;
    reg [CNT_16X_BITS-1:0] cnt_16x;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt_baud      <= 0;
            cnt_16x       <= 0;
            baud_tick     <= 0;
            baud_tick_16x <= 0;
        end else begin
            baud_tick     <= 0;
            baud_tick_16x <= 0;

            if (cnt_16x == CLKS_PER_16X - 1) begin
                cnt_16x       <= 0;
                baud_tick_16x <= 1;
            end else
                cnt_16x <= cnt_16x + 1;

            if (cnt_baud == CLKS_PER_BIT - 1) begin
                cnt_baud  <= 0;
                baud_tick <= 1;
            end else
                cnt_baud <= cnt_baud + 1;
        end
    end

    // synthesis-time sanity checks
    initial begin
        if (CLKS_PER_BIT < 4) begin
            $error("baud_gen: CLKS_PER_BIT=%0d too small, increase CLK_FREQ or decrease BAUD_RATE",
                   CLKS_PER_BIT);
        end
        if (CLKS_PER_16X < 1) begin
            $error("baud_gen: CLKS_PER_16X=%0d too small for 16x oversampling at this CLK_FREQ/BAUD_RATE",
                   CLKS_PER_16X);
        end
        $display("baud_gen: CLK=%0d BAUD=%0d CLKS_PER_BIT=%0d CLKS_PER_16X=%0d",
                 CLOCK_RATE, BAUD_RATE, CLKS_PER_BIT, CLKS_PER_16X);
        $display("baud_gen: actual baud = %0d (error = %0d%%)",
                 CLOCK_RATE / CLKS_PER_BIT,
                 ((CLOCK_RATE / CLKS_PER_BIT - BAUD_RATE) * 100) / BAUD_RATE);
    end

endmodule
