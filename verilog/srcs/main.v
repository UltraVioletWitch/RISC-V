module main (
    input wire clk,
    input wire reset,
    output wire led
);

    wire [31:0] bus;

    cpu core (
        .clk(clk),
        .reset(reset),
        .out(led)
    );

endmodule
