`timescale 1ns / 1ps

module wb_stage_tb;

    logic [31:0] mem_wb_pc, mem_wb_alu_result, mem_wb_load_data;
    logic [4:0] mem_wb_rd;
    logic [6:0] mem_wb_opcode;
    logic mem_wb_valid, mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;

    logic wb_write_enable;
    logic [4:0] wb_write_register;
    logic [31:0] wb_write_data;

    wb_stage dut (
        .mem_wb_pc(mem_wb_pc), .mem_wb_alu_result(mem_wb_alu_result), .mem_wb_load_data(mem_wb_load_data),
        .mem_wb_rd(mem_wb_rd), .mem_wb_opcode(mem_wb_opcode), .mem_wb_valid(mem_wb_valid),
        .mem_wb_reg_write(mem_wb_reg_write), .mem_wb_wb_sel(mem_wb_wb_sel),
        .wb_write_enable(wb_write_enable), .wb_write_register(wb_write_register), .wb_write_data(wb_write_data)
    );

    task automatic check_case(
        input logic [31:0] pc,
        input logic [31:0] alu_value,
        input logic [31:0] mem_value,
        input logic [4:0] rd,
        input logic valid,
        input logic reg_write,
        input logic [1:0] wb_sel,
        input logic expected_enable,
        input logic [31:0] expected_data,
        input string name
    );
        begin
            mem_wb_pc = pc;
            mem_wb_alu_result = alu_value;
            mem_wb_load_data = mem_value;
            mem_wb_rd = rd;
            mem_wb_opcode = 7'h7F;
            mem_wb_valid = valid;
            mem_wb_reg_write = reg_write;
            mem_wb_wb_sel = wb_sel;
            #1;

            if (wb_write_enable !== expected_enable || wb_write_register !== rd || wb_write_data !== expected_data)
                $fatal(1, "FAIL: %s | en=%b rd=%0d data=%h", name, wb_write_enable, wb_write_register, wb_write_data);

            $display("PASS: %s | en=%b rd=%0d data=%h", name, wb_write_enable, wb_write_register, wb_write_data);
        end
    endtask

    initial begin
        check_case(32'd100, 32'd42, 32'hDEADBEEF, 5'd7, 1, 1, 2'b00, 1, 32'd42,       "ALU RESULT");
        check_case(32'd104, 32'd32, 32'hAABBCCDD, 5'd5, 1, 1, 2'b01, 1, 32'hAABBCCDD, "LOAD RESULT");
        check_case(32'd400, 32'hAAAAAAAA, 32'hBBBBBBBB, 5'd1, 1, 1, 2'b10, 1, 32'd404, "PC PLUS 4");
        check_case(32'd120, 32'h12345678, 32'hAAAAAAAA, 5'd9, 1, 0, 2'b00, 0, 32'h12345678, "REGWRITE OFF");
        check_case(32'd124, 32'h12345678, 32'hAAAAAAAA, 5'd9, 0, 1, 2'b00, 0, 32'h12345678, "INVALID BUBBLE");
        check_case(32'd128, 32'h12345678, 32'hAAAAAAAA, 5'd0, 1, 1, 2'b00, 0, 32'h12345678, "RD X0");
        check_case(32'd132, 32'h12345678, 32'hAAAAAAAA, 5'd9, 1, 1, 2'b11, 0, 32'd0,       "INVALID WB SEL");

        $display("PASS: wb_stage");
        $finish;
    end

endmodule
