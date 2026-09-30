`timescale 1ns/1ps

module if_stage #(
    parameter int IMEM_DEPTH = 256
) (
    input  logic        clk,
    input  logic        reset,

    input  logic        if_enable,

    input  logic        redirect_valid,
    input  logic [31:0] redirect_pc,

    input  logic        flush_if_id,

    output logic [31:0] pc_current,

    output logic [31:0] if_id_pc,
    output logic [31:0] if_id_instruction,
    output logic        if_id_valid
);

    logic [31:0] pc_plus_4;
    logic [31:0] next_pc;
    logic [31:0] instruction;

    logic pc_enable;

    // Camino secuencial normal.
    always_comb begin
        pc_plus_4 = pc_current + 32'd4;
    end

    // Selección del próximo PC.
    always_comb begin
        if (redirect_valid)
            next_pc = redirect_pc;
        else
            next_pc = pc_plus_4;
    end

    // Una redirección tiene prioridad sobre un stall normal.
    always_comb begin
        pc_enable = if_enable | redirect_valid;
    end

    program_counter pc_reg (
        .clk        (clk),
        .reset      (reset),
        .enable     (pc_enable),
        .next_pc    (next_pc),
        .pc_current (pc_current)
    );

    instruction_memory #(
        .DEPTH(IMEM_DEPTH)
    ) imem (
        .address     (pc_current),
        .instruction (instruction)
    );

    if_id_register if_id_reg (
        .clk             (clk),
        .reset           (reset),
        .enable          (if_enable),
        .flush           (flush_if_id),
        .pc_in           (pc_current),
        .instruction_in  (instruction),
        .valid_in        (1'b1),
        .pc_out          (if_id_pc),
        .instruction_out (if_id_instruction),
        .valid_out       (if_id_valid)
    );

endmodule
