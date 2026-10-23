`timescale 1ns / 1ps

module mem_wb_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    // =========================================================
    // DATAPATH INPUTS
    // =========================================================

    input  logic [31:0] pc_in,
    input  logic [31:0] alu_result_in,
    input  logic [31:0] load_data_in,

    input  logic [4:0]  rd_in,

    // Opcode se conserva temporalmente para debug/transición.
    // WB dejará de depender de él en el siguiente bloque.
    input  logic [6:0]  opcode_in,

    input  logic        valid_in,

    // =========================================================
    // WB CONTROL INPUTS
    // =========================================================

    input  logic        reg_write_in,
    input  logic [1:0]  wb_sel_in,

    // =========================================================
    // DATAPATH OUTPUTS
    // =========================================================

    output logic [31:0] pc_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] load_data_out,

    output logic [4:0]  rd_out,
    output logic [6:0]  opcode_out,

    output logic        valid_out,

    // =========================================================
    // WB CONTROL OUTPUTS
    // =========================================================

    output logic        reg_write_out,
    output logic [1:0]  wb_sel_out
);


    always_ff @(posedge clk) begin

        // =====================================================
        // RESET
        // =====================================================

        if (reset) begin

            pc_out         <= 32'd0;
            alu_result_out <= 32'd0;
            load_data_out  <= 32'd0;

            rd_out         <= 5'd0;
            opcode_out     <= 7'd0;

            valid_out      <= 1'b0;

            reg_write_out  <= 1'b0;
            wb_sel_out     <= 2'b00;

        end

        // =====================================================
        // FLUSH
        //
        // MEM/WB pasa a representar una burbuja.
        // Neutralizamos también el control de WB.
        // =====================================================

        else if (flush) begin

            pc_out         <= 32'd0;
            alu_result_out <= 32'd0;
            load_data_out  <= 32'd0;

            rd_out         <= 5'd0;
            opcode_out     <= 7'd0;

            valid_out      <= 1'b0;

            reg_write_out  <= 1'b0;
            wb_sel_out     <= 2'b00;

        end

        // =====================================================
        // NORMAL CAPTURE
        // =====================================================

        else if (enable) begin

            pc_out         <= pc_in;
            alu_result_out <= alu_result_in;
            load_data_out  <= load_data_in;

            rd_out         <= rd_in;
            opcode_out     <= opcode_in;

            valid_out      <= valid_in;

            reg_write_out  <= reg_write_in;
            wb_sel_out     <= wb_sel_in;

        end

        // enable = 0:
        // mantiene la fotografía anterior.

    end

endmodule
