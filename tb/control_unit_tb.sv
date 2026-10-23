`timescale 1ns / 1ps

module control_unit_tb;

    // =========================================================
    // DUT INPUTS
    // =========================================================

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;


    // =========================================================
    // DUT OUTPUTS
    // =========================================================

    logic       alu_src_a;
    logic       alu_src_b;
    logic [2:0] alu_op;

    logic       branch;
    logic [1:0] jump_type;

    logic       mem_read;
    logic       mem_write;

    logic       reg_write;
    logic [1:0] wb_sel;

    logic       control_valid;


    // =========================================================
    // CONSTANTS
    // =========================================================

    localparam logic [2:0] ALU_OP_ADD      = 3'b000;
    localparam logic [2:0] ALU_OP_SUB      = 3'b001;
    localparam logic [2:0] ALU_OP_R_DECODE = 3'b010;
    localparam logic [2:0] ALU_OP_I_DECODE = 3'b011;
    localparam logic [2:0] ALU_OP_PASS_B   = 3'b100;

    localparam logic [1:0] WB_SEL_ALU = 2'b00;
    localparam logic [1:0] WB_SEL_MEM = 2'b01;
    localparam logic [1:0] WB_SEL_PC4 = 2'b10;

    localparam logic [1:0] JUMP_NONE = 2'b00;
    localparam logic [1:0] JUMP_JAL  = 2'b01;
    localparam logic [1:0] JUMP_JALR = 2'b10;


    // =========================================================
    // COUNTERS
    // =========================================================

    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    // =========================================================
    // DUT
    // =========================================================

    control_unit dut (
        .opcode        (opcode),
        .funct3        (funct3),
        .funct7        (funct7),

        .alu_src_a     (alu_src_a),
        .alu_src_b     (alu_src_b),
        .alu_op        (alu_op),

        .branch        (branch),
        .jump_type     (jump_type),

        .mem_read      (mem_read),
        .mem_write     (mem_write),

        .reg_write     (reg_write),
        .wb_sel        (wb_sel),

        .control_valid (control_valid)
    );


    // =========================================================
    // CHECK TASK
    // =========================================================

    task automatic check_control(
        input string      test_name,

        input logic [6:0] test_opcode,
        input logic [2:0] test_funct3,
        input logic [6:0] test_funct7,

        input logic       exp_alu_src_a,
        input logic       exp_alu_src_b,
        input logic [2:0] exp_alu_op,

        input logic       exp_branch,
        input logic [1:0] exp_jump_type,

        input logic       exp_mem_read,
        input logic       exp_mem_write,

        input logic       exp_reg_write,
        input logic [1:0] exp_wb_sel,

        input logic       exp_control_valid
    );

        begin

            tests_run = tests_run + 1;

            opcode = test_opcode;
            funct3 = test_funct3;
            funct7 = test_funct7;

            #2;

            if (
                alu_src_a     === exp_alu_src_a     &&
                alu_src_b     === exp_alu_src_b     &&
                alu_op        === exp_alu_op        &&
                branch        === exp_branch        &&
                jump_type     === exp_jump_type     &&
                mem_read      === exp_mem_read      &&
                mem_write     === exp_mem_write     &&
                reg_write     === exp_reg_write     &&
                wb_sel        === exp_wb_sel        &&
                control_valid === exp_control_valid
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-20s | A=%0d B=%0d ALU_OP=%03b BR=%0d J=%02b MR=%0d MW=%0d RW=%0d WB=%02b V=%0d",
                    test_name,
                    alu_src_a,
                    alu_src_b,
                    alu_op,
                    branch,
                    jump_type,
                    mem_read,
                    mem_write,
                    reg_write,
                    wb_sel,
                    control_valid
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", test_name);

                $display(
                    "  INPUT    opcode=%07b funct3=%03b funct7=%07b",
                    opcode,
                    funct3,
                    funct7
                );

                $display(
                    "  RECEIVED A=%0d B=%0d ALU_OP=%03b BR=%0d J=%02b MR=%0d MW=%0d RW=%0d WB=%02b V=%0d",
                    alu_src_a,
                    alu_src_b,
                    alu_op,
                    branch,
                    jump_type,
                    mem_read,
                    mem_write,
                    reg_write,
                    wb_sel,
                    control_valid
                );

                $display(
                    "  EXPECTED A=%0d B=%0d ALU_OP=%03b BR=%0d J=%02b MR=%0d MW=%0d RW=%0d WB=%02b V=%0d",
                    exp_alu_src_a,
                    exp_alu_src_b,
                    exp_alu_op,
                    exp_branch,
                    exp_jump_type,
                    exp_mem_read,
                    exp_mem_write,
                    exp_reg_write,
                    exp_wb_sel,
                    exp_control_valid
                );

                $display("");

            end

        end

    endtask


    // =========================================================
    // TEST SEQUENCE
    // =========================================================

    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        opcode = 7'b0;
        funct3 = 3'b0;
        funct7 = 7'b0;

        #5;


        // =====================================================
        // R-TYPE
        //
        // A = rs1
        // B = rs2
        // ALU_OP = R-DECODE
        // RegWrite = 1
        // WB = ALU
        // =====================================================

        check_control(
            "add",
            7'b0110011, 3'b000, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "sub",
            7'b0110011, 3'b000, 7'b0100000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "sll",
            7'b0110011, 3'b001, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "slt",
            7'b0110011, 3'b010, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "sltu",
            7'b0110011, 3'b011, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "xor",
            7'b0110011, 3'b100, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "srl",
            7'b0110011, 3'b101, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "sra",
            7'b0110011, 3'b101, 7'b0100000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "or",
            7'b0110011, 3'b110, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "and",
            7'b0110011, 3'b111, 7'b0000000,
            0, 0, ALU_OP_R_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );


        // =====================================================
        // I-TYPE ALU
        //
        // A = rs1
        // B = immediate
        // ALU_OP = I-DECODE
        // =====================================================

        check_control(
            "addi",
            7'b0010011, 3'b000, 7'b1010101,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "slti",
            7'b0010011, 3'b010, 7'b1111111,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "sltiu",
            7'b0010011, 3'b011, 7'b1010101,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "xori",
            7'b0010011, 3'b100, 7'b1110001,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "ori",
            7'b0010011, 3'b110, 7'b0110110,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "andi",
            7'b0010011, 3'b111, 7'b1101010,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "slli",
            7'b0010011, 3'b001, 7'b0000000,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "srli",
            7'b0010011, 3'b101, 7'b0000000,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );

        check_control(
            "srai",
            7'b0010011, 3'b101, 7'b0100000,
            0, 1, ALU_OP_I_DECODE,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );


        // =====================================================
        // LOADS
        // =====================================================

        check_control(
            "lb",
            7'b0000011, 3'b000, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            1, 0,
            1, WB_SEL_MEM,
            1
        );

        check_control(
            "lh",
            7'b0000011, 3'b001, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            1, 0,
            1, WB_SEL_MEM,
            1
        );

        check_control(
            "lw",
            7'b0000011, 3'b010, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            1, 0,
            1, WB_SEL_MEM,
            1
        );

        check_control(
            "lbu",
            7'b0000011, 3'b100, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            1, 0,
            1, WB_SEL_MEM,
            1
        );

        check_control(
            "lhu",
            7'b0000011, 3'b101, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            1, 0,
            1, WB_SEL_MEM,
            1
        );


        // =====================================================
        // STORES
        // =====================================================

        check_control(
            "sb",
            7'b0100011, 3'b000, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 1,
            0, WB_SEL_ALU,
            1
        );

        check_control(
            "sh",
            7'b0100011, 3'b001, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 1,
            0, WB_SEL_ALU,
            1
        );

        check_control(
            "sw",
            7'b0100011, 3'b010, 7'b0000000,
            0, 1, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 1,
            0, WB_SEL_ALU,
            1
        );


        // =====================================================
        // BRANCHES
        // =====================================================

        check_control(
            "beq",
            7'b1100011, 3'b000, 7'b0000000,
            0, 0, ALU_OP_SUB,
            1, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            1
        );

        check_control(
            "bne",
            7'b1100011, 3'b001, 7'b0000000,
            0, 0, ALU_OP_SUB,
            1, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            1
        );


        // =====================================================
        // LUI
        //
        // funct3/funct7 no tienen significado funcional aquí.
        // Se ponen valores arbitrarios para comprobar que
        // Control Unit no los interpreta.
        // =====================================================

        check_control(
            "lui",
            7'b0110111, 3'b101, 7'b1101010,
            0, 1, ALU_OP_PASS_B,
            0, JUMP_NONE,
            0, 0,
            1, WB_SEL_ALU,
            1
        );


        // =====================================================
        // JAL
        // =====================================================

        check_control(
            "jal",
            7'b1101111, 3'b111, 7'b1010101,
            1, 1, ALU_OP_ADD,
            0, JUMP_JAL,
            0, 0,
            1, WB_SEL_PC4,
            1
        );


        // =====================================================
        // JALR
        // =====================================================

        check_control(
            "jalr",
            7'b1100111, 3'b000, 7'b1010101,
            0, 1, ALU_OP_ADD,
            0, JUMP_JALR,
            0, 0,
            1, WB_SEL_PC4,
            1
        );


        // =====================================================
        // INVALID CASES
        //
        // Todos deben quedar completamente neutralizados.
        // =====================================================

        check_control(
            "invalid opcode",
            7'b1111111, 3'b000, 7'b0000000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid R funct7",
            7'b0110011, 3'b000, 7'b1111111,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid R shift",
            7'b0110011, 3'b101, 7'b0010000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid slli",
            7'b0010011, 3'b001, 7'b0100000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid load",
            7'b0000011, 3'b111, 7'b0000000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid store",
            7'b0100011, 3'b111, 7'b0000000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid branch",
            7'b1100011, 3'b100, 7'b0000000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );

        check_control(
            "invalid jalr",
            7'b1100111, 3'b001, 7'b0000000,
            0, 0, ALU_OP_ADD,
            0, JUMP_NONE,
            0, 0,
            0, WB_SEL_ALU,
            0
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("CONTROL UNIT TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: control_unit");

        end
        else begin

            $fatal(
                1,
                "FAIL: control_unit | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
