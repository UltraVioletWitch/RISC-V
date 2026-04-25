module uart_rx (
    input wire clk,
    input wire en,
    input wire in,
    output reg busy,
    output reg done,
    output reg err,
    output reg [7:0] out
);

    localparam RESET = 3'b000, IDLE = 3'b001, START_BIT = 3'b010, DATA_BITS = 3'b011, STOP_BIT = 3'b100, READY = 3'b101;

    reg [2:0] state          = RESET;
    reg [1:0] in_reg         = 2'b0;
    reg [4:0] in_hold_reg    = 5'b0;
    reg [3:0] sample_count   = 4'b0;
    reg [4:0] out_hold_count = 5'b0;
    reg [2:0] bit_index      = 3'b0;
    reg [7:0] received_data  = 8'b0;
    wire in_sample;
    wire [3:0] in_prior_hold_reg;
    wire [3:0] in_current_hold_reg;

    always @(posedge clk) begin
        in_reg <= { in_reg[0], in };
    end

    assign in_sample = in_reg[1];

    always @(posedge clk) begin
        in_hold_reg <= { in_hold_reg[3:1], in_sample, in_reg[0] };
    end

    assign in_prior_hold_reg   = in_hold_reg[4:1];
    assign in_current_hold_reg = in_hold_reg[3:0];

    always @(posedge clk) begin
        if (|out_hold_count) begin
            out_hold_count <= out_hold_count + 5'b1;
            if (out_hold_count == 5'b10000) begin
                out_hold_count <= 5'b0;
                done           <= 1'b0;
                out            <= 8'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!en) begin
            state <= RESET;
        end
    end

    always @(posedge clk) begin
        case (state)
            RESET: begin
                sample_count <= 4'b0;
                out_hold_count <= 5'b0;
                received_data <= 8'b0;

                busy <= 1'b0;
                done <= 1'b0;

                if (en && err && !in_sample) begin
                    err <= 1'b1;
                end else begin
                    err <= 1'b0;
                end

                out <= 8'b0;

                if (en) begin
                    state <= IDLE'
                end
            end

            IDLE: begin
                if (!in_sample) begin
                    if (sample_count == 4'b0)
                        if (&in_prior_hold_reg || done && !err) begin
                            sample_count <= 4'b1;
                            err          <= 1'b0;
                        end else begin
                            err <= 1'b1;
                        end 
                    end else begin
                        sample_count <= sample_count + 4'b1;
                        if (sample_count == 4'b1100) begin
                            sample_count <= 4'b0100;
                            busy <= 1'b1;
                            err <= 1'b0;
                            state <= START_BIT;
                        end
                    end
                end else if (|sample_count) begin
                    sample_count <= 4'b0;
                    received_data <= 8'b0;
                    err <= 1'b1;
                end
            end

            START_BIT: begin
                sample_count <= sample_count + 4'b1;
                if (&sample_count) begin
                    bit_index <= 3'b1;
                    received_data <= {in_sample, 7'b0 };
                    out <= 8'b0;
                    state <= DATA_BITS;
                end
            end

            DATA_BITS: begin
                sample_count <= sample_count + 4'b1;
                if (&sample_count) begin
                    received_data <= { in_sample, received_data[7:1] };

                    bit_index <= bit_index + 3'b1;
                    if (&bit_index) begin
                        state <= STOP_BIT;
                    end
                end
            end

            STOP_BIT: begin
                sample_count <= sample_count + 4'b1;
                if (sample_count[3]) begin
                    if (!in_sample) begin
                        if (sample_count == 4'b1000 && &in_prior_hold_reg) begin
                            sample_count <= 4'b0;
                            out_hold_count <= 5'b1;
                            done <= 1'b1;
                            out <= received_data;
                            state <= IDLE;
                        end
                    end else begin
                        if (&in_current_hold_reg) begin
                            sample_count <= 4'b0;
                            done <= 1'b1;
                            out <= received_data;
                            state <= READY;
                        end else if (&sample_count) begin
                            sample_count <= 4'b0;
                            err <= 1'b1;
                            state <= READY;
                        end
                    end
                end
            end

            READY: begin
                sample_count <= sample_count + 4'b1;
                if (!err && !in_sample || &sample_count) begin
                    if (&sample_count) begin
                        if (in_sample) begin
                            received_data <= 8'b0;
                            busy          <= 1'b0;
                        end else begin
                            sample_count <= 4'b1;
                        end
                        done <= 1'b0;
                        out <= 8'b0;
                        state <= IDLE;
                    end else begin
                        sample_count <= 4'b1;
                        out_hold_count <= sample_count + 5'b00010;
                        state <= IDLE;
                    end
                end else if (&sample_count[3:1]) begin
                    if (err || !in_sample) begin
                        state <= RESET;
                    end
                end
            end

            default: begin
                state <= RESET;
            end
        endcase
    end
endmodule
