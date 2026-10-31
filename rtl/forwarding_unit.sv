`timescale 1ns / 1ps

module forwarding_unit (
    // =========================================================
    // REGISTROS FUENTE DE LA INSTRUCCIÓN ACTUAL EN EX
    // =========================================================

    input  logic [4:0] id_ex_rs1,
    input  logic [4:0] id_ex_rs2,

    // =========================================================
    // INSTRUCCIÓN MÁS RECIENTE ADELANTADA: EX/MEM
    // =========================================================

    input  logic [4:0] ex_mem_rd,
    input  logic       ex_mem_reg_write,

    // =========================================================
    // INSTRUCCIÓN MÁS ANTIGUA ADELANTADA: MEM/WB
    // =========================================================

    input  logic [4:0] mem_wb_rd,
    input  logic       mem_wb_reg_write,

    // =========================================================
    // SELECCIÓN DE FORWARDING
    //
    // 00 -> utilizar valor normal de ID/EX
    // 10 -> utilizar valor de EX/MEM
    // 01 -> utilizar valor de MEM/WB
    // 11 -> reservado
    // =========================================================

    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);


    // =========================================================
    // CODIFICACIONES
    // =========================================================

    localparam logic [1:0] FORWARD_ID_EX  = 2'b00;
    localparam logic [1:0] FORWARD_MEM_WB = 2'b01;
    localparam logic [1:0] FORWARD_EX_MEM = 2'b10;


    // =========================================================
    // FORWARDING UNIT
    //
    // Prioridad:
    //
    // EX/MEM > MEM/WB > ID/EX
    //
    // EX/MEM tiene prioridad porque corresponde a una
    // instrucción más reciente que MEM/WB.
    // =========================================================

    always_comb begin

        // -----------------------------------------------------
        // Por defecto no hay forwarding.
        // -----------------------------------------------------

        forward_a = FORWARD_ID_EX;
        forward_b = FORWARD_ID_EX;


        // =====================================================
        // OPERANDO A - rs1
        // =====================================================

        // -----------------------------------------------------
        // Primera prioridad: EX/MEM
        // -----------------------------------------------------

        if (
            ex_mem_reg_write &&
            (ex_mem_rd != 5'd0) &&
            (ex_mem_rd == id_ex_rs1)
        ) begin

            forward_a = FORWARD_EX_MEM;

        end

        // -----------------------------------------------------
        // Segunda prioridad: MEM/WB
        //
        // Este camino solo se utiliza si EX/MEM no produjo
        // una coincidencia válida.
        // -----------------------------------------------------

        else if (
            mem_wb_reg_write &&
            (mem_wb_rd != 5'd0) &&
            (mem_wb_rd == id_ex_rs1)
        ) begin

            forward_a = FORWARD_MEM_WB;

        end


        // =====================================================
        // OPERANDO B / rs2
        // =====================================================

        // -----------------------------------------------------
        // Primera prioridad: EX/MEM
        // -----------------------------------------------------

        if (
            ex_mem_reg_write &&
            (ex_mem_rd != 5'd0) &&
            (ex_mem_rd == id_ex_rs2)
        ) begin

            forward_b = FORWARD_EX_MEM;

        end

        // -----------------------------------------------------
        // Segunda prioridad: MEM/WB
        // -----------------------------------------------------

        else if (
            mem_wb_reg_write &&
            (mem_wb_rd != 5'd0) &&
            (mem_wb_rd == id_ex_rs2)
        ) begin

            forward_b = FORWARD_MEM_WB;

        end

    end

endmodule
