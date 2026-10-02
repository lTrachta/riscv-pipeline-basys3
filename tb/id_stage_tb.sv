`timescale 1ns/1ps

module id_stage_tb;

    logic        clk;
    logic        reset;

    logic        id_enable;
    logic        flush_id_ex;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;

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

    id_stage dut (
        .clk               (clk),
        .reset             (reset),

        .id_enable         (id_enable),
        .flush_id_ex       (flush_id_ex),

        .if_id_pc          (if_id_pc),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),

        .wb_write_enable   (wb_write_enable),
        .wb_write_register (wb_write_register),
        .wb_write_data     (wb_write_data),

        .id_ex_pc          (id_ex_pc),
        .id_ex_read_data1  (id_ex_read_data1),
        .id_ex_read_data2  (id_ex_read_data2),
        .id_ex_immediate   (id_ex_immediate),

        .id_ex_rs1         (id_ex_rs1),
        .id_ex_rs2         (id_ex_rs2),
        .id_ex_rd          (id_ex_rd),

        .id_ex_opcode      (id_ex_opcode),
        .id_ex_funct3      (id_ex_funct3),
        .id_ex_funct7      (id_ex_funct7),

        .id_ex_valid       (id_ex_valid)
    );

    // Clock de período 10 ns.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset             = 1'b1;
        id_enable         = 1'b0;
        flush_id_ex       = 1'b0;

        if_id_pc          = 32'd0;
        if_id_instruction = 32'd0;
        if_id_valid       = 1'b0;

        wb_write_enable   = 1'b0;
        wb_write_register = 5'd0;
        wb_write_data     = 32'd0;


        // Caso 1: reset.
        @(posedge clk);
        #1;

        if (id_ex_valid !== 1'b0)
            $fatal(1, "ERROR RESET: id_ex_valid deberia ser 0");


        // Caso 2: cargar x3 = 150 desde WB.
        @(negedge clk);

        reset             = 1'b0;
        wb_write_enable   = 1'b1;
        wb_write_register = 5'd3;
        wb_write_data     = 32'd150;

        @(posedge clk);
        #1;


        // Caso 3: cargar x5 = 200 desde WB.
        @(negedge clk);

        wb_write_register = 5'd5;
        wb_write_data     = 32'd200;

        @(posedge clk);
        #1;


        // Caso 4: decodificar add x6, x3, x5.
        @(negedge clk);

        wb_write_enable   = 1'b0;

        id_enable         = 1'b1;
        flush_id_ex       = 1'b0;

        if_id_pc          = 32'd100;
        if_id_instruction = 32'h00518333;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        if (id_ex_pc !== 32'd100)
            $fatal(1, "ERROR ADD: PC incorrecto");

        if (id_ex_rs1 !== 5'd3 ||
            id_ex_rs2 !== 5'd5 ||
            id_ex_rd  !== 5'd6)
            $fatal(1, "ERROR ADD: campos de registros incorrectos");

        if (id_ex_read_data1 !== 32'd150)
            $fatal(1, "ERROR ADD: valor de x3 incorrecto");

        if (id_ex_read_data2 !== 32'd200)
            $fatal(1, "ERROR ADD: valor de x5 incorrecto");

        if (id_ex_opcode !== 7'b0110011)
            $fatal(1, "ERROR ADD: opcode incorrecto");

        if (id_ex_immediate !== 32'd0)
            $fatal(1, "ERROR ADD: inmediato deberia ser 0");

        if (id_ex_valid !== 1'b1)
            $fatal(1, "ERROR ADD: instruccion deberia ser valida");


        // Caso 5: addi x7, x3, -4.
        @(negedge clk);

        if_id_pc          = 32'd104;
        if_id_instruction = 32'hFFC18393;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        if (id_ex_pc !== 32'd104)
            $fatal(1, "ERROR ADDI: PC incorrecto");

        if (id_ex_rs1 !== 5'd3)
            $fatal(1, "ERROR ADDI: rs1 incorrecto");

        if (id_ex_rd !== 5'd7)
            $fatal(1, "ERROR ADDI: rd incorrecto");

        if (id_ex_read_data1 !== 32'd150)
            $fatal(1, "ERROR ADDI: valor de x3 incorrecto");

        if (id_ex_immediate !== 32'hFFFFFFFC)
            $fatal(1, "ERROR ADDI: inmediato -4 incorrecto");

        if (id_ex_opcode !== 7'b0010011)
            $fatal(1, "ERROR ADDI: opcode incorrecto");


        // Caso 6: stall de ID/EX.
        @(negedge clk);

        id_enable         = 1'b0;

        if_id_pc          = 32'd108;
        if_id_instruction = 32'h00418863; // beq x3, x4, 16

        @(posedge clk);
        #1;

        // Debe conservar la instrucción ADDI anterior.
        if (id_ex_pc !== 32'd104)
            $fatal(1, "ERROR STALL: ID/EX cambio con id_enable=0");

        if (id_ex_rd !== 5'd7)
            $fatal(1, "ERROR STALL: rd cambio con id_enable=0");

        if (id_ex_immediate !== 32'hFFFFFFFC)
            $fatal(1, "ERROR STALL: inmediato cambio con id_enable=0");


        // Caso 7: WB escribe x4 durante el stall.
        @(negedge clk);

        wb_write_enable   = 1'b1;
        wb_write_register = 5'd4;
        wb_write_data     = 32'd150;

        @(posedge clk);
        #1;


        // Caso 8: reanudar y capturar el BEQ.
        @(negedge clk);

        wb_write_enable   = 1'b0;
        id_enable         = 1'b1;

        if_id_pc          = 32'd108;
        if_id_instruction = 32'h00418863; // beq x3, x4, 16
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        if (id_ex_pc !== 32'd108)
            $fatal(1, "ERROR BEQ: PC incorrecto");

        if (id_ex_rs1 !== 5'd3 ||
            id_ex_rs2 !== 5'd4)
            $fatal(1, "ERROR BEQ: registros fuente incorrectos");

        if (id_ex_read_data1 !== 32'd150 ||
            id_ex_read_data2 !== 32'd150)
            $fatal(1, "ERROR BEQ: valores de registros incorrectos");

        if (id_ex_immediate !== 32'd16)
            $fatal(1, "ERROR BEQ: inmediato incorrecto");

        if (id_ex_opcode !== 7'b1100011)
            $fatal(1, "ERROR BEQ: opcode incorrecto");


        // Caso 9: flush.
        @(negedge clk);

        flush_id_ex = 1'b1;
        id_enable   = 1'b0;

        @(posedge clk);
        #1;

        if (id_ex_valid !== 1'b0)
            $fatal(1, "ERROR FLUSH: id_ex_valid deberia ser 0");

        if (id_ex_pc !== 32'd108)
            $fatal(1, "ERROR FLUSH: los datos no deberian cambiar");


        // Caso 10: comprobar x0.
        @(negedge clk);

        flush_id_ex       = 1'b0;
        id_enable         = 1'b0;

        wb_write_enable   = 1'b1;
        wb_write_register = 5'd0;
        wb_write_data     = 32'd999;

        @(posedge clk);
        #1;

        // Presentamos una instrucción que lea x0.
        @(negedge clk);

        wb_write_enable   = 1'b0;
        id_enable         = 1'b1;

        // addi x1, x0, 5
        if_id_pc          = 32'd112;
        if_id_instruction = 32'h00500093;
        if_id_valid       = 1'b1;

        @(posedge clk);
        #1;

        if (id_ex_rs1 !== 5'd0)
            $fatal(1, "ERROR X0: rs1 deberia ser x0");

        if (id_ex_read_data1 !== 32'd0)
            $fatal(1, "ERROR X0: x0 deberia seguir valiendo 0");

        if (id_ex_immediate !== 32'd5)
            $fatal(1, "ERROR X0: inmediato incorrecto");


        $display("PASS: id_stage");
        $finish;
    end

endmodule
