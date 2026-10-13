`timescale 1ns / 1ps

module wb_stage (
    // ---------------------------------------------------------
    // Entrada desde MEM/WB
    // ---------------------------------------------------------

    input  logic [31:0] mem_wb_pc,
    input  logic [31:0] mem_wb_alu_result,
    input  logic [31:0] mem_wb_load_data,
    input  logic [4:0]  mem_wb_rd,
    input  logic [6:0]  mem_wb_opcode,
    input  logic        mem_wb_valid,

    // ---------------------------------------------------------
    // Salida hacia Register File
    // ---------------------------------------------------------

    output logic        wb_write_enable,
    output logic [4:0]  wb_write_register,
    output logic [31:0] wb_write_data
);

    // ---------------------------------------------------------
    // Opcodes utilizados por el subconjunto implementado
    // ---------------------------------------------------------

    localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU  = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;


    // ---------------------------------------------------------
    // Selección interna de fuente de write-back
    // ---------------------------------------------------------

    localparam logic [1:0] WB_SEL_ALU  = 2'b00;
    localparam logic [1:0] WB_SEL_LOAD = 2'b01;
    localparam logic [1:0] WB_SEL_PC4  = 2'b10;

    logic [1:0] wb_sel;
    logic       writes_register;

    logic [31:0] pc_plus_4;


    // ---------------------------------------------------------
    // PC + 4
    //
    // Se utiliza como link value para JAL y JALR.
    // ---------------------------------------------------------

    assign pc_plus_4 = mem_wb_pc + 32'd4;


    // ---------------------------------------------------------
    // Decodificación de write-back
    //
    // Determina:
    // - si la instrucción escribe un registro;
    // - qué fuente debe seleccionarse.
    // ---------------------------------------------------------

    always_comb begin

        writes_register = 1'b0;
        wb_sel           = WB_SEL_ALU;

        case (mem_wb_opcode)

            // =================================================
            // Operaciones R-type
            // add, sub, sll, srl, sra, and, or, xor, slt, sltu
            // =================================================

            OPCODE_R: begin
                writes_register = 1'b1;
                wb_sel           = WB_SEL_ALU;
            end


            // =================================================
            // Operaciones I-type de ALU
            // addi, andi, ori, xori, slti, sltiu,
            // slli, srli, srai
            // =================================================

            OPCODE_I_ALU: begin
                writes_register = 1'b1;
                wb_sel           = WB_SEL_ALU;
            end


            // =================================================
            // Loads
            // lb, lh, lw, lbu, lhu
            // =================================================

            OPCODE_LOAD: begin
                writes_register = 1'b1;
                wb_sel           = WB_SEL_LOAD;
            end


            // =================================================
            // LUI
            //
            // En nuestro datapath LUI ya produjo su resultado
            // mediante ALU_PASS_B en EX.
            // =================================================

            OPCODE_LUI: begin
                writes_register = 1'b1;
                wb_sel           = WB_SEL_ALU;
            end


            // =================================================
            // JAL
            //
            // rd <- PC + 4
            // =================================================

            OPCODE_JAL: begin
                writes_register = 1'b1;
                wb_sel           = WB_SEL_PC4;
            end


            // =================================================
            // JALR
            //
            // rd <- PC + 4
            // =================================================

            OPCODE_JALR: begin
                writes_register = 1'b1;
                wb_sel           = WB_SEL_PC4;
            end


            // =================================================
            // Stores y branches no escriben Register File.
            // =================================================

            OPCODE_STORE: begin
                writes_register = 1'b0;
                wb_sel           = WB_SEL_ALU;
            end

            OPCODE_BRANCH: begin
                writes_register = 1'b0;
                wb_sel           = WB_SEL_ALU;
            end


            // =================================================
            // Opcode no soportado
            // =================================================

            default: begin
                writes_register = 1'b0;
                wb_sel           = WB_SEL_ALU;
            end

        endcase

    end


    // ---------------------------------------------------------
    // Multiplexor de dato de write-back
    // ---------------------------------------------------------

    always_comb begin

        case (wb_sel)

            WB_SEL_ALU:
                wb_write_data = mem_wb_alu_result;

            WB_SEL_LOAD:
                wb_write_data = mem_wb_load_data;

            WB_SEL_PC4:
                wb_write_data = pc_plus_4;

            default:
                wb_write_data = 32'd0;

        endcase

    end


    // ---------------------------------------------------------
    // Registro destino
    // ---------------------------------------------------------

    assign wb_write_register = mem_wb_rd;


    // ---------------------------------------------------------
    // Habilitación final de escritura
    //
    // Solo escribimos cuando:
    // - la entrada MEM/WB es válida;
    // - la instrucción escribe registro;
    // - rd no es x0.
    // ---------------------------------------------------------

    assign wb_write_enable =
        mem_wb_valid       &&
        writes_register    &&
        (mem_wb_rd != 5'd0);

endmodule
