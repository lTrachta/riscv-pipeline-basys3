`timescale 1ns / 1ps

module data_memory #(
    parameter integer DEPTH = 256
) (
    input  logic        clk,

    input  logic [31:0] address,

    input  logic [31:0] write_data,
    input  logic        write_enable,
    input  logic [3:0]  byte_enable,

    output logic [31:0] read_data
);

    // Cantidad de bits necesarios para indexar DEPTH palabras.
    localparam integer INDEX_WIDTH =
        (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    // Cada palabra contiene 4 bytes.
    localparam logic [31:0] MEMORY_SIZE_BYTES = DEPTH * 4;

    // Memoria organizada como palabras de 32 bits.
    logic [31:0] memory [0:DEPTH-1];

    logic [INDEX_WIDTH-1:0] word_index;
    logic                   address_in_range;


    // ---------------------------------------------------------
    // Conversión de dirección en bytes a índice de palabra.
    //
    // Para DEPTH = 256:
    //   address[9:2] selecciona una de las 256 palabras.
    //
    // address[1:0] NO se utiliza dentro de este módulo.
    // Esos bits serán utilizados por la lógica de load/store.
    // ---------------------------------------------------------

    assign word_index = address[INDEX_WIDTH+1:2];


    // ---------------------------------------------------------
    // Verificación de rango.
    //
    // DEPTH = 256 -> 1024 bytes:
    // direcciones válidas: 0 ... 1023
    // ---------------------------------------------------------

    assign address_in_range = (address < MEMORY_SIZE_BYTES);


    // ---------------------------------------------------------
    // Lectura combinacional.
    //
    // La memoria siempre devuelve una palabra completa.
    // La selección de byte/halfword se realizará fuera de DMEM.
    // ---------------------------------------------------------

    always_comb begin
        if (address_in_range)
            read_data = memory[word_index];
        else
            read_data = 32'd0;
    end


    // ---------------------------------------------------------
    // Escritura secuencial.
    //
    // Cada bit de byte_enable controla un byte independiente.
    // ---------------------------------------------------------

    always_ff @(posedge clk) begin

        if (write_enable && address_in_range) begin

            if (byte_enable[0])
                memory[word_index][7:0] <= write_data[7:0];

            if (byte_enable[1])
                memory[word_index][15:8] <= write_data[15:8];

            if (byte_enable[2])
                memory[word_index][23:16] <= write_data[23:16];

            if (byte_enable[3])
                memory[word_index][31:24] <= write_data[31:24];

        end

    end

endmodule
