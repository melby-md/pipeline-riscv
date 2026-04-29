module PipelineStats (
    input clock,
    input reset,

    input instr_commit,
    input stall,
    input bypassA_MEM,
    input bypassB_MEM,
    input bypassA_WB,
    input bypassB_WB,
    input branch_taken,
    input flush,

    output reg [31:0] cycle_count,
    output reg [31:0] instr_count,
    output reg [31:0] stall_count,
    output reg [31:0] bypass_count,
    output reg [31:0] branch_taken_count,
    output reg [31:0] flush_count
);

    always @(posedge clock) begin
        if (reset) begin
            cycle_count        <= 32'd0;
            instr_count        <= 32'd0;
            stall_count        <= 32'd0;
            bypass_count       <= 32'd0;
            branch_taken_count <= 32'd0;
            flush_count        <= 32'd0;
        end
        else begin
                      cycle_count <= cycle_count + 32'd1;

            if (instr_commit) begin
                instr_count <= instr_count + 32'd1;
            end

            if (stall) begin
                stall_count <= stall_count + 32'd1;
            end

            if (bypassA_MEM || bypassB_MEM || bypassA_WB || bypassB_WB) begin
                bypass_count <= bypass_count + 32'd1;
            end

            if (branch_taken) begin
                branch_taken_count <= branch_taken_count + 32'd1;
            end

            if (flush) begin
                flush_count <= flush_count + 32'd1;
            end
        end
    end

endmodule
