`timescale 1ns/1ps

module program_counter (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic [31:0] next_pc,

    output logic [31:0] pc_current
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_current <= 32'd0;
        end
        else if (enable) begin
            pc_current <= next_pc;
        end
    end

endmodule
