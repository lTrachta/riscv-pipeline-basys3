`timescale 1ns / 1ps

module ex_forwarding_pipeline_tb;

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
    // ID/EX DATAPATH
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
    // FORWARDING
    // =========================================================

    logic [1:0] forward_a;
    logic [1:0] forward_b;

    logic [31:0] ex_mem_forward_value;
    logic [31:0] mem_wb_forward_value;


    // =========================================================
    // EX/MEM OUTPUT
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
    // CONSTANTES
    // =========================================================

    localparam logic [1:0] FORWARD_ID_EX  = 2'b00;
    localparam logic [1:0] FORWARD_MEM_WB = 2'b01;
    localparam logic [1:0] FORWARD_EX_MEM = 2'b10;

    localparam logic [2:0] ALU_OP_ADD      = 3'b000;
    localparam logic [2:0] ALU_OP_SUB      = 3'b001;
    localparam logic [2:0] ALU_OP_R_DECODE = 3'b010;
    localparam logic [2:0] ALU_OP_I_DECODE = 3'b011;

    localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU  = 7'b0010011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    // =========================================================
    // CLOCK
    // =========================================================

    initial clk = 1'b0;

    always #5 clk = ~clk;


    // =========================================================
    // DUT
    // =========================================================

    ex_stage dut (
        .clk                  (clk),
        .reset                (reset),

        .ex_enable            (ex_enable),
        .flush_ex_mem         (flush_ex_mem),

        .id_ex_alu_src_a      (id_ex_alu_src_a),
        .id_ex_alu_src_b      (id_ex_alu_src_b),
        .id_ex_alu_op         (id_ex_alu_op),

        .id_ex_branch         (id_ex_branch),
        .id_ex_jump_type      (id_ex_jump_type),

        .id_ex_mem_read       (id_ex_mem_read),
        .id_ex_mem_write      (id_ex_mem_write),

        .id_ex_reg_write      (id_ex_reg_write),
        .id_ex_wb_sel         (id_ex_wb_sel),

        .id_ex_pc             (id_ex_pc),

        .id_ex_read_data1     (id_ex_read_data1),
        .id_ex_read_data2     (id_ex_read_data2),
        .id_ex_immediate      (id_ex_immediate),

        .id_ex_rd             (id_ex_rd),

        .id_ex_opcode         (id_ex_opcode),
        .id_ex_funct3         (id_ex_funct3),
        .id_ex_funct7         (id_ex_funct7),

        .id_ex_valid          (id_ex_valid),

        .forward_a            (forward_a),
        .forward_b            (forward_b),

        .ex_mem_forward_value (ex_mem_forward_value),
        .mem_wb_forward_value (mem_wb_forward_value),

        .ex_mem_pc            (ex_mem_pc),

        .ex_mem_alu_result    (ex_mem_alu_result),
        .ex_mem_store_data    (ex_mem_store_data),

        .ex_mem_rd            (ex_mem_rd),

        .ex_mem_opcode        (ex_mem_opcode),
        .ex_mem_funct3        (ex_mem_funct3),

        .ex_mem_valid         (ex_mem_valid),

        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),

        .ex_mem_reg_write     (ex_mem_reg_write),
        .ex_mem_wb_sel        (ex_mem_wb_sel)
    );


    // =========================================================
    // DEFAULTS
    // =========================================================

    task automatic set_defaults;

        begin

            ex_enable        = 1'b1;
            flush_ex_mem     = 1'b0;

            id_ex_alu_src_a  = 1'b0;
            id_ex_alu_src_b  = 1'b0;
            id_ex_alu_op     = ALU_OP_ADD;

            id_ex_branch     = 1'b0;
            id_ex_jump_type  = 2'b00;

            id_ex_mem_read   = 1'b0;
            id_ex_mem_write  = 1'b0;

            id_ex_reg_write  = 1'b1;
            id_ex_wb_sel     = 2'b00;

            id_ex_pc         = 32'd0;

            id_ex_read_data1 = 32'd0;
            id_ex_read_data2 = 32'd0;
            id_ex_immediate  = 32'd0;

            id_ex_rd         = 5'd1;

            id_ex_opcode     = OPCODE_R;
            id_ex_funct3     = 3'b000;
            id_ex_funct7     = 7'b0000000;

            id_ex_valid      = 1'b1;

            forward_a        = FORWARD_ID_EX;
            forward_b        = FORWARD_ID_EX;

            ex_mem_forward_value = 32'd0;
            mem_wb_forward_value = 32'd0;

        end

    endtask


    // =========================================================
    // CHECK
    // =========================================================

    task automatic check_result (
        input string       name,
        input logic [31:0] expected_result,
        input logic [31:0] expected_store
    );

        begin

            tests_run = tests_run + 1;

            @(posedge clk);
            #1;

            if (
                ex_mem_alu_result === expected_result &&
                ex_mem_store_data === expected_store &&
                ex_mem_valid      === 1'b1
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-18s | RESULT=%08h STORE=%08h",
                    name,
                    ex_mem_alu_result,
                    ex_mem_store_data
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", name);

                $display(
                    "  RESULT received=%08h expected=%08h",
                    ex_mem_alu_result,
                    expected_result
                );

                $display(
                    "  STORE  received=%08h expected=%08h",
                    ex_mem_store_data,
                    expected_store
                );

                $display(
                    "  VALID  received=%0d expected=1",
                    ex_mem_valid
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

        set_defaults();

        reset = 1'b1;

        repeat (2) @(posedge clk);

        reset = 1'b0;


        // =====================================================
        // TEST 1
        // Sin forwarding:
        //
        // 10 + 20 = 30
        // =====================================================

        set_defaults();

        id_ex_alu_op     = ALU_OP_R_DECODE;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;

        id_ex_read_data1 = 32'd10;
        id_ex_read_data2 = 32'd20;

        check_result(
            "NO FORWARD",
            32'd30,
            32'd20
        );


        // =====================================================
        // TEST 2
        // EX/MEM -> A
        //
        // valor viejo rs1 = 100
        // forwarded A = 30
        // rs2 = 4
        //
        // 30 - 4 = 26
        // =====================================================

        set_defaults();

        id_ex_alu_op     = ALU_OP_R_DECODE;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0100000;

        id_ex_read_data1 = 32'd100;
        id_ex_read_data2 = 32'd4;

        forward_a            = FORWARD_EX_MEM;
        ex_mem_forward_value = 32'd30;

        check_result(
            "EX/MEM -> A",
            32'd26,
            32'd4
        );


        // =====================================================
        // TEST 3
        // MEM/WB -> A
        //
        // mismo ejemplo, pero el valor llega desde MEM/WB.
        // =====================================================

        set_defaults();

        id_ex_alu_op     = ALU_OP_R_DECODE;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0100000;

        id_ex_read_data1 = 32'd100;
        id_ex_read_data2 = 32'd4;

        forward_a            = FORWARD_MEM_WB;
        mem_wb_forward_value = 32'd30;

        check_result(
            "MEM/WB -> A",
            32'd26,
            32'd4
        );


        // =====================================================
        // TEST 4
        // Fuentes diferentes:
        //
        // A <- MEM/WB = 20
        // B <- EX/MEM = 7
        //
        // ADD = 27
        // =====================================================

        set_defaults();

        id_ex_alu_op     = ALU_OP_R_DECODE;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;

        id_ex_read_data1 = 32'hAAAAAAAA;
        id_ex_read_data2 = 32'hBBBBBBBB;

        forward_a = FORWARD_MEM_WB;
        forward_b = FORWARD_EX_MEM;

        mem_wb_forward_value = 32'd20;
        ex_mem_forward_value = 32'd7;

        check_result(
            "MIXED A/B",
            32'd27,
            32'd7
        );


        // =====================================================
        // TEST 5
        // ADDI:
        //
        // A necesita forwarding.
        // B debe seguir usando immediate.
        //
        // 30 + 10 = 40
        // =====================================================

        set_defaults();

        id_ex_opcode     = OPCODE_I_ALU;

        id_ex_alu_src_b  = 1'b1;
        id_ex_alu_op     = ALU_OP_I_DECODE;

        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;

        id_ex_read_data1 = 32'd100;
        id_ex_read_data2 = 32'd99;
        id_ex_immediate  = 32'd10;

        forward_a            = FORWARD_EX_MEM;
        ex_mem_forward_value = 32'd30;

        // Aunque B pueda tener un valor de registro, alu_src_b=1
        // obliga a utilizar el inmediato.

        check_result(
            "ADDI FORWARD A",
            32'd40,
            32'd99
        );


        // =====================================================
        // TEST 6
        // STORE DATA FORWARDING
        //
        // sw x5,8(x3)
        //
        // base x3 = 64
        // immediate = 8
        //
        // address = 72
        //
        // read_data2 viejo = 1
        // nuevo x5 forwarded = 85
        //
        // ALU debe usar inmediato:
        // 64 + 8 = 72
        //
        // store_data debe ser 85.
        // =====================================================

        set_defaults();

        id_ex_opcode      = OPCODE_STORE;

        id_ex_alu_src_a   = 1'b0;
        id_ex_alu_src_b   = 1'b1;
        id_ex_alu_op      = ALU_OP_ADD;

        id_ex_mem_write   = 1'b1;
        id_ex_reg_write   = 1'b0;

        id_ex_read_data1  = 32'd64;
        id_ex_read_data2  = 32'd1;
        id_ex_immediate   = 32'd8;

        forward_b            = FORWARD_EX_MEM;
        ex_mem_forward_value = 32'd85;

        check_result(
            "STORE DATA",
            32'd72,
            32'd85
        );


        // =====================================================
        // TEST 7
        // BRANCH OPERANDS
        //
        // A <- EX/MEM = 55
        // B <- MEM/WB = 55
        //
        // SUB = 0
        //
        // Todavía no resolvemos redirect, pero comprobamos
        // que EX recibe correctamente ambos operands.
        // =====================================================

        set_defaults();

        id_ex_opcode      = OPCODE_BRANCH;

        id_ex_alu_src_a   = 1'b0;
        id_ex_alu_src_b   = 1'b0;
        id_ex_alu_op      = ALU_OP_SUB;

        id_ex_branch      = 1'b1;

        id_ex_read_data1  = 32'd100;
        id_ex_read_data2  = 32'd200;

        forward_a = FORWARD_EX_MEM;
        forward_b = FORWARD_MEM_WB;

        ex_mem_forward_value = 32'd55;
        mem_wb_forward_value = 32'd55;

        check_result(
            "BRANCH OPERANDS",
            32'd0,
            32'd55
        );


        // =====================================================
        // TEST 8
        // JALR BASE FORWARDING
        //
        // rs1 viejo = 0
        // rs1 correcto desde MEM/WB = 0x100
        // immediate = 0x20
        //
        // target preliminar = 0x120
        //
        // Redirect real queda para control hazards.
        // =====================================================

        set_defaults();

        id_ex_opcode       = OPCODE_JALR;

        id_ex_alu_src_a    = 1'b0;
        id_ex_alu_src_b    = 1'b1;
        id_ex_alu_op       = ALU_OP_ADD;

        id_ex_jump_type    = 2'b10;

        id_ex_read_data1   = 32'd0;
        id_ex_read_data2   = 32'd0;
        id_ex_immediate    = 32'h00000020;

        forward_a            = FORWARD_MEM_WB;
        mem_wb_forward_value = 32'h00000100;

        check_result(
            "JALR BASE",
            32'h00000120,
            32'd0
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("EX + FORWARDING TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: ex_forwarding_pipeline");

        end
        else begin

            $fatal(
                1,
                "FAIL: ex_forwarding_pipeline | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
