module gpio (
    input wire [15:0] gpio_in,
    input wire [15:0] gpio_out,
    input wire [15:0] gpio_dir,
    inout [15:0] gpio
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
