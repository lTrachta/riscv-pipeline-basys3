`timescale 1ns / 1ps

module wb_control_pipeline_tb;

    // =========================================================
    // ENTRADAS MEM/WB
    // =========================================================

    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;

    logic [4:0]  mem_wb_rd;
    logic [6:0]  mem_wb_opcode;

    logic        mem_wb_valid;

    logic        mem_wb_reg_write;
    logic [1:0]  mem_wb_wb_sel;

    // =========================================================
    // SALIDAS WB
    // =========================================================

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;


    // =========================================================
    // WB SELECT
    // =========================================================

    localparam logic [1:0] WB_SEL_ALU = 2'b00;
    localparam logic [1:0] WB_SEL_MEM = 2'b01;
    localparam logic [1:0] WB_SEL_PC4 = 2'b10;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    // =========================================================
    // DUT
    // =========================================================

    wb_stage dut (
        .mem_wb_pc             (mem_wb_pc),
        .mem_wb_alu_result     (mem_wb_alu_result),
        .mem_wb_load_data      (mem_wb_load_data),

        .mem_wb_rd             (mem_wb_rd),
        .mem_wb_opcode         (mem_wb_opcode),

        .mem_wb_valid          (mem_wb_valid),

        .mem_wb_reg_write      (mem_wb_reg_write),
        .mem_wb_wb_sel         (mem_wb_wb_sel),

        .wb_write_enable       (wb_write_enable),
        .wb_write_register     (wb_write_register),
        .wb_write_data         (wb_write_data)
    );


    // =========================================================
    // CHECK
    // =========================================================

    task automatic check_wb (
        input string       name,

        input logic        expected_enable,
        input logic [4:0]  expected_register,
        input logic [31:0] expected_data
    );

        begin

            tests_run = tests_run + 1;

            #1;

            if (
                wb_write_enable   === expected_enable   &&
                wb_write_register === expected_register &&
                wb_write_data     === expected_data
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-15s | WE=%0d RD=%0d DATA=%08h",
                    name,
                    wb_write_enable,
                    wb_write_register,
                    wb_write_data
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", name);

                $display(
                    "  ENABLE   received=%0d expected=%0d",
                    wb_write_enable,
                    expected_enable
                );

                $display(
                    "  REGISTER received=%0d expected=%0d",
                    wb_write_register,
                    expected_register
                );

                $display(
                    "  DATA     received=%08h expected=%08h",
                    wb_write_data,
                    expected_data
                );

                $display("");

            end

        end

    endtask


    // =========================================================
    // TEST
    // =========================================================

    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        mem_wb_pc         = 32'b0;
        mem_wb_alu_result = 32'b0;
        mem_wb_load_data  = 32'b0;

        mem_wb_rd         = 5'b0;
        mem_wb_opcode     = 7'b0;

        mem_wb_valid      = 1'b0;

        mem_wb_reg_write  = 1'b0;
        mem_wb_wb_sel     = WB_SEL_ALU;

        #5;


        // =====================================================
        // TEST 1: RESULTADO ALU
        //
        // RegWrite = 1
        // WBSel = ALU
        //
        // x5 <- ALU result
        // =====================================================

        mem_wb_pc         = 32'h00000100;
        mem_wb_alu_result = 32'h12345678;
        mem_wb_load_data  = 32'hAAAAAAAA;

        mem_wb_rd         = 5'd5;

        // Opcode R-type solo para debug.
        mem_wb_opcode     = 7'b0110011;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = WB_SEL_ALU;

        check_wb(
            "ALU",
            1'b1,
            5'd5,
            32'h12345678
        );


        // =====================================================
        // TEST 2: LOAD
        //
        // WBSel = MEM
        //
        // x6 <- load_data
        // =====================================================

        #4;

        mem_wb_pc         = 32'h00000104;
        mem_wb_alu_result = 32'h00000040;
        mem_wb_load_data  = 32'h00000055;

        mem_wb_rd         = 5'd6;
        mem_wb_opcode     = 7'b0000011;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = WB_SEL_MEM;

        check_wb(
            "LOAD",
            1'b1,
            5'd6,
            32'h00000055
        );


        // =====================================================
        // TEST 3: JAL/JALR
        //
        // WBSel = PC+4
        //
        // PC = 0x200
        // PC+4 = 0x204
        // =====================================================

        #4;

        mem_wb_pc         = 32'h00000200;
        mem_wb_alu_result = 32'h00000220;
        mem_wb_load_data  = 32'hBBBBBBBB;

        mem_wb_rd         = 5'd1;
        mem_wb_opcode     = 7'b1101111;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = WB_SEL_PC4;

        check_wb(
            "PC+4",
            1'b1,
            5'd1,
            32'h00000204
        );


        // =====================================================
        // TEST 4: RegWrite = 0
        //
        // Puede haber datos perfectamente válidos,
        // pero WB no debe modificar Register File.
        // =====================================================

        #4;

        mem_wb_pc         = 32'h00000300;
        mem_wb_alu_result = 32'hDEADBEEF;
        mem_wb_load_data  = 32'hCAFEBABE;

        mem_wb_rd         = 5'd10;
        mem_wb_opcode     = 7'b0100011;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b0;
        mem_wb_wb_sel     = WB_SEL_ALU;

        check_wb(
            "REGWRITE=0",
            1'b0,
            5'd10,
            32'hDEADBEEF
        );


        // =====================================================
        // TEST 5: rd = x0
        //
        // Aunque RegWrite=1, x0 nunca puede modificarse.
        // =====================================================

        #4;

        mem_wb_pc         = 32'h00000304;
        mem_wb_alu_result = 32'hFFFFFFFF;
        mem_wb_load_data  = 32'h11111111;

        mem_wb_rd         = 5'd0;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = WB_SEL_ALU;

        check_wb(
            "RD=X0",
            1'b0,
            5'd0,
            32'hFFFFFFFF
        );


        // =====================================================
        // TEST 6: valid = 0
        //
        // Una burbuja nunca puede escribir.
        // =====================================================

        #4;

        mem_wb_pc         = 32'h00000308;
        mem_wb_alu_result = 32'hAAAAAAAA;
        mem_wb_load_data  = 32'hBBBBBBBB;

        mem_wb_rd         = 5'd12;

        mem_wb_valid      = 1'b0;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = WB_SEL_MEM;

        check_wb(
            "VALID=0",
            1'b0,
            5'd12,
            32'hBBBBBBBB
        );


        // =====================================================
        // TEST 7: WBSel inválido
        //
        // 11 está reservado.
        //
        // Por seguridad:
        // - dato = 0
        // - write_enable = 0
        // =====================================================

        #4;

        mem_wb_pc         = 32'h0000030C;
        mem_wb_alu_result = 32'h11111111;
        mem_wb_load_data  = 32'h22222222;

        mem_wb_rd         = 5'd13;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = 2'b11;

        check_wb(
            "INVALID WBSEL",
            1'b0,
            5'd13,
            32'h00000000
        );


        // =====================================================
        // TEST 8: OPCODE IGNORADO
        //
        // Esta es una prueba especialmente importante para
        // comprobar la nueva arquitectura.
        //
        // Colocamos un opcode completamente inválido.
        //
        // Pero:
        // valid     = 1
        // RegWrite  = 1
        // WBSel     = ALU
        //
        // WB debe obedecer exclusivamente el control pipelineado.
        // =====================================================

        #4;

        mem_wb_pc         = 32'h00000400;
        mem_wb_alu_result = 32'hABCDEF01;
        mem_wb_load_data  = 32'h55555555;

        mem_wb_rd         = 5'd14;

        mem_wb_opcode     = 7'b1111111;

        mem_wb_valid      = 1'b1;

        mem_wb_reg_write  = 1'b1;
        mem_wb_wb_sel     = WB_SEL_ALU;

        check_wb(
            "OPCODE IGNORED",
            1'b1,
            5'd14,
            32'hABCDEF01
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("WB CONTROL TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: wb_control_pipeline");

        end
        else begin

            $fatal(
                1,
                "FAIL: wb_control_pipeline | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
