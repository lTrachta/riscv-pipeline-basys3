`timescale 1ns / 1ps

module pipeline_core_store_forwarding_tb;

    logic clk;
    logic reset;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer stall_count;

    logic saw_load_store_data_pair;
    logic load_store_data_stalled;

    logic saw_mem_store_forward;
    logic saw_store_base_stall;


    pipeline_core dut (
        .clk   (clk),
        .reset (reset)
    );


    initial clk = 1'b0;
    always #5 clk = ~clk;


    task automatic check32 (
        input string       name,
        input logic [31:0] received,
        input logic [31:0] expected
    );

        begin

            tests_run = tests_run + 1;

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-28s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-28s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    task automatic check_bool (
        input string name,
        input logic received,
        input logic expected
    );

        begin

            tests_run = tests_run + 1;

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-28s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-28s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    task automatic check_register (
        input string name,
        input integer reg_number,
        input logic [31:0] expected
    );

        begin

            check32(
                name,
                dut.id_stage_inst.registers.registers[reg_number],
                expected
            );

        end

    endtask


    // =========================================================
    // MONITOR
    // =========================================================

    always @(posedge clk) begin

        if (!reset) begin

            if (dut.load_use_stall)
                stall_count = stall_count + 1;


            // -------------------------------------------------
            // I4 load está en EX y I5 store está en ID.
            //
            // PC I4 = 12
            // PC I5 = 16
            //
            // Esto NO debe producir stall.
            // -------------------------------------------------

            if (
                dut.id_ex_valid &&
                dut.id_ex_mem_read &&
                (dut.id_ex_pc == 32'd12) &&
                dut.if_id_valid &&
                (dut.if_id_pc == 32'd16)
            ) begin

                saw_load_store_data_pair = 1'b1;

                if (dut.load_use_stall)
                    load_store_data_stalled = 1'b1;

            end


            // -------------------------------------------------
            // Store de PC=16 en MEM.
            //
            // Debe recibir x5 desde WB.
            // -------------------------------------------------

            if (
                dut.ex_mem_valid &&
                dut.ex_mem_mem_write &&
                (dut.ex_mem_pc == 32'd16) &&
                dut.mem_stage_inst.store_data_forwarded
            ) begin

                saw_mem_store_forward = 1'b1;

            end


            // -------------------------------------------------
            // I6 load PC=20
            // I7 store PC=24
            //
            // Aquí x6 es rs1 del store -> sí debe stall.
            // -------------------------------------------------

            if (
                dut.load_use_stall &&
                dut.if_id_valid &&
                (dut.if_id_pc == 32'd24)
            ) begin

                saw_store_base_stall = 1'b1;

            end

        end

    end


    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        stall_count = 0;

        saw_load_store_data_pair = 1'b0;
        load_store_data_stalled  = 1'b0;

        saw_mem_store_forward = 1'b0;
        saw_store_base_stall  = 1'b0;


        // =====================================================
        // MEMORIA INICIAL
        // =====================================================

        // Address 64.
        dut.mem_stage_inst.data_memory_inst.memory[16] =
            32'h11223344;

        // Address 68.
        //
        // Este load entregará 84, usado después como dirección.
        dut.mem_stage_inst.data_memory_inst.memory[17] =
            32'd84;

        // Destino address 80.
        dut.mem_stage_inst.data_memory_inst.memory[20] =
            32'd0;

        // Destino address 84.
        dut.mem_stage_inst.data_memory_inst.memory[21] =
            32'd0;


        // =====================================================
        // PROGRAMA
        // =====================================================

        // I1: addi x1,x0,64
        dut.if_stage_inst.imem.memory[0] = 32'h04000093;

        // I2: addi x2,x0,80
        dut.if_stage_inst.imem.memory[1] = 32'h05000113;

        // I3: addi x3,x0,123
        dut.if_stage_inst.imem.memory[2] = 32'h07B00193;


        // -----------------------------------------------------
        // CASO A:
        //
        // lw -> sw DATA
        //
        // NO STALL.
        // -----------------------------------------------------

        // I4: lw x5,0(x1)
        dut.if_stage_inst.imem.memory[3] = 32'h0000A283;

        // I5: sw x5,0(x2)
        dut.if_stage_inst.imem.memory[4] = 32'h00512023;


        // -----------------------------------------------------
        // CASO B:
        //
        // lw -> sw BASE
        //
        // SÍ STALL.
        // -----------------------------------------------------

        // I6: lw x6,4(x1)
        dut.if_stage_inst.imem.memory[5] = 32'h0040A303;

        // I7: sw x3,0(x6)
        dut.if_stage_inst.imem.memory[6] = 32'h00332023;


        // NOPS
        dut.if_stage_inst.imem.memory[7]  = 32'h00000013;
        dut.if_stage_inst.imem.memory[8]  = 32'h00000013;
        dut.if_stage_inst.imem.memory[9]  = 32'h00000013;
        dut.if_stage_inst.imem.memory[10] = 32'h00000013;
        dut.if_stage_inst.imem.memory[11] = 32'h00000013;
        dut.if_stage_inst.imem.memory[12] = 32'h00000013;
        dut.if_stage_inst.imem.memory[13] = 32'h00000013;
        dut.if_stage_inst.imem.memory[14] = 32'h00000013;
        dut.if_stage_inst.imem.memory[15] = 32'h00000013;


        reset = 1'b1;

        repeat (3) @(posedge clk);

        reset = 1'b0;


        repeat (35) @(posedge clk);

        #1;


        // =====================================================
        // RESULTADOS
        // =====================================================

        check_register(
            "x1 BASE SOURCE",
            1,
            32'd64
        );

        check_register(
            "x2 STORE DEST",
            2,
            32'd80
        );

        check_register(
            "x3 STORE VALUE",
            3,
            32'd123
        );

        check_register(
            "LOAD x5",
            5,
            32'h11223344
        );

        check_register(
            "LOAD x6 BASE",
            6,
            32'd84
        );


        // -----------------------------------------------------
        // lw x5 -> sw x5
        // -----------------------------------------------------

        check32(
            "LW->SW DATA MEMORY",
            dut.mem_stage_inst.data_memory_inst.memory[20],
            32'h11223344
        );


        // -----------------------------------------------------
        // lw x6 -> sw using x6 as base.
        // -----------------------------------------------------

        check32(
            "LW->SW BASE MEMORY",
            dut.mem_stage_inst.data_memory_inst.memory[21],
            32'd123
        );


        // Sólo debe existir el stall del caso BASE.
        check32(
            "TOTAL STALLS",
            stall_count,
            32'd1
        );


        check_bool(
            "DATA PAIR OBSERVED",
            saw_load_store_data_pair,
            1'b1
        );

        check_bool(
            "DATA PAIR NO STALL",
            load_store_data_stalled,
            1'b0
        );

        check_bool(
            "MEM STORE FORWARD",
            saw_mem_store_forward,
            1'b1
        );

        check_bool(
            "STORE BASE STALL",
            saw_store_base_stall,
            1'b1
        );


        $display("");
        $display("==============================================");
        $display("PIPELINE STORE FORWARDING TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("Stalls       : %0d", stall_count);
        $display("==============================================");
        $display("");

        if (tests_failed == 0)
            $display("PASS: pipeline_core_store_forwarding");
        else
            $fatal(
                1,
                "FAIL: pipeline_core_store_forwarding | %0d failure(s)",
                tests_failed
            );

        #5;
        $finish;

    end

endmodule
