`timescale 1ns / 1ps

module wb_stage (
    // =========================================================
    // DATAPATH DESDE MEM/WB
    // =========================================================

    input  logic [31:0] mem_wb_pc,
    input  logic [31:0] mem_wb_alu_result,
    input  logic [31:0] mem_wb_load_data,

    input  logic [4:0]  mem_wb_rd,

    // Se conserva temporalmente para compatibilidad/debug.
    // WB ya NO lo utiliza para tomar decisiones.
    input  logic [6:0]  mem_wb_opcode,

    input  logic        mem_wb_valid,

    // =========================================================
    // CONTROL WB DESDE MEM/WB
    // =========================================================

    input  logic        mem_wb_reg_write,
    input  logic [1:0]  mem_wb_wb_sel,

    // =========================================================
    // SALIDA HACIA REGISTER FILE
    // =========================================================

    output logic        wb_write_enable,
    output logic [4:0]  wb_write_register,
    output logic [31:0] wb_write_data
);


    // =========================================================
    // WRITE-BACK SELECT
    //
    // Estas codificaciones fueron generadas originalmente
    // por Control Unit en ID.
    // =========================================================

    localparam logic [1:0] WB_SEL_ALU = 2'b00;
    localparam logic [1:0] WB_SEL_MEM = 2'b01;
    localparam logic [1:0] WB_SEL_PC4 = 2'b10;


    // =========================================================
    // PC + 4
    //
    // Valor de link utilizado por JAL/JALR.
    // =========================================================

    logic [31:0] pc_plus_4;

    assign pc_plus_4 = mem_wb_pc + 32'd4;


    // =========================================================
    // VALIDEZ DE LA SELECCIÓN WB
    //
    // 11 está reservado.
    // =========================================================

    logic wb_select_valid;


    // =========================================================
    // MULTIPLEXOR DE WRITE-BACK
    //
    // WB ya no mira opcode.
    //
    // Simplemente obedece wb_sel.
    // =========================================================

    always_comb begin

        wb_write_data   = 32'd0;
        wb_select_valid = 1'b1;

        case (mem_wb_wb_sel)

            WB_SEL_ALU: begin
                wb_write_data = mem_wb_alu_result;
            end

            WB_SEL_MEM: begin
                wb_write_data = mem_wb_load_data;
            end

            WB_SEL_PC4: begin
                wb_write_data = pc_plus_4;
            end

            default: begin
                wb_write_data   = 32'd0;
                wb_select_valid = 1'b0;
            end

        endcase

    end


    // =========================================================
    // REGISTRO DESTINO
    // =========================================================

    assign wb_write_register = mem_wb_rd;


    // =========================================================
    // WRITE ENABLE FINAL
    //
    // Se escribe Register File solamente cuando:
    //
    // - MEM/WB contiene una instrucción válida;
    // - Control Unit indicó RegWrite;
    // - wb_sel es válido;
    // - rd no es x0.
    // =========================================================

    assign wb_write_enable =
        mem_wb_valid       &&
        mem_wb_reg_write   &&
        wb_select_valid    &&
        (mem_wb_rd != 5'd0);


endmodule
