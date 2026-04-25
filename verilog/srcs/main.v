module main (
    input wire clk,
    input wire reset,
    inout wire [15:0] gpio
);

    wire [15:0] gpio_in, gpio_out, gpio_dir;

    rv32 core (
        .clk(clk),
        .reset(reset),
        .illegal_instr(),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
    );

    gpio_module gpio_mod1 (
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .gpio(gpio)
    );

endmodule
