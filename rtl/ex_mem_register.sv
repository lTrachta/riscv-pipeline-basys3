`timescale 1ns / 1ps

module ex_mem_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    // =========================================================
    // DATAPATH INPUTS
    // =========================================================

    input  logic [31:0] pc_in,
    input  logic [31:0] alu_result_in,
    input  logic [31:0] store_data_in,

    input  logic [4:0]  rd_in,
    input  logic [6:0]  opcode_in,
    input  logic [2:0]  funct3_in,

    input  logic        valid_in,

    // =========================================================
    // MEM CONTROL INPUTS
    // =========================================================

    input  logic        mem_read_in,
    input  logic        mem_write_in,

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
    output logic [31:0] store_data_out,

    output logic [4:0]  rd_out,
    output logic [6:0]  opcode_out,
    output logic [2:0]  funct3_out,

    output logic        valid_out,

    // =========================================================
    // MEM CONTROL OUTPUTS
    // =========================================================

    output logic        mem_read_out,
    output logic        mem_write_out,

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

            pc_out          <= 32'd0;
            alu_result_out  <= 32'd0;
            store_data_out  <= 32'd0;

            rd_out          <= 5'd0;
            opcode_out      <= 7'd0;
            funct3_out      <= 3'd0;

            valid_out       <= 1'b0;

            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;

            reg_write_out   <= 1'b0;
            wb_sel_out      <= 2'b00;

        end

        // =====================================================
        // FLUSH
        //
        // Se genera una burbuja.
        // Neutralizamos también los controles con efectos
        // arquitectónicos.
        // =====================================================

        else if (flush) begin

            pc_out          <= 32'd0;
            alu_result_out  <= 32'd0;
            store_data_out  <= 32'd0;

            rd_out          <= 5'd0;
            opcode_out      <= 7'd0;
            funct3_out      <= 3'd0;

            valid_out       <= 1'b0;

            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;

            reg_write_out   <= 1'b0;
            wb_sel_out      <= 2'b00;

        end

        // =====================================================
        // NORMAL CAPTURE
        // =====================================================

        else if (enable) begin

            pc_out          <= pc_in;
            alu_result_out  <= alu_result_in;
            store_data_out  <= store_data_in;

            rd_out          <= rd_in;
            opcode_out      <= opcode_in;
            funct3_out      <= funct3_in;

            valid_out       <= valid_in;

            mem_read_out    <= mem_read_in;
            mem_write_out   <= mem_write_in;

            reg_write_out   <= reg_write_in;
            wb_sel_out      <= wb_sel_in;

        end

        // enable = 0:
        // se conserva la fotografía anterior.

    end

endmodule
