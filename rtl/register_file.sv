`timescale 1ns/1ps

module register_file (
    input  logic        clk,
    input  logic        reset,

    input  logic [4:0]  read_register1,
    input  logic [4:0]  read_register2,

    output logic [31:0] read_data1,
    output logic [31:0] read_data2,

    input  logic        write_enable,
    input  logic [4:0]  write_register,
    input  logic [31:0] write_data
);

    logic [31:0] registers [0:31];

    integer i;


    // =========================================================
    // LECTURA COMBINACIONAL + WB -> ID BYPASS
    //
    // Problema que resuelve:
    //
    // Una instrucción puede estar en WB escribiendo xN
    // mientras otra instrucción en ID intenta leer xN
    // durante el mismo ciclo.
    //
    // Como la escritura real del array ocurre en el posedge,
    // una lectura directa de registers[xN] podría observar
    // todavía el valor viejo.
    //
    // Si WB está escribiendo exactamente el registro que ID
    // intenta leer, entregamos write_data directamente.
    //
    // Esto implementa comportamiento "write-first" para
    // lecturas y escrituras coincidentes.
    // =========================================================

    always_comb begin

        // -----------------------------------------------------
        // READ PORT 1
        // -----------------------------------------------------

        if (read_register1 == 5'd0) begin

            read_data1 = 32'd0;

        end
        else if (
            !reset &&
            write_enable &&
            (write_register != 5'd0) &&
            (write_register == read_register1)
        ) begin

            read_data1 = write_data;

        end
        else begin

            read_data1 = registers[read_register1];

        end


        // -----------------------------------------------------
        // READ PORT 2
        // -----------------------------------------------------

        if (read_register2 == 5'd0) begin

            read_data2 = 32'd0;

        end
        else if (
            !reset &&
            write_enable &&
            (write_register != 5'd0) &&
            (write_register == read_register2)
        ) begin

            read_data2 = write_data;

        end
        else begin

            read_data2 = registers[read_register2];

        end

    end


    // =========================================================
    // ESCRITURA SECUENCIAL
    // =========================================================

    always_ff @(posedge clk) begin

        if (reset) begin

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;

        end
        else begin

            if (
                write_enable &&
                (write_register != 5'd0)
            ) begin

                registers[write_register] <= write_data;

            end

            // x0 siempre permanece en cero.
            registers[0] <= 32'd0;

        end

    end

endmodule
