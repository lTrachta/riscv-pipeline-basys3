`timescale 1ns / 1ps

module alu_control (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic [3:0] alu_operation
);

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

    localparam logic [6:0] OPCODE_R       = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU   = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD    = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE   = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
    localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
    localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR    = 7'b1100111;

    always_comb begin

        alu_operation = ALU_INVALID;

        case (opcode)

            OPCODE_R: begin
                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SUB;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLL;
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLT;
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLTU;
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_XOR;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SRA;
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_OR;
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_AND;
                    end

                    default: begin
                        alu_operation = ALU_INVALID;
                    end

                endcase
            end

            OPCODE_I_ALU: begin
                case (funct3)

                    3'b000:
                        alu_operation = ALU_ADD;

                    3'b010:
                        alu_operation = ALU_SLT;

                    3'b011:
                        alu_operation = ALU_SLTU;

                    3'b100:
                        alu_operation = ALU_XOR;

                    3'b110:
                        alu_operation = ALU_OR;

                    3'b111:
                        alu_operation = ALU_AND;

                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLL;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SRA;
                    end

                    default: begin
                        alu_operation = ALU_INVALID;
                    end

                endcase
            end

            OPCODE_LOAD:
                alu_operation = ALU_ADD;

            OPCODE_STORE:
                alu_operation = ALU_ADD;

            OPCODE_BRANCH:
                alu_operation = ALU_SUB;

            OPCODE_LUI:
                alu_operation = ALU_PASS_B;

            OPCODE_JAL:
                alu_operation = ALU_ADD;

            OPCODE_JALR:
                alu_operation = ALU_ADD;

            default:
                alu_operation = ALU_INVALID;

        endcase
    end

endmodule
