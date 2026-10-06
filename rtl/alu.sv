`timescale 1ns / 1ps

module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_operation,

    output logic [31:0] result,
    output logic        zero
);

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

    always_comb begin
        result = 32'd0;

        case (alu_operation)

            ALU_ADD: begin
                result = operand_a + operand_b;
            end

            ALU_SUB: begin
                result = operand_a - operand_b;
            end

            ALU_AND: begin
                result = operand_a & operand_b;
            end

            ALU_OR: begin
                result = operand_a | operand_b;
            end

            ALU_XOR: begin
                result = operand_a ^ operand_b;
            end

            ALU_SLL: begin
                result = operand_a << operand_b[4:0];
            end

            ALU_SRL: begin
                result = operand_a >> operand_b[4:0];
            end

            ALU_SRA: begin
                result = $signed(operand_a) >>> operand_b[4:0];
            end

            ALU_SLT: begin
                result = ($signed(operand_a) < $signed(operand_b))
                       ? 32'd1
                       : 32'd0;
            end

            ALU_SLTU: begin
                result = (operand_a < operand_b)
                       ? 32'd1
                       : 32'd0;
            end

            ALU_PASS_B: begin
                result = operand_b;
            end

            default: begin
                result = 32'd0;
            end

        endcase
    end

    always_comb begin
        zero = (result == 32'd0);
    end

endmodule
