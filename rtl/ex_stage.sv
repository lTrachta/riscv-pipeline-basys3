`timescale 1ns / 1ps

module ex_stage (
    input  logic        clk,
    input  logic        reset,

    input  logic        ex_enable,
    input  logic        flush_ex_mem,

    // =========================================================
    // CONTROL EX PROVENIENTE DE ID/EX
    // =========================================================

    input  logic        id_ex_alu_src_a,
    input  logic        id_ex_alu_src_b,
    input  logic [2:0]  id_ex_alu_op,

    input  logic        id_ex_branch,
    input  logic [1:0]  id_ex_jump_type,

    // =========================================================
    // CONTROL MEM QUE DEBE CONTINUAR
    // =========================================================

    input  logic        id_ex_mem_read,
    input  logic        id_ex_mem_write,

    // =========================================================
    // CONTROL WB QUE DEBE CONTINUAR
    // =========================================================

    input  logic        id_ex_reg_write,
    input  logic [1:0]  id_ex_wb_sel,

    // =========================================================
    // DATOS PROVENIENTES DE ID/EX
    // =========================================================

    input  logic [31:0] id_ex_pc,

    input  logic [31:0] id_ex_read_data1,
    input  logic [31:0] id_ex_read_data2,

    input  logic [31:0] id_ex_immediate,

    input  logic [4:0]  id_ex_rd,

    input  logic [6:0]  id_ex_opcode,
    input  logic [2:0]  id_ex_funct3,
    input  logic [6:0]  id_ex_funct7,

    input  logic        id_ex_valid,

    // =========================================================
    // DATOS HACIA MEM
    // =========================================================

    output logic [31:0] ex_mem_pc,
    output logic [31:0] ex_mem_alu_result,
    output logic [31:0] ex_mem_store_data,

    output logic [4:0]  ex_mem_rd,

    output logic [6:0]  ex_mem_opcode,
    output logic [2:0]  ex_mem_funct3,

    output logic        ex_mem_valid,

    // =========================================================
    // CONTROL MEM HACIA EX/MEM
    // =========================================================

    output logic        ex_mem_mem_read,
    output logic        ex_mem_mem_write,

    // =========================================================
    // CONTROL WB HACIA EX/MEM
    // =========================================================

    output logic        ex_mem_reg_write,
    output logic [1:0]  ex_mem_wb_sel
);


    // =========================================================
    // OPERANDOS DE ALU
    // =========================================================

    logic [31:0] operand_a;
    logic [31:0] operand_b;


    // =========================================================
    // RESULTADO DE ALU
    // =========================================================

    logic [3:0]  alu_operation;
    logic [31:0] alu_result;
    logic        alu_zero;


    // =========================================================
    // SELECCIÓN DE OPERANDO A
    //
    // id_ex_alu_src_a:
    //
    // 0 -> rs1
    // 1 -> PC
    // =========================================================

    always_comb begin

        if (id_ex_alu_src_a)
            operand_a = id_ex_pc;
        else
            operand_a = id_ex_read_data1;

    end


    // =========================================================
    // SELECCIÓN DE OPERANDO B
    //
    // id_ex_alu_src_b:
    //
    // 0 -> rs2
    // 1 -> immediate
    // =========================================================

    always_comb begin

        if (id_ex_alu_src_b)
            operand_b = id_ex_immediate;
        else
            operand_b = id_ex_read_data2;

    end


    // =========================================================
    // ALU CONTROL
    //
    // Ya NO vuelve a mirar opcode.
    //
    // Recibe alu_op generado originalmente por Control Unit
    // en ID y transportado por ID/EX.
    // =========================================================

    alu_control alu_control_unit (
        .alu_op        (id_ex_alu_op),
        .funct3        (id_ex_funct3),
        .funct7        (id_ex_funct7),

        .alu_operation (alu_operation)
    );


    // =========================================================
    // ALU
    // =========================================================

    alu alu_unit (
        .operand_a     (operand_a),
        .operand_b     (operand_b),

        .alu_operation (alu_operation),

        .result        (alu_result),
        .zero          (alu_zero)
    );


    // =========================================================
    // BRANCH / JUMP
    //
    // id_ex_branch e id_ex_jump_type ya llegan correctamente
    // hasta EX.
    //
    // Todavía no se utilizan para modificar el PC.
    // La resolución completa de control hazards se realizará
    // posteriormente.
    // =========================================================


    // =========================================================
    // EX/MEM PIPELINE REGISTER
    //
    // EX ya consumió:
    //
    // - alu_src_a
    // - alu_src_b
    // - alu_op
    // - branch
    // - jump_type
    //
    // Por lo tanto EX/MEM solamente conserva:
    //
    // - controles MEM
    // - controles WB
    //
    // además de los datos necesarios.
    // =========================================================

    ex_mem_register ex_mem_reg (
        .clk             (clk),
        .reset           (reset),
        .enable          (ex_enable),
        .flush           (flush_ex_mem),

        // -----------------------------------------------------
        // Datapath
        // -----------------------------------------------------

        .pc_in           (id_ex_pc),

        .alu_result_in   (alu_result),

        // IMPORTANTE:
        // El dato del store sigue siendo siempre rs2 original,
        // no operand_b.
        //
        // Para un store operand_b contiene el inmediato.
        .store_data_in   (id_ex_read_data2),

        .rd_in           (id_ex_rd),

        .opcode_in       (id_ex_opcode),
        .funct3_in       (id_ex_funct3),

        .valid_in        (id_ex_valid),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .mem_read_in     (id_ex_mem_read),
        .mem_write_in    (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .reg_write_in    (id_ex_reg_write),
        .wb_sel_in       (id_ex_wb_sel),

        // -----------------------------------------------------
        // Datapath outputs
        // -----------------------------------------------------

        .pc_out          (ex_mem_pc),
        .alu_result_out  (ex_mem_alu_result),
        .store_data_out  (ex_mem_store_data),

        .rd_out          (ex_mem_rd),

        .opcode_out      (ex_mem_opcode),
        .funct3_out      (ex_mem_funct3),

        .valid_out       (ex_mem_valid),

        // -----------------------------------------------------
        // MEM control outputs
        // -----------------------------------------------------

        .mem_read_out    (ex_mem_mem_read),
        .mem_write_out   (ex_mem_mem_write),

        // -----------------------------------------------------
        // WB control outputs
        // -----------------------------------------------------

        .reg_write_out   (ex_mem_reg_write),
        .wb_sel_out      (ex_mem_wb_sel)
    );

endmodule
