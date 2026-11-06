`timescale 1ns / 1ps

module pipeline_program_loading_tb;


    logic clk;

    // Reset del procesador y reset del loader son independientes.
    logic core_reset;
    logic loader_reset;


    // =========================================================
    // BYTE STREAM
    //
    // En el futuro:
    //
    // uart_rx -> rx_byte_valid / rx_byte_data
    //
    // En este testbench simulamos directamente esos bytes.
    // =========================================================

    logic       rx_byte_valid;
    logic [7:0] rx_byte_data;


    // =========================================================
    // PROGRAM LOADER
    // =========================================================

    logic        load_active;
    logic        load_done;
    logic        load_error;

    logic [15:0] expected_instructions;
    logic [15:0] received_instructions;

    logic        imem_write_enable;
    logic [31:0] imem_write_address;
    logic [31:0] imem_write_data;


    // =========================================================
    // CORE
    // =========================================================

    logic running;
    logic draining;
    logic halted;
    logic pipeline_empty;


    // =========================================================
    // TEST COUNTERS
    // =========================================================

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer load_done_count;


    localparam logic [7:0] CMD_BEGIN =
        8'h4C; // L

    localparam logic [7:0] CMD_WRITE =
        8'h57; // W

    localparam logic [7:0] CMD_END =
        8'h45; // E


    // =========================================================
    // PROGRAM LOADER
    // =========================================================

    program_loader #(
        .IMEM_DEPTH(256)
    ) loader (
        .clk                   (clk),
        .reset                 (loader_reset),

        .rx_byte_valid         (rx_byte_valid),
        .rx_byte_data          (rx_byte_data),

        .load_active           (load_active),
        .load_done             (load_done),
        .load_error            (load_error),

        .expected_instructions (expected_instructions),
        .received_instructions (received_instructions),

        .imem_write_enable     (imem_write_enable),
        .imem_write_address    (imem_write_address),
        .imem_write_data       (imem_write_data)
    );


    // =========================================================
    // PROCESSOR
    // =========================================================

    pipeline_core dut (
        .clk                   (clk),
        .reset                 (core_reset),
        .cycle_enable    (1'b1),

        .program_write_enable  (imem_write_enable),
        .program_write_address (imem_write_address),
        .program_write_data    (imem_write_data),

        .running               (running),
        .draining              (draining),
        .halted                (halted),
        .pipeline_empty        (pipeline_empty)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // LOAD DONE COUNTER
    // =========================================================

    always @(posedge clk) begin

        if (loader_reset)
            load_done_count <= 0;

        else if (load_done)
            load_done_count <= load_done_count + 1;

    end


    // =========================================================
    // CHECK BOOL
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
                    "PASS: %-38s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-38s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // CHECK 32
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
                    "PASS: %-38s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-38s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // REGISTER CHECK
    // =========================================================

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


    // =========================================================
    // IMEM CHECK
    // =========================================================

    task automatic check_imem (
        input string       name,
        input integer      word_index,
        input logic [31:0] expected
    );

        begin

            check32(
                name,
                dut.if_stage_inst.imem.memory[word_index],
                expected
            );

        end

    endtask


    // =========================================================
    // UART-RX ABSTRACT BYTE
    // =========================================================

    task automatic send_byte (
        input logic [7:0] value
    );

        begin

            @(negedge clk);

            rx_byte_data  = value;
            rx_byte_valid = 1'b1;


            @(negedge clk);

            rx_byte_valid = 1'b0;

        end

    endtask


    // =========================================================
    // BEGIN LOAD
    // =========================================================

    task automatic send_begin (
        input logic [15:0] instruction_count
    );

        begin

            send_byte(CMD_BEGIN);

            send_byte(
                instruction_count[15:8]
            );

            send_byte(
                instruction_count[7:0]
            );

        end

    endtask


    // =========================================================
    // WRITE WORD
    // =========================================================

    task automatic send_write (
        input logic [15:0] address,
        input logic [31:0] data
    );

        begin

            send_byte(CMD_WRITE);

            send_byte(address[15:8]);
            send_byte(address[7:0]);

            send_byte(data[31:24]);
            send_byte(data[23:16]);
            send_byte(data[15:8]);
            send_byte(data[7:0]);

        end

    endtask


    // =========================================================
    // END LOAD
    // =========================================================

    task automatic send_end;

        begin

            send_byte(CMD_END);

        end

    endtask


    // =========================================================
    // RUN UNTIL HALT
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

        end

    endtask


    // =========================================================
    // TEST
    // =========================================================

    initial begin

        clk = 1'b0;

        core_reset   = 1'b1;
        loader_reset = 1'b1;

        rx_byte_valid = 1'b0;
        rx_byte_data  = 8'd0;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;


        // =====================================================
        // RESET INICIAL
        // =====================================================

        repeat (2)
            @(posedge clk);

        @(negedge clk);

        // El loader empieza a funcionar.
        //
        // El procesador continúa mantenido en reset.

        loader_reset = 1'b0;


        // =====================================================
        // PROGRAMA A
        //
        // addi x1,x0,10
        // addi x2,x0,20
        // add  x3,x1,x2
        // HALT
        //
        // Resultado:
        //
        // x1 = 10
        // x2 = 20
        // x3 = 30
        // =====================================================

        $display("");
        $display("==============================================");
        $display("LOAD PROGRAM A");
        $display("==============================================");


        send_begin(16'd4);


        send_write(
            16'd0,
            32'h00A00093
        );

        send_write(
            16'd4,
            32'h01400113
        );

        send_write(
            16'd8,
            32'h002081B3
        );

        send_write(
            16'd12,
            32'h0000000B
        );


        send_end();

        #1;


        check_bool(
            "PROGRAM A LOAD ERROR",
            load_error,
            1'b0
        );


        check32(
            "PROGRAM A RECEIVED WORDS",
            received_instructions,
            32'd4
        );


        // Core estuvo en reset durante toda la carga.

        check32(
            "PC HELD AT ZERO WHILE LOADING",
            dut.if_pc_current,
            32'd0
        );


        check_bool(
            "PIPELINE EMPTY WHILE LOADING",
            pipeline_empty,
            1'b1
        );


        // Verificar contenido físico de IMEM.

        check_imem(
            "PROGRAM A IMEM[0]",
            0,
            32'h00A00093
        );

        check_imem(
            "PROGRAM A IMEM[1]",
            1,
            32'h01400113
        );

        check_imem(
            "PROGRAM A IMEM[2]",
            2,
            32'h002081B3
        );

        check_imem(
            "PROGRAM A IMEM[3]",
            3,
            32'h0000000B
        );


        // =====================================================
        // EJECUTAR PROGRAMA A
        // =====================================================

        $display("");
        $display("==============================================");
        $display("RUN PROGRAM A");
        $display("==============================================");


        @(negedge clk);

        core_reset = 1'b0;


        run_until_halted(
            "PROGRAM A",
            50
        );


        check_bool(
            "PROGRAM A PIPELINE EMPTY",
            pipeline_empty,
            1'b1
        );


        check_reg(
            "PROGRAM A x1",
            1,
            32'd10
        );

        check_reg(
            "PROGRAM A x2",
            2,
            32'd20
        );

        check_reg(
            "PROGRAM A x3",
            3,
            32'd30
        );


        // =====================================================
        // PREPARAR REPROGRAMACIÓN
        //
        // Se resetea EL CORE.
        //
        // Instruction Memory NO se borra.
        // Program Loader NO se resetea.
        // =====================================================

        $display("");
        $display("==============================================");
        $display("REPROGRAM PROCESSOR");
        $display("==============================================");


        @(negedge clk);

        core_reset = 1'b1;


        repeat (2)
            @(posedge clk);

        #1;


        // Register File sí vuelve a su estado inicial.

        check_reg(
            "x1 CLEARED BY CORE RESET",
            1,
            32'd0
        );

        check_reg(
            "x2 CLEARED BY CORE RESET",
            2,
            32'd0
        );

        check_reg(
            "x3 CLEARED BY CORE RESET",
            3,
            32'd0
        );


        // Pero IMEM conserva el programa.

        check_imem(
            "IMEM SURVIVES CORE RESET",
            0,
            32'h00A00093
        );


        // =====================================================
        // PROGRAMA B
        //
        // addi x5,x0,7
        // addi x6,x5,8
        // HALT
        //
        // Resultado:
        //
        // x5 = 7
        // x6 = 15
        // =====================================================

        send_begin(16'd3);


        send_write(
            16'd0,
            32'h00700293
        );

        send_write(
            16'd4,
            32'h00828313
        );

        send_write(
            16'd8,
            32'h0000000B
        );


        send_end();

        #1;


        check_bool(
            "PROGRAM B LOAD ERROR",
            load_error,
            1'b0
        );


        check32(
            "PROGRAM B RECEIVED WORDS",
            received_instructions,
            32'd3
        );


        // =====================================================
        // VERIFICAR REPROGRAMACIÓN
        // =====================================================

        check_imem(
            "PROGRAM B IMEM[0]",
            0,
            32'h00700293
        );

        check_imem(
            "PROGRAM B IMEM[1]",
            1,
            32'h00828313
        );

        check_imem(
            "PROGRAM B IMEM[2]",
            2,
            32'h0000000B
        );


        // Esta posición no fue sobrescrita.
        //
        // Conserva el HALT viejo del programa A.
        //
        // Esto demuestra que no vaciamos toda IMEM.

        check_imem(
            "OLD IMEM[3] PRESERVED",
            3,
            32'h0000000B
        );


        // =====================================================
        // EJECUTAR PROGRAMA B
        // =====================================================

        $display("");
        $display("==============================================");
        $display("RUN PROGRAM B");
        $display("==============================================");


        @(negedge clk);

        core_reset = 1'b0;


        run_until_halted(
            "PROGRAM B",
            50
        );


        check_bool(
            "PROGRAM B PIPELINE EMPTY",
            pipeline_empty,
            1'b1
        );


        check_reg(
            "PROGRAM B x5",
            5,
            32'd7
        );

        check_reg(
            "PROGRAM B x6",
            6,
            32'd15
        );


        // Los resultados del programa A no reaparecen.

        check_reg(
            "PROGRAM B x1 REMAINS ZERO",
            1,
            32'd0
        );

        check_reg(
            "PROGRAM B x2 REMAINS ZERO",
            2,
            32'd0
        );

        check_reg(
            "PROGRAM B x3 REMAINS ZERO",
            3,
            32'd0
        );


        // =====================================================
        // LOAD COUNT
        // =====================================================

        check32(
            "TWO DYNAMIC LOADS COMPLETED",
            load_done_count,
            32'd2
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("DYNAMIC PROGRAM LOADING TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("Load done    : %0d", load_done_count);
        $display("==============================================");
        $display("");


        if (tests_failed == 0) begin

            $display(
                "PASS: pipeline_program_loading"
            );

        end
        else begin

            $fatal(
                1,
                "FAIL: dynamic program loading"
            );

        end


        $finish;

    end

endmodule
