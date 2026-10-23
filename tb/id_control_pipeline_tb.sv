`timescale 1ns/1ps

module id_control_pipeline_tb;

    logic clk;
    logic reset;

    logic id_enable;
    logic flush_id_ex;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;

    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;
    logic [31:0] id_ex_immediate;

    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;
    logic [4:0] id_ex_rd;

    logic [6:0] id_ex_opcode;
    logic [2:0] id_ex_funct3;
    logic [6:0] id_ex_funct7;

    logic id_ex_valid;

    logic       id_ex_alu_src_a;
    logic       id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;

    logic       id_ex_branch;
    logic [1:0] id_ex_jump_type;

    logic id_ex_mem_read;
    logic id_ex_mem_write;

    logic       id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;


    // =========================================================
    // CONTROL BUS PARA FACILITAR LAS COMPROBACIONES
    // =========================================================

    logic [12:0] id_ex_control_bus;

    assign id_ex_control_bus = {
        id_ex_alu_src_a,
        id_ex_alu_src_b,
        id_ex_alu_op,
        id_ex_branch,
        id_ex_jump_type,
        id_ex_mem_read,
        id_ex_mem_write,
        id_ex_reg_write,
        id_ex_wb_sel
    };


    // =========================================================
    // CONTROL WORDS ESPERADAS
    // =========================================================

    localparam logic [12:0] CTRL_R = {
        1'b0,       // A = rs1
        1'b0,       // B = rs2
        3'b010,     // R-DECODE
        1'b0,       // branch
        2'b00,      // no jump
        1'b0,       // mem read
        1'b0,       // mem write
        1'b1,       // reg write
        2'b00       // WB ALU
    };

    localparam logic [12:0] CTRL_LOAD = {
        1'b0,
        1'b1,
        3'b000,
        1'b0,
        2'b00,
        1'b1,
        1'b0,
        1'b1,
        2'b01
    };

    localparam logic [12:0] CTRL_STORE = {
        1'b0,
        1'b1,
        3'b000,
        1'b0,
        2'b00,
        1'b0,
        1'b1,
        1'b0,
        2'b00
    };

    localparam logic [12:0] CTRL_BRANCH = {
        1'b0,
        1'b0,
        3'b001,
        1'b1,
        2'b00,
        1'b0,
        1'b0,
        1'b0,
        2'b00
    };

    localparam logic [12:0] CTRL_JAL = {
        1'b1,
        1'b1,
        3'b000,
        1'b0,
        2'b01,
        1'b0,
        1'b0,
        1'b1,
        2'b10
    };

    localparam logic [12:0] CTRL_JALR = {
        1'b0,
        1'b1,
        3'b000,
        1'b0,
        2'b10,
        1'b0,
        1'b0,
        1'b1,
        2'b10
    };

    localparam logic [12:0] CTRL_NEUTRAL = 13'b0;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    // =========================================================
    // DUT
    // =========================================================

    id_stage dut (
        .clk               (clk),
        .reset             (reset),

        .id_enable         (id_enable),
        .flush_id_ex       (flush_id_ex),

        .if_id_pc          (if_id_pc),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),

        .wb_write_enable   (wb_write_enable),
        .wb_write_register (wb_write_register),
        .wb_write_data     (wb_write_data),

        .id_ex_pc          (id_ex_pc),
        .id_ex_read_data1  (id_ex_read_data1),
        .id_ex_read_data2  (id_ex_read_data2),
        .id_ex_immediate   (id_ex_immediate),

        .id_ex_rs1         (id_ex_rs1),
        .id_ex_rs2         (id_ex_rs2),
        .id_ex_rd          (id_ex_rd),

        .id_ex_opcode      (id_ex_opcode),
        .id_ex_funct3      (id_ex_funct3),
        .id_ex_funct7      (id_ex_funct7),

        .id_ex_valid       (id_ex_valid),

        .id_ex_alu_src_a   (id_ex_alu_src_a),
        .id_ex_alu_src_b   (id_ex_alu_src_b),
        .id_ex_alu_op      (id_ex_alu_op),

        .id_ex_branch      (id_ex_branch),
        .id_ex_jump_type   (id_ex_jump_type),

        .id_ex_mem_read    (id_ex_mem_read),
        .id_ex_mem_write   (id_ex_mem_write),

        .id_ex_reg_write   (id_ex_reg_write),
        .id_ex_wb_sel      (id_ex_wb_sel)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // =========================================================
    // CHECK GENERAL DE UNA "FOTOGRAFÍA" ID/EX
    // =========================================================

    task automatic check_snapshot (
        input string       name,
        input logic [31:0] expected_pc,
        input logic        expected_valid,
        input logic [12:0] expected_control
    );

        begin

            tests_run = tests_run + 1;

            if (
                id_ex_pc          === expected_pc      &&
                id_ex_valid       === expected_valid   &&
                id_ex_control_bus === expected_control
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-12s | PC=%08h VALID=%0d CTRL=%013b",
                    name,
                    id_ex_pc,
                    id_ex_valid,
                    id_ex_control_bus
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", name);

                $display(
                    "  PC       received=%08h expected=%08h",
                    id_ex_pc,
                    expected_pc
                );

                $display(
                    "  VALID    received=%0d expected=%0d",
                    id_ex_valid,
                    expected_valid
                );

                $display(
                    "  CONTROL  received=%013b expected=%013b",
                    id_ex_control_bus,
                    expected_control
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

        reset       = 1'b1;
        id_enable   = 1'b1;
        flush_id_ex = 1'b0;

        if_id_pc          = 32'b0;
        if_id_instruction = 32'h00000013;
        if_id_valid       = 1'b0;

        wb_write_enable   = 1'b0;
        wb_write_register = 5'b0;
        wb_write_data     = 32'b0;


        // =====================================================
        // RESET
        // =====================================================

        repeat (2) @(posedge clk);
        #1;

        if (
            id_ex_valid !== 1'b0 ||
            id_ex_control_bus !== CTRL_NEUTRAL
        ) begin
            $fatal(1, "FAIL: reset did not clear ID/EX");
        end

        @(negedge clk);
        reset = 1'b0;


        // =====================================================
        // PREPARAR REGISTER FILE
        //
        // x5 = 0x55
        // x6 = 0x40
        // =====================================================

        wb_write_enable   = 1'b1;
        wb_write_register = 5'd5;
        wb_write_data     = 32'h00000055;

        @(posedge clk);
        #1;

        @(negedge clk);

        wb_write_register = 5'd6;
        wb_write_data     = 32'h00000040;

        @(posedge clk);
        #1;

        @(negedge clk);

        wb_write_enable = 1'b0;


        // =====================================================
        // TEST 1: XOR
        //
        // xor x7,x5,x6
        //
        // x5 = 0x55
        // x6 = 0x40
        // =====================================================

        if_id_pc          = 32'h00000100;
        if_id_instruction = 32'h0062C3B3;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "XOR",
            32'h00000100,
            1'b1,
            CTRL_R
        );

        if (
            id_ex_read_data1 !== 32'h00000055 ||
            id_ex_read_data2 !== 32'h00000040 ||
            id_ex_rd         !== 5'd7             ||
            id_ex_opcode     !== 7'b0110011       ||
            id_ex_funct3     !== 3'b100
        ) begin
            $fatal(1, "FAIL: XOR datapath fields");
        end


        // =====================================================
        // TEST 2: LW
        //
        // lw x5,12(x6)
        // =====================================================

        @(negedge clk);

        if_id_pc          = 32'h00000104;
        if_id_instruction = 32'h00C32283;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "LW",
            32'h00000104,
            1'b1,
            CTRL_LOAD
        );

        if (
            id_ex_read_data1 !== 32'h00000040 ||
            id_ex_immediate  !== 32'h0000000C ||
            id_ex_rd         !== 5'd5          ||
            id_ex_opcode     !== 7'b0000011    ||
            id_ex_funct3     !== 3'b010
        ) begin
            $fatal(1, "FAIL: LW datapath fields");
        end


        // =====================================================
        // TEST 3: SW
        //
        // sw x5,12(x6)
        // =====================================================

        @(negedge clk);

        if_id_pc          = 32'h00000108;
        if_id_instruction = 32'h00532623;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "SW",
            32'h00000108,
            1'b1,
            CTRL_STORE
        );

        if (
            id_ex_read_data1 !== 32'h00000040 ||
            id_ex_read_data2 !== 32'h00000055 ||
            id_ex_immediate  !== 32'h0000000C ||
            id_ex_opcode     !== 7'b0100011    ||
            id_ex_funct3     !== 3'b010
        ) begin
            $fatal(1, "FAIL: SW datapath fields");
        end


        // =====================================================
        // TEST 4: BEQ
        //
        // beq x5,x6,+8
        // =====================================================

        @(negedge clk);

        if_id_pc          = 32'h0000010C;
        if_id_instruction = 32'h00628463;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "BEQ",
            32'h0000010C,
            1'b1,
            CTRL_BRANCH
        );

        if (
            id_ex_read_data1 !== 32'h00000055 ||
            id_ex_read_data2 !== 32'h00000040 ||
            id_ex_immediate  !== 32'h00000008 ||
            id_ex_opcode     !== 7'b1100011    ||
            id_ex_funct3     !== 3'b000
        ) begin
            $fatal(1, "FAIL: BEQ datapath fields");
        end


        // =====================================================
        // TEST 5: JAL
        //
        // jal x1,+16
        // =====================================================

        @(negedge clk);

        if_id_pc          = 32'h00000110;
        if_id_instruction = 32'h010000EF;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "JAL",
            32'h00000110,
            1'b1,
            CTRL_JAL
        );

        if (
            id_ex_immediate !== 32'h00000010 ||
            id_ex_rd        !== 5'd1          ||
            id_ex_opcode    !== 7'b1101111
        ) begin
            $fatal(1, "FAIL: JAL datapath fields");
        end


        // =====================================================
        // TEST 6: JALR
        //
        // jalr x1,4(x6)
        // =====================================================

        @(negedge clk);

        if_id_pc          = 32'h00000114;
        if_id_instruction = 32'h004300E7;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "JALR",
            32'h00000114,
            1'b1,
            CTRL_JALR
        );

        if (
            id_ex_read_data1 !== 32'h00000040 ||
            id_ex_immediate  !== 32'h00000004 ||
            id_ex_rd         !== 5'd1          ||
            id_ex_opcode     !== 7'b1100111    ||
            id_ex_funct3     !== 3'b000
        ) begin
            $fatal(1, "FAIL: JALR datapath fields");
        end


        // =====================================================
        // TEST 7: HOLD
        //
        // id_enable = 0.
        //
        // Aunque cambiemos la instrucción de entrada,
        // ID/EX debe conservar la fotografía de JALR.
        // =====================================================

        @(negedge clk);

        id_enable = 1'b0;

        if_id_pc          = 32'h00000118;
        if_id_instruction = 32'h00C32283;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "HOLD",
            32'h00000114,
            1'b1,
            CTRL_JALR
        );


        // =====================================================
        // TEST 8: FLUSH
        //
        // flush tiene prioridad y genera burbuja.
        // =====================================================

        @(negedge clk);

        id_enable   = 1'b1;
        flush_id_ex = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "FLUSH",
            32'h00000000,
            1'b0,
            CTRL_NEUTRAL
        );

        if (
            id_ex_read_data1 !== 32'b0 ||
            id_ex_read_data2 !== 32'b0 ||
            id_ex_immediate  !== 32'b0 ||
            id_ex_rd         !== 5'b0
        ) begin
            $fatal(1, "FAIL: flush did not clear datapath");
        end


        // =====================================================
        // TEST 9: INSTRUCCIÓN INVÁLIDA
        //
        // IF/ID dice valid=1, pero Control Unit no reconoce
        // la codificación.
        //
        // Debe entrar a ID/EX con valid=0 y control neutral.
        // =====================================================

        @(negedge clk);

        flush_id_ex = 1'b0;

        if_id_pc          = 32'h0000011C;
        if_id_instruction = 32'hFFFFFFFF;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "INVALID",
            32'h0000011C,
            1'b0,
            CTRL_NEUTRAL
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("ID + CONTROL + ID/EX TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin
            $display("PASS: id_control_pipeline");
        end
        else begin
            $fatal(
                1,
                "FAIL: id_control_pipeline | %0d test(s) failed",
                tests_failed
            );
        end

        #5;
        $finish;

    end

endmodule
