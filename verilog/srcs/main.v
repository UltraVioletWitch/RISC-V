module main (
    input wire clk,
    input wire reset,
    inout wire [7:0] gpio
);

    wire [7:0] gpio_in, gpio_out, gpio_dir;


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
        for (i = 0; i < 8; i = i + 1) begin : gpio_buf
            IOBUF gpio_iobuf (
                .O (gpio_in[i]),
                .IO (gpio[i]),
                .I (gpio_out[i]),
                .T (~gpio_dir[i])
            );
        end
    endgenerate
    
    /*
   reg [26:0] counter;

   always @(posedge clk or posedge reset) begin
       if (reset)
           counter <= 0;
       else
           counter <= counter + 1;
   end

   genvar i;
   generate
       for (i = 0; i < 8; i = i + 1) begin : gpio_buf
           IOBUF gpio_iobuf (
               .O(gpio_in[i]),
               .IO(gpio[i]),
               .I(gpio_dir[i] ? gpio_out[i] : counter[i + 19]),
               .T(1'b0)
           );
       end
   endgenerate
   */

   /*
    IOBUF gpio_iobuf (
        .O (gpio_in[0]),
        .IO (gpio[0]),
        .I (1'b1),
        .T (1'b0)
    );
    */
endmodule
