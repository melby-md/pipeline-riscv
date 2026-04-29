module ForwardingUnit (
    input  [4:0] idex_rs1,
    input  [4:0] idex_rs2,
    input  [4:0] exmem_rd,
    input  [4:0] memwb_rd,

    input  [6:0] exmem_op,
    input  [6:0] memwb_op,

    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);

    localparam NO_FORWARD  = 2'b00;
    localparam FROM_MEM    = 2'b01;
    localparam FROM_WB_ALU = 2'b10;
    localparam FROM_WB_LD  = 2'b11;

    localparam LW    = 7'b000_0011;
    localparam ALUop = 7'b001_0011;

    initial begin
      forwardA = NO_FORWARD;
      forwardB = NO_FORWARD;
    end

    always @(*) begin
        // Valores padrão: sem forwarding
        forwardA = NO_FORWARD;
        forwardB = NO_FORWARD;

        // Lógica de Forwarding para o Operando A (rs1)
        
        // 1. Hazard do Estágio EX/MEM (Instrução imediatamente anterior)
        if ((exmem_op == ALUop) && (idex_rs1 == exmem_rd)) begin
            forwardA = FROM_MEM;
        end
        // 2. Hazard do Estágio MEM/WB (Duas instruções atrás)
        else if ((memwb_op == ALUop) && (idex_rs1 === memwb_rd)) begin
            forwardA = FROM_WB_ALU;
        end
        else if ((memwb_op == LW) && (idex_rs1 === memwb_rd)) begin
            forwardA = FROM_WB_LD;
        end

        // Lógica de Forwarding para o Operando B (rs2)
        
        // 1. Hazard do Estágio EX/MEM (Instrução imediatamente anterior)
        if ((exmem_op == ALUop) && (idex_rs2 == exmem_rd)) begin
            forwardB = FROM_MEM;
        end
        // 2. Hazard do Estágio MEM/WB (Duas instruções atrás)
        else if ((memwb_op == ALUop) && (idex_rs2 === memwb_rd)) begin
            forwardB = FROM_WB_ALU;
        end
        else if ((memwb_op == LW) && (idex_rs2 === memwb_rd)) begin
            forwardB = FROM_WB_LD;
        end

    end

endmodule