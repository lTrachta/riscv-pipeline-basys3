`timescale 1ns / 1ps

module pipeline_core (
    input logic clk,
    input logic reset
);

    // =========================================================
    // OPCODES NECESARIOS PARA CONTROL TEMPORAL DE EX
    //
    // Esto NO reemplaza la futura unidad de control central.
    // Solo permite integrar el datapath.
    // =========================================================

    localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU  = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;


    // =========================================================
    // CONTROL TEMPORAL DEL PIPELINE
    //
    // Primera integración:
    // - todas las etapas avanzan;
    // - no hay stalls;
    // - no hay flushes;
    // - no hay redirects.
    // =========================================================

    logic if_enable;
    logic id_enable;
    logic ex_enable;
    logic mem_enable;

    logic flush_if_id;
    logic flush_id_ex;
    logic flush_ex_mem;
    logic flush_mem_wb;

    logic        redirect_valid;
    logic [31:0] redirect_target;


    assign if_enable     = 1'b1;
    assign id_enable     = 1'b1;
    assign ex_enable     = 1'b1;
    assign mem_enable    = 1'b1;

    assign flush_if_id   = 1'b0;
    assign flush_id_ex   = 1'b0;
    assign flush_ex_mem  = 1'b0;
    assign flush_mem_wb  = 1'b0;

    assign redirect_valid  = 1'b0;
    assign redirect_target = 32'd0;


    // =========================================================
    // IF / ID
    // =========================================================

    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;


    if_stage if_stage_inst (
        .clk                (clk),
        .reset              (reset),
        .if_enable          (if_enable),

        .redirect_valid     (redirect_valid),
        .redirect_pc        (redirect_target),

        .flush_if_id        (flush_if_id),

        .if_id_pc           (if_id_pc),
        .if_id_instruction  (if_id_instruction),
        .if_id_valid        (if_id_valid)
    );


    // =========================================================
    // ID / EX
    // =========================================================

    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;
    logic [31:0] id_ex_immediate;

    logic [4:0]  id_ex_rs1;
    logic [4:0]  id_ex_rs2;
    logic [4:0]  id_ex_rd;

    logic [6:0]  id_ex_opcode;
    logic [2:0]  id_ex_funct3;
    logic [6:0]  id_ex_funct7;

    logic        id_ex_valid;


    // =========================================================
    // WB -> REGISTER FILE
    //
    // Estas señales salen de WB y vuelven al Register File
    // que se encuentra dentro de id_stage.
    // =========================================================

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;


    id_stage id_stage_inst (
        .clk                 (clk),
        .reset               (reset),
        .id_enable           (id_enable),
        .flush_id_ex         (flush_id_ex),

        .if_id_pc            (if_id_pc),
        .if_id_instruction   (if_id_instruction),
        .if_id_valid         (if_id_valid),

        .wb_write_enable     (wb_write_enable),
        .wb_write_register   (wb_write_register),
        .wb_write_data       (wb_write_data),

        .id_ex_pc            (id_ex_pc),
        .id_ex_read_data1    (id_ex_read_data1),
        .id_ex_read_data2    (id_ex_read_data2),
        .id_ex_immediate     (id_ex_immediate),

        .id_ex_rs1           (id_ex_rs1),
        .id_ex_rs2           (id_ex_rs2),
        .id_ex_rd            (id_ex_rd),

        .id_ex_opcode        (id_ex_opcode),
        .id_ex_funct3        (id_ex_funct3),
        .id_ex_funct7        (id_ex_funct7),

        .id_ex_valid         (id_ex_valid)
    );


    // =========================================================
    // CONTROL TEMPORAL DE OPERANDOS DE EX
    //
    // IMPORTANTE:
    //
    // Se utiliza id_ex_opcode, NO if_id_instruction.
    //
    // Por lo tanto estas decisiones pertenecen a la instrucción
    // que está realmente en EX.
    //
    // Más adelante serán reemplazadas por señales generadas en ID
    // y transportadas por los registros del pipeline.
    // =========================================================

    logic alu_src_a;
    logic alu_src_b;


    always_comb begin

        // Valores por defecto:
        // operand A = rs1
        // operand B = rs2

        alu_src_a = 1'b0;
        alu_src_b = 1'b0;

        case (id_ex_opcode)

            // R-type:
            //
            // A = rs1
            // B = rs2

            OPCODE_R: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b0;
            end


            // I-type ALU:
            //
            // A = rs1
            // B = immediate

            OPCODE_I_ALU: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b1;
            end


            // Loads:
            //
            // address = rs1 + immediate

            OPCODE_LOAD: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b1;
            end


            // Stores:
            //
            // address = rs1 + immediate

            OPCODE_STORE: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b1;
            end


            // Branch:
            //
            // El ALU control actual utiliza SUB para comparación.
            //
            // A = rs1
            // B = rs2
            //
            // Resolución completa de branch queda diferida.

            OPCODE_BRANCH: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b0;
            end


            // LUI:
            //
            // ALU_PASS_B ignora A.
            // B = immediate.

            OPCODE_LUI: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b1;
            end


            // JAL:
            //
            // target preliminar = PC + immediate.
            //
            // Redirect completo queda diferido.

            OPCODE_JAL: begin
                alu_src_a = 1'b1;
                alu_src_b = 1'b1;
            end


            // JALR:
            //
            // target preliminar = rs1 + immediate.
            //
            // Ajuste del bit 0 y redirect quedan diferidos.

            OPCODE_JALR: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b1;
            end


            default: begin
                alu_src_a = 1'b0;
                alu_src_b = 1'b0;
            end

        endcase

    end


    // =========================================================
    // EX / MEM
    // =========================================================

    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;

    logic [4:0]  ex_mem_rd;
    logic [6:0]  ex_mem_opcode;
    logic [2:0]  ex_mem_funct3;

    logic        ex_mem_valid;


    ex_stage ex_stage_inst (
        .clk                 (clk),
        .reset               (reset),
        .ex_enable           (ex_enable),
        .flush_ex_mem        (flush_ex_mem),

        .alu_src_a           (alu_src_a),
        .alu_src_b           (alu_src_b),

        .id_ex_pc            (id_ex_pc),
        .id_ex_read_data1    (id_ex_read_data1),
        .id_ex_read_data2    (id_ex_read_data2),
        .id_ex_immediate     (id_ex_immediate),

        .id_ex_rd            (id_ex_rd),
        .id_ex_opcode        (id_ex_opcode),
        .id_ex_funct3        (id_ex_funct3),
        .id_ex_funct7        (id_ex_funct7),
        .id_ex_valid         (id_ex_valid),

        .ex_mem_pc           (ex_mem_pc),
        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_store_data   (ex_mem_store_data),
        .ex_mem_rd           (ex_mem_rd),
        .ex_mem_opcode       (ex_mem_opcode),
        .ex_mem_funct3       (ex_mem_funct3),
        .ex_mem_valid        (ex_mem_valid)
    );


    // =========================================================
    // MEM / WB
    // =========================================================

    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;

    logic [4:0]  mem_wb_rd;
    logic [6:0]  mem_wb_opcode;

    logic        mem_wb_valid;


    mem_stage mem_stage_inst (
        .clk                 (clk),
        .reset               (reset),
        .mem_enable          (mem_enable),
        .flush_mem_wb        (flush_mem_wb),

        .ex_mem_pc           (ex_mem_pc),
        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_store_data   (ex_mem_store_data),
        .ex_mem_rd           (ex_mem_rd),
        .ex_mem_opcode       (ex_mem_opcode),
        .ex_mem_funct3       (ex_mem_funct3),
        .ex_mem_valid        (ex_mem_valid),

        .mem_wb_pc           (mem_wb_pc),
        .mem_wb_alu_result   (mem_wb_alu_result),
        .mem_wb_load_data    (mem_wb_load_data),
        .mem_wb_rd           (mem_wb_rd),
        .mem_wb_opcode       (mem_wb_opcode),
        .mem_wb_valid        (mem_wb_valid)
    );


    // =========================================================
    // WRITE BACK
    // =========================================================

    wb_stage wb_stage_inst (
        .mem_wb_pc             (mem_wb_pc),
        .mem_wb_alu_result     (mem_wb_alu_result),
        .mem_wb_load_data      (mem_wb_load_data),
        .mem_wb_rd             (mem_wb_rd),
        .mem_wb_opcode         (mem_wb_opcode),
        .mem_wb_valid          (mem_wb_valid),

        .wb_write_enable       (wb_write_enable),
        .wb_write_register     (wb_write_register),
        .wb_write_data         (wb_write_data)
    );

endmodule
