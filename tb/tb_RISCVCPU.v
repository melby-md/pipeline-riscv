`timescale 1ns/1ps

module tb_RISCVCPU;

    reg clock;
    reg reset;
    
    wire halt;

    integer i;

    RISCVCPU cpu (
        .clock(clock),
        .reset(reset),
        .halt(halt)
    );

    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_RISCVCPU);
    end

    initial begin
        run_full_dependencies();
        $finish;
    end

    task reset_cpu;
        begin
            reset = 1'b1;
            #20;
            reset = 1'b0;
        end
    endtask

    task clear_memories;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                cpu.IMemory[i] = 32'h0000_0013; // nop
                cpu.DMemory[i] = 32'd0;
            end
        end
    endtask

    task run_full_dependencies;
        begin
            clear_memories();
            load_program_full_dependencies();
            reset_cpu();
            while(!halt) @(posedge clock);
            print_stats("full_dependencies");
            check_expected();
            print_state_nonzero();
        end
    endtask

    task load_program_full_dependencies;
        begin
            cpu.DMemory[0] = 32'd10;

            cpu.IMemory[0] = 32'h00002083;  // lw   x1, 0(x0)      # x1 = mem[0]
            cpu.IMemory[1] = 32'h00508113;  // addi x2, x1, 5      # x2 = x1 + 5
            cpu.IMemory[2] = 32'h00110193; // addi x3, x2, 1       # x3 = x2 + 1
            cpu.IMemory[3] = 32'h00302223; // sw   x3, 4(x0)       # mem[1] = x3
            cpu.IMemory[4] = 32'h00a18213; // addi x4, x3, 10      # x4 = x3 + 10
            // PC do beq = 20, label está em PC = 32
            // offset = 32 - 20 = 12 bytes
            cpu.IMemory[5] = 32'h00420663; // beq  x4, x4, label   # sempre tomado

            cpu.IMemory[6] = 32'h06300293; // addi x5, x0, 99      # deve ser flushado
            cpu.IMemory[7] = 32'h05800313; // addi x6, x0, 88      # pode ser flushado

            // label:
            cpu.IMemory[8] = 32'h00120393; // addi x7, x4, 1       # x7 = resultado final

            cpu.IMemory[9] = 32'h0000000b; // halt                 # Instrução para finalizar a simulação
        end
    endtask

    task print_registers_nonzero;
        integer i;
        begin
            $display("===== REGISTERS (non-zero) =====");
            for (i = 0; i < 32; i = i + 1) begin
                if (cpu.Regs[i] != 0) begin
                    $display("x%0d = %0d (0x%08h)", i, cpu.Regs[i], cpu.Regs[i]);
                end
            end
        end
    endtask

    task print_memory_nonzero;
        integer i;
        begin
            $display("===== DATA MEMORY (non-zero) =====");
            for (i = 0; i < 32; i = i + 1) begin
                if (cpu.DMemory[i] != 0) begin
                    $display("mem[%0d] = %0d (0x%08h)", i, cpu.DMemory[i], cpu.DMemory[i]);
                end
            end
        end
    endtask

    task print_state_nonzero;
        integer i;
        begin
            $display("\n============================================");
            $display("STATE (non-zero values) for DEBUG");
            $display("============================================");

            $display("\n-- REGISTERS --");
            for (i = 0; i < 32; i = i + 1) begin
                if (cpu.Regs[i] != 0) begin
                    $display("x%0d = %0d (0x%08h)", i, cpu.Regs[i], cpu.Regs[i]);
                end
            end

            $display("\n-- DATA MEMORY --");
            for (i = 0; i < 32; i = i + 1) begin
                if (cpu.DMemory[i] != 0) begin
                    $display("mem[%0d] = %0d (0x%08h)", i, cpu.DMemory[i], cpu.DMemory[i]);
                end
            end

            $display("============================================\n");
        end
    endtask

    task check_expected;
        integer errors;
        begin
            errors = 0;

            $display("\n==============================");
            $display("CHECK EXPECTED RESULTS");
            $display("==============================");

            if (cpu.Regs[1] !== 32'd10) begin
                $display("FAIL: x1 expected 10, got %0d", cpu.Regs[1]);
                errors = errors + 1;
            end

            if (cpu.Regs[2] !== 32'd15) begin
                $display("FAIL: x2 expected 15, got %0d", cpu.Regs[2]);
                errors = errors + 1;
            end

            if (cpu.Regs[3] !== 32'd16) begin
                $display("FAIL: x3 expected 16, got %0d", cpu.Regs[3]);
                errors = errors + 1;
            end

            if (cpu.Regs[4] !== 32'd26) begin
                $display("FAIL: x4 expected 26, got %0d", cpu.Regs[4]);
                errors = errors + 1;
            end

            if (cpu.Regs[5] !== 32'd0) begin
                $display("FAIL: x5 expected 0 because branch should flush it, got %0d", cpu.Regs[5]);
                errors = errors + 1;
            end

            if (cpu.Regs[7] !== 32'd27) begin
                $display("FAIL: x7 expected 27, got %0d", cpu.Regs[7]);
                errors = errors + 1;
            end

            if (cpu.DMemory[0] !== 32'd10) begin
                $display("FAIL: DMemory[0] expected 10, got %0d", cpu.DMemory[0]);
                errors = errors + 1;
            end

            if (cpu.DMemory[1] !== 32'd16) begin
                $display("FAIL: DMemory[1] expected 16, got %0d", cpu.DMemory[1]);
                errors = errors + 1;
            end

            if (errors == 0) begin
                $display("PASS: all expected results match.");
            end
            else begin
                $display("FAIL: %0d error(s) found.", errors);
            end

            $display("==============================\n");
            end
    endtask

    task print_stats;
        input [8*40-1:0] program_name;
        real cpi;
        begin
            cpi = 0.0;
            if (cpu.stats.instr_count != 0) begin
                cpi = $itor(cpu.stats.cycle_count) / $itor(cpu.stats.instr_count);
            end

            $display("\n============================================");
            $display("Program      : %0s", program_name);
            $display("Cycles       : %0d", cpu.stats.cycle_count);
            $display("Instructions : %0d", cpu.stats.instr_count);
            $display("Stalls       : %0d", cpu.stats.stall_count);
            $display("Bypasses     : %0d", cpu.stats.bypass_count);
            $display("Branches     : %0d", cpu.stats.branch_taken_count);
            $display("Flushes      : %0d", cpu.stats.flush_count);
            $display("CPI          : %0.2f", cpi);
            $display("============================================\n");
        end
    endtask

endmodule
