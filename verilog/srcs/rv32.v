module rv32 (
    input wire clk,
    input wire reset,
    output reg illegal_instr,
    input wire [15:0] gpio_in,
    output reg [15:0] gpio_out,
    output reg [15:0] gpio_dir,
    input wire ext_irq,
    output wire uart_tx,
    input wire uart_rx
);

    localparam CODE_BASE = 32'h0000_0000;
    localparam CODE_TOP = 32'h0000_1FFF;
    localparam DATA_BASE = 32'h0000_2000;
    localparam DATA_TOP = 32'h0000_3FFF;

    localparam GPIO_OUT_ADDR = 32'hF000_0000;
    localparam GPIO_IN_ADDR = 32'hF000_0004;
    localparam GPIO_DIR_ADDR = 32'hF000_0008;

    localparam UART_TX_ADDR = 32'hF000_0100;
    localparam UART_RX_ADDR = 32'hF000_0104;
    localparam UART_SR_ADDR = 32'hF000_0108;

    localparam TIMER0_MTIME_H = 32'hFFFF_0000;
    localparam TIMER0_MTIME_L = 32'hFFFF_0004;
    localparam TIMER0_MTIMECMP_H = 32'hFFFF_0008;
    localparam TIMER0_MTIMECMP_L = 32'hFFFF_000C;



    // machine mode CSRs
    reg [31:0] mstatus;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mie;
    wire [31:0] mip;
    reg [31:0] misa;
    reg [31:0] mhartid;
    reg [31:0] mvendorid;
    reg [31:0] marchid;
    reg [31:0] mimpid;
    reg [31:0] mtval;
    reg [31:0] mcounteren;

    initial begin
        mstatus    = 32'b0;
        mtvec      = 32'b0;
        mscratch   = 32'b0;
        mepc       = 32'b0;
        mcause     = 32'b0;
        mie        = 32'b0;
        misa       = 32'h40001100;
        mhartid    = 32'b0;
        mvendorid  = 32'b0;
        marchid    = 32'b0;
        mimpid     = 32'b0;
        mtval      = 32'b0;
        mcounteren = 32'b0;
    end

    // timer regs
    reg [63:0] timer0_mtime, timer0_mtimecmp;

    wire timer_irq = (timer0_mtime >= timer0_mtimecmp) ? 1'b1 : 1'b0; // to be implemented later

    assign mip = {20'b0, ext_irq, 3'b0, timer_irq, 3'b0, 1'b0, 3'b0};

    // type definitions
    localparam R_type = 3'b000, I_type = 3'b001, S_type = 3'b010, B_type = 3'b011, U_type = 3'b100, J_type = 3'b101;

    // opcode definitions
    localparam LOAD = 5'b00000, LOAD_FP = 5'b00001, MISC_MEM = 5'b00011, OP_IMM = 5'b00100, AUIPC = 5'b00101, 
               STORE = 5'b01000, STORE_FP = 5'b01001, AMO = 5'b01011, OP = 5'b01100, LUI = 5'b01101,
               MADD = 5'b10000, MSUB = 5'b10001, NMSUB = 5'b10010, NMADD = 5'b10011, OP_FP = 5'b10100,
               BRANCH = 5'b11000, JALR = 5'b11001, JAL = 5'b11011, SYSTEM = 5'b11100;

    localparam ADD = 5'b00000, SUB = 5'b00001, XOR = 5'b00010, OR = 5'b00011, AND = 5'b00100, SLL = 5'b00101, SRL = 5'b00110, SRA = 5'b00111, SLT = 5'b01000, SLTU = 5'b01001, MUL = 5'b01010, MULH = 5'b01011, MULHU = 5'b01100, MULHSU = 5'b01101, DIV = 5'b01110, DIVU = 5'b01111, REM = 5'b10000, REMU = 5'b10001;
    // pc, instruction mem, and instruction declaration
    reg [31:0] pc, pc_next;
    reg [31:0] mem [4095:0];
    initial $readmemh("program.hex", mem);
    wire [31:0] rdMem;
    wire [31:0] instruction;

    reg RegWrite, ALUSrc, MemRead, MemWrite;
    reg [4:0] ALUCtrl;
    reg [2:0] toReg;
    reg PCSrc;
    reg csr_write;

    wire interrupt_pending = mstatus[3] && |(mie & mip);

    reg [31:0] immGen;

    wire [4:0] opcode;
    assign opcode = instruction[6:2];

    reg [2:0] type;

    reg [31:0] alu, alu_in1, alu_in2;
    wire [31:0] mem_addr = alu;

    wire baud_tick_tx, baud_tick_rx;
    wire uart_tx_valid;
    wire [7:0] uart_tx_data, uart_rx_data;
    wire uart_tx_active, uart_tx_done;
    wire uart_rx_ready;

    assign uart_tx_valid = MemWrite && (mem_addr == UART_TX_ADDR);
    assign uart_tx_data  = rdReg2[7:0];

    wire is_uart_sr = (mem_addr == UART_SR_ADDR);
    wire is_uart_rx = (mem_addr == UART_RX_ADDR);

    uart_tx tx0 (
        .clk                (clk),
        .reset     (reset),
        .baud_tick (baud_tick_tx),
        .tx_start      (uart_tx_valid),
        .tx_data     (uart_tx_data),
        .tx_busy (uart_tx_active),
        .tx_line        (uart_tx),
        .tx_done    (uart_tx_done)
    );

    uart_rx rx0 (
        .clk                   (clk),
        .rst                 (reset),
        .rx                (uart_rx),
        .baud_tick_rx (baud_tick_rx),
        .data_valid  (uart_rx_ready),
        .data_out     (uart_rx_data)
    );

    baud_gen bgen0 (
        .clk          (clk),
        .rst          (reset),
        .baud_tick_tx (baud_tick_tx),
        .baud_tick_rx (baud_tick_rx)
    );

    reg uart_tx_done_latch;
    reg uart_rx_ready_latch;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_tx_done_latch  <= 0;
            uart_rx_ready_latch <= 0;
        end else begin
            if (uart_tx_done)
                uart_tx_done_latch  <= 1;
            if (uart_rx_ready)
                uart_rx_ready_latch <= 1;

            if (MemWrite && mem_addr == UART_SR_ADDR) begin
                if (rdReg2[1]) uart_tx_done_latch  <= 0;
                if (rdReg2[2]) uart_rx_ready_latch <= 0;
            end
        end
    end

    reg [7:0] uart_rx_latch;
    always @(posedge clk or posedge reset) begin
        if (reset)
            uart_rx_latch <= 0;
        else if (uart_rx_ready)
            uart_rx_latch <= uart_rx_data;
    end

    wire is_timer0_mtime_h = (mem_addr == TIMER0_MTIME_H);
    wire is_timer0_mtime_l = (mem_addr == TIMER0_MTIME_L);
    wire is_timer0_mtimecmp_h = (mem_addr == TIMER0_MTIMECMP_H);
    wire is_timer0_mtimecmp_l = (mem_addr == TIMER0_MTIMECMP_L);


    wire in_code_region = (mem_addr >= CODE_BASE && mem_addr <= CODE_TOP);
    wire in_data_region = (mem_addr >= DATA_BASE && mem_addr <= DATA_TOP);
    wire in_gpio        = (mem_addr == GPIO_OUT_ADDR || mem_addr == GPIO_DIR_ADDR);
    //wire in_uart        = (mem_addr == UART_TX_ADDR || mem_addr == UART_RDY_ADDR);
    wire in_timer       = (mem_addr >= TIMER0_MTIME_H && mem_addr <= TIMER0_MTIMECMP_L);

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

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            timer0_mtimecmp <= 64'hFFFFFFFFFFFFFFFF;
        end else if (MemWrite && in_timer) begin
            if (mem_addr == TIMER0_MTIMECMP_H)
                timer0_mtimecmp[63:32] <= rdReg2;
            else if (mem_addr == TIMER0_MTIMECMP_L)
                timer0_mtimecmp[31:0] <= rdReg2;
        end
        if (reset) begin
            timer0_mtime <= 64'b0;
        end else
            timer0_mtime <= timer0_mtime + 1;
    end

    // read from registers
    assign rdReg1 = regs[instruction[19:15]];
    assign rdReg2 = regs[instruction[24:20]];

    reg [31:0] csr_rdata;

    always @* begin
        case (instruction[31:20])
            12'h300: csr_rdata = mstatus;
            12'h305: csr_rdata = mtvec;
            12'h340: csr_rdata = mscratch;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            12'h304: csr_rdata = mie;
            12'h344: csr_rdata = mip;
            12'h301: csr_rdata = misa;
            12'hF14: csr_rdata = mhartid;
            12'hF11: csr_rdata = mvendorid;
            12'hF12: csr_rdata = marchid;
            12'hF13: csr_rdata = mimpid;
            12'h343: csr_rdata = mtval;
            12'h306: csr_rdata = mcounteren;
            default: csr_rdata = 32'b0;
        endcase
    end

    // write to registers
    assign wrReg = (toReg == 3'b000) ? alu :
                   (toReg == 3'b001) ? pc + 4 :
                   (toReg == 3'b010) ? rdMem :
                   (toReg == 3'b011) ? pc + immGen :
                   (toReg == 3'b100) ? immGen :
                   (toReg == 3'b101) ? csr_rdata :
                                       32'b0;

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

    reg [31:0] csr_wdata;

    always @* begin
        case (instruction[14:12])
            3'h1: csr_wdata = rdReg1;
            3'h2: csr_wdata = rdReg1 | csr_rdata;
            3'h3: csr_wdata = ~rdReg1 & csr_rdata;
            3'h5: csr_wdata = {27'b0, instruction[19:15]};
            3'h6: csr_wdata = {27'b0, instruction[19:15]} | csr_rdata;
            3'h7: csr_wdata = ~{27'b0, instruction[19:15]} & csr_rdata;
            default: csr_wdata = 32'b0;
        endcase
    end

    always @(posedge clk) begin
        if (interrupt_pending) begin
            mepc           <= pc;
            if (mie[11] & mip[11]) mcause <= 32'h8000000B;
            else if (mie[7] & mip[7]) mcause <= 32'h80000007;
            else mcause <= 32'h80000003;
            mstatus[7]     <= mstatus[3];    // save MIE to MPIE
            mstatus[3]     <= 1'b0;          // clear MIE
            mstatus[12:11] <= 2'b11;         // MPP = M-mode
        end else if (opcode == SYSTEM && instruction[14:12] == 3'h0) begin
            case (instruction[31:20])
                12'h000: begin
                    mepc  <= pc;
                    mcause <= 32'd11;
                    mstatus[7] <= mstatus[3];
                    mstatus[3] <= 1'b0;
                    mstatus[12:11] <= 2'b11;
                end
                12'h001: begin
                    mepc <= pc;
                    mcause <= 32'd3;
                    mstatus[7] <= mstatus[3];
                    mstatus[3] <= 1'b0;
                    mstatus[12:11] <= 2'b11;
                end
                12'h302: begin 
                    mstatus[3] <= mstatus[7];
                    mstatus[7] <= 1'b1;
                end
            endcase
        end else if (csr_write) begin
            case (instruction[31:20])
                12'h300: mstatus  <= csr_wdata;
                12'h304: mie      <= csr_wdata;
                12'h305: mtvec    <= csr_wdata;
                12'h340: mscratch <= csr_wdata;
                12'h341: mepc     <= csr_wdata & ~32'h3;
                12'h342: mcause   <= csr_wdata;
            endcase
        end
    end

    localparam INT_MIN = 32'h8000_0000;

    wire [63:0] mul_ss = $signed(alu_in1) * $signed(alu_in2);
    wire [63:0] mul_uu = {32'b0, alu_in1} * {32'b0, alu_in2};
    wire [63:0] mul_su = $signed(alu_in1) * {32'b0, alu_in2};

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
            MUL: alu = mul_ss[31:0];
            MULH: alu = mul_ss[63:32];
            MULHU: alu = mul_uu[63:32];
            MULHSU: alu = mul_su[63:32];
            DIV: begin
                if (alu_in2 == 0)
                    alu = 32'hFFFFFFFF;
                else if (alu_in1 == INT_MIN && alu_in2 == -1)
                    alu = INT_MIN;
                else
                    alu = $signed(alu_in1) / $signed(alu_in2);
            end
            DIVU: begin
                if (alu_in2 == 0)
                    alu = 32'hFFFFFFFF;
                else
                    alu = alu_in1 / alu_in2;
            end
            REM: begin
                if (alu_in2 == 0)
                    alu = alu_in1;
                else if (alu_in1 == INT_MIN && alu_in2 == -1)
                    alu = 32'b0;
                else
                    alu = $signed(alu_in1) % $signed(alu_in2);
            end
            REMU: begin
                if (alu_in2 == 0)
                    alu = alu_in1;
                else
                    alu = alu_in1 % alu_in2;
            end
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

    assign rdMem = !MemRead         ? 32'b0 :
               is_gpio_in           ? gpio_in :
               is_gpio_out          ? gpio_out :
               is_gpio_dir          ? gpio_dir :
               is_timer0_mtime_h    ? timer0_mtime[63:32] :
               is_timer0_mtime_l    ? timer0_mtime[31:0] :
               is_timer0_mtimecmp_h ? timer0_mtimecmp[63:32] :
               is_timer0_mtimecmp_l ? timer0_mtimecmp[31:0] :
               is_uart_rx           ? uart_rx_latch :
               is_uart_sr           ? {29'b0, uart_rx_ready_latch, uart_tx_done_latch, uart_tx_active} :
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
        if (interrupt_pending) begin
            pc_next = {mtvec[31:2], 2'b00};
        end else if ((opcode == BRANCH && PCSrc) || opcode == JAL) begin
            pc_next = pc + immGen;
        end else if (opcode == JALR) begin
            pc_next = (rdReg1 + immGen) & ~32'b1;
        end else if (opcode == SYSTEM && instruction[14:12] == 3'h0) begin
            case (instruction[31:20])
                12'h302: pc_next = {mepc[31:2], 2'b00};
                12'h105: pc_next = pc +4;
                default: pc_next = {mtvec[31:2], 2'b00};
            endcase
        end else begin
            pc_next = pc + 4;
        end
    end


    always @* begin
        RegWrite = 0;
        ALUSrc = 0;
        MemRead = 0;
        MemWrite = 0;
        ALUCtrl = ADD;
        toReg = 3'b000;
        PCSrc = 1'b0;
        illegal_instr = 0;
        csr_write = 0;

        case (opcode)
            OP: begin
                RegWrite = 1;

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
                    7'h01: begin
                        case (instruction[14:12])
                            3'h0: ALUCtrl = MUL;
                            3'h1: ALUCtrl = MULH;
                            3'h2: ALUCtrl = MULHSU;
                            3'h3: ALUCtrl = MULHU;
                            3'h4: ALUCtrl = DIV;
                            3'h5: ALUCtrl = DIVU;
                            3'h6: ALUCtrl = REM;
                            3'h7: ALUCtrl = REMU;
                        endcase
                    end
                    default: ALUCtrl = ADD;
                endcase
            end
            OP_IMM: begin
                RegWrite = 1;
                ALUSrc = 1;

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
                toReg = 3'b010;
            end
            STORE: begin
                ALUSrc = 1;
                MemWrite = 1;
            end
            BRANCH: begin
                case (instruction[14:12])
                    3'h0: PCSrc = eq;
                    3'h1: PCSrc = ~eq;
                    3'h4: PCSrc = lt;
                    3'h5: PCSrc = ~lt;
                    3'h6: PCSrc = ltu;
                    3'h7: PCSrc = ~ltu;
                    default: PCSrc = 1'b0;
                endcase
            end
            JAL: begin
                RegWrite = 1;
                toReg = 3'b001;
            end
            JALR: begin
                RegWrite = 1;
                ALUSrc = 1;
                toReg = 3'b001;
            end
            LUI: begin
                RegWrite = 1;
                toReg = 3'b100;
            end
            AUIPC: begin
                RegWrite = 1;
                toReg = 3'b011;
            end
            SYSTEM: begin
                case (instruction[14:12])
                    3'h1: begin
                        RegWrite = 1'b1;
                        csr_write = 1'b1;
                        toReg  = (instruction[11:7] == 5'b0)  ? 3'b000 : 3'b101;
                    end
                    3'h2: begin
                        RegWrite = 1'b1;
                        csr_write = (instruction[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        toReg = 3'b101;
                    end
                    3'h3: begin
                        RegWrite = 1'b1;
                        csr_write = (instruction[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        toReg = 3'b101;
                    end
                    3'h5: begin
                        RegWrite = 1'b1;
                        csr_write = 1'b1;
                        toReg  = (instruction[11:7] == 5'b0)  ? 3'b000 : 3'b101;
                    end
                    3'h6: begin
                        RegWrite = 1'b1;
                        csr_write = (instruction[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        toReg = 3'b101;
                    end
                    3'h7: begin
                        RegWrite = 1'b1;
                        csr_write = (instruction[19:15] == 5'b0) ? 1'b0 : 1'b1;
                        toReg = 3'b101;
                    end
                    3'h0: begin
                    end
                endcase
            end
            MISC_MEM: begin
                // nop
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
