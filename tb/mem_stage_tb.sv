`timescale 1ns / 1ps

module mem_stage_tb;

    logic        clk;
    logic        reset;
    logic        mem_enable;
    logic        flush_mem_wb;

    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [4:0]  ex_mem_rd;
    logic [6:0]  ex_mem_opcode;
    logic [2:0]  ex_mem_funct3;
    logic        ex_mem_valid;

    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;
    logic [4:0]  mem_wb_rd;
    logic [6:0]  mem_wb_opcode;
    logic        mem_wb_valid;


    localparam logic [6:0] OPCODE_LOAD  = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE = 7'b0100011;
    localparam logic [6:0] OPCODE_R     = 7'b0110011;


    mem_stage #(
        .DATA_MEM_DEPTH(256)
    ) dut (
        .clk               (clk),
        .reset             (reset),
        .mem_enable        (mem_enable),
        .flush_mem_wb      (flush_mem_wb),

        .ex_mem_pc         (ex_mem_pc),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_store_data (ex_mem_store_data),
        .ex_mem_rd         (ex_mem_rd),
        .ex_mem_opcode     (ex_mem_opcode),
        .ex_mem_funct3     (ex_mem_funct3),
        .ex_mem_valid      (ex_mem_valid),

        .mem_wb_pc         (mem_wb_pc),
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_load_data  (mem_wb_load_data),
        .mem_wb_rd         (mem_wb_rd),
        .mem_wb_opcode     (mem_wb_opcode),
        .mem_wb_valid      (mem_wb_valid)
    );


    always #5 clk = ~clk;


    // =============================================================
    // CHECK COMPLETO DE MEM/WB
    // =============================================================

    task automatic check_mem_wb (
        input logic [31:0] expected_pc,
        input logic [31:0] expected_alu_result,
        input logic [31:0] expected_load_data,
        input logic [4:0]  expected_rd,
        input logic [6:0]  expected_opcode,
        input logic        expected_valid,
        input string       test_name
    );
        begin

            #1;

            if (
                mem_wb_pc         !== expected_pc         ||
                mem_wb_alu_result !== expected_alu_result ||
                mem_wb_load_data  !== expected_load_data  ||
                mem_wb_rd         !== expected_rd         ||
                mem_wb_opcode     !== expected_opcode     ||
                mem_wb_valid      !== expected_valid
            ) begin

                $display("FAIL: %s", test_name);

                $display(
                    "  pc=%h expected=%h",
                    mem_wb_pc,
                    expected_pc
                );

                $display(
                    "  alu_result=%h expected=%h",
                    mem_wb_alu_result,
                    expected_alu_result
                );

                $display(
                    "  load_data=%h expected=%h",
                    mem_wb_load_data,
                    expected_load_data
                );

                $display(
                    "  rd=%0d expected=%0d",
                    mem_wb_rd,
                    expected_rd
                );

                $display(
                    "  opcode=%b expected=%b",
                    mem_wb_opcode,
                    expected_opcode
                );

                $display(
                    "  valid=%b expected=%b",
                    mem_wb_valid,
                    expected_valid
                );

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | pc=%h | alu=%h | load=%h | rd=%0d | valid=%b",
                    test_name,
                    mem_wb_pc,
                    mem_wb_alu_result,
                    mem_wb_load_data,
                    mem_wb_rd,
                    mem_wb_valid
                );

            end

        end
    endtask


    // =============================================================
    // STORE ALINEADO
    // =============================================================

    task automatic issue_store (
        input logic [31:0] test_pc,
        input logic [31:0] test_address,
        input logic [2:0]  test_funct3,
        input logic [31:0] test_store_data,
        input string       test_name
    );
        begin

            @(negedge clk);

            reset             = 1'b0;
            mem_enable        = 1'b1;
            flush_mem_wb      = 1'b0;

            ex_mem_pc         = test_pc;
            ex_mem_alu_result = test_address;
            ex_mem_store_data = test_store_data;
            ex_mem_rd         = 5'd0;
            ex_mem_opcode     = OPCODE_STORE;
            ex_mem_funct3     = test_funct3;
            ex_mem_valid      = 1'b1;

            @(posedge clk);

            check_mem_wb(
                test_pc,
                test_address,
                32'd0,
                5'd0,
                OPCODE_STORE,
                1'b1,
                test_name
            );

        end
    endtask


    // =============================================================
    // LOAD ALINEADO
    // =============================================================

    task automatic issue_load (
        input logic [31:0] test_pc,
        input logic [31:0] test_address,
        input logic [2:0]  test_funct3,
        input logic [4:0]  test_rd,
        input logic [31:0] expected_load_data,
        input string       test_name
    );
        begin

            @(negedge clk);

            reset             = 1'b0;
            mem_enable        = 1'b1;
            flush_mem_wb      = 1'b0;

            ex_mem_pc         = test_pc;
            ex_mem_alu_result = test_address;
            ex_mem_store_data = 32'd0;
            ex_mem_rd         = test_rd;
            ex_mem_opcode     = OPCODE_LOAD;
            ex_mem_funct3     = test_funct3;
            ex_mem_valid      = 1'b1;

            @(posedge clk);

            check_mem_wb(
                test_pc,
                test_address,
                expected_load_data,
                test_rd,
                OPCODE_LOAD,
                1'b1,
                test_name
            );

        end
    endtask


    initial begin

        clk               = 1'b0;
        reset             = 1'b1;
        mem_enable        = 1'b1;
        flush_mem_wb      = 1'b0;

        ex_mem_pc         = 32'd0;
        ex_mem_alu_result = 32'd0;
        ex_mem_store_data = 32'd0;
        ex_mem_rd         = 5'd0;
        ex_mem_opcode     = 7'd0;
        ex_mem_funct3     = 3'd0;
        ex_mem_valid      = 1'b0;


        // =========================================================
        // 1. RESET
        // =========================================================

        @(posedge clk);

        check_mem_wb(
            32'd0,
            32'd0,
            32'd0,
            5'd0,
            7'd0,
            1'b0,
            "RESET"
        );

        reset = 1'b0;


        // =========================================================
        // 2. SW INICIAL
        //
        // DMEM[0x20] = 0x80A53344
        // =========================================================

        issue_store(
            32'd100,
            32'h00000020,
            3'b010,
            32'h80A53344,
            "SW INITIAL WORD"
        );


        // =========================================================
        // 3. LW
        // =========================================================

        issue_load(
            32'd104,
            32'h00000020,
            3'b010,
            5'd5,
            32'h80A53344,
            "LW COMPLETE WORD"
        );


        // =========================================================
        // 4. LB byte 2
        //
        // A5 signed -> FFFFFFA5
        // =========================================================

        issue_load(
            32'd108,
            32'h00000022,
            3'b000,
            5'd6,
            32'hFFFFFFA5,
            "LB BYTE 2 SIGNED"
        );


        // =========================================================
        // 5. LBU byte 2
        // =========================================================

        issue_load(
            32'd112,
            32'h00000022,
            3'b100,
            5'd7,
            32'h000000A5,
            "LBU BYTE 2"
        );


        // =========================================================
        // 6. LH upper
        //
        // 80A5 signed -> FFFF80A5
        // =========================================================

        issue_load(
            32'd116,
            32'h00000022,
            3'b001,
            5'd8,
            32'hFFFF80A5,
            "LH UPPER SIGNED"
        );


        // =========================================================
        // 7. LHU upper
        // =========================================================

        issue_load(
            32'd120,
            32'h00000022,
            3'b101,
            5'd9,
            32'h000080A5,
            "LHU UPPER"
        );


        // =========================================================
        // 8. SB BYTE 1
        //
        // 80A53344 -> 80A5EE44
        // =========================================================

        issue_store(
            32'd124,
            32'h00000021,
            3'b000,
            32'h123456EE,
            "SB BYTE 1"
        );


        // Verificamos con LW.

        issue_load(
            32'd128,
            32'h00000020,
            3'b010,
            5'd10,
            32'h80A5EE44,
            "LW AFTER SB"
        );


        // =========================================================
        // 9. SH UPPER
        //
        // 80A5EE44 -> ABCDEE44
        // =========================================================

        issue_store(
            32'd132,
            32'h00000022,
            3'b001,
            32'h1234ABCD,
            "SH UPPER"
        );


        issue_load(
            32'd136,
            32'h00000020,
            3'b010,
            5'd11,
            32'hABCDEE44,
            "LW AFTER SH"
        );


        // =========================================================
        // 10. INSTRUCCIÓN ALU PASSTHROUGH
        //
        // ADD con resultado 42.
        //
        // No debe acceder a memoria.
        // load_data no tiene significado y se fuerza a 0.
        // =========================================================

        @(negedge clk);

        ex_mem_pc         = 32'd140;
        ex_mem_alu_result = 32'd42;
        ex_mem_store_data = 32'hFFFFFFFF;
        ex_mem_rd         = 5'd7;
        ex_mem_opcode     = OPCODE_R;
        ex_mem_funct3     = 3'b000;
        ex_mem_valid      = 1'b1;

        mem_enable        = 1'b1;
        flush_mem_wb      = 1'b0;

        @(posedge clk);

        check_mem_wb(
            32'd140,
            32'd42,
            32'd0,
            5'd7,
            OPCODE_R,
            1'b1,
            "ALU PASSTHROUGH"
        );


        // =========================================================
        // 11. HOLD
        //
        // Intentamos hacer SW mientras mem_enable=0.
        //
        // - MEM/WB debe conservar ADD anterior.
        // - DMEM NO debe modificarse.
        // =========================================================

        @(negedge clk);

        mem_enable        = 1'b0;

        ex_mem_pc         = 32'd144;
        ex_mem_alu_result = 32'h00000020;
        ex_mem_store_data = 32'h11111111;
        ex_mem_rd         = 5'd0;
        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b010;
        ex_mem_valid      = 1'b1;

        @(posedge clk);

        check_mem_wb(
            32'd140,
            32'd42,
            32'd0,
            5'd7,
            OPCODE_R,
            1'b1,
            "HOLD BLOCKS STORE"
        );


        // Verificamos que la memoria siga ABCDEE44.

        issue_load(
            32'd148,
            32'h00000020,
            3'b010,
            5'd12,
            32'hABCDEE44,
            "MEMORY PRESERVED AFTER HOLD"
        );


        // =========================================================
        // 12. FLUSH BLOQUEANDO STORE
        //
        // Intentamos SW durante flush.
        //
        // No debe modificar DMEM.
        // MEM/WB pasa a valid=0.
        // =========================================================

        @(negedge clk);

        mem_enable        = 1'b1;
        flush_mem_wb      = 1'b1;

        ex_mem_pc         = 32'd152;
        ex_mem_alu_result = 32'h00000020;
        ex_mem_store_data = 32'h22222222;
        ex_mem_rd         = 5'd0;
        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b010;
        ex_mem_valid      = 1'b1;

        @(posedge clk);

        check_mem_wb(
            32'd148,
            32'h00000020,
            32'hABCDEE44,
            5'd12,
            OPCODE_LOAD,
            1'b0,
            "FLUSH BLOCKS STORE"
        );


        // Verificamos nuevamente memoria.

        issue_load(
            32'd156,
            32'h00000020,
            3'b010,
            5'd13,
            32'hABCDEE44,
            "MEMORY PRESERVED AFTER FLUSH"
        );


        // =========================================================
        // 13. STORE DESALINEADO
        //
        // sh en dirección 0x21.
        //
        // Debe:
        // - no escribir memoria;
        // - entrar a MEM/WB como burbuja.
        // =========================================================

        @(negedge clk);

        mem_enable        = 1'b1;
        flush_mem_wb      = 1'b0;

        ex_mem_pc         = 32'd160;
        ex_mem_alu_result = 32'h00000021;
        ex_mem_store_data = 32'h00001234;
        ex_mem_rd         = 5'd0;
        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b001;
        ex_mem_valid      = 1'b1;

        @(posedge clk);

        check_mem_wb(
            32'd160,
            32'h00000021,
            32'd0,
            5'd0,
            OPCODE_STORE,
            1'b0,
            "MISALIGNED SH"
        );


        issue_load(
            32'd164,
            32'h00000020,
            3'b010,
            5'd14,
            32'hABCDEE44,
            "MEMORY PRESERVED AFTER MISALIGNED SH"
        );


        // =========================================================
        // 14. LOAD DESALINEADO
        //
        // lw desde 0x21.
        //
        // No lo soportamos:
        // valid debe ser 0.
        // =========================================================

        @(negedge clk);

        ex_mem_pc         = 32'd168;
        ex_mem_alu_result = 32'h00000021;
        ex_mem_store_data = 32'd0;
        ex_mem_rd         = 5'd15;
        ex_mem_opcode     = OPCODE_LOAD;
        ex_mem_funct3     = 3'b010;
        ex_mem_valid      = 1'b1;

        mem_enable        = 1'b1;
        flush_mem_wb      = 1'b0;

        @(posedge clk);

        check_mem_wb(
            32'd168,
            32'h00000021,
            32'd0,
            5'd15,
            OPCODE_LOAD,
            1'b0,
            "MISALIGNED LW"
        );


        // =========================================================
        // 15. STORE CON FUNCT3 INVÁLIDO
        //
        // No debe escribir.
        // =========================================================

        @(negedge clk);

        ex_mem_pc         = 32'd172;
        ex_mem_alu_result = 32'h00000020;
        ex_mem_store_data = 32'hFFFFFFFF;
        ex_mem_rd         = 5'd0;
        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b111;
        ex_mem_valid      = 1'b1;

        @(posedge clk);

        check_mem_wb(
            32'd172,
            32'h00000020,
            32'd0,
            5'd0,
            OPCODE_STORE,
            1'b0,
            "INVALID STORE FUNCT3"
        );


        issue_load(
            32'd176,
            32'h00000020,
            3'b010,
            5'd16,
            32'hABCDEE44,
            "MEMORY PRESERVED AFTER INVALID STORE"
        );


        // =========================================================
        // 16. RESET BLOQUEANDO STORE
        //
        // DMEM NO se borra con reset.
        //
        // Además, aunque las entradas representen un SW,
        // reset debe impedir la escritura.
        // =========================================================

        @(negedge clk);

        reset             = 1'b1;
        mem_enable        = 1'b1;
        flush_mem_wb      = 1'b0;

        ex_mem_pc         = 32'd180;
        ex_mem_alu_result = 32'h00000020;
        ex_mem_store_data = 32'hFFFFFFFF;
        ex_mem_rd         = 5'd0;
        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b010;
        ex_mem_valid      = 1'b1;

        @(posedge clk);

        check_mem_wb(
            32'd0,
            32'd0,
            32'd0,
            5'd0,
            7'd0,
            1'b0,
            "RESET BLOCKS STORE"
        );

        reset = 1'b0;


        // DMEM debe conservar ABCDEE44.

        issue_load(
            32'd184,
            32'h00000020,
            3'b010,
            5'd17,
            32'hABCDEE44,
            "DMEM PRESERVED ACROSS RESET"
        );


        $display("PASS: mem_stage");
        $finish;

    end

endmodule
