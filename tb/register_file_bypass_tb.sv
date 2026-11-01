`timescale 1ns / 1ps

module register_file_bypass_tb;

    logic clk;
    logic reset;

    logic [4:0] read_register1;
    logic [4:0] read_register2;

    logic [31:0] read_data1;
    logic [31:0] read_data2;

    logic        write_enable;
    logic [4:0]  write_register;
    logic [31:0] write_data;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    register_file dut (
        .clk            (clk),
        .reset          (reset),

        .read_register1 (read_register1),
        .read_register2 (read_register2),

        .read_data1     (read_data1),
        .read_data2     (read_data2),

        .write_enable   (write_enable),
        .write_register (write_register),
        .write_data     (write_data)
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
                    "PASS: %-22s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-22s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        read_register1 = 5'd0;
        read_register2 = 5'd0;

        write_enable   = 1'b0;
        write_register = 5'd0;
        write_data     = 32'd0;


        // =====================================================
        // RESET
        // =====================================================

        reset = 1'b1;

        repeat (2) @(posedge clk);

        reset = 1'b0;

        #1;


        // =====================================================
        // TEST 1
        // x0 siempre debe leerse como 0.
        // =====================================================

        read_register1 = 5'd0;
        read_register2 = 5'd0;

        #1;

        check32(
            "X0 READ PORT 1",
            read_data1,
            32'd0
        );

        check32(
            "X0 READ PORT 2",
            read_data2,
            32'd0
        );


        // =====================================================
        // Preparar x5 = 0x11111111 mediante escritura normal.
        // =====================================================

        write_enable   = 1'b1;
        write_register = 5'd5;
        write_data     = 32'h11111111;

        @(posedge clk);
        #1;

        write_enable = 1'b0;

        read_register1 = 5'd5;

        #1;

        check32(
            "NORMAL READ",
            read_data1,
            32'h11111111
        );


        // =====================================================
        // TEST 3
        // WB -> ID BYPASS SOBRE READ PORT 1
        //
        // El array todavía contiene 0x11111111.
        //
        // WB quiere escribir 0x22222222 en x5.
        //
        // Antes incluso del próximo posedge,
        // ID debe observar 0x22222222.
        // =====================================================

        read_register1 = 5'd5;

        write_enable   = 1'b1;
        write_register = 5'd5;
        write_data     = 32'h22222222;

        #1;

        check32(
            "BYPASS READ PORT 1",
            read_data1,
            32'h22222222
        );


        // =====================================================
        // TEST 4
        // WB -> ID BYPASS SOBRE READ PORT 2
        // =====================================================

        read_register2 = 5'd5;

        #1;

        check32(
            "BYPASS READ PORT 2",
            read_data2,
            32'h22222222
        );


        // =====================================================
        // TEST 5
        // No debe haber falso bypass.
        //
        // WB escribe x7 pero ID lee x5.
        // =====================================================

        write_register = 5'd7;
        write_data     = 32'hAAAAAAAA;

        #1;

        check32(
            "NO FALSE BYPASS",
            read_data1,
            32'h11111111
        );


        // =====================================================
        // TEST 6
        // Intento de escritura sobre x0.
        //
        // x0 debe seguir entregando cero.
        // =====================================================

        read_register1 = 5'd0;

        write_register = 5'd0;
        write_data     = 32'hDEADBEEF;

        #1;

        check32(
            "NO BYPASS X0",
            read_data1,
            32'd0
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("REGISTER FILE WB->ID BYPASS TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: register_file_bypass");

        end
        else begin

            $fatal(
                1,
                "FAIL: register_file_bypass | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
