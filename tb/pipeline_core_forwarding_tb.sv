`timescale 1ns / 1ps

module pipeline_core_forwarding_tb;

    logic clk;
    logic reset;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    logic saw_ex_forward;
    logic saw_mem_forward;
    logic saw_mixed_forward;
    logic saw_store_forward;


    // =========================================================
    // DUT
    // =========================================================

    pipeline_core dut (
        .clk   (clk),
        .reset (reset),
        .cycle_enable (1'b1)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    initial clk = 1'b0;

    always #5 clk = ~clk;


    // =========================================================
    // DETECCIÓN DE EVENTOS DE FORWARDING
    // =========================================================

    always @(posedge clk) begin

        if (!reset) begin

            if (
                dut.forward_a == 2'b10 ||
                dut.forward_b == 2'b10
            )
                saw_ex_forward <= 1'b1;

            if (
                dut.forward_a == 2'b01 ||
                dut.forward_b == 2'b01
            )
                saw_mem_forward <= 1'b1;

            if (
                dut.forward_a == 2'b01 &&
                dut.forward_b == 2'b10
            )
                saw_mixed_forward <= 1'b1;

            if (
                dut.id_ex_opcode == 7'b0100011 &&
                dut.forward_b == 2'b10
            )
                saw_store_forward <= 1'b1;

        end

    end


    // =========================================================
    // CHECK REGISTER
    // =========================================================

    task automatic check_register (
        input string       name,
        input integer      reg_number,
        input logic [31:0] expected
    );

        logic [31:0] received;

        begin

            tests_run = tests_run + 1;

            received =
                dut.id_stage_inst.registers.registers[reg_number];

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-15s | x%0d=%08h",
                    name,
                    reg_number,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-15s | x%0d=%08h expected=%08h",
                    name,
                    reg_number,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // CHECK MEMORY
    // =========================================================

    task automatic check_memory (
        input string       name,
        input integer      word_index,
        input logic [31:0] expected
    );

        logic [31:0] received;

        begin

            tests_run = tests_run + 1;

            received =
                dut.mem_stage_inst.data_memory_inst.memory[word_index];

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-15s | DMEM[%0d]=%08h",
                    name,
                    word_index,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-15s | DMEM[%0d]=%08h expected=%08h",
                    name,
                    word_index,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // TEST
    // =========================================================

    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        saw_ex_forward    = 1'b0;
        saw_mem_forward   = 1'b0;
        saw_mixed_forward = 1'b0;
        saw_store_forward = 1'b0;


        // =====================================================
        // PROGRAMA
        //
        // I1: addi x1,x0,10
        // I2: addi x2,x0,20
        //
        // I3: add  x5,x1,x2
        //
        // Cuando I3 está en EX:
        //
        // x1 viene desde MEM/WB
        // x2 viene desde EX/MEM
        //
        // ForwardA = 01
        // ForwardB = 10
        //
        // x5 = 30
        //
        // -----------------------------------------------------
        //
        // I4: sub x6,x5,x2
        //
        // x5 viene desde EX/MEM.
        // x2 viene desde MEM/WB.
        //
        // x6 = 30 - 20 = 10
        //
        // -----------------------------------------------------
        //
        // I5: xor x7,x6,x5
        //
        // x6 viene desde EX/MEM.
        // x5 viene desde MEM/WB.
        //
        // x7 = 10 XOR 30 = 20
        //
        // -----------------------------------------------------
        //
        // I6: sw x7,0(x0)
        //
        // store_data debe recibir x7 mediante forwarding.
        //
        // DMEM[0] = 20
        // =====================================================


        // addi x1,x0,10
        dut.if_stage_inst.imem.memory[0] = 32'h00A00093;

        // addi x2,x0,20
        dut.if_stage_inst.imem.memory[1] = 32'h01400113;

        // add x5,x1,x2
        dut.if_stage_inst.imem.memory[2] = 32'h002082B3;

        // sub x6,x5,x2
        dut.if_stage_inst.imem.memory[3] = 32'h40228333;

        // xor x7,x6,x5
        dut.if_stage_inst.imem.memory[4] = 32'h005343B3;

        // sw x7,0(x0)
        dut.if_stage_inst.imem.memory[5] = 32'h00702023;


        // NOPs posteriores

        dut.if_stage_inst.imem.memory[6] = 32'h00000013;
        dut.if_stage_inst.imem.memory[7] = 32'h00000013;
        dut.if_stage_inst.imem.memory[8] = 32'h00000013;
        dut.if_stage_inst.imem.memory[9] = 32'h00000013;
        dut.if_stage_inst.imem.memory[10] = 32'h00000013;
        dut.if_stage_inst.imem.memory[11] = 32'h00000013;


        // =====================================================
        // RESET
        // =====================================================

        reset = 1'b1;

        repeat (3) @(posedge clk);

        reset = 1'b0;


        // =====================================================
        // EJECUCIÓN
        // =====================================================

        repeat (16) @(posedge clk);

        #1;


        // =====================================================
        // RESULTADOS
        // =====================================================

        check_register(
            "I1 ADDI",
            1,
            32'd10
        );

        check_register(
            "I2 ADDI",
            2,
            32'd20
        );

        check_register(
            "I3 ADD",
            5,
            32'd30
        );

        check_register(
            "I4 SUB",
            6,
            32'd10
        );

        check_register(
            "I5 XOR",
            7,
            32'd20
        );

        check_memory(
            "I6 STORE",
            0,
            32'd20
        );


        // =====================================================
        // COMPROBACIÓN DE QUE REALMENTE HUBO FORWARDING
        // =====================================================

        tests_run = tests_run + 1;

        if (saw_ex_forward) begin

            tests_passed = tests_passed + 1;
            $display("PASS: EX/MEM forwarding observed");

        end
        else begin

            tests_failed = tests_failed + 1;
            $display("FAIL: EX/MEM forwarding was never observed");

        end


        tests_run = tests_run + 1;

        if (saw_mem_forward) begin

            tests_passed = tests_passed + 1;
            $display("PASS: MEM/WB forwarding observed");

        end
        else begin

            tests_failed = tests_failed + 1;
            $display("FAIL: MEM/WB forwarding was never observed");

        end


        tests_run = tests_run + 1;

        if (saw_mixed_forward) begin

            tests_passed = tests_passed + 1;
            $display("PASS: mixed forwarding observed");

        end
        else begin

            tests_failed = tests_failed + 1;
            $display("FAIL: mixed forwarding was never observed");

        end


        tests_run = tests_run + 1;

        if (saw_store_forward) begin

            tests_passed = tests_passed + 1;
            $display("PASS: store-data forwarding observed");

        end
        else begin

            tests_failed = tests_failed + 1;
            $display("FAIL: store-data forwarding was never observed");

        end


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PIPELINE FORWARDING TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: pipeline_core_forwarding");

        end
        else begin

            $fatal(
                1,
                "FAIL: pipeline_core_forwarding | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
