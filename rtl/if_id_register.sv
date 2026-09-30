`timescale 1ns/1ps

module if_id_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    input  logic [31:0] pc_in,
    input  logic [31:0] instruction_in,
    input  logic        valid_in,

    output logic [31:0] pc_out,
    output logic [31:0] instruction_out,
    output logic        valid_out
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out          <= 32'd0;
            instruction_out <= 32'd0;
            valid_out       <= 1'b0;
        end
        else if (flush) begin
            valid_out <= 1'b0;
        end
        else if (enable) begin
            pc_out          <= pc_in;
            instruction_out <= instruction_in;
            valid_out       <= valid_in;
        end
    end

endmodule
