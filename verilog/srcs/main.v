module main (
    input wire clk,
    input wire reset,
    output wire led
);

    cpu core (
        .clk(clk),
        .reset(reset),
        .out(led)
    );

endmodule
