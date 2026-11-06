`timescale 1ns / 1ps

module pipeline_core_integrated_tb;

    logic clk;
    logic reset;

    logic running;
    logic draining;
    logic halted;
    logic pipeline_empty;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer stall_count;
    integer redirect_count;
    integer halt_accept_count;

    logic saw_ex_mem_forward;
    logic saw_mem_wb_forward;
    logic saw_store_data_forward;


    localparam logic [31:0] NOP =
        32'h00000013;


    // =========================================================
    // DUT
    // =========================================================

    pipeline_core dut (
        .clk            (clk),
        .reset          (reset),
        .cycle_enable    (1'b1),

        .running        (running),
        .draining       (draining),
        .halted         (halted),
        .pipeline_empty (pipeline_empty)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // OBSERVACIÓN MICROARQUITECTÓNICA
    // =========================================================

    always @(negedge clk) begin

        if (!reset) begin

            if (dut.load_use_stall)
                stall_count = stall_count + 1;

            if (dut.redirect_valid)
                redirect_count = redirect_count + 1;

            if (dut.halt_accept)
                halt_accept_count = halt_accept_count + 1;


            // Forwarding desde EX/MEM.

            if (
                dut.id_ex_valid &&
                (
                    dut.forward_a == 2'b10 ||
                    dut.forward_b == 2'b10
                )
            )
                saw_ex_mem_forward = 1'b1;


            // Forwarding desde MEM/WB.

            if (
                dut.id_ex_valid &&
                (
                    dut.forward_a == 2'b01 ||
                    dut.forward_b == 2'b01
                )
            )
                saw_mem_wb_forward = 1'b1;


            // Forwarding específico WB -> MEM para store-data.

            if (
                dut.mem_stage_inst.store_data_forwarded
            )
                saw_store_data_forward = 1'b1;

        end

    end


    // =========================================================
    // CHECKS
    // =========================================================

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
                    "PASS: %-36s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-36s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


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
                    "PASS: %-36s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-36s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    task automatic check_reg (
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


    task automatic check_mem (
        input string       name,
        input integer      word_index,
        input logic [31:0] expected
    );

        begin

            check32(
                name,
                dut.mem_stage_inst.data_memory_inst.memory[word_index],
                expected
            );

        end

    endtask


    // =========================================================
    // LIMPIEZA
    // =========================================================

    task automatic clear_memories;

        integer j;

        begin

            for (j = 0; j < 256; j = j + 1) begin

                dut.if_stage_inst.imem.memory[j] =
                    NOP;

                dut.mem_stage_inst.data_memory_inst.memory[j] =
                    32'd0;

            end

        end

    endtask


    task automatic clear_observation;

        begin

            stall_count       = 0;
            redirect_count    = 0;
            halt_accept_count = 0;

            saw_ex_mem_forward    = 1'b0;
            saw_mem_wb_forward    = 1'b0;
            saw_store_data_forward = 1'b0;

        end

    endtask


    // =========================================================
    // CARGA DE PROGRAMA
    // =========================================================

    task automatic start_program (
        input string  file_name,
        input integer last_word
    );

        begin

            // Activar reset entre programas.

            @(negedge clk);

            reset = 1'b1;

            clear_memories();
            clear_observation();


            // Cargar solamente el rango utilizado por el
            // programa. El resto de IMEM queda con NOP.

            $readmemh(
                file_name,
                dut.if_stage_inst.imem.memory,
                0,
                last_word
            );


            // Dos flancos con reset activo limpian RF,
            // pipeline y estado RUNNING/DRAINING/HALTED.

            repeat (2)
                @(posedge clk);

            @(negedge clk);

            reset = 1'b0;

        end

    endtask


    // =========================================================
    // EJECUCIÓN HASTA HALT CON TIMEOUT
    // =========================================================

    task automatic run_until_halted (
        input string  program_name,
        input integer max_cycles
    );

        integer cycles;

        begin

            cycles = 0;

            while (
                !halted &&
                cycles < max_cycles
            ) begin

                @(posedge clk);
                #1;

                cycles = cycles + 1;

            end


            if (!halted) begin

                tests_run    = tests_run + 1;
                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %s TIMEOUT after %0d cycles",
                    program_name,
                    max_cycles
                );

                $fatal(
                    1,
                    "Integrated verification timeout"
                );

            end
            else begin

                tests_run    = tests_run + 1;
                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %s HALTED after %0d cycles",
                    program_name,
                    cycles
                );

            end


            check_bool(
                "PIPELINE EMPTY AT HALT",
                pipeline_empty,
                1'b1
            );

            check32(
                "HALT ACCEPT COUNT",
                halt_accept_count,
                32'd1
            );

        end

    endtask


    // =========================================================
    // TEST PRINCIPAL
    // =========================================================

    initial begin

        clk = 1'b0;

        reset = 1'b1;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        clear_observation();


        // =====================================================
        // PROGRAM 1 — ALU + IMMEDIATES
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM: ALU + IMMEDIATES");
        $display("==============================================");

        start_program(
            "../../../programs/integrated_verification/alu_immediates.hex",
            22
        );

        run_until_halted(
            "ALU + IMMEDIATES",
            100
        );


        check_reg("ADD x3",   3,  32'd13);
        check_reg("SUB x4",   4,  32'd7);
        check_reg("SLL x5",   5,  32'd24);
        check_reg("SRL x6",   6,  32'd3);

        check_reg(
            "NEGATIVE SOURCE x7",
            7,
            32'hFFFFFFF0
        );

        check_reg(
            "SRA x8",
            8,
            32'hFFFFFFFE
        );

        check_reg("AND x9",   9,  32'd2);
        check_reg("OR x10",   10, 32'd11);
        check_reg("XOR x11",  11, 32'd9);

        check_reg("SLT x12",  12, 32'd1);
        check_reg("SLTU x13", 13, 32'd0);

        check_reg("ANDI x14", 14, 32'd2);
        check_reg("ORI x15",  15, 32'd11);
        check_reg("XORI x16", 16, 32'd5);

        check_reg("SLTI x17",  17, 32'd1);
        check_reg("SLTIU x18", 18, 32'd1);

        check_reg("SLLI x19", 19, 32'd48);
        check_reg("SRLI x20", 20, 32'd12);

        check_reg(
            "SRAI x21",
            21,
            32'hFFFFFFFC
        );

        check_reg(
            "LUI x22",
            22,
            32'h12345000
        );

        check32(
            "ALU STALL COUNT",
            stall_count,
            32'd0
        );

        check32(
            "ALU REDIRECT COUNT",
            redirect_count,
            32'd0
        );

        check_bool(
            "ALU EX/MEM FORWARD SEEN",
            saw_ex_mem_forward,
            1'b1
        );

        check_bool(
            "ALU MEM/WB FORWARD SEEN",
            saw_mem_wb_forward,
            1'b1
        );


        // =====================================================
        // PROGRAM 2 — MEMORY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM: MEMORY");
        $display("==============================================");

        start_program(
            "../../../programs/integrated_verification/memory.hex",
            12
        );

        run_until_halted(
            "MEMORY",
            100
        );


        check_reg(
            "LB SIGN EXTENSION",
            3,
            32'hFFFFFFFF
        );

        check_reg(
            "LBU ZERO EXTENSION",
            4,
            32'h000000FF
        );

        check_reg(
            "LH SIGN EXTENSION",
            5,
            32'hFFFFFFFF
        );

        check_reg(
            "LHU ZERO EXTENSION",
            6,
            32'h0000FFFF
        );

        check_reg(
            "LW VALUE",
            8,
            32'h11223344
        );


        // Dirección 64 -> word index 16.
        //
        // bytes:
        // 67 = FF
        // 66 = FF
        // 65 = 00
        // 64 = FF

        check_mem(
            "BYTE/HALF MEMORY WORD",
            16,
            32'hFFFF00FF
        );


        // Dirección 68 -> word index 17.

        check_mem(
            "WORD STORE MEMORY",
            17,
            32'h11223344
        );


        check32(
            "MEMORY STALL COUNT",
            stall_count,
            32'd0
        );

        check32(
            "MEMORY REDIRECT COUNT",
            redirect_count,
            32'd0
        );


        // =====================================================
        // PROGRAM 3 — CONTROL FLOW
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM: CONTROL FLOW");
        $display("==============================================");

        start_program(
            "../../../programs/integrated_verification/control_flow.hex",
            22
        );

        run_until_halted(
            "CONTROL FLOW",
            150
        );


        check_reg("BEQ TARGET x3", 3, 32'd1);
        check_reg("BNE FALLTHROUGH x4", 4, 32'd2);
        check_reg("BEQ FALLTHROUGH x5", 5, 32'd3);

        // JAL en PC=56.
        // Link = 60.

        check_reg(
            "JAL LINK x6",
            6,
            32'd60
        );


        // JALR en PC=72.
        // Link = 76.

        check_reg(
            "JALR LINK x8",
            8,
            32'd76
        );

        check_reg(
            "JALR TARGET x9",
            9,
            32'd4
        );


        // Wrong-path.

        check_reg("WRONG PATH x10", 10, 32'd0);
        check_reg("WRONG PATH x11", 11, 32'd0);
        check_reg("WRONG PATH x12", 12, 32'd0);
        check_reg("WRONG PATH x13", 13, 32'd0);
        check_reg("WRONG PATH x14", 14, 32'd0);
        check_reg("WRONG PATH x15", 15, 32'd0);
        check_reg("WRONG PATH x16", 16, 32'd0);
        check_reg("WRONG PATH x17", 17, 32'd0);


        check32(
            "CONTROL STALL COUNT",
            stall_count,
            32'd0
        );

        check32(
            "CONTROL REDIRECT COUNT",
            redirect_count,
            32'd4
        );

        check_bool(
            "CONTROL FORWARD SEEN",
            saw_ex_mem_forward,
            1'b1
        );


        // =====================================================
        // PROGRAM 4 — COMBINED HAZARDS
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM: COMBINED HAZARDS");
        $display("==============================================");

        start_program(
            "../../../programs/integrated_verification/hazards.hex",
            22
        );

        run_until_halted(
            "COMBINED HAZARDS",
            180
        );


        check_reg("FORWARD RESULT x3", 3, 32'd15);
        check_reg("FORWARD RESULT x4", 4, 32'd25);

        check_reg("LOAD x5", 5, 32'd10);

        check_reg(
            "LOAD USE RESULT x6",
            6,
            32'd35
        );

        check_reg("LOAD x7", 7, 32'd10);

        check_reg(
            "LOADED BASE x12",
            12,
            32'd132
        );

        check_reg(
            "ALU BRANCH SOURCE x13",
            13,
            32'd1
        );

        check_reg(
            "ALU BRANCH WRONG PATH x14",
            14,
            32'd0
        );

        check_reg(
            "LOAD BRANCH SOURCE x15",
            15,
            32'd10
        );

        check_reg(
            "LOAD BRANCH WRONG PATH x16",
            16,
            32'd0
        );

        check_reg(
            "FINAL RESULT x17",
            17,
            32'd36
        );


        check_mem(
            "BASE MEMORY",
            32,
            32'd10
        );

        check_mem(
            "LOAD STORE DATA",
            33,
            32'd10
        );

        check_mem(
            "STORED BASE POINTER",
            34,
            32'd132
        );


        check32(
            "HAZARD STALL COUNT",
            stall_count,
            32'd3
        );

        check32(
            "HAZARD REDIRECT COUNT",
            redirect_count,
            32'd2
        );

        check_bool(
            "HAZARD EX/MEM FORWARD",
            saw_ex_mem_forward,
            1'b1
        );

        check_bool(
            "HAZARD MEM/WB FORWARD",
            saw_mem_wb_forward,
            1'b1
        );

        check_bool(
            "STORE DATA FORWARD",
            saw_store_data_forward,
            1'b1
        );


        // =====================================================
        // PROGRAM 5 — COMPLETE INTEGRATION
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM: COMPLETE INTEGRATION");
        $display("==============================================");

        start_program(
            "../../../programs/integrated_verification/integration.hex",
            19
        );

        run_until_halted(
            "COMPLETE INTEGRATION",
            250
        );


        check_reg(
            "FINAL SUM x3",
            3,
            32'd10
        );

        check_reg(
            "FINAL COUNT x4",
            4,
            32'd0
        );

        check_reg(
            "FINAL POINTER x5",
            5,
            32'd216
        );

        check_reg(
            "LAST LOADED VALUE x6",
            6,
            32'd4
        );

        check_reg(
            "RELOADED SUM x7",
            7,
            32'd10
        );


        // Base = 200 bytes.
        //
        // 200 / 4 = index 50.

        check_mem("ARRAY[0]", 50, 32'd1);
        check_mem("ARRAY[1]", 51, 32'd2);
        check_mem("ARRAY[2]", 52, 32'd3);
        check_mem("ARRAY[3]", 53, 32'd4);
        check_mem("FINAL SUM MEMORY", 54, 32'd10);


        check32(
            "INTEGRATION STALL COUNT",
            stall_count,
            32'd4
        );

        check32(
            "INTEGRATION REDIRECT COUNT",
            redirect_count,
            32'd3
        );

        check_bool(
            "INTEGRATION EX/MEM FORWARD",
            saw_ex_mem_forward,
            1'b1
        );

        check_bool(
            "INTEGRATION MEM/WB FORWARD",
            saw_mem_wb_forward,
            1'b1
        );


        // =====================================================
        // FINAL SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("INTEGRATED PROCESSOR VERIFICATION SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");


        if (tests_failed == 0) begin

            $display(
                "PASS: pipeline_core_integrated"
            );

        end
        else begin

            $fatal(
                1,
                "FAIL: integrated processor verification | %0d failure(s)",
                tests_failed
            );

        end


        $finish;

    end

endmodule
