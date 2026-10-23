`timescale 1ns / 1ps

module mem_stage #(
    parameter integer DATA_MEM_DEPTH = 256
) (
    input  logic        clk,
    input  logic        reset,

    input  logic        mem_enable,
    input  logic        flush_mem_wb,

    // =========================================================
    // DATAPATH DESDE EX/MEM
    // =========================================================

    input  logic [31:0] ex_mem_pc,
    input  logic [31:0] ex_mem_alu_result,
    input  logic [31:0] ex_mem_store_data,

    input  logic [4:0]  ex_mem_rd,

    // Opcode se conserva temporalmente.
    input  logic [6:0]  ex_mem_opcode,

    // funct3 sigue siendo necesario para distinguir:
    //
    // LOAD:
    // lb/lh/lw/lbu/lhu
    //
    // STORE:
    // sb/sh/sw
    input  logic [2:0]  ex_mem_funct3,

    input  logic        ex_mem_valid,

    // =========================================================
    // CONTROL MEM DESDE EX/MEM
    // =========================================================

    input  logic        ex_mem_mem_read,
    input  logic        ex_mem_mem_write,

    // =========================================================
    // CONTROL WB QUE DEBE CONTINUAR
    // =========================================================

    input  logic        ex_mem_reg_write,
    input  logic [1:0]  ex_mem_wb_sel,

    // =========================================================
    // DATAPATH HACIA MEM/WB
    // =========================================================

    output logic [31:0] mem_wb_pc,
    output logic [31:0] mem_wb_alu_result,
    output logic [31:0] mem_wb_load_data,

    output logic [4:0]  mem_wb_rd,
    output logic [6:0]  mem_wb_opcode,

    output logic        mem_wb_valid,

    // =========================================================
    // CONTROL WB HACIA MEM/WB
    // =========================================================

    output logic        mem_wb_reg_write,
    output logic [1:0]  mem_wb_wb_sel
);


    // =========================================================
    // CLASIFICACIÓN DE LA OPERACIÓN DE MEMORIA
    //
    // Antes se reconstruía mirando opcode.
    //
    // Ahora la decisión ya llegó desde Control Unit:
    //
    // mem_read  = LOAD
    // mem_write = STORE
    // =========================================================

    logic is_load;
    logic is_store;

    assign is_load  = ex_mem_mem_read;
    assign is_store = ex_mem_mem_write;


    // =========================================================
    // VALIDEZ DE FUNCT3
    //
    // Aunque Control Unit ya valida estas combinaciones,
    // mantenemos estas comprobaciones como defensa local y
    // para detectar accesos no soportados.
    // =========================================================

    logic load_funct3_valid;
    logic store_funct3_valid;


    always_comb begin

        case (ex_mem_funct3)

            3'b000,   // lb
            3'b001,   // lh
            3'b010,   // lw
            3'b100,   // lbu
            3'b101:   // lhu
                load_funct3_valid = 1'b1;

            default:
                load_funct3_valid = 1'b0;

        endcase

    end


    always_comb begin

        case (ex_mem_funct3)

            3'b000,   // sb
            3'b001,   // sh
            3'b010:   // sw
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
    // WRITE ENABLE REAL DE DMEM
    //
    // Ya NO depende de opcode.
    //
    // ex_mem_mem_write llegó desde Control Unit a través de:
    //
    // ID/EX -> EX -> EX/MEM
    // =========================================================

    logic memory_write_enable;


    assign memory_write_enable =
        ex_mem_valid          &&
        ex_mem_mem_write      &&
        !ex_mem_mem_read      &&
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
    // Solamente tiene significado cuando MemRead = 1.
    // =========================================================

    logic [31:0] mem_wb_load_data_in;


    always_comb begin

        if (
            ex_mem_mem_read     &&
            !ex_mem_mem_write   &&
            load_funct3_valid   &&
            !load_misaligned
        )
            mem_wb_load_data_in = load_data_formatted;

        else
            mem_wb_load_data_in = 32'd0;

    end


    // =========================================================
    // VALID HACIA MEM/WB
    //
    // Instrucciones sin acceso a memoria:
    //     valid pasa normalmente.
    //
    // LOAD/STORE:
    //     además exigimos funct3 válido y alineación correcta.
    //
    // Si por algún error MemRead y MemWrite llegan activos a la
    // vez, neutralizamos la instrucción.
    // =========================================================

    logic mem_wb_valid_in;


    always_comb begin

        mem_wb_valid_in = ex_mem_valid;

        if (ex_mem_mem_read && ex_mem_mem_write) begin

            mem_wb_valid_in = 1'b0;

        end
        else if (is_load) begin

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
    //
    // MEM ya consumió:
    //
    // - mem_read
    // - mem_write
    //
    // Por lo tanto solamente continúan:
    //
    // - reg_write
    // - wb_sel
    // =========================================================

    mem_wb_register mem_wb_reg (
        .clk            (clk),
        .reset          (reset),
        .enable         (mem_enable),
        .flush          (flush_mem_wb),

        // -----------------------------------------------------
        // Datapath
        // -----------------------------------------------------

        .pc_in          (ex_mem_pc),
        .alu_result_in  (ex_mem_alu_result),
        .load_data_in   (mem_wb_load_data_in),

        .rd_in          (ex_mem_rd),
        .opcode_in      (ex_mem_opcode),

        .valid_in       (mem_wb_valid_in),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .reg_write_in   (ex_mem_reg_write),
        .wb_sel_in      (ex_mem_wb_sel),

        // -----------------------------------------------------
        // Datapath outputs
        // -----------------------------------------------------

        .pc_out         (mem_wb_pc),
        .alu_result_out (mem_wb_alu_result),
        .load_data_out  (mem_wb_load_data),

        .rd_out         (mem_wb_rd),
        .opcode_out     (mem_wb_opcode),

        .valid_out      (mem_wb_valid),

        // -----------------------------------------------------
        // WB control outputs
        // -----------------------------------------------------

        .reg_write_out  (mem_wb_reg_write),
        .wb_sel_out     (mem_wb_wb_sel)
    );

endmodule
