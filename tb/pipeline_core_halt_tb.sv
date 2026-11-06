`timescale 1ns / 1ps

module pipeline_core_halt_tb;

    logic clk;
    logic reset;

    integer i;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer halt_accept_count;
    integer redirect_count;

    logic saw_wrong_path_halt;


    localparam logic [31:0] HALT =
        32'h0000000B;

    localparam logic [31:0] NOP =
        32'h00000013;


    // =========================================================
    // DUT
    // =========================================================

    pipeline_core dut (
        .clk            (clk),
        .reset          (reset),
        .cycle_enable    (1'b1),

        .running        (),
        .draining       (),
        .halted         (),
        .pipeline_empty ()
    );


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // CHECKS
    // =========================================================

    task automatic check_bool (
        input string name,
        input logic  received,
        input logic  expected
    );

        begin

            tests_run = tests_run + 1;

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-30s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-30s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


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
                    "PASS: %-30s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-30s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    task automatic check_register (
        input string       name,
        input integer      reg_number,
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
    // LIMPIAR IMEM
    // =========================================================

    task automatic clear_imem;

        integer j;

        begin

            for (j = 0; j < 256; j = j + 1)
                dut.if_stage_inst.imem.memory[j] = NOP;

        end

    endtask


    // =========================================================
    // MONITOR
    // =========================================================

    always @(negedge clk) begin

        if (!reset) begin

            if (dut.halt_accept)
                halt_accept_count = halt_accept_count + 1;

            if (dut.redirect_valid)
                redirect_count = redirect_count + 1;


            // HALT wrong-path detrás de un branch tomado.

            if (
                dut.halt_in_id &&
                dut.redirect_valid
            ) begin

                saw_wrong_path_halt = 1'b1;

                if (dut.halt_accept) begin

                    $display(
                        "FAIL: wrong-path HALT was accepted"
                    );

                    $fatal;

                end

            end

        end

    end


    // =========================================================
    // TEST PRINCIPAL
    // =========================================================

    initial begin

        clk = 1'b0;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        reset = 1'b1;

        halt_accept_count = 0;
        redirect_count    = 0;

        saw_wrong_path_halt = 1'b0;


        // =====================================================
        // TEST 1
        //
        // HALT REAL + DRAIN
        //
        // Programa:
        //
        // addi x1,x0,64
        // addi x2,x0,85
        // sw   x2,0(x1)
        // addi x3,x0,33
        // HALT
        // addi x4,x0,44   <- NO debe ejecutarse
        //
        // Al aceptar HALT:
        //
        // - x4 debe descartarse;
        // - addi x3 debe llegar a WB;
        // - store debe completar;
        // - después el pipeline debe quedar vacío.
        // =====================================================

        clear_imem();

        dut.if_stage_inst.imem.memory[0] =
            32'h04000093; // addi x1,x0,64

        dut.if_stage_inst.imem.memory[1] =
            32'h05500113; // addi x2,x0,85

        dut.if_stage_inst.imem.memory[2] =
            32'h0020A023; // sw x2,0(x1)

        dut.if_stage_inst.imem.memory[3] =
            32'h02100193; // addi x3,x0,33

        dut.if_stage_inst.imem.memory[4] =
            HALT;

        dut.if_stage_inst.imem.memory[5] =
            32'h02C00213; // WRONG: addi x4,x0,44


        halt_accept_count = 0;
        redirect_count    = 0;
        saw_wrong_path_halt = 1'b0;


        repeat (2) @(posedge clk);
        #1;


        // Pipeline vacío por reset NO significa HALTED.

        check_bool(
            "RESET PIPELINE EMPTY",
            dut.pipeline_empty,
            1'b1
        );

        check_bool(
            "RESET NOT HALTED",
            dut.halted,
            1'b0
        );

        check_bool(
            "RESET STATE RUNNING",
            dut.running,
            1'b1
        );


        @(negedge clk);
        reset = 1'b0;


        // Esperamos que HALT llegue realmente a ID.

        wait (dut.halt_accept === 1'b1);

        #1;

        check_bool(
            "HALT DETECTED IN ID",
            dut.halt_in_id,
            1'b1
        );

        check_bool(
            "HALT ACCEPTED",
            dut.halt_accept,
            1'b1
        );

        check_bool(
            "NO REDIRECT ON REAL HALT",
            dut.redirect_valid,
            1'b0
        );


        // Aplicación del HALT.

        @(posedge clk);
        #1;


        check_bool(
            "ENTERED DRAINING",
            dut.draining,
            1'b1
        );

        check_bool(
            "IF/ID CLEARED BY HALT",
            dut.if_id_valid,
            1'b0
        );

        check_bool(
            "ID/EX CLEARED BY HALT",
            dut.id_ex_valid,
            1'b0
        );

        check_bool(
            "NOT HALTED IMMEDIATELY",
            dut.halted,
            1'b0
        );


        // Debe quedar al menos una instrucción vieja drenándose.

        check_bool(
            "OLDER INSTRUCTION SURVIVES",
            dut.ex_mem_valid | dut.mem_wb_valid,
            1'b1
        );


        // Esperar drain completo.

        wait (dut.halted === 1'b1);

        #1;


        check_bool(
            "PIPELINE EMPTY AT HALT",
            dut.pipeline_empty,
            1'b1
        );

        check_bool(
            "FINAL STATE HALTED",
            dut.halted,
            1'b1
        );


        // Resultados anteriores a HALT.

        check_register(
            "x1 BEFORE HALT",
            1,
            32'd64
        );

        check_register(
            "x2 BEFORE HALT",
            2,
            32'd85
        );

        check_register(
            "x3 DRAINED TO WB",
            3,
            32'd33
        );


        // Instrucción posterior a HALT.

        check_register(
            "x4 AFTER HALT DISCARDED",
            4,
            32'd0
        );


        // Store anterior a HALT.

        check32(
            "STORE COMPLETED DURING DRAIN",
            dut.mem_stage_inst.data_memory_inst.memory[16],
            32'd85
        );


        check32(
            "ONE HALT ACCEPTED TEST1",
            halt_accept_count,
            32'd1
        );


        // =====================================================
        // TEST 2
        //
        // HALT WRONG-PATH
        //
        // addi x1,x0,1
        // addi x2,x0,1
        // beq  x1,x2,+12
        // HALT                  <- WRONG PATH
        // addi x5,x0,99         <- WRONG PATH
        // TARGET:
        // addi x6,x0,66
        // HALT                  <- REAL
        // addi x7,x0,77         <- AFTER HALT
        //
        // El primer HALT aparece en ID mientras BEQ está
        // resolviéndose en EX.
        //
        // Debe ganar el redirect.
        // =====================================================

        @(negedge clk);
        reset = 1'b1;

        clear_imem();

        dut.if_stage_inst.imem.memory[0] =
            32'h00100093; // addi x1,x0,1

        dut.if_stage_inst.imem.memory[1] =
            32'h00100113; // addi x2,x0,1

        dut.if_stage_inst.imem.memory[2] =
            32'h00208663; // beq x1,x2,+12 -> PC 20

        dut.if_stage_inst.imem.memory[3] =
            HALT;         // WRONG PATH

        dut.if_stage_inst.imem.memory[4] =
            32'h06300293; // WRONG: addi x5,x0,99

        dut.if_stage_inst.imem.memory[5] =
            32'h04200313; // TARGET: addi x6,x0,66

        dut.if_stage_inst.imem.memory[6] =
            HALT;         // REAL HALT

        dut.if_stage_inst.imem.memory[7] =
            32'h04D00393; // WRONG: addi x7,x0,77


        halt_accept_count   = 0;
        redirect_count      = 0;
        saw_wrong_path_halt = 1'b0;


        repeat (2) @(posedge clk);
        #1;

        check_bool(
            "TEST2 RESET NOT HALTED",
            dut.halted,
            1'b0
        );


        @(negedge clk);
        reset = 1'b0;


        // Debemos observar físicamente:
        //
        // EX = BEQ tomado
        // ID = HALT
        //
        // sin aceptar HALT.

        wait (saw_wrong_path_halt === 1'b1);

        #1;

        check_bool(
            "WRONG HALT DID NOT STOP",
            dut.running,
            1'b1
        );


        // Después del flanco del redirect seguimos RUNNING.

        @(posedge clk);
        #1;

        check_bool(
            "RUNNING AFTER REDIRECT",
            dut.running,
            1'b1
        );

        check_bool(
            "NOT DRAINING AFTER WRONG HALT",
            dut.draining,
            1'b0
        );


        // El HALT real del target sí debe terminar el programa.

        wait (dut.halted === 1'b1);

        #1;


        check_bool(
            "TEST2 FINAL HALTED",
            dut.halted,
            1'b1
        );

        check_bool(
            "TEST2 PIPELINE EMPTY",
            dut.pipeline_empty,
            1'b1
        );


        check_register(
            "WRONG PATH x5",
            5,
            32'd0
        );

        check_register(
            "TARGET x6",
            6,
            32'd66
        );

        check_register(
            "AFTER HALT x7",
            7,
            32'd0
        );


        check_bool(
            "WRONG PATH HALT OBSERVED",
            saw_wrong_path_halt,
            1'b1
        );

        check32(
            "ONE REAL HALT ACCEPTED",
            halt_accept_count,
            32'd1
        );

        check32(
            "ONE BRANCH REDIRECT",
            redirect_count,
            32'd1
        );


        // =====================================================
        // TEST 3
        //
        // PROGRAMA SIN HALT
        //
        // No existe timeout automático.
        // El procesador debe seguir RUNNING.
        // =====================================================

        @(negedge clk);
        reset = 1'b1;

        clear_imem();

        dut.if_stage_inst.imem.memory[0] =
            32'h00A00513; // addi x10,x0,10


        halt_accept_count   = 0;
        redirect_count      = 0;
        saw_wrong_path_halt = 1'b0;


        repeat (2) @(posedge clk);
        #1;


        check_bool(
            "NOHALT RESET EMPTY",
            dut.pipeline_empty,
            1'b1
        );

        check_bool(
            "NOHALT RESET NOT HALTED",
            dut.halted,
            1'b0
        );


        @(negedge clk);
        reset = 1'b0;


        repeat (25) @(posedge clk);

        #1;


        check_bool(
            "NOHALT STILL RUNNING",
            dut.running,
            1'b1
        );

        check_bool(
            "NOHALT NOT DRAINING",
            dut.draining,
            1'b0
        );

        check_bool(
            "NOHALT NOT HALTED",
            dut.halted,
            1'b0
        );


        check32(
            "NOHALT ACCEPT COUNT",
            halt_accept_count,
            32'd0
        );


        check_register(
            "NOHALT PROGRAM EXECUTED",
            10,
            32'd10
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PIPELINE HALT / DRAIN TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0)
            $display("PASS: pipeline_core_halt");
        else
            $fatal(
                1,
                "FAIL: pipeline_core_halt | %0d failure(s)",
                tests_failed
            );

        $finish;

    end

endmodule
