`timescale 1ns / 1ps

module uart_program_loader_tb;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer OVERSAMPLING = 16;
    localparam integer IMEM_DEPTH   = 256;

    // Duración aproximada del bit generado por una PC ideal.
    localparam integer BIT_CLKS =
        (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;

    localparam logic [7:0] CMD_BEGIN = 8'h4C; // 'L'
    localparam logic [7:0] CMD_WRITE = 8'h57; // 'W'
    localparam logic [7:0] CMD_END   = 8'h45; // 'E'

    logic clk;
    logic reset;

    logic baud_tick;
    logic uart_rx_line;

    logic [7:0] rx_byte_data;
    logic       rx_byte_valid;
    logic       rx_frame_error;

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

    integer uart_byte_count;
    integer frame_error_count;
    integer imem_write_count;
    integer load_done_count;

    // =========================================================
    // DUTS
    // =========================================================

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) baud_gen_inst (
        .clk   (clk),
        .reset (reset),
        .tick  (baud_tick)
    );

    uart_rx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) uart_rx_inst (
        .clk            (clk),
        .reset          (reset),
        .baud_tick      (baud_tick),

        .rx             (uart_rx_line),

        .rx_byte_data   (rx_byte_data),
        .rx_byte_valid  (rx_byte_valid),
        .rx_frame_error (rx_frame_error)
    );

    program_loader #(
        .IMEM_DEPTH (IMEM_DEPTH)
    ) loader_inst (
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
        .DEPTH (IMEM_DEPTH)
    ) imem_inst (
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
    // EVENT COUNTERS
    // =========================================================

    always @(posedge clk) begin
        #1;

        if (reset) begin
            uart_byte_count  = 0;
            frame_error_count = 0;
            imem_write_count = 0;
            load_done_count  = 0;
        end
        else begin

            if (rx_byte_valid)
                uart_byte_count = uart_byte_count + 1;

            if (rx_frame_error)
                frame_error_count = frame_error_count + 1;

            if (imem_write_enable)
                imem_write_count = imem_write_count + 1;

            if (load_done)
                load_done_count = load_done_count + 1;

        end
    end

    // =========================================================
    // UART DRIVER
    //
    // Emula físicamente lo que hará el TX de la PC:
    //
    // IDLE = 1
    // START = 0
    // D0 ... D7
    // STOP = 1
    // =========================================================

    task automatic hold_line (
        input logic value,
        input integer cycles
    );
        integer k;
        begin

            uart_rx_line = value;

            for (k = 0; k < cycles; k = k + 1)
                @(posedge clk);

        end
    endtask

    task automatic send_uart_byte (
        input logic [7:0] value
    );
        integer bit_i;
        begin

            // START
            hold_line(1'b0, BIT_CLKS);

            // D0 ... D7, LSB first
            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1)
                hold_line(value[bit_i], BIT_CLKS);

            // STOP
            hold_line(1'b1, BIT_CLKS);

            // Pequeño tiempo de reposo entre bytes.
            hold_line(1'b1, BIT_CLKS / 2);

        end
    endtask

    // =========================================================
    // PROTOCOL HELPERS
    // =========================================================

    task automatic send_write_word (
        input logic [15:0] address,
        input logic [31:0] data
    );
        begin

            send_uart_byte(CMD_WRITE);

            send_uart_byte(address[15:8]);
            send_uart_byte(address[7:0]);

            send_uart_byte(data[31:24]);
            send_uart_byte(data[23:16]);
            send_uart_byte(data[15:8]);
            send_uart_byte(data[7:0]);

        end
    endtask

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
                    "PASS: %-32s | VALUE=%0d",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-32s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );
            end

        end
    endtask

    task automatic check_int (
        input string  name,
        input integer received,
        input integer expected
    );
        begin

            tests_run = tests_run + 1;

            if (received == expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-32s | VALUE=%0d",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-32s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );
            end

        end
    endtask

    task automatic check16 (
        input string       name,
        input logic [15:0] received,
        input logic [15:0] expected
    );
        begin

            tests_run = tests_run + 1;

            if (received === expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-32s | VALUE=%04h",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-32s | VALUE=%04h expected=%04h",
                    name,
                    received,
                    expected
                );
            end

        end
    endtask

    task automatic check_imem (
        input logic [31:0] address,
        input logic [31:0] expected,
        input string       name
    );
        begin

            read_address = address;
            #1;

            tests_run = tests_run + 1;

            if (instruction === expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-32s | IMEM[%0d]=%08h",
                    name,
                    address,
                    instruction
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-32s | IMEM[%0d]=%08h expected=%08h",
                    name,
                    address,
                    instruction,
                    expected
                );
            end

        end
    endtask

    // =========================================================
    // TEST
    // =========================================================

    initial begin

        clk          = 1'b0;
        reset        = 1'b1;
        uart_rx_line = 1'b1;
        read_address = 32'd0;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Desfase intencional respecto del clock.
        #3;

        $display("");
        $display("UART PROGRAM LOAD");
        $display("=================");

        // -----------------------------------------------------
        // Programa:
        //
        // 0x00000000: addi x1,x0,10  = 00A00093
        // 0x00000004: addi x2,x0,20  = 01400113
        // 0x00000008: add  x3,x1,x2  = 002081B3
        // 0x0000000C: HALT           = 0000000B
        // -----------------------------------------------------

        send_uart_byte(CMD_BEGIN);
        send_uart_byte(8'h00);
        send_uart_byte(8'h04);

        send_write_word(16'h0000, 32'h00A00093);
        send_write_word(16'h0004, 32'h01400113);
        send_write_word(16'h0008, 32'h002081B3);
        send_write_word(16'h000C, 32'h0000000B);

        send_uart_byte(CMD_END);

        // Dar tiempo a que el último pulso atraviese loader/IMEM.
        repeat (20) @(posedge clk);
        #1;

        // Paquete:
        // 3 bytes BEGIN/count
        // 4 * 7 bytes WRITE
        // 1 byte END
        // = 32 bytes UART.
        check_int(
            "UART BYTES RECEIVED",
            uart_byte_count,
            32
        );

        check_int(
            "UART FRAME ERRORS",
            frame_error_count,
            0
        );

        check16(
            "EXPECTED INSTRUCTIONS",
            expected_instructions,
            16'd4
        );

        check16(
            "RECEIVED INSTRUCTIONS",
            received_instructions,
            16'd4
        );

        check_int(
            "IMEM WRITE COUNT",
            imem_write_count,
            4
        );

        check_int(
            "LOAD DONE COUNT",
            load_done_count,
            1
        );

        check_bool(
            "LOAD ACTIVE AFTER END",
            load_active,
            1'b0
        );

        check_bool(
            "LOAD ERROR",
            load_error,
            1'b0
        );

        check_imem(
            32'h00000000,
            32'h00A00093,
            "INSTRUCTION 0"
        );

        check_imem(
            32'h00000004,
            32'h01400113,
            "INSTRUCTION 1"
        );

        check_imem(
            32'h00000008,
            32'h002081B3,
            "INSTRUCTION 2"
        );

        check_imem(
            32'h0000000C,
            32'h0000000B,
            "HALT"
        );

        $display("");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("UART bytes   : %0d", uart_byte_count);
        $display("IMEM writes  : %0d", imem_write_count);
        $display("Load done    : %0d", load_done_count);

        if (tests_failed == 0)
            $display("PASS: uart_program_loader");
        else
            $fatal(1, "FAIL: uart_program_loader");

        $finish;

    end

endmodule
