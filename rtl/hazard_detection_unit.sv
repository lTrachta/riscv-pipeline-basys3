`timescale 1ns / 1ps

module hazard_detection_unit (
    // =========================================================
    // INSTRUCCIÓN ACTUAL EN ID
    // =========================================================

    input  logic [31:0] if_id_instruction,
    input  logic        if_id_valid,

    // =========================================================
    // INSTRUCCIÓN ACTUAL EN EX
    //
    // Nos interesa saber si es un load y cuál es su rd.
    // =========================================================

    input  logic        id_ex_valid,
    input  logic        id_ex_mem_read,
    input  logic [4:0]  id_ex_rd,

    // =========================================================
    // SALIDA
    // =========================================================

    output logic        stall
);


    // =========================================================
    // OPCODES
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
    // CAMPOS FÍSICOS DE IF/ID
    // =========================================================

    logic [6:0] if_id_opcode;

    logic [4:0] if_id_rs1;
    logic [4:0] if_id_rs2;


    assign if_id_opcode = if_id_instruction[6:0];

    assign if_id_rs1 = if_id_instruction[19:15];
    assign if_id_rs2 = if_id_instruction[24:20];


    // =========================================================
    // USO REAL DE REGISTROS EN EX
    //
    // No todos los formatos utilizan físicamente los campos
    // rs1 y rs2.
    //
    // Además hacemos una distinción importante:
    //
    // STORE:
    //
    // rs1 -> se necesita en EX para calcular la dirección.
    // rs2 -> se necesita recién en MEM para escribir el dato.
    //
    // Como en el Paso 14.4 implementaremos forwarding hacia
    // store-data en MEM, una dependencia exclusivamente sobre
    // rs2 de un store NO necesita stall.
    // =========================================================

    logic uses_rs1_ex;
    logic uses_rs2_ex;


    always_comb begin

        uses_rs1_ex = 1'b0;
        uses_rs2_ex = 1'b0;

        case (if_id_opcode)

            // -------------------------------------------------
            // R-Type
            //
            // rs1 OP rs2
            // -------------------------------------------------

            OPCODE_R: begin
                uses_rs1_ex = 1'b1;
                uses_rs2_ex = 1'b1;
            end


            // -------------------------------------------------
            // I-Type ALU
            //
            // rs1 OP immediate
            // -------------------------------------------------

            OPCODE_I_ALU: begin
                uses_rs1_ex = 1'b1;
                uses_rs2_ex = 1'b0;
            end


            // -------------------------------------------------
            // LOAD
            //
            // address = rs1 + immediate
            // -------------------------------------------------

            OPCODE_LOAD: begin
                uses_rs1_ex = 1'b1;
                uses_rs2_ex = 1'b0;
            end


            // -------------------------------------------------
            // STORE
            //
            // rs1 se necesita en EX para dirección.
            //
            // rs2 se necesita en MEM como dato.
            //
            // Por eso rs2 NO participa en la detección de
            // load-use que exige stall en EX.
            // -------------------------------------------------

            OPCODE_STORE: begin
                uses_rs1_ex = 1'b1;
                uses_rs2_ex = 1'b0;
            end


            // -------------------------------------------------
            // BRANCH
            //
            // compara rs1 contra rs2 en EX.
            // -------------------------------------------------

            OPCODE_BRANCH: begin
                uses_rs1_ex = 1'b1;
                uses_rs2_ex = 1'b1;
            end


            // -------------------------------------------------
            // LUI
            //
            // No utiliza registros fuente.
            // -------------------------------------------------

            OPCODE_LUI: begin
                uses_rs1_ex = 1'b0;
                uses_rs2_ex = 1'b0;
            end


            // -------------------------------------------------
            // JAL
            //
            // target = PC + immediate.
            // -------------------------------------------------

            OPCODE_JAL: begin
                uses_rs1_ex = 1'b0;
                uses_rs2_ex = 1'b0;
            end


            // -------------------------------------------------
            // JALR
            //
            // target = rs1 + immediate.
            // -------------------------------------------------

            OPCODE_JALR: begin
                uses_rs1_ex = 1'b1;
                uses_rs2_ex = 1'b0;
            end


            default: begin
                uses_rs1_ex = 1'b0;
                uses_rs2_ex = 1'b0;
            end

        endcase

    end


    // =========================================================
    // DETECCIÓN LOAD-USE
    //
    // Hay stall solamente cuando:
    //
    // 1. La instrucción de EX es válida.
    // 2. Es un load.
    // 3. Su rd no es x0.
    // 4. La instrucción de ID es válida.
    // 5. Necesita en EX ese mismo registro.
    // =========================================================

    always_comb begin

        stall = 1'b0;

        if (
            id_ex_valid &&
            id_ex_mem_read &&
            (id_ex_rd != 5'd0) &&
            if_id_valid
        ) begin

            if (
                (uses_rs1_ex && (id_ex_rd == if_id_rs1)) ||
                (uses_rs2_ex && (id_ex_rd == if_id_rs2))
            ) begin

                stall = 1'b1;

            end

        end

    end

endmodule
