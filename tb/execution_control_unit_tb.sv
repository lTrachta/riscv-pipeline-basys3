`timescale 1ns / 1ps

module execution_control_unit_tb;

    logic clk;
    logic reset;
    logic enable;

    logic [31:0] if_id_instruction;
    logic        if_id_valid;

    logic redirect_valid;
    logic pipeline_empty;

    logic running;
    logic draining;
    logic halted;

    logic halt_in_id;
    logic halt_accept;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    localparam logic [31:0] HALT =
        32'h0000000B;


    // =========================================================
    // DUT
    // =========================================================

    execution_control_unit dut (
        .clk               (clk),
        .reset             (reset),
        .enable            (enable),

        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),

        .redirect_valid    (redirect_valid),
        .pipeline_empty    (pipeline_empty),

        .running           (running),
        .draining          (draining),
        .halted            (halted),

        .halt_in_id        (halt_in_id),
        .halt_accept       (halt_accept)
    );


    always #5 clk = ~clk;


    // =========================================================
    // CHECK
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


    // =========================================================
    // TEST
    // =========================================================

    initial begin

        clk = 1'b0;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        reset             = 1'b1;
        enable            = 1'b1;
        if_id_instruction = 32'd0;
        if_id_valid       = 1'b0;
        redirect_valid    = 1'b0;
        pipeline_empty    = 1'b1;


        // =====================================================
        // RESET
        //
        // Pipeline vacío NO significa HALTED.
        // =====================================================

        repeat (2) @(posedge clk);
        #1;

        check_bool("RESET RUNNING", running, 1'b1);
        check_bool("RESET NOT DRAINING", draining, 1'b0);
        check_bool("RESET NOT HALTED", halted, 1'b0);


        @(negedge clk);
        reset = 1'b0;


        // =====================================================
        // PIPELINE VACÍO SIN HALT
        //
        // Debe seguir RUNNING.
        // =====================================================

        @(posedge clk);
        #1;

        check_bool(
            "EMPTY WITHOUT HALT RUNNING",
            running,
            1'b1
        );

        check_bool(
            "EMPTY WITHOUT HALT NOT HALTED",
            halted,
            1'b0
        );


        // =====================================================
        // HALT WRONG-PATH
        //
        // Existe redirect desde EX.
        // HALT está físicamente en ID pero NO debe aceptarse.
        // =====================================================

        @(negedge clk);

        if_id_instruction = HALT;
        if_id_valid       = 1'b1;
        redirect_valid    = 1'b1;
        pipeline_empty    = 1'b0;

        #1;

        check_bool(
            "WRONG PATH HALT DETECTED",
            halt_in_id,
            1'b1
        );

        check_bool(
            "WRONG PATH HALT REJECTED",
            halt_accept,
            1'b0
        );


        @(posedge clk);
        #1;

        check_bool(
            "REDIRECT KEEPS RUNNING",
            running,
            1'b1
        );


        // =====================================================
        // HALT REAL
        // =====================================================

        @(negedge clk);

        redirect_valid = 1'b0;

        #1;

        check_bool(
            "REAL HALT ACCEPTED",
            halt_accept,
            1'b1
        );


        @(posedge clk);
        #1;

        check_bool(
            "ENTER DRAINING",
            draining,
            1'b1
        );

        check_bool(
            "NOT HALTED YET",
            halted,
            1'b0
        );


        // =====================================================
        // DRAINING CON PIPELINE TODAVÍA OCUPADO
        // =====================================================

        @(negedge clk);

        if_id_instruction = 32'd0;
        if_id_valid       = 1'b0;
        pipeline_empty    = 1'b0;

        @(posedge clk);
        #1;

        check_bool(
            "DRAINING CONTINUES",
            draining,
            1'b1
        );


        // =====================================================
        // PIPELINE VACÍO
        // =====================================================

        @(negedge clk);

        pipeline_empty = 1'b1;

        @(posedge clk);
        #1;

        check_bool(
            "HALTED AFTER DRAIN",
            halted,
            1'b1
        );

        check_bool(
            "NOT RUNNING AFTER HALT",
            running,
            1'b0
        );

        check_bool(
            "NOT DRAINING AFTER HALT",
            draining,
            1'b0
        );


        // =====================================================
        // RESET DEBE PERMITIR NUEVA EJECUCIÓN
        // =====================================================

        @(negedge clk);
        reset = 1'b1;

        @(posedge clk);
        #1;

        check_bool(
            "RESET RESTARTS RUNNING",
            running,
            1'b1
        );

        check_bool(
            "RESET CLEARS HALTED",
            halted,
            1'b0
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("EXECUTION CONTROL UNIT TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0)
            $display("PASS: execution_control_unit");
        else
            $fatal(1, "FAIL: execution_control_unit");

        $finish;

    end

endmodule
