`timescale 1ns / 1ps

module alu_tb;

    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [3:0]  alu_operation;

    logic [31:0] result;
    logic        zero;

    localparam logic [3:0] ALU_ADD    = 4'b0000;
    localparam logic [3:0] ALU_SUB    = 4'b0001;
    localparam logic [3:0] ALU_AND    = 4'b0010;
    localparam logic [3:0] ALU_OR     = 4'b0011;
    localparam logic [3:0] ALU_XOR    = 4'b0100;
    localparam logic [3:0] ALU_SLL    = 4'b0101;
    localparam logic [3:0] ALU_SRL    = 4'b0110;
    localparam logic [3:0] ALU_SRA    = 4'b0111;
    localparam logic [3:0] ALU_SLT    = 4'b1000;
    localparam logic [3:0] ALU_SLTU   = 4'b1001;
    localparam logic [3:0] ALU_PASS_B = 4'b1010;

    alu dut (
        .operand_a     (operand_a),
        .operand_b     (operand_b),
        .alu_operation (alu_operation),
        .result        (result),
        .zero          (zero)
    );

    task automatic check_result (
        input logic [31:0] expected_result,
        input logic        expected_zero,
        input string       test_name
    );
        begin
            #1;

            if ((result !== expected_result) ||
                (zero !== expected_zero)) begin

                $display(
                    "FAIL: %s | result=%h expected=%h | zero=%b expected_zero=%b",
                    test_name,
                    result,
                    expected_result,
                    zero,
                    expected_zero
                );

                $fatal;
            end
            else begin
                $display(
                    "PASS: %s | result=%h | zero=%b",
                    test_name,
                    result,
                    zero
                );
            end
        end
    endtask

    initial begin

        // ADD: 25 + 17 = 42
        operand_a     = 32'd25;
        operand_b     = 32'd17;
        alu_operation = ALU_ADD;
        check_result(32'd42, 1'b0, "ADD");

        // SUB: 25 - 17 = 8
        operand_a     = 32'd25;
        operand_b     = 32'd17;
        alu_operation = ALU_SUB;
        check_result(32'd8, 1'b0, "SUB");

        // SUB producing zero
        operand_a     = 32'd150;
        operand_b     = 32'd150;
        alu_operation = ALU_SUB;
        check_result(32'd0, 1'b1, "SUB ZERO");

        // AND
        operand_a     = 32'h000000B4;
        operand_b     = 32'h0000006C;
        alu_operation = ALU_AND;
        check_result(32'h00000024, 1'b0, "AND");

        // OR
        operand_a     = 32'h000000B4;
        operand_b     = 32'h0000006C;
        alu_operation = ALU_OR;
        check_result(32'h000000FC, 1'b0, "OR");

        // XOR
        operand_a     = 32'h000000B4;
        operand_b     = 32'h0000006C;
        alu_operation = ALU_XOR;
        check_result(32'h000000D8, 1'b0, "XOR");

        // SLL: 5 << 2 = 20
        operand_a     = 32'd5;
        operand_b     = 32'd2;
        alu_operation = ALU_SLL;
        check_result(32'd20, 1'b0, "SLL");

        // SRL: logical shift of FFFFFFF0 by 2
        operand_a     = 32'hFFFFFFF0;
        operand_b     = 32'd2;
        alu_operation = ALU_SRL;
        check_result(32'h3FFFFFFC, 1'b0, "SRL");

        // SRA: arithmetic shift of FFFFFFF0 (-16) by 2
        operand_a     = 32'hFFFFFFF0;
        operand_b     = 32'd2;
        alu_operation = ALU_SRA;
        check_result(32'hFFFFFFFC, 1'b0, "SRA");

        // SLT signed: -5 < 3 -> 1
        operand_a     = 32'hFFFFFFFB;
        operand_b     = 32'd3;
        alu_operation = ALU_SLT;
        check_result(32'd1, 1'b0, "SLT SIGNED TRUE");

        // SLT signed: 10 < -2 -> 0
        operand_a     = 32'd10;
        operand_b     = 32'hFFFFFFFE;
        alu_operation = ALU_SLT;
        check_result(32'd0, 1'b1, "SLT SIGNED FALSE");

        // SLTU unsigned:
        // FFFFFFFB = 4294967291, so it is NOT < 3
        operand_a     = 32'hFFFFFFFB;
        operand_b     = 32'd3;
        alu_operation = ALU_SLTU;
        check_result(32'd0, 1'b1, "SLTU FALSE");

        // SLTU unsigned: 3 < FFFFFFFB -> 1
        operand_a     = 32'd3;
        operand_b     = 32'hFFFFFFFB;
        alu_operation = ALU_SLTU;
        check_result(32'd1, 1'b0, "SLTU TRUE");

        // PASS_B, intended for LUI datapath
        operand_a     = 32'hAAAAAAAA;
        operand_b     = 32'h12345000;
        alu_operation = ALU_PASS_B;
        check_result(32'h12345000, 1'b0, "PASS_B");

        // Invalid operation -> safe default 0
        operand_a     = 32'h12345678;
        operand_b     = 32'h87654321;
        alu_operation = 4'b1111;
        check_result(32'd0, 1'b1, "INVALID");

        $display("PASS: alu");
        $finish;
    end

endmodule
