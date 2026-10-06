`timescale 1ns / 1ps

module ex_stage (
    input  logic        clk,
    input  logic        reset,
    input  logic        ex_enable,
    input  logic        flush_ex_mem,

    // Control de selección de operandos
    input  logic        alu_src_a,
    input  logic        alu_src_b,

    // Datos provenientes de ID/EX
    input  logic [31:0] id_ex_pc,
    input  logic [31:0] id_ex_read_data1,
    input  logic [31:0] id_ex_read_data2,
    input  logic [31:0] id_ex_immediate,
    input  logic [4:0]  id_ex_rd,
    input  logic [6:0]  id_ex_opcode,
    input  logic [2:0]  id_ex_funct3,
    input  logic [6:0]  id_ex_funct7,
    input  logic        id_ex_valid,

    // Datos almacenados en EX/MEM
    output logic [31:0] ex_mem_pc,
    output logic [31:0] ex_mem_alu_result,
    output logic [31:0] ex_mem_store_data,
    output logic [4:0]  ex_mem_rd,
    output logic [6:0]  ex_mem_opcode,
    output logic [2:0]  ex_mem_funct3,
    output logic        ex_mem_valid
);

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [3:0]  alu_operation;
    logic [31:0] alu_result;
    logic        alu_zero;


    // ============================================================
    // SELECCION DE OPERANDO A
    //
    // 0 -> read_data1
    // 1 -> PC
    // ============================================================

    always_comb begin
        if (alu_src_a)
            operand_a = id_ex_pc;
        else
            operand_a = id_ex_read_data1;
    end


    // ============================================================
    // SELECCION DE OPERANDO B
    //
    // 0 -> read_data2
    // 1 -> immediate
    // ============================================================

    always_comb begin
        if (alu_src_b)
            operand_b = id_ex_immediate;
        else
            operand_b = id_ex_read_data2;
    end


    // ============================================================
    // ALU CONTROL
    // ============================================================

    alu_control alu_control_unit (
        .opcode        (id_ex_opcode),
        .funct3        (id_ex_funct3),
        .funct7        (id_ex_funct7),
        .alu_operation (alu_operation)
    );


    // ============================================================
    // ALU
    // ============================================================

    alu alu_unit (
        .operand_a     (operand_a),
        .operand_b     (operand_b),
        .alu_operation (alu_operation),
        .result        (alu_result),
        .zero          (alu_zero)
    );


    // ============================================================
    // REGISTRO EX/MEM
    // ============================================================

    ex_mem_register ex_mem_reg (
        .clk             (clk),
        .reset           (reset),
        .enable          (ex_enable),
        .flush           (flush_ex_mem),

        .pc_in           (id_ex_pc),
        .alu_result_in   (alu_result),
        .store_data_in   (id_ex_read_data2),
        .rd_in           (id_ex_rd),
        .opcode_in       (id_ex_opcode),
        .funct3_in       (id_ex_funct3),
        .valid_in        (id_ex_valid),

        .pc_out          (ex_mem_pc),
        .alu_result_out  (ex_mem_alu_result),
        .store_data_out  (ex_mem_store_data),
        .rd_out          (ex_mem_rd),
        .opcode_out      (ex_mem_opcode),
        .funct3_out      (ex_mem_funct3),
        .valid_out       (ex_mem_valid)
    );

endmodule
