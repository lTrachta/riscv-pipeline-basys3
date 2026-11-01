`timescale 1ns / 1ps

module ex_stage (
    input  logic        clk,
    input  logic        reset,

    input  logic        ex_enable,
    input  logic        flush_ex_mem,

    // =========================================================
    // CONTROL EX PROVENIENTE DE ID/EX
    // =========================================================

    input  logic        id_ex_alu_src_a,
    input  logic        id_ex_alu_src_b,
    input  logic [2:0]  id_ex_alu_op,

    input  logic        id_ex_branch,
    input  logic [1:0]  id_ex_jump_type,

    // =========================================================
    // CONTROL MEM QUE DEBE CONTINUAR
    // =========================================================

    input  logic        id_ex_mem_read,
    input  logic        id_ex_mem_write,

    // =========================================================
    // CONTROL WB QUE DEBE CONTINUAR
    // =========================================================

    input  logic        id_ex_reg_write,
    input  logic [1:0]  id_ex_wb_sel,

    // =========================================================
    // DATOS PROVENIENTES DE ID/EX
    // =========================================================

    input  logic [31:0] id_ex_pc,

    input  logic [31:0] id_ex_read_data1,
    input  logic [31:0] id_ex_read_data2,

    input  logic [31:0] id_ex_immediate,

    input  logic [4:0]  id_ex_rs2,
    input  logic [4:0]  id_ex_rd,

    input  logic [6:0]  id_ex_opcode,
    input  logic [2:0]  id_ex_funct3,
    input  logic [6:0]  id_ex_funct7,

    input  logic        id_ex_valid,

    // =========================================================
    // FORWARDING
    //
    // forward_a / forward_b:
    //
    // 00 -> valor original almacenado en ID/EX
    // 01 -> valor proveniente de MEM/WB
    // 10 -> valor proveniente de EX/MEM
    // 11 -> reservado
    // =========================================================

    input  logic [1:0]  forward_a,
    input  logic [1:0]  forward_b,

    input  logic [31:0] ex_mem_forward_value,
    input  logic [31:0] mem_wb_forward_value,

    // =========================================================
    // DATOS HACIA MEM
    // =========================================================

    output logic [31:0] ex_mem_pc,
    output logic [31:0] ex_mem_alu_result,
    output logic [31:0] ex_mem_store_data,

    output logic [4:0]  ex_mem_rs2,
    output logic [4:0]  ex_mem_rd,

    output logic [6:0]  ex_mem_opcode,
    output logic [2:0]  ex_mem_funct3,

    output logic        ex_mem_valid,

    // =========================================================
    // CONTROL MEM HACIA EX/MEM
    // =========================================================

    output logic        ex_mem_mem_read,
    output logic        ex_mem_mem_write,

    // =========================================================
    // CONTROL WB HACIA EX/MEM
    // =========================================================

    output logic        ex_mem_reg_write,
    output logic [1:0]  ex_mem_wb_sel
);


    // =========================================================
    // CODIFICACIÓN DE FORWARDING
    // =========================================================

    localparam logic [1:0] FORWARD_ID_EX  = 2'b00;
    localparam logic [1:0] FORWARD_MEM_WB = 2'b01;
    localparam logic [1:0] FORWARD_EX_MEM = 2'b10;


    // =========================================================
    // VALORES DE REGISTRO DESPUÉS DE FORWARDING
    // =========================================================

    logic [31:0] forwarded_rs1;
    logic [31:0] forwarded_rs2;


    // =========================================================
    // OPERANDOS FINALES DE ALU
    // =========================================================

    logic [31:0] operand_a;
    logic [31:0] operand_b;


    // =========================================================
    // RESULTADO DE ALU
    // =========================================================

    logic [3:0]  alu_operation;
    logic [31:0] alu_result;
    logic        alu_zero;


    // =========================================================
    // FORWARDING DE rs1
    //
    // Determina cuál es la versión más actual del registro rs1.
    //
    // 00 -> valor leído originalmente del Register File
    // 01 -> valor que se encuentra en MEM/WB
    // 10 -> valor que se encuentra en EX/MEM
    //
    // La prioridad EX/MEM > MEM/WB ya fue resuelta por la
    // Forwarding Unit.
    // =========================================================

    always_comb begin

        case (forward_a)

            FORWARD_ID_EX: begin
                forwarded_rs1 = id_ex_read_data1;
            end

            FORWARD_MEM_WB: begin
                forwarded_rs1 = mem_wb_forward_value;
            end

            FORWARD_EX_MEM: begin
                forwarded_rs1 = ex_mem_forward_value;
            end

            default: begin
                forwarded_rs1 = id_ex_read_data1;
            end

        endcase

    end


    // =========================================================
    // FORWARDING DE rs2
    //
    // El resultado forwarded_rs2 se utiliza para dos posibles
    // propósitos:
    //
    // 1. Operando B de ALU, cuando alu_src_b = 0.
    //
    // 2. store_data, independientemente de alu_src_b.
    //
    // Esto es fundamental para instrucciones store.
    // =========================================================

    always_comb begin

        case (forward_b)

            FORWARD_ID_EX: begin
                forwarded_rs2 = id_ex_read_data2;
            end

            FORWARD_MEM_WB: begin
                forwarded_rs2 = mem_wb_forward_value;
            end

            FORWARD_EX_MEM: begin
                forwarded_rs2 = ex_mem_forward_value;
            end

            default: begin
                forwarded_rs2 = id_ex_read_data2;
            end

        endcase

    end


    // =========================================================
    // SELECCIÓN DE OPERANDO A
    //
    // id_ex_alu_src_a:
    //
    // 0 -> rs1 corregido mediante forwarding
    // 1 -> PC
    //
    // Ejemplos:
    //
    // R/I/load/store/jalr:
    //      normalmente usan rs1.
    //
    // JAL:
    //      usa PC.
    //
    // Si se selecciona PC, ForwardA no modifica la entrada
    // final de la ALU.
    // =========================================================

    always_comb begin

        if (id_ex_alu_src_a)
            operand_a = id_ex_pc;
        else
            operand_a = forwarded_rs1;

    end


    // =========================================================
    // SELECCIÓN DE OPERANDO B
    //
    // id_ex_alu_src_b:
    //
    // 0 -> rs2 corregido mediante forwarding
    // 1 -> immediate
    //
    // IMPORTANTE:
    //
    // ForwardB determina cuál es la versión correcta de rs2.
    //
    // alu_src_b determina si la ALU realmente utiliza rs2
    // o utiliza el inmediato.
    //
    // Por ejemplo:
    //
    // add:
    //      B = forwarded_rs2
    //
    // addi:
    //      B = immediate
    //
    // sw:
    //      B = immediate para calcular la dirección,
    //      pero forwarded_rs2 sigue usándose como store_data.
    // =========================================================

    always_comb begin

        if (id_ex_alu_src_b)
            operand_b = id_ex_immediate;
        else
            operand_b = forwarded_rs2;

    end


    // =========================================================
    // ALU CONTROL
    //
    // La Control Unit ya generó alu_op en ID.
    //
    // ALU Control solamente convierte:
    //
    // alu_op + funct3 + funct7
    //
    // en la operación exacta de ALU.
    // =========================================================

    alu_control alu_control_unit (
        .alu_op        (id_ex_alu_op),
        .funct3        (id_ex_funct3),
        .funct7        (id_ex_funct7),

        .alu_operation (alu_operation)
    );


    // =========================================================
    // ALU
    // =========================================================

    alu alu_unit (
        .operand_a     (operand_a),
        .operand_b     (operand_b),

        .alu_operation (alu_operation),

        .result        (alu_result),
        .zero          (alu_zero)
    );


    // =========================================================
    // BRANCH / JUMP
    //
    // id_ex_branch e id_ex_jump_type llegan correctamente
    // hasta EX.
    //
    // Gracias al forwarding, cuando posteriormente se implemente
    // la resolución de branch, los valores de rs1/rs2 utilizados
    // en EX podrán ser los valores actualizados.
    //
    // La modificación real del PC y los flushes quedan para el
    // paso de control hazards.
    // =========================================================


    // =========================================================
    // EX/MEM PIPELINE REGISTER
    //
    // EX ya consume:
    //
    // - alu_src_a
    // - alu_src_b
    // - alu_op
    // - branch
    // - jump_type
    // - ForwardA
    // - ForwardB
    //
    // EX/MEM conserva:
    //
    // - resultado de ALU
    // - dato de store ya corregido
    // - controles MEM
    // - controles WB
    // - demás información necesaria
    // =========================================================

    ex_mem_register ex_mem_reg (
        .clk             (clk),
        .reset           (reset),
        .enable          (ex_enable),
        .flush           (flush_ex_mem),

        // -----------------------------------------------------
        // Datapath
        // -----------------------------------------------------

        .pc_in           (id_ex_pc),

        .alu_result_in   (alu_result),

        // -----------------------------------------------------
        // STORE DATA
        //
        // IMPORTANTE:
        //
        // Antes:
        //
        // store_data_in = id_ex_read_data2
        //
        // Ahora:
        //
        // store_data_in = forwarded_rs2
        //
        // Esto permite resolver:
        //
        // add x5, ...
        // sw  x5, 0(x3)
        //
        // sin esperar a que x5 llegue primero al Register File.
        //
        // El store sigue utilizando el inmediato como operand_b
        // de ALU para calcular la dirección.
        // -----------------------------------------------------

        .store_data_in   (forwarded_rs2),

        .rs2_in          (id_ex_rs2),
        .rd_in           (id_ex_rd),

        .opcode_in       (id_ex_opcode),
        .funct3_in       (id_ex_funct3),

        .valid_in        (id_ex_valid),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .mem_read_in     (id_ex_mem_read),
        .mem_write_in    (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .reg_write_in    (id_ex_reg_write),
        .wb_sel_in       (id_ex_wb_sel),

        // -----------------------------------------------------
        // Datapath outputs
        // -----------------------------------------------------

        .pc_out          (ex_mem_pc),
        .alu_result_out  (ex_mem_alu_result),
        .store_data_out  (ex_mem_store_data),

        .rs2_out         (ex_mem_rs2),
        .rd_out          (ex_mem_rd),

        .opcode_out      (ex_mem_opcode),
        .funct3_out      (ex_mem_funct3),

        .valid_out       (ex_mem_valid),

        // -----------------------------------------------------
        // MEM control outputs
        // -----------------------------------------------------

        .mem_read_out    (ex_mem_mem_read),
        .mem_write_out   (ex_mem_mem_write),

        // -----------------------------------------------------
        // WB control outputs
        // -----------------------------------------------------

        .reg_write_out   (ex_mem_reg_write),
        .wb_sel_out      (ex_mem_wb_sel)
    );

endmodule
