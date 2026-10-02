`timescale 1ns/1ps

module immediate_generator_tb;

    logic [31:0] instruction;
    logic [31:0] immediate;

    immediate_generator dut (
        .instruction (instruction),
        .immediate   (immediate)
    );

    initial begin

        // Caso 1: Tipo I positivo
        // addi x6, x3, 10
        instruction = 32'h00A18313;
        #1;

        if (immediate !== 32'd10)
            $fatal(1, "ERROR I positivo: inmediato incorrecto");


        // Caso 2: Tipo I negativo
        // addi x6, x3, -4
        instruction = 32'hFFC18313;
        #1;

        if (immediate !== 32'hFFFFFFFC)
            $fatal(1, "ERROR I negativo: extension de signo incorrecta");


        // Caso 3: Tipo S positivo
        // sw x5, 12(x6)
        instruction = 32'h00532623;
        #1;

        if (immediate !== 32'd12)
            $fatal(1, "ERROR S positivo: inmediato incorrecto");


        // Caso 4: Tipo S negativo
        // sw x5, -8(x6)
        instruction = 32'hFE532C23;
        #1;

        if (immediate !== 32'hFFFFFFF8)
            $fatal(1, "ERROR S negativo: extension de signo incorrecta");


        // Caso 5: Tipo B positivo
        // beq x3, x4, 16
        instruction = 32'h00418863;
        #1;

        if (immediate !== 32'd16)
            $fatal(1, "ERROR B positivo: inmediato incorrecto");


        // Caso 6: Tipo B negativo
        // beq x3, x4, -8
        instruction = 32'hFE418CE3;
        #1;

        if (immediate !== 32'hFFFFFFF8)
            $fatal(1, "ERROR B negativo: extension de signo incorrecta");


        // Caso 7: Tipo U
        // lui x5, 0x12345
        instruction = 32'h123452B7;
        #1;

        if (immediate !== 32'h12345000)
            $fatal(1, "ERROR U: inmediato incorrecto");


        // Caso 8: Tipo J positivo
        // jal x1, 20
        instruction = 32'h014000EF;
        #1;

        if (immediate !== 32'd20)
            $fatal(1, "ERROR J positivo: inmediato incorrecto");


        // Caso 9: Tipo J negativo
        // jal x1, -8
        instruction = 32'hFF9FF0EF;
        #1;

        if (immediate !== 32'hFFFFFFF8)
            $fatal(1, "ERROR J negativo: extension de signo incorrecta");


        // Caso 10: Tipo R
        // add x6, x3, x5
        instruction = 32'h00518333;
        #1;

        if (immediate !== 32'd0)
            $fatal(1, "ERROR R: el inmediato deberia ser 0");


        $display("PASS: immediate_generator");
        $finish;

    end

endmodule
