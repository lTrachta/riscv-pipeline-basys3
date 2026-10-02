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

    // Salidas hacia EX.
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

    output logic        id_ex_valid
);

    // Campos extraídos de la instrucción.
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    // Datos leídos del banco de registros.
    logic [31:0] read_data1;
    logic [31:0] read_data2;

    // Inmediato reconstruido.
    logic [31:0] immediate;


    // Decoder de campos.
    field_decoder decoder (
        .instruction (if_id_instruction),

        .opcode      (opcode),
        .rd          (rd),
        .funct3      (funct3),
        .rs1         (rs1),
        .rs2         (rs2),
        .funct7      (funct7)
    );


    // Banco de registros.
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


    // Generador de inmediatos.
    immediate_generator imm_gen (
        .instruction (if_id_instruction),
        .immediate   (immediate)
    );


    // Registro de segmentación ID/EX.
    id_ex_register id_ex_reg (
        .clk            (clk),
        .reset          (reset),
        .enable         (id_enable),
        .flush          (flush_id_ex),

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

        .valid_in       (if_id_valid),

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

        .valid_out      (id_ex_valid)
    );

endmodule
