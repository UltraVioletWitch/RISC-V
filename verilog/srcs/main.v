module main (
    input wire clk,
    input wire reset,
    inout wire [15:0] gpio
);

    wire [15:0] gpio_in, gpio_out, gpio_dir;


    cpu core (
        .clk(clk),
        .reset(reset),
        .out(),
        .illegal_instr(),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir)
    );

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gpio_buf
            IOBUF gpio_iobuf (
                .O (gpio_in[i]),
                .IO (gpio[i]),
                .I (gpio_out[i]),
                .T (~gpio_dir[i])
            );
        end
    endgenerate
endmodule
