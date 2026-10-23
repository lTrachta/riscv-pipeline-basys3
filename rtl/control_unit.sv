`timescale 1ns / 1ps

module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    // ---------------------------------------------------------
    // Control utilizado en EX
    // ---------------------------------------------------------

    output logic       alu_src_a,
    output logic       alu_src_b,
    output logic [2:0] alu_op,

    output logic       branch,
    output logic [1:0] jump_type,

    // ---------------------------------------------------------
    // Control utilizado en MEM
    // ---------------------------------------------------------

    output logic       mem_read,
    output logic       mem_write,

    // ---------------------------------------------------------
    // Control utilizado en WB
    // ---------------------------------------------------------

    output logic       reg_write,
    output logic [1:0] wb_sel,

    // ---------------------------------------------------------
    // Instrucción soportada por nuestro procesador
    // ---------------------------------------------------------

    output logic       control_valid
);

    // =========================================================
    // OPCODES
    // =========================================================

    localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU  = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;


    // =========================================================
    // ALU OP
    //
    // Señal general generada por Main Control.
    //
    // La operación exacta será determinada posteriormente por
    // alu_control.sv en EX.
    // =========================================================

    localparam logic [2:0] ALU_OP_ADD      = 3'b000;
    localparam logic [2:0] ALU_OP_SUB      = 3'b001;
    localparam logic [2:0] ALU_OP_R_DECODE = 3'b010;
    localparam logic [2:0] ALU_OP_I_DECODE = 3'b011;
    localparam logic [2:0] ALU_OP_PASS_B   = 3'b100;


    // =========================================================
    // WRITE BACK SELECT
    // =========================================================

    localparam logic [1:0] WB_SEL_ALU  = 2'b00;
    localparam logic [1:0] WB_SEL_MEM  = 2'b01;
    localparam logic [1:0] WB_SEL_PC4  = 2'b10;


    // =========================================================
    // JUMP TYPE
    // =========================================================

    localparam logic [1:0] JUMP_NONE = 2'b00;
    localparam logic [1:0] JUMP_JAL  = 2'b01;
    localparam logic [1:0] JUMP_JALR = 2'b10;


    // =========================================================
    // MAIN CONTROL
    // =========================================================

    always_comb begin

        // -----------------------------------------------------
        // VALORES NEUTRALES POR DEFECTO
        //
        // Una instrucción desconocida no puede:
        // - escribir registros;
        // - escribir memoria;
        // - leer memoria como operación arquitectónica;
        // - producir branch;
        // - producir jump.
        // -----------------------------------------------------

        alu_src_a    = 1'b0;
        alu_src_b    = 1'b0;
        alu_op       = ALU_OP_ADD;

        branch       = 1'b0;
        jump_type    = JUMP_NONE;

        mem_read     = 1'b0;
        mem_write    = 1'b0;

        reg_write    = 1'b0;
        wb_sel       = WB_SEL_ALU;

        control_valid = 1'b0;


        case (opcode)

            // =================================================
            // R-TYPE
            //
            // add, sub, sll, srl, sra,
            // and, or, xor, slt, sltu
            // =================================================

            OPCODE_R: begin

                case (funct3)

                    // add / sub
                    3'b000: begin

                        if (
                            funct7 == 7'b0000000 ||
                            funct7 == 7'b0100000
                        ) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // sll
                    3'b001: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // slt
                    3'b010: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // sltu
                    3'b011: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // xor
                    3'b100: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // srl / sra
                    3'b101: begin

                        if (
                            funct7 == 7'b0000000 ||
                            funct7 == 7'b0100000
                        ) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // or
                    3'b110: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // and
                    3'b111: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b0;
                            alu_op        = ALU_OP_R_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    default: begin
                        // Valores neutrales.
                    end

                endcase

            end


            // =================================================
            // I-TYPE ALU
            //
            // addi, andi, ori, xori,
            // slti, sltiu,
            // slli, srli, srai
            // =================================================

            OPCODE_I_ALU: begin

                case (funct3)

                    // addi
                    3'b000,

                    // slti
                    3'b010,

                    // sltiu
                    3'b011,

                    // xori
                    3'b100,

                    // ori
                    3'b110,

                    // andi
                    3'b111: begin

                        alu_src_a     = 1'b0;
                        alu_src_b     = 1'b1;
                        alu_op        = ALU_OP_I_DECODE;

                        reg_write     = 1'b1;
                        wb_sel        = WB_SEL_ALU;

                        control_valid = 1'b1;

                    end


                    // slli
                    3'b001: begin

                        if (funct7 == 7'b0000000) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b1;
                            alu_op        = ALU_OP_I_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    // srli / srai
                    3'b101: begin

                        if (
                            funct7 == 7'b0000000 ||
                            funct7 == 7'b0100000
                        ) begin

                            alu_src_a     = 1'b0;
                            alu_src_b     = 1'b1;
                            alu_op        = ALU_OP_I_DECODE;

                            reg_write     = 1'b1;
                            wb_sel        = WB_SEL_ALU;

                            control_valid = 1'b1;

                        end

                    end


                    default: begin
                        // Valores neutrales.
                    end

                endcase

            end


            // =================================================
            // LOAD
            //
            // lb, lh, lw, lbu, lhu
            // =================================================

            OPCODE_LOAD: begin

                case (funct3)

                    3'b000,   // lb
                    3'b001,   // lh
                    3'b010,   // lw
                    3'b100,   // lbu
                    3'b101: begin // lhu

                        alu_src_a     = 1'b0;
                        alu_src_b     = 1'b1;
                        alu_op        = ALU_OP_ADD;

                        mem_read      = 1'b1;

                        reg_write     = 1'b1;
                        wb_sel        = WB_SEL_MEM;

                        control_valid = 1'b1;

                    end


                    default: begin
                        // Load no soportado.
                    end

                endcase

            end


            // =================================================
            // STORE
            //
            // sb, sh, sw
            // =================================================

            OPCODE_STORE: begin

                case (funct3)

                    3'b000,   // sb
                    3'b001,   // sh
                    3'b010: begin // sw

                        alu_src_a     = 1'b0;
                        alu_src_b     = 1'b1;
                        alu_op        = ALU_OP_ADD;

                        mem_write     = 1'b1;

                        reg_write     = 1'b0;

                        control_valid = 1'b1;

                    end


                    default: begin
                        // Store no soportado.
                    end

                endcase

            end


            // =================================================
            // BRANCH
            //
            // beq, bne
            // =================================================

            OPCODE_BRANCH: begin

                case (funct3)

                    3'b000,   // beq
                    3'b001: begin // bne

                        alu_src_a     = 1'b0;
                        alu_src_b     = 1'b0;
                        alu_op        = ALU_OP_SUB;

                        branch        = 1'b1;

                        reg_write     = 1'b0;

                        control_valid = 1'b1;

                    end


                    default: begin
                        // Branch no soportado.
                    end

                endcase

            end


            // =================================================
            // LUI
            // =================================================

            OPCODE_LUI: begin

                alu_src_a     = 1'b0;
                alu_src_b     = 1'b1;
                alu_op        = ALU_OP_PASS_B;

                reg_write     = 1'b1;
                wb_sel        = WB_SEL_ALU;

                control_valid = 1'b1;

            end


            // =================================================
            // JAL
            // =================================================

            OPCODE_JAL: begin

                alu_src_a     = 1'b1;
                alu_src_b     = 1'b1;
                alu_op        = ALU_OP_ADD;

                jump_type     = JUMP_JAL;

                reg_write     = 1'b1;
                wb_sel        = WB_SEL_PC4;

                control_valid = 1'b1;

            end


            // =================================================
            // JALR
            // =================================================

            OPCODE_JALR: begin

                if (funct3 == 3'b000) begin

                    alu_src_a     = 1'b0;
                    alu_src_b     = 1'b1;
                    alu_op        = ALU_OP_ADD;

                    jump_type     = JUMP_JALR;

                    reg_write     = 1'b1;
                    wb_sel        = WB_SEL_PC4;

                    control_valid = 1'b1;

                end

            end


            // =================================================
            // OPCODE NO SOPORTADO
            // =================================================

            default: begin
                // Permanecen todos los valores neutrales.
            end

        endcase

    end

endmodule
