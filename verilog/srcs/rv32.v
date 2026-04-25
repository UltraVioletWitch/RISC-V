module rv32 (
    input wire clk,
    input wire reset,
    output reg illegal_instr,
    input wire [15:0] gpio_in,
    output reg [15:0] gpio_out,
    output reg [15:0] gpio_dir,
);

    localparam CODE_BASE = 32'h0000_0000;
    localparam CODE_TOP = 32'h0000_1FFF;
    localparam DATA_BASE = 32'h0000_2000;
    localparam DATA_TOP = 32'h0000_3FFF;

    localparam GPIO_OUT_ADDR = 32'hF000_0000;
    localparam GPIO_IN_ADDR = 32'hF000_0004;
    localparam GPIO_DIR_ADDR = 32'hF000_0008;

    localparam UART_BASE = 32'hFF00_0000;

    // type definitions
    localparam R_type = 3'b000, I_type = 3'b001, S_type = 3'b010, B_type = 3'b011, U_type = 3'b100, J_type = 3'b101;

    // opcode definitions
    localparam LOAD = 5'b00000, LOAD_FP = 5'b00001, MISC_MEM = 5'b00011, OP_IMM = 5'b00100, AUIPC = 5'b00101, 
               STORE = 5'b01000, STORE_FP = 5'b01001, AMO = 5'b01011, OP = 5'b01100, LUI = 5'b01101,
               MADD = 5'b10000, MSUB = 5'b10001, NMSUB = 5'b10010, NMADD = 5'b10011, OP_FP = 5'b10100,
               BRANCH = 5'b11000, JALR = 5'b11001, JAL = 5'b11011, SYSTEM = 5'b11100;

    localparam ADD = 4'b0000, SUB = 4'b0001, XOR = 4'b0010, OR = 4'b0011, AND = 4'b0100, SLL = 4'b0101, SRL = 4'b0110, SRA = 4'b0111, SLT = 4'b1000, SLTU = 4'b1001;
    // pc, instruction mem, and instruction declaration
    reg [31:0] pc, pc_next;
    reg [31:0] mem [4095:0];
    initial $readmemh("program.hex", mem);
    wire [31:0] rdMem;
    wire [31:0] instruction;

    reg RegWrite, ALUSrc, MemRead, MemWrite;
    reg [3:0] ALUCtrl;
    reg [2:0] toReg;
    reg PCSrc;

    reg [31:0] immGen;

    wire [4:0] opcode;
    assign opcode = instruction[6:2];

    reg [2:0] type;

    reg [31:0] alu, alu_in1, alu_in2;
    wire [31:0] mem_addr = alu;

    wire in_code_region = (mem_addr >= CODE_BASE && mem_addr <= CODE_TOP);
    wire in_data_region = (mem_addr >= DATA_BASE && mem_addr <= DATA_TOP);
    wire in_gpio        = (mem_addr == GPIO_OUT_ADDR || mem_addr == GPIO_DIR_ADDR);
    wire in_uart        = (mem_addr == UART_BASE);

    // pc assignment with reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 0;
        end else begin
            pc <= pc_next;
        end
    end

    assign instruction = mem[pc >> 2];

    // registers declaration
    reg [31:0] regs [31:0];
    initial regs[0] = 32'b0;

    // instruction registers declaration
    wire [31:0] rdReg1, rdReg2, wrReg;

    // read from registers
    assign rdReg1 = regs[instruction[19:15]];
    assign rdReg2 = regs[instruction[24:20]];

    // write to registers
    assign wrReg = (toReg == 3'b000) ? alu :
                   (toReg == 3'b001) ? pc + 4 :
                   (toReg == 3'b010) ? rdMem :
                   (toReg == 3'b011) ? pc + immGen :
                                       immGen;
    always @(posedge clk) begin
        if (RegWrite && instruction[11:7] != 5'b0) begin
            if (opcode == LOAD)
                case (instruction[14:12])
                    3'h0: begin
                        case (mem_addr[1:0])
                            2'b00: regs[instruction[11:7]] <= {{24{rdMem[7]}}, rdMem[7:0]};
                            2'b01: regs[instruction[11:7]] <= {{24{rdMem[15]}}, rdMem[15:8]};
                            2'b10: regs[instruction[11:7]] <= {{24{rdMem[23]}}, rdMem[23:16]};
                            2'b11: regs[instruction[11:7]] <= {{24{rdMem[31]}}, rdMem[31:24]};
                        endcase
                    end
                    3'h1: begin
                        if (mem_addr[1])
                            regs[instruction[11:7]] <= {{16{rdMem[31]}}, rdMem[31:16]};
                        else
                            regs[instruction[11:7]] <= {{16{rdMem[15]}}, rdMem[15:0]};
                    end
                    3'h2: regs[instruction[11:7]] <= rdMem;
                    3'h4: begin
                        case (mem_addr[1:0])
                            2'b00: regs[instruction[11:7]] <= {24'b0, rdMem[7:0]};
                            2'b01: regs[instruction[11:7]] <= {24'b0, rdMem[15:8]};
                            2'b10: regs[instruction[11:7]] <= {24'b0, rdMem[23:16]};
                            2'b11: regs[instruction[11:7]] <= {24'b0, rdMem[31:24]};
                        endcase
                    end
                    3'h5: begin
                        if (mem_addr[1])
                            regs[instruction[11:7]] <= {16'b0, rdMem[31:16]};
                        else
                            regs[instruction[11:7]] <= {16'b0, rdMem[15:0]};
                    end
                endcase
            else
                regs[instruction[11:7]] <= wrReg;
        end
    end

    always @* begin
        alu_in1 = (opcode == AUIPC) ? pc : rdReg1;
        if (ALUSrc) begin
            alu_in2 = immGen;
        end else begin
            alu_in2 = rdReg2;
        end

        case (ALUCtrl)
            AND: alu = alu_in1 & alu_in2;
            OR: alu = alu_in1 | alu_in2;
            ADD: alu = alu_in1 + alu_in2;
            XOR: alu = alu_in1 ^ alu_in2;
            SLL: alu = alu_in1 << alu_in2[4:0];
            SRL: alu = alu_in1 >> alu_in2[4:0];
            SUB: alu = alu_in1 - alu_in2;
            SRA: alu = $signed(alu_in1) >>> alu_in2[4:0];
            SLT: alu = ($signed(alu_in1) < $signed(alu_in2)) ? 1 : 0;
            SLTU: alu = (alu_in1 < alu_in2) ? 1 : 0;
            default: alu = alu_in1 + alu_in2;
        endcase
    end

    always @(posedge clk) begin
        if (MemWrite && in_data_region) begin
            case (instruction[14:12])
                3'h0: begin
                    case (mem_addr[1:0])
                        2'b00: mem[mem_addr >> 2][7:0] <= rdReg2[7:0];
                        2'b01: mem[mem_addr >> 2][15:8] <= rdReg2[7:0];
                        2'b10: mem[mem_addr >> 2][23:16] <= rdReg2[7:0];
                        2'b11: mem[mem_addr >> 2][31:24] <= rdReg2[7:0];
                    endcase
                end
                3'h1: begin
                    if (mem_addr[1])
                        mem[mem_addr >> 2][31:16] <= rdReg2[15:0];
                    else
                        mem[mem_addr >> 2][15:0] <= rdReg2[15:0];
                end
                3'h2: mem[mem_addr >> 2]       <= rdReg2;
            endcase
        end else if (MemWrite && in_gpio) begin
            if (mem_addr == GPIO_OUT_ADDR)
                gpio_out <= rdReg2;
            else if(mem_addr == GPIO_DIR_ADDR)
                gpio_dir <= rdReg2;
        end else if (MemWrite && in_code_region) begin
            illegal_instr <= 1;
        end
    end

    wire is_gpio_out = (mem_addr == GPIO_OUT_ADDR);
    wire is_gpio_in  = (mem_addr == GPIO_IN_ADDR);
    wire is_gpio_dir = (mem_addr == GPIO_DIR_ADDR);
    wire is_gpio     = is_gpio_out | is_gpio_in | is_gpio_dir;
    assign rdMem = !MemRead    ? 32'b0 :
               is_gpio_in  ? gpio_in :
               is_gpio_out ? gpio_out :
               is_gpio_dir ? gpio_dir :
                             mem[mem_addr >> 2];

    always @* begin
        case (type)
            I_type: immGen = {{20{instruction[31]}}, instruction[31:20]};
            S_type: immGen = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            B_type: immGen = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            U_type: immGen = {instruction[31:12], 12'b0};
            J_type: immGen = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:25], instruction[24:21], 1'b0};
            default: immGen = 32'b0;
        endcase
    end

    always @* begin
        case (opcode)
            OP:     type = R_type;
            OP_IMM: type = I_type;
            LOAD:   type = I_type;
            STORE:  type = S_type;
            BRANCH: type = B_type;
            JAL:    type = J_type;
            JALR:   type = I_type;
            LUI:    type = U_type;
            AUIPC:  type = U_type;
            SYSTEM: type = I_type;
            default: type = R_type;
        endcase
    end

    wire eq = (rdReg1 == rdReg2);
    wire lt = ($signed(rdReg1) < $signed(rdReg2));
    wire ltu = (rdReg1 < rdReg2);

    always @* begin
        RegWrite = 0;
        ALUSrc = 0;
        MemRead = 0;
        MemWrite = 0;
        ALUCtrl = ADD;
        toReg = 3'b000;
        PCSrc = 1'b0;
        pc_next = pc + 4;
        illegal_instr = 0;

        case (opcode)
            OP: begin
                RegWrite = 1;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                toReg = 3'b000;

                case (instruction[31:25])
                    7'h00: begin
                        case (instruction[14:12])
                            3'h0: ALUCtrl = ADD;
                            3'h1: ALUCtrl = SLL;
                            3'h2: ALUCtrl = SLT;
                            3'h3: ALUCtrl = SLTU;
                            3'h4: ALUCtrl = XOR;
                            3'h5: ALUCtrl = SRL;
                            3'h6: ALUCtrl = OR;
                            3'h7: ALUCtrl = AND;
                        endcase
                    end
                    7'h20: begin
                        case (instruction[14:12])
                            3'h0: ALUCtrl = SUB;
                            3'h5: ALUCtrl = SRA;
                            default: ALUCtrl = ADD;
                        endcase
                    end
                    default: ALUCtrl = ADD;
                endcase
            end
            OP_IMM: begin
                RegWrite = 1;
                ALUSrc = 1;
                MemRead = 0;
                MemWrite = 0;
                toReg = 3'b000;

                case (instruction[14:12])
                    3'h0: ALUCtrl = ADD;
                    3'h1: ALUCtrl = SLL;
                    3'h2: ALUCtrl = SLT;
                    3'h3: ALUCtrl = SLTU;
                    3'h4: ALUCtrl = XOR;
                    3'h5: begin
                        if (instruction[30] == 1)
                            ALUCtrl = SRA;
                        else
                            ALUCtrl = SRL;
                    end
                    3'h6: ALUCtrl = OR;
                    3'h7: ALUCtrl = AND;
                endcase
            end
            LOAD: begin
                RegWrite = 1;
                ALUSrc = 1;
                MemRead = 1;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b010;
            end
            STORE: begin
                RegWrite = 0;
                ALUSrc = 1;
                MemRead = 0;
                MemWrite = 1;
                ALUCtrl = ADD;
                toReg = 3'b000;
            end
            BRANCH: begin
                RegWrite = 0;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                toReg = 3'b000;

                case (instruction[14:12])
                    3'h0: PCSrc = eq;
                    3'h1: PCSrc = ~eq;
                    3'h4: PCSrc = lt;
                    3'h5: PCSrc = ~lt;
                    3'h6: PCSrc = ltu;
                    3'h7: PCSrc = ~ltu;
                    default: PCSrc = 1'b0;
                endcase

                if (PCSrc)
                    pc_next = pc + immGen;
                else
                    pc_next = pc + 4;
            end
            JAL: begin
                RegWrite = 1;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b001;
                pc_next = pc + immGen;
            end
            JALR: begin
                RegWrite = 1;
                ALUSrc = 1;
                MemRead = 0;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b001;
                pc_next = (rdReg1 + immGen) & ~32'b1;
            end
            LUI: begin
                RegWrite = 1;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b100;
            end
            AUIPC: begin
                RegWrite = 1;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b011;
            end
            SYSTEM: begin
                RegWrite = 0;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b000;
            end
            default: begin
                RegWrite = 0;
                ALUSrc = 0;
                MemRead = 0;
                MemWrite = 0;
                ALUCtrl = ADD;
                toReg = 3'b000;

                illegal_instr = 1;
            end
        endcase
    end
endmodule
