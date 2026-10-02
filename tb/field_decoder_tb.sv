`timescale 1ns/1ps

module field_decoder_tb;

    logic [31:0] instruction;

    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;

    field_decoder dut (
        .instruction (instruction),
        .opcode      (opcode),
        .rd          (rd),
        .funct3      (funct3),
        .rs1         (rs1),
        .rs2         (rs2),
        .funct7      (funct7)
    );

    initial begin

        // Caso 1: add x6, x3, x5
        instruction = 32'h00518333;
        #1;

        if (opcode !== 7'b0110011)
            $fatal(1, "ERROR ADD: opcode incorrecto");

        if (rd !== 5'd6)
            $fatal(1, "ERROR ADD: rd incorrecto");

        if (funct3 !== 3'b000)
            $fatal(1, "ERROR ADD: funct3 incorrecto");

        if (rs1 !== 5'd3)
            $fatal(1, "ERROR ADD: rs1 incorrecto");

        if (rs2 !== 5'd5)
            $fatal(1, "ERROR ADD: rs2 incorrecto");

        if (funct7 !== 7'b0000000)
            $fatal(1, "ERROR ADD: funct7 incorrecto");


        // Caso 2: addi x6, x3, 10
        instruction = 32'h00A18313;
        #1;

        if (opcode !== 7'b0010011)
            $fatal(1, "ERROR ADDI: opcode incorrecto");

        if (rd !== 5'd6)
            $fatal(1, "ERROR ADDI: rd incorrecto");

        if (funct3 !== 3'b000)
            $fatal(1, "ERROR ADDI: funct3 incorrecto");

        if (rs1 !== 5'd3)
            $fatal(1, "ERROR ADDI: rs1 incorrecto");


        // Caso 3: sw x5, 12(x6)
        instruction = 32'h00532623;
        #1;

        if (opcode !== 7'b0100011)
            $fatal(1, "ERROR SW: opcode incorrecto");

        if (funct3 !== 3'b010)
            $fatal(1, "ERROR SW: funct3 incorrecto");

        if (rs1 !== 5'd6)
            $fatal(1, "ERROR SW: rs1 incorrecto");

        if (rs2 !== 5'd5)
            $fatal(1, "ERROR SW: rs2 incorrecto");


        // Caso 4: beq x3, x4, 16
        instruction = 32'h00418863;
        #1;

        if (opcode !== 7'b1100011)
            $fatal(1, "ERROR BEQ: opcode incorrecto");

        if (funct3 !== 3'b000)
            $fatal(1, "ERROR BEQ: funct3 incorrecto");

        if (rs1 !== 5'd3)
            $fatal(1, "ERROR BEQ: rs1 incorrecto");

        if (rs2 !== 5'd4)
            $fatal(1, "ERROR BEQ: rs2 incorrecto");

        $display("PASS: field_decoder");
        $finish;

    end

endmodule
