module RISCVCPU (
    input clock,
    input reset,
    output reg halt
);

    // Instruction opcodes
    localparam LW    = 7'b000_0011;
    localparam SW    = 7'b010_0011;
    localparam BEQ   = 7'b110_0011;
    localparam ALUop = 7'b001_0011; // used here as ADDI-style immediate ALU operation
    localparam HALT_OP = 7'b0001011; 

    localparam NOP  = 32'h0000_0013;
    localparam HALT = 32'h0000_000B;

    localparam NO_FORWARD  = 2'b00;
    localparam FROM_MEM    = 2'b01;
    localparam FROM_WB_ALU = 2'b10;
    localparam FROM_WB_LD  = 2'b11;

    reg [31:0] PC;
    reg [31:0] Regs[0:31];

    // Separate instruction and data memories
    reg [31:0] IMemory[0:1023];
    reg [31:0] DMemory[0:1023];

    // Pipeline registers
    reg [31:0] IFIDIR;
    reg [31:0] IDEXIR;
    reg [31:0] EXMEMIR;
    reg [31:0] MEMWBIR;

    reg [31:0] IFIDPC;
    reg [31:0] IDEXPC;

    reg [31:0] IDEXA;
    reg [31:0] IDEXB;
    reg [31:0] EXMEMB;
    reg [31:0] EXMEMALUOut;
    reg [31:0] MEMWBValue;

    // Register fields
    wire [4:0] IFIDrs1;
    wire [4:0] IFIDrs2;
    wire [4:0] IDEXrs1;
    wire [4:0] IDEXrs2;
    wire [4:0] EXMEMrd;
    wire [4:0] MEMWBrd;

    // Opcodes
    wire [6:0] IDEXop;
    wire [6:0] EXMEMop;
    wire [6:0] MEMWBop;

    // ALU inputs after forwarding
    wire [31:0] Ain;
    wire [31:0] Bin;

    wire [1:0] forwardA;
    wire [1:0] forwardB;

    wire stall;
    wire branch_taken;
    wire flush;
    wire [31:0] branch_target;

    wire instr_commit;

    integer i;

    assign IFIDrs1 = IFIDIR[19:15];
    assign IFIDrs2 = IFIDIR[24:20];

    assign IDEXop  = IDEXIR[6:0];
    assign IDEXrs1 = IDEXIR[19:15];
    assign IDEXrs2 = IDEXIR[24:20];

    assign EXMEMop = EXMEMIR[6:0];
    assign EXMEMrd = EXMEMIR[11:7];

    assign MEMWBop = MEMWBIR[6:0];
    assign MEMWBrd = MEMWBIR[11:7];

    ForwardingUnit forwarding_unit (
        .idex_rs1(IDEXrs1),
        .idex_rs2(IDEXrs2),
        .exmem_rd(EXMEMrd),
        .memwb_rd(MEMWBrd),
        .exmem_op(EXMEMop),
        .memwb_op(MEMWBop),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );

    HazardDetectionUnit hazard_unit (
        .idex_rs1(IDEXrs1),
        .idex_rs2(IDEXrs2),
        .exmem_rd(EXMEMrd),
        .idex_op(IDEXop),
        .exmem_op(EXMEMop),
        .stall(stall)
    );

    assign Ain =
        (forwardA == FROM_MEM)    ? EXMEMALUOut :
        (forwardA == FROM_WB_ALU) ? MEMWBValue  :
        (forwardA == FROM_WB_LD)  ? MEMWBValue  :
        IDEXA;

    assign Bin =
        (forwardB == FROM_MEM)    ? EXMEMALUOut :
        (forwardB == FROM_WB_ALU) ? MEMWBValue  :
        (forwardB == FROM_WB_LD)  ? MEMWBValue  :
        IDEXB;

    BranchUnit branch_unit (
        .pc_ex(IDEXPC),
        .rs1_value(Ain),
        .rs2_value(Bin),
        .instruction(IDEXIR),
        .branch_taken(branch_taken),
        .branch_target(branch_target)
    );

    assign flush = branch_taken;

    assign instr_commit =
        (MEMWBIR != NOP) && 
        ((MEMWBop == LW) || 
        (MEMWBop == SW) || 
        (MEMWBop == ALUop) ||
         (MEMWBop == BEQ));

    PipelineStats stats (
        .clock(clock),
        .reset(reset),
        .instr_commit(instr_commit),
        .stall(stall),
        .bypassA_MEM(forwardA == FROM_MEM),
        .bypassB_MEM(forwardB == FROM_MEM),
        .bypassA_WB((forwardA == FROM_WB_ALU) || (forwardA == FROM_WB_LD)),
        .bypassB_WB((forwardB == FROM_WB_ALU) || (forwardB == FROM_WB_LD)),
        .branch_taken(branch_taken),
        .flush(flush),
        .cycle_count(),
        .instr_count(),
        .stall_count(),
        .bypass_count(),
        .branch_taken_count(),
        .flush_count()
    );

    wire [31:0] imm_i;
    wire [31:0] imm_s;

    assign imm_i = {{20{IDEXIR[31]}}, IDEXIR[31:20]};
    assign imm_s = {{20{IDEXIR[31]}}, IDEXIR[31:25], IDEXIR[11:7]};

// Lembre-se de que TODAS essas ações acontecem em cada estágio do pipeline e com o uso de <= elas acontecem em paralelo!
    always @(posedge clock) begin
        if (reset) begin
            PC <= 32'd0;

            IFIDIR  <= NOP;
            IDEXIR  <= NOP;
            EXMEMIR <= NOP;
            MEMWBIR <= NOP;

            IFIDPC <= 32'd0;
            IDEXPC <= 32'd0;

            IDEXA <= 32'd0;
            IDEXB <= 32'd0;
            EXMEMB <= 32'd0;
            EXMEMALUOut <= 32'd0;
            MEMWBValue <= 32'd0;

            halt <= 0;

            for (i = 0; i < 32; i = i + 1) begin
                Regs[i] <= 32'd0;
            end
        end
        else if (!halt) begin

        if (MEMWBop == HALT_OP) begin
            halt <= 1'b1;
        end
        else begin
            // IF, ID and EX stages
            if (~stall) begin
                if (branch_taken) begin
                    PC <= branch_target;

                    // Flush younger instructions in IF/ID and ID/EX.
                    // The branch itself is allowed to advance to EX/MEM.
                    IFIDIR <= NOP;
                    IDEXIR <= NOP;

                    IFIDPC <= 32'd0;
                    IDEXPC <= 32'd0;

                    EXMEMIR <= IDEXIR;
                    EXMEMB <= Bin;
                    EXMEMALUOut <= 32'd0;
                end
                else begin
                    // IF stage
                    IFIDIR <= IMemory[PC >> 2];
                    IFIDPC <= PC;
                    PC <= PC + 32'd4;

                    // ID stage
                    IDEXA <= Regs[IFIDrs1];
                    IDEXB <= Regs[IFIDrs2];
                    IDEXIR <= IFIDIR;
                    IDEXPC <= IFIDPC;

                    // EX stage
                    if (IDEXop == LW) begin
                        EXMEMALUOut <= Ain + imm_i;
                    end
                    else if (IDEXop == SW) begin
                        EXMEMALUOut <= Ain + imm_s;
                    end
                    else if (IDEXop == ALUop) begin
                        // Simplified model: implement ADDI only.
                        EXMEMALUOut <= Ain + imm_i;
                    end

                    EXMEMIR <= IDEXIR;
                    EXMEMB  <= Bin;
                end
            end
            else begin
                // Freeze IF/ID and ID/EX; inject NOP into EX/MEM.
                EXMEMIR <= NOP;
                EXMEMB <= 32'd0;
                EXMEMALUOut <= 32'd0;
            end

            // MEM stage
            if (EXMEMop == ALUop) begin
                MEMWBValue <= EXMEMALUOut;
            end
            else if (EXMEMop == LW) begin
                MEMWBValue <= DMemory[EXMEMALUOut >> 2];
            end
            else if (EXMEMop == SW) begin
                DMemory[EXMEMALUOut >> 2] <= EXMEMB;
            end

            MEMWBIR <= EXMEMIR;

            // WB stage
            if (((MEMWBop == LW) || (MEMWBop == ALUop)) && (MEMWBrd != 5'd0)) begin
                Regs[MEMWBrd] <= MEMWBValue;
            end

            // x0 is always zero in RISC-V.
            Regs[0] <= 32'd0;
        end
    end
    end

endmodule
