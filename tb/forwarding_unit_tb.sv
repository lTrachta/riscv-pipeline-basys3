`timescale 1ns / 1ps

module forwarding_unit_tb;

    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;

    logic [4:0] ex_mem_rd;
    logic       ex_mem_reg_write;

    logic [4:0] mem_wb_rd;
    logic       mem_wb_reg_write;

    logic [1:0] forward_a;
    logic [1:0] forward_b;


    localparam logic [1:0] FORWARD_ID_EX  = 2'b00;
    localparam logic [1:0] FORWARD_MEM_WB = 2'b01;
    localparam logic [1:0] FORWARD_EX_MEM = 2'b10;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    forwarding_unit dut (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),

        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_write (ex_mem_reg_write),

        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_write (mem_wb_reg_write),

        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );


    task automatic check_forwarding (
        input string      name,
        input logic [1:0] expected_a,
        input logic [1:0] expected_b
    );

        begin

            tests_run = tests_run + 1;

            #1;

            if (
                forward_a === expected_a &&
                forward_b === expected_b
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-20s | A=%b B=%b",
                    name,
                    forward_a,
                    forward_b
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", name);

                $display(
                    "  ForwardA received=%b expected=%b",
                    forward_a,
                    expected_a
                );

                $display(
                    "  ForwardB received=%b expected=%b",
                    forward_b,
                    expected_b
                );

                $display("");

            end

        end

    endtask


    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;


        // =====================================================
        // TEST 1
        // Sin dependencia
        // =====================================================

        id_ex_rs1        = 5'd1;
        id_ex_rs2        = 5'd2;

        ex_mem_rd        = 5'd3;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd4;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "NO HAZARD",
            FORWARD_ID_EX,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 2
        // EX/MEM -> A
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd3;

        ex_mem_rd        = 5'd5;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd8;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "EX/MEM -> A",
            FORWARD_EX_MEM,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 3
        // EX/MEM -> B
        // =====================================================

        id_ex_rs1 = 5'd3;
        id_ex_rs2 = 5'd5;

        ex_mem_rd        = 5'd5;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd8;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "EX/MEM -> B",
            FORWARD_ID_EX,
            FORWARD_EX_MEM
        );


        // =====================================================
        // TEST 4
        // EX/MEM -> A y B
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd5;

        ex_mem_rd        = 5'd5;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd8;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "EX/MEM -> A+B",
            FORWARD_EX_MEM,
            FORWARD_EX_MEM
        );


        // =====================================================
        // TEST 5
        // MEM/WB -> A
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd3;

        ex_mem_rd        = 5'd8;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd5;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "MEM/WB -> A",
            FORWARD_MEM_WB,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 6
        // MEM/WB -> B
        // =====================================================

        id_ex_rs1 = 5'd3;
        id_ex_rs2 = 5'd5;

        ex_mem_rd        = 5'd8;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd5;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "MEM/WB -> B",
            FORWARD_ID_EX,
            FORWARD_MEM_WB
        );


        // =====================================================
        // TEST 7
        // A y B desde diferentes etapas
        //
        // A <- MEM/WB
        // B <- EX/MEM
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd6;

        ex_mem_rd        = 5'd6;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd5;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "MIXED A/B",
            FORWARD_MEM_WB,
            FORWARD_EX_MEM
        );


        // =====================================================
        // TEST 8
        // Prioridad EX/MEM sobre MEM/WB
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd3;

        ex_mem_rd        = 5'd5;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd5;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "PRIORITY EX/MEM",
            FORWARD_EX_MEM,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 9
        // x0 jamás genera forwarding
        // =====================================================

        id_ex_rs1 = 5'd0;
        id_ex_rs2 = 5'd0;

        ex_mem_rd        = 5'd0;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd0;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "X0",
            FORWARD_ID_EX,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 10
        //
        // EX/MEM coincide pero RegWrite=0.
        // MEM/WB sí contiene una dependencia válida.
        //
        // MEM/WB debe ganar.
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd3;

        ex_mem_rd        = 5'd5;
        ex_mem_reg_write = 1'b0;

        mem_wb_rd        = 5'd5;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "EX INVALID MEM VALID",
            FORWARD_MEM_WB,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 11
        // Coincidencia física pero nadie escribe.
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd6;

        ex_mem_rd        = 5'd5;
        ex_mem_reg_write = 1'b0;

        mem_wb_rd        = 5'd6;
        mem_wb_reg_write = 1'b0;

        check_forwarding(
            "REGWRITE OFF",
            FORWARD_ID_EX,
            FORWARD_ID_EX
        );


        // =====================================================
        // TEST 12
        // Ambos operands desde MEM/WB.
        // =====================================================

        id_ex_rs1 = 5'd5;
        id_ex_rs2 = 5'd5;

        ex_mem_rd        = 5'd8;
        ex_mem_reg_write = 1'b1;

        mem_wb_rd        = 5'd5;
        mem_wb_reg_write = 1'b1;

        check_forwarding(
            "MEM/WB -> A+B",
            FORWARD_MEM_WB,
            FORWARD_MEM_WB
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("FORWARDING UNIT TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: forwarding_unit");

        end
        else begin

            $fatal(
                1,
                "FAIL: forwarding_unit | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
