`timescale 1ns/1ps

module instruction_memory #(
    parameter int DEPTH = 256
) (
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    logic [31:0] memory [0:DEPTH-1];

    always_comb begin
        instruction = memory[address[31:2]];
    end

endmodule
