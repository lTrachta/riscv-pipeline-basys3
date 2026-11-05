`timescale 1ns / 1ps

module alu_control_tb;

    logic [2:0] alu_op;
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

    localparam logic [2:0] ALU_OP_ADD      = 3'b000;
    localparam logic [2:0] ALU_OP_SUB      = 3'b001;
    localparam logic [2:0] ALU_OP_R_DECODE = 3'b010;
    localparam logic [2:0] ALU_OP_I_DECODE = 3'b011;
    localparam logic [2:0] ALU_OP_PASS_B   = 3'b100;

    alu_control dut (
        .alu_op        (alu_op),
        .funct3        (funct3),
        .funct7        (funct7),
        .alu_operation (alu_operation)
    );

    task automatic check_decode(
        input logic [2:0] op,
        input logic [2:0] f3,
        input logic [6:0] f7,
        input logic [3:0] expected,
        input string name
    );
        begin
            alu_op = op;
            funct3 = f3;
            funct7 = f7;
            #1;

            if (alu_operation !== expected)
                $fatal(1, "FAIL: %s | got=%b expected=%b", name, alu_operation, expected);

            $display("PASS: %s | operation=%b", name, alu_operation);
        end
    endtask

    initial begin
        alu_op = 3'd0;
        funct3 = 3'd0;
        funct7 = 7'd0;

        check_decode(ALU_OP_ADD,      3'b000, 7'b0000000, ALU_ADD,    "ADDRESS ADD");
        check_decode(ALU_OP_SUB,      3'b000, 7'b0000000, ALU_SUB,    "BRANCH SUB");
        check_decode(ALU_OP_PASS_B,   3'b000, 7'b0000000, ALU_PASS_B, "LUI PASS B");

        check_decode(ALU_OP_R_DECODE, 3'b000, 7'b0000000, ALU_ADD,    "R ADD");
        check_decode(ALU_OP_R_DECODE, 3'b000, 7'b0100000, ALU_SUB,    "R SUB");
        check_decode(ALU_OP_R_DECODE, 3'b100, 7'b0000000, ALU_XOR,    "R XOR");
        check_decode(ALU_OP_R_DECODE, 3'b101, 7'b0100000, ALU_SRA,    "R SRA");
        check_decode(ALU_OP_R_DECODE, 3'b111, 7'b0000000, ALU_AND,    "R AND");

        check_decode(ALU_OP_I_DECODE, 3'b000, 7'b1111111, ALU_ADD,    "I ADDI");
        check_decode(ALU_OP_I_DECODE, 3'b001, 7'b0000000, ALU_SLL,    "I SLLI");
        check_decode(ALU_OP_I_DECODE, 3'b101, 7'b0000000, ALU_SRL,    "I SRLI");
        check_decode(ALU_OP_I_DECODE, 3'b101, 7'b0100000, ALU_SRA,    "I SRAI");
        check_decode(ALU_OP_I_DECODE, 3'b011, 7'b0000000, ALU_SLTU,   "I SLTIU");
        check_decode(ALU_OP_I_DECODE, 3'b110, 7'b0000000, ALU_OR,     "I ORI");

        check_decode(ALU_OP_R_DECODE, 3'b000, 7'b1111111, ALU_INVALID, "INVALID R FUNCT7");
        check_decode(3'b111,           3'b000, 7'b0000000, ALU_INVALID, "INVALID ALU OP");

        $display("PASS: alu_control");
        $finish;
    end

endmodule
