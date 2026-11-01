`timescale 1ns / 1ps

module store_data_forwarding_unit (

    // Store actualmente en MEM.
    input  logic        ex_mem_valid,
    input  logic        ex_mem_mem_write,
    input  logic [4:0]  ex_mem_rs2,
    input  logic [31:0] ex_mem_store_data,

    // Instrucción actualmente en WB.
    input  logic        wb_write_enable,
    input  logic [4:0]  wb_write_register,
    input  logic [31:0] wb_write_data,

    // Resultado.
    output logic        forward_store_data,
    output logic [31:0] store_data_out
);


    always_comb begin

        // Comportamiento normal:
        // usar el dato que vino desde EX/MEM.
        forward_store_data = 1'b0;
        store_data_out      = ex_mem_store_data;


        // WB -> MEM forwarding.
        //
        // Caso principal:
        //
        // lw x5,0(x1)
        // sw x5,0(x2)
        //
        // Cuando sw está en MEM, lw está en WB.
        if (
            ex_mem_valid &&
            ex_mem_mem_write &&
            wb_write_enable &&
            (wb_write_register != 5'd0) &&
            (wb_write_register == ex_mem_rs2)
        ) begin

            forward_store_data = 1'b1;
            store_data_out      = wb_write_data;

        end

    end

endmodule
