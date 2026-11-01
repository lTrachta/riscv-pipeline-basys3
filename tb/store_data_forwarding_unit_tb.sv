`timescale 1ns / 1ps

module store_data_forwarding_unit_tb;

    logic        ex_mem_valid;
    logic        ex_mem_mem_write;
    logic [4:0]  ex_mem_rs2;
    logic [31:0] ex_mem_store_data;

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;

    logic        forward_store_data;
    logic [31:0] store_data_out;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    store_data_forwarding_unit dut (
        .ex_mem_valid       (ex_mem_valid),
        .ex_mem_mem_write   (ex_mem_mem_write),
        .ex_mem_rs2         (ex_mem_rs2),
        .ex_mem_store_data  (ex_mem_store_data),

        .wb_write_enable    (wb_write_enable),
        .wb_write_register  (wb_write_register),
        .wb_write_data      (wb_write_data),

        .forward_store_data (forward_store_data),
        .store_data_out     (store_data_out)
    );


    task automatic check_case (
        input string       name,
        input logic        expected_forward,
        input logic [31:0] expected_data
    );

        begin

            tests_run = tests_run + 1;

            #1;

            if (
                (forward_store_data === expected_forward) &&
                (store_data_out === expected_data)
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-24s | FWD=%0d DATA=%08h",
                    name,
                    forward_store_data,
                    store_data_out
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-24s | FWD=%0d DATA=%08h | expected FWD=%0d DATA=%08h",
                    name,
                    forward_store_data,
                    store_data_out,
                    expected_forward,
                    expected_data
                );

            end

        end

    endtask


    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;


        // Estado base.
        ex_mem_valid      = 1'b1;
        ex_mem_mem_write  = 1'b1;
        ex_mem_rs2        = 5'd5;
        ex_mem_store_data = 32'h11111111;

        wb_write_enable   = 1'b0;
        wb_write_register = 5'd0;
        wb_write_data     = 32'h22222222;


        // 1. Sin productor WB.
        check_case(
            "NO WB PRODUCER",
            1'b0,
            32'h11111111
        );


        // 2. Match real -> forwarding.
        wb_write_enable   = 1'b1;
        wb_write_register = 5'd5;

        check_case(
            "WB MATCH",
            1'b1,
            32'h22222222
        );


        // 3. Registro distinto.
        wb_write_register = 5'd6;

        check_case(
            "WB RD MISMATCH",
            1'b0,
            32'h11111111
        );


        // 4. WB deshabilitado.
        wb_write_register = 5'd5;
        wb_write_enable   = 1'b0;

        check_case(
            "WB DISABLED",
            1'b0,
            32'h11111111
        );


        // 5. Instrucción de MEM inválida.
        wb_write_enable = 1'b1;
        ex_mem_valid    = 1'b0;

        check_case(
            "STORE INVALID",
            1'b0,
            32'h11111111
        );


        // 6. No es store.
        ex_mem_valid     = 1'b1;
        ex_mem_mem_write = 1'b0;

        check_case(
            "NOT STORE",
            1'b0,
            32'h11111111
        );


        // 7. x0 nunca debe reenviarse.
        ex_mem_mem_write  = 1'b1;
        ex_mem_rs2        = 5'd0;
        wb_write_register = 5'd0;
        wb_write_enable   = 1'b1;
        wb_write_data     = 32'hDEADBEEF;

        check_case(
            "X0",
            1'b0,
            32'h11111111
        );


        $display("");
        $display("==============================================");
        $display("STORE DATA FORWARDING TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0)
            $display("PASS: store_data_forwarding_unit");
        else
            $fatal(
                1,
                "FAIL: store_data_forwarding_unit | %0d failures",
                tests_failed
            );

        #5;
        $finish;

    end

endmodule
