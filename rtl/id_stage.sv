`timescale 1ns/1ps

module id_stage (
    input  logic        clk,
    input  logic        reset,

    // Control de ID/EX.
    input  logic        id_enable,
    input  logic        flush_id_ex,

    // Entradas provenientes de IF/ID.
    input  logic [31:0] if_id_pc,
    input  logic [31:0] if_id_instruction,
    input  logic        if_id_valid,

    // Entradas provenientes de WB.
    input  logic        wb_write_enable,
    input  logic [4:0]  wb_write_register,
    input  logic [31:0] wb_write_data,

    // =========================================================
    // DATAPATH HACIA EX
    // =========================================================

    output logic [31:0] id_ex_pc,
    output logic [31:0] id_ex_read_data1,
    output logic [31:0] id_ex_read_data2,
    output logic [31:0] id_ex_immediate,

    output logic [4:0]  id_ex_rs1,
    output logic [4:0]  id_ex_rs2,
    output logic [4:0]  id_ex_rd,

    output logic [6:0]  id_ex_opcode,
    output logic [2:0]  id_ex_funct3,
    output logic [6:0]  id_ex_funct7,

    output logic        id_ex_valid,

    // =========================================================
    // CONTROL EX
    // =========================================================

    output logic        id_ex_alu_src_a,
    output logic        id_ex_alu_src_b,
    output logic [2:0]  id_ex_alu_op,

    output logic        id_ex_branch,
    output logic [1:0]  id_ex_jump_type,

    // =========================================================
    // CONTROL MEM
    // =========================================================

    output logic        id_ex_mem_read,
    output logic        id_ex_mem_write,

    // =========================================================
    // CONTROL WB
    // =========================================================

    output logic        id_ex_reg_write,
    output logic [1:0]  id_ex_wb_sel
);


    // =========================================================
    // CAMPOS DECODIFICADOS
    // =========================================================

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;


    // =========================================================
    // REGISTER FILE
    // =========================================================

    logic [31:0] read_data1;
    logic [31:0] read_data2;


    // =========================================================
    // IMMEDIATE GENERATOR
    // =========================================================

    logic [31:0] immediate;


    // =========================================================
    // CONTROL UNIT OUTPUTS
    //
    // Estas señales son generadas en ID.
    // Después serán capturadas junto con la instrucción
    // por el registro ID/EX.
    // =========================================================

    logic       control_alu_src_a;
    logic       control_alu_src_b;
    logic [2:0] control_alu_op;

    logic       control_branch;
    logic [1:0] control_jump_type;

    logic       control_mem_read;
    logic       control_mem_write;

    logic       control_reg_write;
    logic [1:0] control_wb_sel;

    logic       control_valid;


    // =========================================================
    // VALID HACIA ID/EX
    //
    // Una instrucción solamente continúa como válida si:
    //
    // 1. IF/ID contiene una instrucción válida.
    // 2. Control Unit reconoce su codificación.
    //
    // Una instrucción no soportada se transforma en burbuja.
    // =========================================================

    logic id_ex_valid_in;

    always_comb begin
        id_ex_valid_in = if_id_valid && control_valid;
    end


    // =========================================================
    // FIELD DECODER
    // =========================================================

    field_decoder decoder (
        .instruction (if_id_instruction),

        .opcode      (opcode),
        .rd          (rd),
        .funct3      (funct3),
        .rs1         (rs1),
        .rs2         (rs2),
        .funct7      (funct7)
    );


    // =========================================================
    // REGISTER FILE
    // =========================================================

    register_file registers (
        .clk            (clk),
        .reset          (reset),

        .read_register1 (rs1),
        .read_register2 (rs2),

        .read_data1     (read_data1),
        .read_data2     (read_data2),

        .write_enable   (wb_write_enable),
        .write_register (wb_write_register),
        .write_data     (wb_write_data)
    );


    // =========================================================
    // IMMEDIATE GENERATOR
    // =========================================================

    immediate_generator imm_gen (
        .instruction (if_id_instruction),
        .immediate   (immediate)
    );


    // =========================================================
    // CONTROL UNIT
    //
    // La instrucción se interpreta una sola vez en ID.
    //
    // A partir de opcode/funct3/funct7 se generan:
    //
    // - controles de EX;
    // - controles de MEM;
    // - controles de WB;
    // - control_valid.
    //
    // Estos controles acompañarán a la instrucción a través
    // del pipeline.
    // =========================================================

    control_unit control (
        .opcode        (opcode),
        .funct3        (funct3),
        .funct7        (funct7),

        .alu_src_a     (control_alu_src_a),
        .alu_src_b     (control_alu_src_b),
        .alu_op        (control_alu_op),

        .branch        (control_branch),
        .jump_type     (control_jump_type),

        .mem_read      (control_mem_read),
        .mem_write     (control_mem_write),

        .reg_write     (control_reg_write),
        .wb_sel        (control_wb_sel),

        .control_valid (control_valid)
    );


    // =========================================================
    // ID/EX PIPELINE REGISTER
    //
    // Captura simultáneamente:
    //
    // - datos;
    // - campos de instrucción;
    // - control EX;
    // - control MEM;
    // - control WB.
    //
    // Todo corresponde a la MISMA instrucción.
    // =========================================================

    id_ex_register id_ex_reg (
        .clk            (clk),
        .reset          (reset),
        .enable         (id_enable),
        .flush          (flush_id_ex),

        // -----------------------------------------------------
        // Datapath inputs
        // -----------------------------------------------------

        .pc_in          (if_id_pc),
        .read_data1_in  (read_data1),
        .read_data2_in  (read_data2),
        .immediate_in   (immediate),

        .rs1_in         (rs1),
        .rs2_in         (rs2),
        .rd_in          (rd),

        .opcode_in      (opcode),
        .funct3_in      (funct3),
        .funct7_in      (funct7),

        .valid_in       (id_ex_valid_in),

        // -----------------------------------------------------
        // EX control inputs
        // -----------------------------------------------------

        .alu_src_a_in   (control_alu_src_a),
        .alu_src_b_in   (control_alu_src_b),
        .alu_op_in      (control_alu_op),

        .branch_in      (control_branch),
        .jump_type_in   (control_jump_type),

        // -----------------------------------------------------
        // MEM control inputs
        // -----------------------------------------------------

        .mem_read_in    (control_mem_read),
        .mem_write_in   (control_mem_write),

        // -----------------------------------------------------
        // WB control inputs
        // -----------------------------------------------------

        .reg_write_in   (control_reg_write),
        .wb_sel_in      (control_wb_sel),

        // -----------------------------------------------------
        // Datapath outputs
        // -----------------------------------------------------

        .pc_out         (id_ex_pc),
        .read_data1_out (id_ex_read_data1),
        .read_data2_out (id_ex_read_data2),
        .immediate_out  (id_ex_immediate),

        .rs1_out        (id_ex_rs1),
        .rs2_out        (id_ex_rs2),
        .rd_out         (id_ex_rd),

        .opcode_out     (id_ex_opcode),
        .funct3_out     (id_ex_funct3),
        .funct7_out     (id_ex_funct7),

        .valid_out      (id_ex_valid),

        // -----------------------------------------------------
        // EX control outputs
        // -----------------------------------------------------

        .alu_src_a_out  (id_ex_alu_src_a),
        .alu_src_b_out  (id_ex_alu_src_b),
        .alu_op_out     (id_ex_alu_op),

        .branch_out     (id_ex_branch),
        .jump_type_out  (id_ex_jump_type),

        // -----------------------------------------------------
        // MEM control outputs
        // -----------------------------------------------------

        .mem_read_out   (id_ex_mem_read),
        .mem_write_out  (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control outputs
        // -----------------------------------------------------

        .reg_write_out  (id_ex_reg_write),
        .wb_sel_out     (id_ex_wb_sel)
    );

endmodule
