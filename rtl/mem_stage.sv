`timescale 1ns / 1ps

module mem_stage #(
    parameter integer DATA_MEM_DEPTH = 256
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        mem_enable,
    input  logic        flush_mem_wb,

    // ---------------------------------------------------------
    // Entrada desde EX/MEM
    // ---------------------------------------------------------

    input  logic [31:0] ex_mem_pc,
    input  logic [31:0] ex_mem_alu_result,
    input  logic [31:0] ex_mem_store_data,
    input  logic [4:0]  ex_mem_rd,
    input  logic [6:0]  ex_mem_opcode,
    input  logic [2:0]  ex_mem_funct3,
    input  logic        ex_mem_valid,

    // ---------------------------------------------------------
    // Salida hacia MEM/WB
    // ---------------------------------------------------------

    output logic [31:0] mem_wb_pc,
    output logic [31:0] mem_wb_alu_result,
    output logic [31:0] mem_wb_load_data,
    output logic [4:0]  mem_wb_rd,
    output logic [6:0]  mem_wb_opcode,
    output logic        mem_wb_valid
);

    // ---------------------------------------------------------
    // Opcodes utilizados en MEM
    // ---------------------------------------------------------

    localparam logic [6:0] OPCODE_LOAD  = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE = 7'b0100011;


    // ---------------------------------------------------------
    // Clasificación de instrucción
    // ---------------------------------------------------------

    logic is_load;
    logic is_store;

    assign is_load  = (ex_mem_opcode == OPCODE_LOAD);
    assign is_store = (ex_mem_opcode == OPCODE_STORE);


    // ---------------------------------------------------------
    // Validez de funct3
    //
    // LOAD:
    //   000 -> lb
    //   001 -> lh
    //   010 -> lw
    //   100 -> lbu
    //   101 -> lhu
    //
    // STORE:
    //   000 -> sb
    //   001 -> sh
    //   010 -> sw
    // ---------------------------------------------------------

    logic load_funct3_valid;
    logic store_funct3_valid;

    always_comb begin

        case (ex_mem_funct3)

            3'b000,
            3'b001,
            3'b010,
            3'b100,
            3'b101:
                load_funct3_valid = 1'b1;

            default:
                load_funct3_valid = 1'b0;

        endcase

    end


    always_comb begin

        case (ex_mem_funct3)

            3'b000,
            3'b001,
            3'b010:
                store_funct3_valid = 1'b1;

            default:
                store_funct3_valid = 1'b0;

        endcase

    end


    // =========================================================
    // STORE UNIT
    // =========================================================

    logic [31:0] store_write_data;
    logic [3:0]  store_byte_enable;
    logic        store_misaligned;


    store_unit store_unit_inst (
        .funct3         (ex_mem_funct3),
        .address_offset (ex_mem_alu_result[1:0]),
        .store_data     (ex_mem_store_data),

        .write_data     (store_write_data),
        .byte_enable    (store_byte_enable),
        .misaligned     (store_misaligned)
    );


    // =========================================================
    // HABILITACIÓN REAL DE ESCRITURA EN DMEM
    //
    // Un store solamente puede modificar memoria cuando:
    //
    // - la instrucción es válida;
    // - realmente es STORE;
    // - MEM está habilitado;
    // - no estamos en reset;
    // - no estamos haciendo flush;
    // - funct3 es soportado;
    // - el acceso está alineado.
    // =========================================================

    logic memory_write_enable;

    assign memory_write_enable =
        ex_mem_valid          &&
        is_store              &&
        mem_enable            &&
        !reset                &&
        !flush_mem_wb         &&
        store_funct3_valid    &&
        !store_misaligned;


    // =========================================================
    // DATA MEMORY
    // =========================================================

    logic [31:0] memory_read_data;


    data_memory #(
        .DEPTH(DATA_MEM_DEPTH)
    ) data_memory_inst (
        .clk          (clk),

        .address      (ex_mem_alu_result),

        .write_data   (store_write_data),
        .write_enable (memory_write_enable),
        .byte_enable  (store_byte_enable),

        .read_data    (memory_read_data)
    );


    // =========================================================
    // LOAD UNIT
    // =========================================================

    logic [31:0] load_data_formatted;
    logic        load_misaligned;


    load_unit load_unit_inst (
        .funct3         (ex_mem_funct3),
        .address_offset (ex_mem_alu_result[1:0]),
        .read_data      (memory_read_data),

        .load_data      (load_data_formatted),
        .misaligned     (load_misaligned)
    );


    // =========================================================
    // DATO DE LOAD HACIA MEM/WB
    //
    // Para instrucciones que no son LOAD, dejamos este campo
    // en cero porque no tiene significado.
    // =========================================================

    logic [31:0] mem_wb_load_data_in;


    always_comb begin

        if (
            is_load              &&
            load_funct3_valid    &&
            !load_misaligned
        )
            mem_wb_load_data_in = load_data_formatted;
        else
            mem_wb_load_data_in = 32'd0;

    end


    // =========================================================
    // VALID HACIA MEM/WB
    //
    // Una instrucción normal pasa su valid.
    //
    // Un load/store no soportado o desalineado se convierte
    // en burbuja.
    // =========================================================

    logic mem_wb_valid_in;


    always_comb begin

        mem_wb_valid_in = ex_mem_valid;

        if (is_load) begin

            mem_wb_valid_in =
                ex_mem_valid       &&
                load_funct3_valid  &&
                !load_misaligned;

        end
        else if (is_store) begin

            mem_wb_valid_in =
                ex_mem_valid        &&
                store_funct3_valid  &&
                !store_misaligned;

        end

    end


    // =========================================================
    // MEM/WB PIPELINE REGISTER
    // =========================================================

    mem_wb_register mem_wb_reg (
        .clk            (clk),
        .reset          (reset),
        .enable         (mem_enable),
        .flush          (flush_mem_wb),

        .pc_in          (ex_mem_pc),
        .alu_result_in  (ex_mem_alu_result),
        .load_data_in   (mem_wb_load_data_in),
        .rd_in          (ex_mem_rd),
        .opcode_in      (ex_mem_opcode),
        .valid_in       (mem_wb_valid_in),

        .pc_out         (mem_wb_pc),
        .alu_result_out (mem_wb_alu_result),
        .load_data_out  (mem_wb_load_data),
        .rd_out         (mem_wb_rd),
        .opcode_out     (mem_wb_opcode),
        .valid_out      (mem_wb_valid)
    );

endmodule
