`timescale 1ns / 1ps

module pipeline_core (
    input logic clk,
    input logic reset
);

    // =========================================================
    // CONTROL GENERAL DEL PIPELINE
    //
    // Todavía:
    // - todas las etapas avanzan;
    // - no hay stalls automáticos;
    // - no hay redirects reales;
    // - no hay flushes por hazards de control.
    //
    // Estas funcionalidades se implementarán posteriormente.
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


    assign if_enable  = 1'b1;
    assign id_enable  = 1'b1;
    assign ex_enable  = 1'b1;
    assign mem_enable = 1'b1;

    assign flush_if_id  = 1'b0;
    assign flush_id_ex  = 1'b0;
    assign flush_ex_mem = 1'b0;
    assign flush_mem_wb = 1'b0;

    assign redirect_valid  = 1'b0;
    assign redirect_target = 32'd0;


    // =========================================================
    // IF / ID
    // =========================================================

    logic [31:0] if_pc_current;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;


    if_stage if_stage_inst (
        .clk               (clk),
        .reset             (reset),

        .if_enable         (if_enable),

        .redirect_valid    (redirect_valid),
        .redirect_pc       (redirect_target),

        .flush_if_id       (flush_if_id),

        .pc_current        (if_pc_current),

        .if_id_pc          (if_id_pc),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid)
    );


    // =========================================================
    // ID / EX DATAPATH
    // =========================================================

    logic [31:0] id_ex_pc;

    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;

    logic [31:0] id_ex_immediate;

    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;
    logic [4:0] id_ex_rd;

    logic [6:0] id_ex_opcode;
    logic [2:0] id_ex_funct3;
    logic [6:0] id_ex_funct7;

    logic id_ex_valid;


    // =========================================================
    // ID / EX CONTROL
    //
    // Generado por Control Unit en ID.
    //
    // ID/EX contiene:
    //
    // - control EX
    // - control MEM
    // - control WB
    // =========================================================

    // EX control
    logic       id_ex_alu_src_a;
    logic       id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;

    logic       id_ex_branch;
    logic [1:0] id_ex_jump_type;

    // MEM control
    logic id_ex_mem_read;
    logic id_ex_mem_write;

    // WB control
    logic       id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;


    // =========================================================
    // WB -> REGISTER FILE
    // =========================================================

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;


    // =========================================================
    // ID STAGE
    //
    // Control Unit se encuentra dentro de id_stage.
    //
    // La instrucción se decodifica una vez en ID y sus señales
    // de control quedan capturadas junto con los datos en ID/EX.
    // =========================================================

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

        // -----------------------------------------------------
        // Datapath
        // -----------------------------------------------------

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

        .id_ex_valid         (id_ex_valid),

        // -----------------------------------------------------
        // EX control
        // -----------------------------------------------------

        .id_ex_alu_src_a     (id_ex_alu_src_a),
        .id_ex_alu_src_b     (id_ex_alu_src_b),
        .id_ex_alu_op        (id_ex_alu_op),

        .id_ex_branch        (id_ex_branch),
        .id_ex_jump_type     (id_ex_jump_type),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .id_ex_mem_read      (id_ex_mem_read),
        .id_ex_mem_write     (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .id_ex_reg_write     (id_ex_reg_write),
        .id_ex_wb_sel        (id_ex_wb_sel)
    );


    // =========================================================
    // EX / MEM DATAPATH
    // =========================================================

    logic [31:0] ex_mem_pc;

    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;

    logic [4:0] ex_mem_rd;

    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;

    logic ex_mem_valid;


    // =========================================================
    // EX / MEM CONTROL
    //
    // EX ya consumió sus controles.
    //
    // Solamente continúan:
    //
    // MEM + WB
    // =========================================================

    logic ex_mem_mem_read;
    logic ex_mem_mem_write;

    logic       ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;


    // =========================================================
    // EX STAGE
    // =========================================================

    ex_stage ex_stage_inst (
        .clk                 (clk),
        .reset               (reset),

        .ex_enable           (ex_enable),
        .flush_ex_mem        (flush_ex_mem),

        // -----------------------------------------------------
        // EX control
        // -----------------------------------------------------

        .id_ex_alu_src_a     (id_ex_alu_src_a),
        .id_ex_alu_src_b     (id_ex_alu_src_b),
        .id_ex_alu_op        (id_ex_alu_op),

        .id_ex_branch        (id_ex_branch),
        .id_ex_jump_type     (id_ex_jump_type),

        // -----------------------------------------------------
        // MEM control que debe continuar
        // -----------------------------------------------------

        .id_ex_mem_read      (id_ex_mem_read),
        .id_ex_mem_write     (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control que debe continuar
        // -----------------------------------------------------

        .id_ex_reg_write     (id_ex_reg_write),
        .id_ex_wb_sel        (id_ex_wb_sel),

        // -----------------------------------------------------
        // Datapath ID/EX
        // -----------------------------------------------------

        .id_ex_pc            (id_ex_pc),

        .id_ex_read_data1    (id_ex_read_data1),
        .id_ex_read_data2    (id_ex_read_data2),

        .id_ex_immediate     (id_ex_immediate),

        .id_ex_rd            (id_ex_rd),

        .id_ex_opcode        (id_ex_opcode),
        .id_ex_funct3        (id_ex_funct3),
        .id_ex_funct7        (id_ex_funct7),

        .id_ex_valid         (id_ex_valid),

        // -----------------------------------------------------
        // Datapath EX/MEM
        // -----------------------------------------------------

        .ex_mem_pc           (ex_mem_pc),

        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_store_data   (ex_mem_store_data),

        .ex_mem_rd           (ex_mem_rd),

        .ex_mem_opcode       (ex_mem_opcode),
        .ex_mem_funct3       (ex_mem_funct3),

        .ex_mem_valid        (ex_mem_valid),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .ex_mem_mem_read     (ex_mem_mem_read),
        .ex_mem_mem_write    (ex_mem_mem_write),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .ex_mem_reg_write    (ex_mem_reg_write),
        .ex_mem_wb_sel       (ex_mem_wb_sel)
    );


    // =========================================================
    // MEM / WB DATAPATH
    // =========================================================

    logic [31:0] mem_wb_pc;

    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;

    logic [4:0] mem_wb_rd;

    logic [6:0] mem_wb_opcode;

    logic mem_wb_valid;


    // =========================================================
    // MEM / WB CONTROL
    //
    // MEM ya consumió MemRead/MemWrite.
    //
    // Solamente continúa control WB.
    // =========================================================

    logic       mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;


    // =========================================================
    // MEM STAGE
    // =========================================================

    mem_stage mem_stage_inst (
        .clk                 (clk),
        .reset               (reset),

        .mem_enable          (mem_enable),
        .flush_mem_wb        (flush_mem_wb),

        // -----------------------------------------------------
        // Datapath EX/MEM
        // -----------------------------------------------------

        .ex_mem_pc           (ex_mem_pc),

        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_store_data   (ex_mem_store_data),

        .ex_mem_rd           (ex_mem_rd),

        .ex_mem_opcode       (ex_mem_opcode),
        .ex_mem_funct3       (ex_mem_funct3),

        .ex_mem_valid        (ex_mem_valid),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .ex_mem_mem_read     (ex_mem_mem_read),
        .ex_mem_mem_write    (ex_mem_mem_write),

        // -----------------------------------------------------
        // WB control que debe continuar
        // -----------------------------------------------------

        .ex_mem_reg_write    (ex_mem_reg_write),
        .ex_mem_wb_sel       (ex_mem_wb_sel),

        // -----------------------------------------------------
        // Datapath MEM/WB
        // -----------------------------------------------------

        .mem_wb_pc           (mem_wb_pc),

        .mem_wb_alu_result   (mem_wb_alu_result),
        .mem_wb_load_data    (mem_wb_load_data),

        .mem_wb_rd           (mem_wb_rd),
        .mem_wb_opcode       (mem_wb_opcode),

        .mem_wb_valid        (mem_wb_valid),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .mem_wb_reg_write    (mem_wb_reg_write),
        .mem_wb_wb_sel       (mem_wb_wb_sel)
    );


    // =========================================================
    // WRITE BACK
    //
    // WB ya NO decodifica opcode.
    //
    // Consume exclusivamente:
    //
    // - RegWrite
    // - WBSel
    //
    // junto con valid y rd.
    // =========================================================

    wb_stage wb_stage_inst (
        .mem_wb_pc             (mem_wb_pc),

        .mem_wb_alu_result     (mem_wb_alu_result),
        .mem_wb_load_data      (mem_wb_load_data),

        .mem_wb_rd             (mem_wb_rd),

        // Temporal para debug/compatibilidad.
        .mem_wb_opcode         (mem_wb_opcode),

        .mem_wb_valid          (mem_wb_valid),

        .mem_wb_reg_write      (mem_wb_reg_write),
        .mem_wb_wb_sel         (mem_wb_wb_sel),

        .wb_write_enable       (wb_write_enable),
        .wb_write_register     (wb_write_register),
        .wb_write_data         (wb_write_data)
    );

endmodule
