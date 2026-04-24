module cpu (
    input wire clk,
    input wire reset,
    output wire out
);

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
    reg [31:0] iMem [16383:0];
    reg [31:0] dMem [16383:0];
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

    // pc assignment with reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 0;
        end else begin
            pc <= pc_next;
        end
    end

    assign instruction = iMem[pc >> 2];

    // registers declaration
    reg [31:0] regs [31:0];

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

    wire [31:0] mem_addr = alu;

    always @(posedge clk) begin
        if (MemWrite)
            dMem[mem_addr >> 2] <= rdReg2;
    end

    assign rdMem = (MemRead) ? dMem[mem_addr >> 2] : 32'b0;


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
            end
        endcase
    end

    assign out = pc[28];
endmodule
