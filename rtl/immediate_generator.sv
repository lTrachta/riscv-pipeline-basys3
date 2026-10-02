`timescale 1ns/1ps

module immediate_generator (
    input  logic [31:0] instruction,
    output logic [31:0] immediate
);

    logic [6:0] opcode;

    always_comb begin
        opcode = instruction[6:0];

        case (opcode)

            // Tipo I:
            // loads, operaciones inmediatas y jalr.
            7'b0000011,
            7'b0010011,
            7'b1100111: begin
                immediate = {
                    {20{instruction[31]}},
                    instruction[31:20]
                };
            end

            // Tipo S:
            // sb, sh, sw.
            7'b0100011: begin
                immediate = {
                    {20{instruction[31]}},
                    instruction[31:25],
                    instruction[11:7]
                };
            end

            // Tipo B:
            // beq, bne.
            7'b1100011: begin
                immediate = {
                    {19{instruction[31]}},
                    instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0
                };
            end

            // Tipo U:
            // lui.
            7'b0110111: begin
                immediate = {
                    instruction[31:12],
                    12'b0
                };
            end

            // Tipo J:
            // jal.
            7'b1101111: begin
                immediate = {
                    {11{instruction[31]}},
                    instruction[31],
                    instruction[19:12],
                    instruction[20],
                    instruction[30:21],
                    1'b0
                };
            end

            // Instrucciones sin inmediato útil, por ejemplo tipo R.
            default: begin
                immediate = 32'd0;
            end

        endcase
    end

endmodule
