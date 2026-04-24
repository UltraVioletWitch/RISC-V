// Project F: Hello Arty F - Top
// (C)2020 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module main (
    input wire clk,
    output reg [3:0] led
    );

    reg [31:0] cnt = 0;  // 32-bit counter

    always @(posedge clk) begin
        cnt <= cnt + 1;
        led[0] <= cnt[26];
        led[1] <= cnt[24];
        led[2] <= cnt[22];
        led[3] <= cnt[20];
    end
endmodule
