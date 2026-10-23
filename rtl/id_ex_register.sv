`timescale 1ns / 1ps

module id_ex_register (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic        flush,

    // =========================================================
    // DATAPATH INPUTS
    // =========================================================

    input  logic [31:0] pc_in,
    input  logic [31:0] read_data1_in,
    input  logic [31:0] read_data2_in,
    input  logic [31:0] immediate_in,

    input  logic [4:0]  rs1_in,
    input  logic [4:0]  rs2_in,
    input  logic [4:0]  rd_in,

    input  logic [6:0]  opcode_in,
    input  logic [2:0]  funct3_in,
    input  logic [6:0]  funct7_in,

    input  logic        valid_in,

    // =========================================================
    // EX CONTROL INPUTS
    // =========================================================

    input  logic        alu_src_a_in,
    input  logic        alu_src_b_in,
    input  logic [2:0]  alu_op_in,

    input  logic        branch_in,
    input  logic [1:0]  jump_type_in,

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
    output logic [31:0] read_data1_out,
    output logic [31:0] read_data2_out,
    output logic [31:0] immediate_out,

    output logic [4:0]  rs1_out,
    output logic [4:0]  rs2_out,
    output logic [4:0]  rd_out,

    output logic [6:0]  opcode_out,
    output logic [2:0]  funct3_out,
    output logic [6:0]  funct7_out,

    output logic        valid_out,

    // =========================================================
    // EX CONTROL OUTPUTS
    // =========================================================

    output logic        alu_src_a_out,
    output logic        alu_src_b_out,
    output logic [2:0]  alu_op_out,

    output logic        branch_out,
    output logic [1:0]  jump_type_out,

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

            pc_out          <= 32'b0;
            read_data1_out  <= 32'b0;
            read_data2_out  <= 32'b0;
            immediate_out   <= 32'b0;

            rs1_out         <= 5'b0;
            rs2_out         <= 5'b0;
            rd_out          <= 5'b0;

            opcode_out      <= 7'b0;
            funct3_out      <= 3'b0;
            funct7_out      <= 7'b0;

            valid_out       <= 1'b0;

            alu_src_a_out   <= 1'b0;
            alu_src_b_out   <= 1'b0;
            alu_op_out      <= 3'b0;

            branch_out      <= 1'b0;
            jump_type_out   <= 2'b0;

            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;

            reg_write_out   <= 1'b0;
            wb_sel_out      <= 2'b0;

        end

        // =====================================================
        // FLUSH
        //
        // El contenido pasa a representar una burbuja.
        // Además neutralizamos todos los controles con posibles
        // efectos arquitectónicos.
        // =====================================================

        else if (flush) begin

            pc_out          <= 32'b0;
            read_data1_out  <= 32'b0;
            read_data2_out  <= 32'b0;
            immediate_out   <= 32'b0;

            rs1_out         <= 5'b0;
            rs2_out         <= 5'b0;
            rd_out          <= 5'b0;

            opcode_out      <= 7'b0;
            funct3_out      <= 3'b0;
            funct7_out      <= 7'b0;

            valid_out       <= 1'b0;

            alu_src_a_out   <= 1'b0;
            alu_src_b_out   <= 1'b0;
            alu_op_out      <= 3'b0;

            branch_out      <= 1'b0;
            jump_type_out   <= 2'b0;

            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;

            reg_write_out   <= 1'b0;
            wb_sel_out      <= 2'b0;

        end

        // =====================================================
        // NORMAL CAPTURE
        // =====================================================

        else if (enable) begin

            pc_out          <= pc_in;
            read_data1_out  <= read_data1_in;
            read_data2_out  <= read_data2_in;
            immediate_out   <= immediate_in;

            rs1_out         <= rs1_in;
            rs2_out         <= rs2_in;
            rd_out          <= rd_in;

            opcode_out      <= opcode_in;
            funct3_out      <= funct3_in;
            funct7_out      <= funct7_in;

            valid_out       <= valid_in;

            alu_src_a_out   <= alu_src_a_in;
            alu_src_b_out   <= alu_src_b_in;
            alu_op_out      <= alu_op_in;

            branch_out      <= branch_in;
            jump_type_out   <= jump_type_in;

            mem_read_out    <= mem_read_in;
            mem_write_out   <= mem_write_in;

            reg_write_out   <= reg_write_in;
            wb_sel_out      <= wb_sel_in;

        end

        // =====================================================
        // enable = 0
        //
        // No hay asignaciones:
        // el registro conserva la fotografía anterior.
        // =====================================================

    end

endmodule
