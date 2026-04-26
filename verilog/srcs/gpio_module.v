module gpio_module (
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

/*
module IOBUF (
    input wire O,  // Output signal
    inout wire IO, // Bidirectional signal (inout)
    input wire I,  // Input signal
    input wire T   // Tri-state control signal
);
    assign IO = T ? 1'bz : I;  // If T is high, drive high impedance, otherwise drive input I
    assign O = IO;             // Output is driven by IO

endmodule
*/
