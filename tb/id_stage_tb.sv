`timescale 1ns / 1ps

module id_stage_tb;

    logic clk, reset, id_enable, flush_id_ex;
    logic [31:0] if_id_pc, if_id_instruction;
    logic if_id_valid;
    logic wb_write_enable;
    logic [4:0] wb_write_register;
    logic [31:0] wb_write_data;

    logic [31:0] id_ex_pc, id_ex_read_data1, id_ex_read_data2, id_ex_immediate;
    logic [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd;
    logic [6:0] id_ex_opcode, id_ex_funct7;
    logic [2:0] id_ex_funct3;
    logic id_ex_valid;
    logic id_ex_alu_src_a, id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;
    logic id_ex_branch;
    logic [1:0] id_ex_jump_type;
    logic id_ex_mem_read, id_ex_mem_write, id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;

    id_stage dut (
        .clk(clk), .reset(reset), .id_enable(id_enable), .flush_id_ex(flush_id_ex),
        .if_id_pc(if_id_pc), .if_id_instruction(if_id_instruction), .if_id_valid(if_id_valid),
        .wb_write_enable(wb_write_enable), .wb_write_register(wb_write_register), .wb_write_data(wb_write_data),
        .id_ex_pc(id_ex_pc), .id_ex_read_data1(id_ex_read_data1), .id_ex_read_data2(id_ex_read_data2),
        .id_ex_immediate(id_ex_immediate), .id_ex_rs1(id_ex_rs1), .id_ex_rs2(id_ex_rs2), .id_ex_rd(id_ex_rd),
        .id_ex_opcode(id_ex_opcode), .id_ex_funct3(id_ex_funct3), .id_ex_funct7(id_ex_funct7), .id_ex_valid(id_ex_valid),
        .id_ex_alu_src_a(id_ex_alu_src_a), .id_ex_alu_src_b(id_ex_alu_src_b), .id_ex_alu_op(id_ex_alu_op),
        .id_ex_branch(id_ex_branch), .id_ex_jump_type(id_ex_jump_type),
        .id_ex_mem_read(id_ex_mem_read), .id_ex_mem_write(id_ex_mem_write),
        .id_ex_reg_write(id_ex_reg_write), .id_ex_wb_sel(id_ex_wb_sel)
    );

    always #5 clk = ~clk;

    task automatic write_reg(input logic [4:0] rd, input logic [31:0] data);
        begin
            @(negedge clk);
            wb_write_enable = 1; wb_write_register = rd; wb_write_data = data;
            @(posedge clk); #1;
            @(negedge clk);
            wb_write_enable = 0;
        end
    endtask

    initial begin
        clk = 0; reset = 1; id_enable = 1; flush_id_ex = 0;
        if_id_pc = 0; if_id_instruction = 0; if_id_valid = 0;
        wb_write_enable = 0; wb_write_register = 0; wb_write_data = 0;

        @(posedge clk); #1;
        if (id_ex_valid !== 0 || id_ex_pc !== 0) $fatal(1, "FAIL: RESET");
        $display("PASS: RESET");
        reset = 0;

        write_reg(5'd3, 32'd10);
        write_reg(5'd4, 32'd20);

        // add x5,x3,x4 = 0x004182B3
        @(negedge clk);
        id_enable = 1; flush_id_ex = 0;
        if_id_pc = 32'd100; if_id_instruction = 32'h004182B3; if_id_valid = 1;
        @(posedge clk); #1;

        if (id_ex_valid !== 1 || id_ex_pc !== 32'd100 || id_ex_rs1 !== 5'd3 || id_ex_rs2 !== 5'd4 || id_ex_rd !== 5'd5 ||
            id_ex_read_data1 !== 32'd10 || id_ex_read_data2 !== 32'd20 || id_ex_opcode !== 7'b0110011 ||
            id_ex_alu_src_a !== 0 || id_ex_alu_src_b !== 0 || id_ex_alu_op !== 3'b010 ||
            id_ex_branch !== 0 || id_ex_jump_type !== 0 || id_ex_mem_read !== 0 || id_ex_mem_write !== 0 ||
            id_ex_reg_write !== 1 || id_ex_wb_sel !== 2'b00)
            $fatal(1, "FAIL: ADD DECODE/CAPTURE");
        $display("PASS: ADD DECODE/CAPTURE");

        // Unsupported instruction becomes bubble.
        @(negedge clk);
        if_id_pc = 32'd104; if_id_instruction = 32'hFFFFFFFF; if_id_valid = 1;
        @(posedge clk); #1;
        if (id_ex_valid !== 0)
            $fatal(1, "FAIL: INVALID INSTRUCTION");
        $display("PASS: INVALID INSTRUCTION -> BUBBLE");

        // Flush fully neutralizes ID/EX.
        @(negedge clk);
        flush_id_ex = 1; id_enable = 0;
        if_id_pc = 32'd108; if_id_instruction = 32'h00500093; if_id_valid = 1;
        @(posedge clk); #1;
        if (id_ex_valid !== 0 || id_ex_pc !== 0 || id_ex_rd !== 0 || id_ex_reg_write !== 0 || id_ex_mem_read !== 0 || id_ex_mem_write !== 0)
            $fatal(1, "FAIL: FLUSH");
        $display("PASS: FLUSH CREATES BUBBLE");

        $display("PASS: id_stage");
        $finish;
    end

endmodule
