`timescale 1ns / 1ps

module hazard_detection_unit_tb;

    logic [31:0] if_id_instruction;
    logic        if_id_valid;

    logic        id_ex_valid;
    logic        id_ex_mem_read;
    logic [4:0]  id_ex_rd;

    logic        stall;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    hazard_detection_unit dut (
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),

        .id_ex_valid       (id_ex_valid),
        .id_ex_mem_read    (id_ex_mem_read),
        .id_ex_rd          (id_ex_rd),

        .stall             (stall)
    );


    task automatic check_stall (
        input string       name,
        input logic [31:0] instruction,
        input logic        expected_stall
    );

        begin

            tests_run = tests_run + 1;

            if_id_instruction = instruction;

            #1;

            if (stall === expected_stall) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-28s | STALL=%0d",
                    name,
                    stall
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-28s | STALL=%0d expected=%0d",
                    name,
                    stall,
                    expected_stall
                );

            end

        end

    endtask


    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        // -----------------------------------------------------
        // Por defecto:
        //
        // en EX tenemos:
        //
        // lw x5,...
        // -----------------------------------------------------

        if_id_valid    = 1'b1;

        id_ex_valid    = 1'b1;
        id_ex_mem_read = 1'b1;
        id_ex_rd       = 5'd5;


        // =====================================================
        // 1. R-TYPE DEPENDENCIA EN rs1
        //
        // add x6,x5,x2
        // =====================================================

        check_stall(
            "R-TYPE RS1",
            32'h00228333,
            1'b1
        );


        // =====================================================
        // 2. R-TYPE DEPENDENCIA EN rs2
        //
        // add x6,x2,x5
        // =====================================================

        check_stall(
            "R-TYPE RS2",
            32'h00510333,
            1'b1
        );


        // =====================================================
        // 3. R-TYPE INDEPENDIENTE
        //
        // add x6,x2,x3
        // =====================================================

        check_stall(
            "R-TYPE NO HAZARD",
            32'h00310333,
            1'b0
        );


        // =====================================================
        // 4. LOAD DEPENDIENTE EN BASE
        //
        // lw x6,0(x5)
        // =====================================================

        check_stall(
            "LOAD BASE",
            32'h0002A303,
            1'b1
        );


        // =====================================================
        // 5. STORE DEPENDIENTE EN BASE
        //
        // sw x7,0(x5)
        //
        // x5 = rs1 → necesario en EX.
        // =====================================================

        check_stall(
            "STORE BASE",
            32'h0072A023,
            1'b1
        );


        // =====================================================
        // 6. STORE DEPENDIENTE SOLO EN DATA
        //
        // sw x5,0(x2)
        //
        // x5 = rs2.
        //
        // NO hacemos stall porque será resuelto mediante
        // MEM forwarding en el Paso 14.4.
        // =====================================================

        check_stall(
            "STORE DATA ONLY",
            32'h00512023,
            1'b0
        );


        // =====================================================
        // 7. BRANCH DEPENDIENTE EN rs1
        //
        // beq x5,x0,...
        // =====================================================

        check_stall(
            "BRANCH RS1",
            32'h00028063,
            1'b1
        );


        // =====================================================
        // 8. BRANCH DEPENDIENTE EN rs2
        //
        // beq x0,x5,...
        // =====================================================

        check_stall(
            "BRANCH RS2",
            32'h00500063,
            1'b1
        );


        // =====================================================
        // 9. ADDI DEPENDIENTE EN rs1
        //
        // addi x6,x5,5
        // =====================================================

        check_stall(
            "ADDI RS1",
            32'h00528313,
            1'b1
        );


        // =====================================================
        // 10. FALSO rs2 EN ADDI
        //
        // addi x6,x2,5
        //
        // Los bits físicos 24:20 valen 00101 = 5,
        // pero forman parte del inmediato.
        //
        // NO debe hacer stall.
        // =====================================================

        check_stall(
            "ADDI FALSE RS2",
            32'h00510313,
            1'b0
        );


        // =====================================================
        // 11. x0
        //
        // Un load con rd=x0 no genera dependencia real.
        // =====================================================

        id_ex_rd = 5'd0;

        check_stall(
            "RD X0",
            32'h00000033,
            1'b0
        );


        // =====================================================
        // 12. PRODUCTOR NO ES LOAD
        // =====================================================

        id_ex_rd       = 5'd5;
        id_ex_mem_read = 1'b0;

        check_stall(
            "PRODUCER NOT LOAD",
            32'h00228333,
            1'b0
        );


        // =====================================================
        // 13. IF/ID INVÁLIDO
        // =====================================================

        id_ex_mem_read = 1'b1;
        if_id_valid    = 1'b0;

        check_stall(
            "IF/ID INVALID",
            32'h00228333,
            1'b0
        );


        // =====================================================
        // 14. ID/EX INVÁLIDO
        // =====================================================

        if_id_valid = 1'b1;
        id_ex_valid = 1'b0;

        check_stall(
            "ID/EX INVALID",
            32'h00228333,
            1'b0
        );


        // =====================================================
        // 15. LUI NO USA REGISTROS FUENTE
        // =====================================================

        id_ex_valid = 1'b1;

        check_stall(
            "LUI",
            32'h12345337,
            1'b0
        );


        // =====================================================
        // 16. JAL NO USA REGISTROS FUENTE
        // =====================================================

        check_stall(
            "JAL",
            32'h000000EF,
            1'b0
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("HAZARD DETECTION UNIT TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: hazard_detection_unit");

        end
        else begin

            $fatal(
                1,
                "FAIL: hazard_detection_unit | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
