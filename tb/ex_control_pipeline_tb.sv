`timescale 1ns / 1ps

module ex_control_pipeline_tb;

    logic clk;
    logic reset;

    logic ex_enable;
    logic flush_ex_mem;

    // =========================================================
    // CONTROL EX
    // =========================================================

    logic       id_ex_alu_src_a;
    logic       id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;

    logic       id_ex_branch;
    logic [1:0] id_ex_jump_type;

    // =========================================================
    // CONTROL MEM
    // =========================================================

    logic id_ex_mem_read;
    logic id_ex_mem_write;

    // =========================================================
    // CONTROL WB
    // =========================================================

    logic       id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;

    // =========================================================
    // DATAPATH ID/EX
    // =========================================================

    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;
    logic [31:0] id_ex_immediate;

    logic [4:0] id_ex_rd;

    logic [6:0] id_ex_opcode;
    logic [2:0] id_ex_funct3;
    logic [6:0] id_ex_funct7;

    logic id_ex_valid;

    // =========================================================
    // EX/MEM OUTPUTS
    // =========================================================

    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;

    logic [4:0] ex_mem_rd;

    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;

    logic ex_mem_valid;

    logic ex_mem_mem_read;
    logic ex_mem_mem_write;

    logic       ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;


    // =========================================================
    // CONTROL BUS EX/MEM
    //
    // Solo MEM + WB continúan después de EX.
    // =========================================================

    logic [4:0] ex_mem_control_bus;

    assign ex_mem_control_bus = {
        ex_mem_mem_read,
        ex_mem_mem_write,
        ex_mem_reg_write,
        ex_mem_wb_sel
    };


    // =========================================================
    // ALU_OP
    // =========================================================

    localparam logic [2:0] ALU_OP_ADD      = 3'b000;
    localparam logic [2:0] ALU_OP_SUB      = 3'b001;
    localparam logic [2:0] ALU_OP_R_DECODE = 3'b010;
    localparam logic [2:0] ALU_OP_I_DECODE = 3'b011;
    localparam logic [2:0] ALU_OP_PASS_B   = 3'b100;


    // =========================================================
    // WB SELECT
    // =========================================================

    localparam logic [1:0] WB_SEL_ALU = 2'b00;
    localparam logic [1:0] WB_SEL_MEM = 2'b01;
    localparam logic [1:0] WB_SEL_PC4 = 2'b10;


    // =========================================================
    // JUMP
    // =========================================================

    localparam logic [1:0] JUMP_NONE = 2'b00;
    localparam logic [1:0] JUMP_JAL  = 2'b01;


    // =========================================================
    // EX/MEM CONTROL WORDS
    // =========================================================

    localparam logic [4:0] CTRL_ALU = {
        1'b0,       // mem_read
        1'b0,       // mem_write
        1'b1,       // reg_write
        2'b00       // WB ALU
    };

    localparam logic [4:0] CTRL_LOAD = {
        1'b1,
        1'b0,
        1'b1,
        2'b01
    };

    localparam logic [4:0] CTRL_STORE = {
        1'b0,
        1'b1,
        1'b0,
        2'b00
    };

    localparam logic [4:0] CTRL_BRANCH = {
        1'b0,
        1'b0,
        1'b0,
        2'b00
    };

    localparam logic [4:0] CTRL_JAL = {
        1'b0,
        1'b0,
        1'b1,
        2'b10
    };

    localparam logic [4:0] CTRL_NEUTRAL = 5'b00000;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    // =========================================================
    // DUT
    // =========================================================

    ex_stage dut (
        .clk               (clk),
        .reset             (reset),

        .ex_enable         (ex_enable),
        .flush_ex_mem      (flush_ex_mem),

        .id_ex_alu_src_a   (id_ex_alu_src_a),
        .id_ex_alu_src_b   (id_ex_alu_src_b),
        .id_ex_alu_op      (id_ex_alu_op),

        .id_ex_branch      (id_ex_branch),
        .id_ex_jump_type   (id_ex_jump_type),

        .id_ex_mem_read    (id_ex_mem_read),
        .id_ex_mem_write   (id_ex_mem_write),

        .id_ex_reg_write   (id_ex_reg_write),
        .id_ex_wb_sel      (id_ex_wb_sel),

        .id_ex_pc          (id_ex_pc),

        .id_ex_read_data1  (id_ex_read_data1),
        .id_ex_read_data2  (id_ex_read_data2),

        .id_ex_immediate   (id_ex_immediate),

        .id_ex_rd          (id_ex_rd),

        .id_ex_opcode      (id_ex_opcode),
        .id_ex_funct3      (id_ex_funct3),
        .id_ex_funct7      (id_ex_funct7),

        .id_ex_valid       (id_ex_valid),

        .ex_mem_pc         (ex_mem_pc),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_store_data (ex_mem_store_data),

        .ex_mem_rd         (ex_mem_rd),

        .ex_mem_opcode     (ex_mem_opcode),
        .ex_mem_funct3     (ex_mem_funct3),

        .ex_mem_valid      (ex_mem_valid),

        .ex_mem_mem_read   (ex_mem_mem_read),
        .ex_mem_mem_write  (ex_mem_mem_write),

        .ex_mem_reg_write  (ex_mem_reg_write),
        .ex_mem_wb_sel     (ex_mem_wb_sel)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // =========================================================
    // CHECK EX/MEM
    // =========================================================

    task automatic check_snapshot (
        input string       name,

        input logic [31:0] expected_pc,
        input logic [31:0] expected_result,
        input logic [31:0] expected_store_data,

        input logic [4:0]  expected_rd,

        input logic        expected_valid,
        input logic [4:0]  expected_control
    );

        begin

            tests_run = tests_run + 1;

            if (
                ex_mem_pc          === expected_pc         &&
                ex_mem_alu_result  === expected_result     &&
                ex_mem_store_data  === expected_store_data &&
                ex_mem_rd          === expected_rd         &&
                ex_mem_valid       === expected_valid      &&
                ex_mem_control_bus === expected_control
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-10s | PC=%08h RESULT=%08h STORE=%08h RD=%0d VALID=%0d CTRL=%05b",
                    name,
                    ex_mem_pc,
                    ex_mem_alu_result,
                    ex_mem_store_data,
                    ex_mem_rd,
                    ex_mem_valid,
                    ex_mem_control_bus
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", name);

                $display(
                    "  PC       received=%08h expected=%08h",
                    ex_mem_pc,
                    expected_pc
                );

                $display(
                    "  RESULT   received=%08h expected=%08h",
                    ex_mem_alu_result,
                    expected_result
                );

                $display(
                    "  STORE    received=%08h expected=%08h",
                    ex_mem_store_data,
                    expected_store_data
                );

                $display(
                    "  RD       received=%0d expected=%0d",
                    ex_mem_rd,
                    expected_rd
                );

                $display(
                    "  VALID    received=%0d expected=%0d",
                    ex_mem_valid,
                    expected_valid
                );

                $display(
                    "  CONTROL  received=%05b expected=%05b",
                    ex_mem_control_bus,
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

        reset        = 1'b1;
        ex_enable    = 1'b1;
        flush_ex_mem = 1'b0;

        id_ex_alu_src_a = 1'b0;
        id_ex_alu_src_b = 1'b0;
        id_ex_alu_op    = ALU_OP_ADD;

        id_ex_branch    = 1'b0;
        id_ex_jump_type = JUMP_NONE;

        id_ex_mem_read  = 1'b0;
        id_ex_mem_write = 1'b0;

        id_ex_reg_write = 1'b0;
        id_ex_wb_sel    = WB_SEL_ALU;

        id_ex_pc         = 32'b0;
        id_ex_read_data1 = 32'b0;
        id_ex_read_data2 = 32'b0;
        id_ex_immediate  = 32'b0;

        id_ex_rd         = 5'b0;

        id_ex_opcode     = 7'b0;
        id_ex_funct3     = 3'b0;
        id_ex_funct7     = 7'b0;

        id_ex_valid      = 1'b0;


        // =====================================================
        // RESET
        // =====================================================

        repeat (2) @(posedge clk);
        #1;

        if (
            ex_mem_valid !== 1'b0 ||
            ex_mem_control_bus !== CTRL_NEUTRAL
        ) begin
            $fatal(1, "FAIL: reset did not clear EX/MEM");
        end

        @(negedge clk);
        reset = 1'b0;


        // =====================================================
        // TEST 1: XOR
        //
        // 0x55 XOR 0x0F = 0x5A
        //
        // Prueba:
        // - alu_op R-DECODE
        // - funct3/funct7
        // - selección rs1/rs2
        // =====================================================

        id_ex_pc         = 32'h00000100;

        id_ex_read_data1 = 32'h00000055;
        id_ex_read_data2 = 32'h0000000F;
        id_ex_immediate  = 32'b0;

        id_ex_rd         = 5'd7;

        id_ex_opcode     = 7'b0110011;
        id_ex_funct3     = 3'b100;
        id_ex_funct7     = 7'b0000000;

        id_ex_alu_src_a  = 1'b0;
        id_ex_alu_src_b  = 1'b0;
        id_ex_alu_op     = ALU_OP_R_DECODE;

        id_ex_branch     = 1'b0;
        id_ex_jump_type  = JUMP_NONE;

        id_ex_mem_read   = 1'b0;
        id_ex_mem_write  = 1'b0;

        id_ex_reg_write  = 1'b1;
        id_ex_wb_sel     = WB_SEL_ALU;

        id_ex_valid      = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "XOR",
            32'h00000100,
            32'h0000005A,
            32'h0000000F,
            5'd7,
            1'b1,
            CTRL_ALU
        );


        // =====================================================
        // TEST 2: ADDI
        //
        // 10 + 7 = 17
        //
        // Prueba I-DECODE.
        // =====================================================

        @(negedge clk);

        id_ex_pc         = 32'h00000104;

        id_ex_read_data1 = 32'd10;
        id_ex_read_data2 = 32'hAAAAAAAA;
        id_ex_immediate  = 32'd7;

        id_ex_rd         = 5'd8;

        id_ex_opcode     = 7'b0010011;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b1111111;

        id_ex_alu_src_a  = 1'b0;
        id_ex_alu_src_b  = 1'b1;
        id_ex_alu_op     = ALU_OP_I_DECODE;

        id_ex_mem_read   = 1'b0;
        id_ex_mem_write  = 1'b0;

        id_ex_reg_write  = 1'b1;
        id_ex_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "ADDI",
            32'h00000104,
            32'd17,
            32'hAAAAAAAA,
            5'd8,
            1'b1,
            CTRL_ALU
        );


        // =====================================================
        // TEST 3: LW
        //
        // Dirección = 0x40 + 12 = 0x4C
        //
        // EX consume ADD.
        // MEM + WB deben continuar.
        // =====================================================

        @(negedge clk);

        id_ex_pc         = 32'h00000108;

        id_ex_read_data1 = 32'h00000040;
        id_ex_read_data2 = 32'h12345678;
        id_ex_immediate  = 32'h0000000C;

        id_ex_rd         = 5'd5;

        id_ex_opcode     = 7'b0000011;
        id_ex_funct3     = 3'b010;
        id_ex_funct7     = 7'b0000000;

        id_ex_alu_src_a  = 1'b0;
        id_ex_alu_src_b  = 1'b1;
        id_ex_alu_op     = ALU_OP_ADD;

        id_ex_mem_read   = 1'b1;
        id_ex_mem_write  = 1'b0;

        id_ex_reg_write  = 1'b1;
        id_ex_wb_sel     = WB_SEL_MEM;

        @(posedge clk);
        #1;

        check_snapshot(
            "LW",
            32'h00000108,
            32'h0000004C,
            32'h12345678,
            5'd5,
            1'b1,
            CTRL_LOAD
        );


        // =====================================================
        // TEST 4: SW
        //
        // sw x5,8(x6)
        //
        // Dirección = 0x40 + 8 = 0x48
        // Dato store = 0x55
        //
        // IMPORTANTE:
        // store_data debe ser read_data2, NO immediate.
        // =====================================================

        @(negedge clk);

        id_ex_pc         = 32'h0000010C;

        id_ex_read_data1 = 32'h00000040;
        id_ex_read_data2 = 32'h00000055;
        id_ex_immediate  = 32'h00000008;

        id_ex_rd         = 5'd0;

        id_ex_opcode     = 7'b0100011;
        id_ex_funct3     = 3'b010;
        id_ex_funct7     = 7'b0000000;

        id_ex_alu_src_a  = 1'b0;
        id_ex_alu_src_b  = 1'b1;
        id_ex_alu_op     = ALU_OP_ADD;

        id_ex_mem_read   = 1'b0;
        id_ex_mem_write  = 1'b1;

        id_ex_reg_write  = 1'b0;
        id_ex_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "SW",
            32'h0000010C,
            32'h00000048,
            32'h00000055,
            5'd0,
            1'b1,
            CTRL_STORE
        );


        // =====================================================
        // TEST 5: BEQ
        //
        // rs1 == rs2
        //
        // SUB → resultado 0.
        //
        // Branch se consume en EX y NO continúa a EX/MEM.
        // =====================================================

        @(negedge clk);

        id_ex_pc         = 32'h00000110;

        id_ex_read_data1 = 32'h00000055;
        id_ex_read_data2 = 32'h00000055;
        id_ex_immediate  = 32'h00000008;

        id_ex_rd         = 5'd0;

        id_ex_opcode     = 7'b1100011;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;

        id_ex_alu_src_a  = 1'b0;
        id_ex_alu_src_b  = 1'b0;
        id_ex_alu_op     = ALU_OP_SUB;

        id_ex_branch     = 1'b1;
        id_ex_jump_type  = JUMP_NONE;

        id_ex_mem_read   = 1'b0;
        id_ex_mem_write  = 1'b0;

        id_ex_reg_write  = 1'b0;
        id_ex_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "BEQ",
            32'h00000110,
            32'h00000000,
            32'h00000055,
            5'd0,
            1'b1,
            CTRL_BRANCH
        );


        // =====================================================
        // TEST 6: LUI
        //
        // PASS_B debe entregar el inmediato directamente.
        // =====================================================

        @(negedge clk);

        id_ex_pc         = 32'h00000114;

        id_ex_read_data1 = 32'hDEADBEEF;
        id_ex_read_data2 = 32'h00000000;
        id_ex_immediate  = 32'h12345000;

        id_ex_rd         = 5'd9;

        id_ex_opcode     = 7'b0110111;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;

        id_ex_alu_src_a  = 1'b0;
        id_ex_alu_src_b  = 1'b1;
        id_ex_alu_op     = ALU_OP_PASS_B;

        id_ex_branch     = 1'b0;
        id_ex_jump_type  = JUMP_NONE;

        id_ex_mem_read   = 1'b0;
        id_ex_mem_write  = 1'b0;

        id_ex_reg_write  = 1'b1;
        id_ex_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "LUI",
            32'h00000114,
            32'h12345000,
            32'h00000000,
            5'd9,
            1'b1,
            CTRL_ALU
        );


        // =====================================================
        // TEST 7: JAL
        //
        // operand A = PC
        // operand B = immediate
        //
        // 0x200 + 0x20 = 0x220
        //
        // WB debe continuar como PC+4.
        // =====================================================

        @(negedge clk);

        id_ex_pc         = 32'h00000200;

        id_ex_read_data1 = 32'hAAAAAAAA;
        id_ex_read_data2 = 32'h00000000;
        id_ex_immediate  = 32'h00000020;

        id_ex_rd         = 5'd1;

        id_ex_opcode     = 7'b1101111;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;

        id_ex_alu_src_a  = 1'b1;
        id_ex_alu_src_b  = 1'b1;
        id_ex_alu_op     = ALU_OP_ADD;

        id_ex_branch     = 1'b0;
        id_ex_jump_type  = JUMP_JAL;

        id_ex_mem_read   = 1'b0;
        id_ex_mem_write  = 1'b0;

        id_ex_reg_write  = 1'b1;
        id_ex_wb_sel     = WB_SEL_PC4;

        @(posedge clk);
        #1;

        check_snapshot(
            "JAL",
            32'h00000200,
            32'h00000220,
            32'h00000000,
            5'd1,
            1'b1,
            CTRL_JAL
        );


        // =====================================================
        // TEST 8: HOLD
        //
        // Cambiamos las entradas pero EX/MEM debe conservar JAL.
        // =====================================================

        @(negedge clk);

        ex_enable = 1'b0;

        id_ex_pc         = 32'hFFFFFFFF;
        id_ex_read_data1 = 32'h11111111;
        id_ex_read_data2 = 32'h22222222;
        id_ex_immediate  = 32'h33333333;

        id_ex_mem_read   = 1'b1;
        id_ex_mem_write  = 1'b1;

        id_ex_reg_write  = 1'b0;
        id_ex_wb_sel     = WB_SEL_MEM;

        @(posedge clk);
        #1;

        check_snapshot(
            "HOLD",
            32'h00000200,
            32'h00000220,
            32'h00000000,
            5'd1,
            1'b1,
            CTRL_JAL
        );


        // =====================================================
        // TEST 9: FLUSH
        // =====================================================

        @(negedge clk);

        ex_enable    = 1'b1;
        flush_ex_mem = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "FLUSH",
            32'h00000000,
            32'h00000000,
            32'h00000000,
            5'd0,
            1'b0,
            CTRL_NEUTRAL
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("EX + CONTROL + EX/MEM TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin
            $display("PASS: ex_control_pipeline");
        end
        else begin
            $fatal(
                1,
                "FAIL: ex_control_pipeline | %0d test(s) failed",
                tests_failed
            );
        end

        #5;
        $finish;

    end

endmodule
