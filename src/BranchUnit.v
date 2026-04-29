module BranchUnit (
    input  [31:0] pc_ex,
    input  [31:0] rs1_value,
    input  [31:0] rs2_value,
    input  [31:0] instruction,

    output reg        branch_taken,
    output reg [31:0] branch_target
);

    localparam BEQ = 7'b110_0011;

    wire [6:0] opcode;
    assign opcode = instruction[6:0];
    wire [31:0] branch_imm;


    assign branch_imm = {
        {20{instruction[31]}},
        instruction[7],
        instruction[30:25],
        instruction[11:8],
        1'b0
    };

    always @(*) begin
        branch_taken  = 1'b0;
        branch_target = pc_ex + 32'd4;

        // BEQ: se opcode == BEQ e rs1 == rs2, desvio é tomado
        if (opcode == BEQ && rs1_value == rs2_value) begin
            branch_taken  = 1'b1;
            branch_target = pc_ex + branch_imm;
        end
    end

endmodule
