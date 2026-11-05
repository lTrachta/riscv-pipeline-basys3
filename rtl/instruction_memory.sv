`timescale 1ns / 1ps

module instruction_memory #(
    parameter integer DEPTH = 256
) (
    input  logic        clk,

    // =========================================================
    // PUERTO DE LECTURA DEL PROCESADOR
    // =========================================================

    input  logic [31:0] address,

    output logic [31:0] instruction,


    // =========================================================
    // PUERTO DE PROGRAMACIÓN
    //
    // Será utilizado por Program Loader.
    //
    // La memoria NO se borra con reset.
    // =========================================================

    input  logic        program_write_enable,
    input  logic [31:0] program_write_address,
    input  logic [31:0] program_write_data
);


    localparam integer INDEX_WIDTH =
        (DEPTH <= 1) ? 1 : $clog2(DEPTH);


    localparam logic [31:0] MEMORY_SIZE_BYTES =
        DEPTH * 4;


    logic [31:0] memory [0:DEPTH-1];


    logic [INDEX_WIDTH-1:0] read_word_index;
    logic [INDEX_WIDTH-1:0] write_word_index;

    logic read_address_valid;
    logic write_address_valid;


    // =========================================================
    // ÍNDICES
    // =========================================================

    assign read_word_index =
        address[INDEX_WIDTH+1:2];


    assign write_word_index =
        program_write_address[INDEX_WIDTH+1:2];


    // =========================================================
    // VALIDACIÓN DE DIRECCIONES
    // =========================================================

    assign read_address_valid =
        address < MEMORY_SIZE_BYTES;


    assign write_address_valid =
        (program_write_address < MEMORY_SIZE_BYTES) &&
        (program_write_address[1:0] == 2'b00);


    // =========================================================
    // LECTURA COMBINACIONAL
    // =========================================================

    always_comb begin

        if (read_address_valid)
            instruction = memory[read_word_index];
        else
            instruction = 32'd0;

    end


    // =========================================================
    // ESCRITURA SÍNCRONA
    //
    // No existe reset de memoria.
    //
    // Esto permite:
    //
    // 1. cargar un programa;
    // 2. resetear el procesador;
    // 3. conservar el programa;
    // 4. ejecutarlo.
    // =========================================================

    always_ff @(posedge clk) begin

        if (
            program_write_enable &&
            write_address_valid
        ) begin

            memory[write_word_index] <=
                program_write_data;

        end

    end

endmodule
