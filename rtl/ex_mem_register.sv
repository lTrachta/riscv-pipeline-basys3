`timescale 1ns / 1ps

module ex_mem_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    input  logic [31:0] pc_in,
    input  logic [31:0] alu_result_in,
    input  logic [31:0] store_data_in,
    input  logic [4:0]  rd_in,
    input  logic [6:0]  opcode_in,
    input  logic [2:0]  funct3_in,
    input  logic        valid_in,

    output logic [31:0] pc_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] store_data_out,
    output logic [4:0]  rd_out,
    output logic [6:0]  opcode_out,
    output logic [2:0]  funct3_out,
    output logic        valid_out
);

    always_ff @(posedge clk) begin

        if (reset) begin
            pc_out          <= 32'd0;
            alu_result_out  <= 32'd0;
            store_data_out  <= 32'd0;
            rd_out          <= 5'd0;
            opcode_out      <= 7'd0;
            funct3_out      <= 3'd0;
            valid_out       <= 1'b0;
        end

        else if (flush) begin
            valid_out <= 1'b0;
        end

        else if (enable) begin
            pc_out          <= pc_in;
            alu_result_out  <= alu_result_in;
            store_data_out  <= store_data_in;
            rd_out          <= rd_in;
            opcode_out      <= opcode_in;
            funct3_out      <= funct3_in;
            valid_out       <= valid_in;
        end

    end

endmodule
