`timescale 1ns/1ps

module instruction_memory_tb;

    logic [31:0] address;
    logic [31:0] instruction;

    instruction_memory #(
        .DEPTH(256)
    ) dut (
        .address     (address),
        .instruction (instruction)
    );

    initial begin
        // Cargamos valores conocidos directamente desde el testbench.
        dut.memory[0] = 32'hAAAAAAAA;
        dut.memory[1] = 32'hBBBBBBBB;
        dut.memory[2] = 32'hCCCCCCCC;
        dut.memory[3] = 32'hDDDDDDDD;

        // Dirección 0 -> palabra 0
        address = 32'd0;
        #1;

        if (instruction !== 32'hAAAAAAAA)
            $fatal(1, "ERROR: address 0 no devolvio memory[0]");

        // Dirección 4 -> palabra 1
        address = 32'd4;
        #1;

        if (instruction !== 32'hBBBBBBBB)
            $fatal(1, "ERROR: address 4 no devolvio memory[1]");

        // Dirección 8 -> palabra 2
        address = 32'd8;
        #1;

        if (instruction !== 32'hCCCCCCCC)
            $fatal(1, "ERROR: address 8 no devolvio memory[2]");

        // Dirección 12 -> palabra 3
        address = 32'd12;
        #1;

        if (instruction !== 32'hDDDDDDDD)
            $fatal(1, "ERROR: address 12 no devolvio memory[3]");

        $display("PASS: instruction_memory");
        $finish;
    end

endmodule
