`timescale 1ns / 1ps

module alu_control (
    // Control general generado por Control Unit en ID.
    input  logic [2:0] alu_op,

    // Campos necesarios para resolver operaciones R/I.
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    // Operación exacta enviada a la ALU.
    output logic [3:0] alu_operation
);

    // =========================================================
    // OPERACIONES EXACTAS DE LA ALU
    // =========================================================

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


    // =========================================================
    // ALU_OP GENERADO POR CONTROL UNIT
    // =========================================================

    localparam logic [2:0] ALU_OP_ADD      = 3'b000;
    localparam logic [2:0] ALU_OP_SUB      = 3'b001;
    localparam logic [2:0] ALU_OP_R_DECODE = 3'b010;
    localparam logic [2:0] ALU_OP_I_DECODE = 3'b011;
    localparam logic [2:0] ALU_OP_PASS_B   = 3'b100;


    // =========================================================
    // ALU CONTROL
    // =========================================================

    always_comb begin

        // Ante cualquier combinación no reconocida,
        // la ALU queda en operación inválida.
        alu_operation = ALU_INVALID;

        case (alu_op)

            // -------------------------------------------------
            // Operaciones que Main Control ya resolvió
            // completamente.
            // -------------------------------------------------

            ALU_OP_ADD: begin
                alu_operation = ALU_ADD;
            end


            ALU_OP_SUB: begin
                alu_operation = ALU_SUB;
            end


            ALU_OP_PASS_B: begin
                alu_operation = ALU_PASS_B;
            end


            // -------------------------------------------------
            // R-TYPE
            //
            // La operación exacta depende de funct3/funct7.
            // -------------------------------------------------

            ALU_OP_R_DECODE: begin

                case (funct3)

                    // add / sub
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SUB;
                    end


                    // sll
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLL;
                    end


                    // slt
                    3'b010: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLT;
                    end


                    // sltu
                    3'b011: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLTU;
                    end


                    // xor
                    3'b100: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_XOR;
                    end


                    // srl / sra
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SRA;
                    end


                    // or
                    3'b110: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_OR;
                    end


                    // and
                    3'b111: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_AND;
                    end


                    default: begin
                        alu_operation = ALU_INVALID;
                    end

                endcase

            end


            // -------------------------------------------------
            // I-TYPE ALU
            //
            // Para operaciones inmediatas normales funct7 no
            // tiene significado funcional.
            //
            // Para shifts sí es necesario.
            // -------------------------------------------------

            ALU_OP_I_DECODE: begin

                case (funct3)

                    // addi
                    3'b000:
                        alu_operation = ALU_ADD;


                    // slti
                    3'b010:
                        alu_operation = ALU_SLT;


                    // sltiu
                    3'b011:
                        alu_operation = ALU_SLTU;


                    // xori
                    3'b100:
                        alu_operation = ALU_XOR;


                    // ori
                    3'b110:
                        alu_operation = ALU_OR;


                    // andi
                    3'b111:
                        alu_operation = ALU_AND;


                    // slli
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SLL;
                    end


                    // srli / srai
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


            default: begin
                alu_operation = ALU_INVALID;
            end

        endcase

    end

endmodule
