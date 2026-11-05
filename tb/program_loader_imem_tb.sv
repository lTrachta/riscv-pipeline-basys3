`timescale 1ns / 1ps

module program_loader_imem_tb;


    logic clk;
    logic reset;


    logic       rx_byte_valid;
    logic [7:0] rx_byte_data;


    logic        load_active;
    logic        load_done;
    logic        load_error;

    logic [15:0] expected_instructions;
    logic [15:0] received_instructions;


    logic        imem_write_enable;
    logic [31:0] imem_write_address;
    logic [31:0] imem_write_data;


    logic [31:0] read_address;
    logic [31:0] instruction;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer load_done_count;


    localparam logic [7:0] CMD_BEGIN =
        8'h4C;

    localparam logic [7:0] CMD_WRITE =
        8'h57;

    localparam logic [7:0] CMD_END =
        8'h45;


    // =========================================================
    // DUTS
    // =========================================================

    program_loader #(
        .IMEM_DEPTH(256)
    ) loader (
        .clk                   (clk),
        .reset                 (reset),

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


    instruction_memory #(
        .DEPTH(256)
    ) imem (
        .clk                   (clk),

        .address               (read_address),
        .instruction           (instruction),

        .program_write_enable  (imem_write_enable),
        .program_write_address (imem_write_address),
        .program_write_data    (imem_write_data)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // LOAD DONE COUNTER
    // =========================================================

    always @(posedge clk) begin

        if (reset)
            load_done_count <= 0;
        else if (load_done)
            load_done_count <= load_done_count + 1;

    end


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
                    "PASS: %-34s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-34s | VALUE=%0d expected=%0d",
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
                    "PASS: %-34s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-34s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // ENVIAR UN BYTE
    //
    // Simula lo que más adelante hará uart_rx:
    //
    // rx_byte_valid = 1 durante un ciclo
    // rx_byte_data  = byte recibido
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
    // READ IMEM
    // =========================================================

    task automatic check_imem (
        input string       name,
        input logic [31:0] address,
        input logic [31:0] expected
    );

        begin

            read_address = address;

            #1;

            check32(
                name,
                instruction,
                expected
            );

        end

    endtask


    // =========================================================
    // TEST
    // =========================================================

    initial begin

        clk = 1'b0;
        reset = 1'b1;

        rx_byte_valid = 1'b0;
        rx_byte_data  = 8'd0;

        read_address = 32'd0;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;


        // =====================================================
        // RESET
        // =====================================================

        repeat (2)
            @(posedge clk);

        #1;

        check_bool(
            "RESET LOAD ACTIVE",
            load_active,
            1'b0
        );

        check_bool(
            "RESET LOAD DONE",
            load_done,
            1'b0
        );

        check_bool(
            "RESET LOAD ERROR",
            load_error,
            1'b0
        );


        @(negedge clk);
        reset = 1'b0;


        // =====================================================
        // TEST 1
        //
        // CARGAR:
        //
        // addi x1,x0,10
        // addi x2,x0,20
        // add  x3,x1,x2
        // HALT
        // =====================================================

        send_begin(16'd4);


        check_bool(
            "LOAD ACTIVE AFTER BEGIN",
            load_active,
            1'b1
        );

        check32(
            "EXPECTED INSTRUCTIONS",
            expected_instructions,
            32'd4
        );


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


        check32(
            "RECEIVED INSTRUCTIONS",
            received_instructions,
            32'd4
        );


        send_end();

        #1;


        check_bool(
            "LOAD FINISHED",
            load_active,
            1'b0
        );

        check_bool(
            "LOAD WITHOUT ERROR",
            load_error,
            1'b0
        );


        // =====================================================
        // VERIFICAR MEMORIA
        // =====================================================

        check_imem(
            "IMEM ADDRESS 0",
            32'd0,
            32'h00A00093
        );

        check_imem(
            "IMEM ADDRESS 4",
            32'd4,
            32'h01400113
        );

        check_imem(
            "IMEM ADDRESS 8",
            32'd8,
            32'h002081B3
        );

        check_imem(
            "IMEM ADDRESS 12",
            32'd12,
            32'h0000000B
        );


        // =====================================================
        // TEST 2
        //
        // REPROGRAMAR CON UN PROGRAMA MÁS CORTO.
        //
        // addi x5,x0,7
        // HALT
        //
        // Sólo se sobrescriben addresses 0 y 4.
        // Addresses 8 y 12 deben conservar el programa viejo.
        // =====================================================

        send_begin(16'd2);


        send_write(
            16'd0,
            32'h00700293
        );

        send_write(
            16'd4,
            32'h0000000B
        );


        send_end();

        #1;


        check_bool(
            "RELOAD WITHOUT ERROR",
            load_error,
            1'b0
        );


        check_imem(
            "REPROGRAMMED ADDRESS 0",
            32'd0,
            32'h00700293
        );

        check_imem(
            "REPROGRAMMED ADDRESS 4",
            32'd4,
            32'h0000000B
        );


        // Las posiciones antiguas permanecen físicamente.

        check_imem(
            "OLD ADDRESS 8 PRESERVED",
            32'd8,
            32'h002081B3
        );

        check_imem(
            "OLD ADDRESS 12 PRESERVED",
            32'd12,
            32'h0000000B
        );


        // =====================================================
        // TEST 3
        //
        // DIRECCIÓN NO ALINEADA.
        //
        // Address 2 no es válida para una instrucción.
        // =====================================================

        send_begin(16'd1);


        send_write(
            16'd2,
            32'h12345678
        );


        check_bool(
            "UNALIGNED ADDRESS ERROR",
            load_error,
            1'b1
        );


        send_end();

        #1;


        check_bool(
            "INVALID LOAD NOT DONE",
            load_done,
            1'b0
        );


        // =====================================================
        // RESUMEN
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PROGRAM LOADER / IMEM TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("Load done    : %0d", load_done_count);
        $display("==============================================");
        $display("");


        if (tests_failed == 0)
            $display(
                "PASS: program_loader_imem"
            );
        else
            $fatal(
                1,
                "FAIL: program_loader_imem"
            );


        $finish;

    end

endmodule
