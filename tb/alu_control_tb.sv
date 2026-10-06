`timescale 1ns / 1ps

module alu_control_tb;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    logic [3:0] alu_operation;

    localparam logic [3:0] ALU_ADD     = 4'b0000;
    localparam logic [3:0] ALU_SUB     = 4'b0001;
    localparam logic [3:0] ALU_AND     = 4'b0010;
    localparam logic [3:0] ALU_OR      = 4'b0011;
    localparam logic [3:0] ALU_XOR     = 4'b0100;
    localparam logic [3:0] ALU_SLL     = 4'b0101;
    localparam logic [3:0] ALU_SRL     = 4'b0110;
    localparam logic [3:0] ALU_SRA     = 4'b0111;
    localparam logic [3:0] ALU_SLT     = 4'b1000;
    localparam logic [3:0] ALU_SLTU    = 4'b1001;
    localparam logic [3:0] ALU_PASS_B  = 4'b1010;
    localparam logic [3:0] ALU_INVALID = 4'b1111;

    alu_control dut (
        .opcode        (opcode),
        .funct3        (funct3),
        .funct7        (funct7),
        .alu_operation (alu_operation)
    );

    task automatic check_decode (
        input logic [6:0] test_opcode,
        input logic [2:0] test_funct3,
        input logic [6:0] test_funct7,
        input logic [3:0] expected_operation,
        input string      test_name
    );
        begin
            opcode = test_opcode;
            funct3 = test_funct3;
            funct7 = test_funct7;

            #1;

            if (alu_operation !== expected_operation) begin
                $display(
                    "FAIL: %s | opcode=%b funct3=%b funct7=%b | alu_operation=%b expected=%b",
                    test_name,
                    opcode,
                    funct3,
                    funct7,
                    alu_operation,
                    expected_operation
                );

                $fatal;
            end
            else begin
                $display(
                    "PASS: %s | alu_operation=%b",
                    test_name,
                    alu_operation
                );
            end
        end
    endtask

    initial begin

        // =========================================================
        // R-TYPE
        // opcode = 0110011
        // =========================================================

        check_decode(
            7'b0110011, 3'b000, 7'b0000000,
            ALU_ADD, "ADD"
        );

        check_decode(
            7'b0110011, 3'b000, 7'b0100000,
            ALU_SUB, "SUB"
        );

        check_decode(
            7'b0110011, 3'b001, 7'b0000000,
            ALU_SLL, "SLL"
        );

        check_decode(
            7'b0110011, 3'b010, 7'b0000000,
            ALU_SLT, "SLT"
        );

        check_decode(
            7'b0110011, 3'b011, 7'b0000000,
            ALU_SLTU, "SLTU"
        );

        check_decode(
            7'b0110011, 3'b100, 7'b0000000,
            ALU_XOR, "XOR"
        );

        check_decode(
            7'b0110011, 3'b101, 7'b0000000,
            ALU_SRL, "SRL"
        );

        check_decode(
            7'b0110011, 3'b101, 7'b0100000,
            ALU_SRA, "SRA"
        );

        check_decode(
            7'b0110011, 3'b110, 7'b0000000,
            ALU_OR, "OR"
        );

        check_decode(
            7'b0110011, 3'b111, 7'b0000000,
            ALU_AND, "AND"
        );


        // =========================================================
        // I-TYPE ALU
        // opcode = 0010011
        // =========================================================

        check_decode(
            7'b0010011, 3'b000, 7'b0000000,
            ALU_ADD, "ADDI"
        );

        check_decode(
            7'b0010011, 3'b010, 7'b0000000,
            ALU_SLT, "SLTI"
        );

        check_decode(
            7'b0010011, 3'b011, 7'b0000000,
            ALU_SLTU, "SLTIU"
        );

        check_decode(
            7'b0010011, 3'b100, 7'b0000000,
            ALU_XOR, "XORI"
        );

        check_decode(
            7'b0010011, 3'b110, 7'b0000000,
            ALU_OR, "ORI"
        );

        check_decode(
            7'b0010011, 3'b111, 7'b0000000,
            ALU_AND, "ANDI"
        );

        check_decode(
            7'b0010011, 3'b001, 7'b0000000,
            ALU_SLL, "SLLI"
        );

        check_decode(
            7'b0010011, 3'b101, 7'b0000000,
            ALU_SRL, "SRLI"
        );

        check_decode(
            7'b0010011, 3'b101, 7'b0100000,
            ALU_SRA, "SRAI"
        );


        // =========================================================
        // LOADS
        // Todas calculan direccion con ADD
        // opcode = 0000011
        // =========================================================

        check_decode(
            7'b0000011, 3'b000, 7'b0000000,
            ALU_ADD, "LB"
        );

        check_decode(
            7'b0000011, 3'b001, 7'b0000000,
            ALU_ADD, "LH"
        );

        check_decode(
            7'b0000011, 3'b010, 7'b0000000,
            ALU_ADD, "LW"
        );

        check_decode(
            7'b0000011, 3'b100, 7'b0000000,
            ALU_ADD, "LBU"
        );

        check_decode(
            7'b0000011, 3'b101, 7'b0000000,
            ALU_ADD, "LHU"
        );


        // =========================================================
        // STORES
        // Todas calculan direccion con ADD
        // opcode = 0100011
        // =========================================================

        check_decode(
            7'b0100011, 3'b000, 7'b0000000,
            ALU_ADD, "SB"
        );

        check_decode(
            7'b0100011, 3'b001, 7'b0000000,
            ALU_ADD, "SH"
        );

        check_decode(
            7'b0100011, 3'b010, 7'b0000000,
            ALU_ADD, "SW"
        );


        // =========================================================
        // BRANCHES
        // Comparacion mediante SUB
        // opcode = 1100011
        // =========================================================

        check_decode(
            7'b1100011, 3'b000, 7'b0000000,
            ALU_SUB, "BEQ"
        );

        check_decode(
            7'b1100011, 3'b001, 7'b0000000,
            ALU_SUB, "BNE"
        );


        // =========================================================
        // LUI
        // =========================================================

        check_decode(
            7'b0110111, 3'b000, 7'b0000000,
            ALU_PASS_B, "LUI"
        );


        // =========================================================
        // JAL
        // =========================================================

        check_decode(
            7'b1101111, 3'b000, 7'b0000000,
            ALU_ADD, "JAL"
        );


        // =========================================================
        // JALR
        // =========================================================

        check_decode(
            7'b1100111, 3'b000, 7'b0000000,
            ALU_ADD, "JALR"
        );


        // =========================================================
        // INVALID CASES
        // =========================================================

        // R-type con funct7 no reconocido
        check_decode(
            7'b0110011, 3'b000, 7'b1111111,
            ALU_INVALID, "INVALID R FUNCT7"
        );

        // Shift inmediato con funct7 no reconocido
        check_decode(
            7'b0010011, 3'b101, 7'b1111111,
            ALU_INVALID, "INVALID I SHIFT"
        );

        // Opcode desconocido
        check_decode(
            7'b0000000, 3'b000, 7'b0000000,
            ALU_INVALID, "INVALID OPCODE"
        );


        $display("PASS: alu_control");
        $finish;

    end

endmodule
