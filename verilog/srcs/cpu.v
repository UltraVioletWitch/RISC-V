module cpu (
    input wire clk,
    input wire reset,
    output reg [31:0] bus
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bus <= 0;
        end else begin
            bus <= bus + 1;
        end
    end

endmodule
