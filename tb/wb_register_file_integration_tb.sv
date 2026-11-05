`timescale 1ns / 1ps

module wb_register_file_integration_tb;

    logic clk, reset;
    logic [31:0] mem_wb_pc, mem_wb_alu_result, mem_wb_load_data;
    logic [4:0] mem_wb_rd;
    logic [6:0] mem_wb_opcode;
    logic mem_wb_valid, mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;

    logic wb_write_enable;
    logic [4:0] wb_write_register;
    logic [31:0] wb_write_data;

    logic [4:0] read_register1, read_register2;
    logic [31:0] read_data1, read_data2;

    wb_stage wb_dut (
        .mem_wb_pc(mem_wb_pc), .mem_wb_alu_result(mem_wb_alu_result), .mem_wb_load_data(mem_wb_load_data),
        .mem_wb_rd(mem_wb_rd), .mem_wb_opcode(mem_wb_opcode), .mem_wb_valid(mem_wb_valid),
        .mem_wb_reg_write(mem_wb_reg_write), .mem_wb_wb_sel(mem_wb_wb_sel),
        .wb_write_enable(wb_write_enable), .wb_write_register(wb_write_register), .wb_write_data(wb_write_data)
    );

    register_file rf (
        .clk(clk), .reset(reset),
        .read_register1(read_register1), .read_register2(read_register2),
        .write_enable(wb_write_enable), .write_register(wb_write_register), .write_data(wb_write_data),
        .read_data1(read_data1), .read_data2(read_data2)
    );

    always #5 clk = ~clk;

    task automatic issue_write(
        input logic [31:0] pc,
        input logic [31:0] alu_value,
        input logic [31:0] mem_value,
        input logic [4:0] rd,
        input logic [1:0] wb_sel,
        input logic [31:0] expected,
        input string name
    );
        begin
            @(negedge clk);
            mem_wb_pc = pc; mem_wb_alu_result = alu_value; mem_wb_load_data = mem_value;
            mem_wb_rd = rd; mem_wb_opcode = 0; mem_wb_valid = 1; mem_wb_reg_write = 1; mem_wb_wb_sel = wb_sel;
            read_register1 = rd;
            #1;
            if (!wb_write_enable)
                $fatal(1, "FAIL: %s write_enable", name);
            @(posedge clk); #1;
            if (read_data1 !== expected)
                $fatal(1, "FAIL: %s | value=%h expected=%h", name, read_data1, expected);
            $display("PASS: %s | x%0d=%h", name, rd, read_data1);
        end
    endtask

    initial begin
        clk = 0; reset = 1;
        mem_wb_pc = 0; mem_wb_alu_result = 0; mem_wb_load_data = 0; mem_wb_rd = 0; mem_wb_opcode = 0;
        mem_wb_valid = 0; mem_wb_reg_write = 0; mem_wb_wb_sel = 0;
        read_register1 = 0; read_register2 = 0;

        @(posedge clk); #1;
        if (read_data1 !== 0) $fatal(1, "FAIL: RESET");
        $display("PASS: RESET");
        reset = 0;

        issue_write(32'd100, 32'd42, 32'hDEADBEEF, 5'd7, 2'b00, 32'd42,       "ALU -> RF");
        issue_write(32'd104, 32'd32, 32'h80A53344, 5'd5, 2'b01, 32'h80A53344, "LOAD -> RF");
        issue_write(32'd400, 32'hAAAAAAAA, 32'hBBBBBBBB, 5'd1, 2'b10, 32'd404, "PC+4 -> RF");

        @(negedge clk);
        mem_wb_pc = 32'd120; mem_wb_alu_result = 32'hFFFFFFFF; mem_wb_load_data = 0;
        mem_wb_rd = 5'd7; mem_wb_valid = 1; mem_wb_reg_write = 0; mem_wb_wb_sel = 2'b00;
        read_register1 = 5'd7;
        @(posedge clk); #1;
        if (read_data1 !== 32'd42)
            $fatal(1, "FAIL: REGWRITE OFF PRESERVE");
        $display("PASS: REGWRITE OFF PRESERVE");

        @(negedge clk);
        mem_wb_rd = 5'd0; mem_wb_alu_result = 32'hFFFFFFFF; mem_wb_valid = 1; mem_wb_reg_write = 1; mem_wb_wb_sel = 2'b00;
        read_register1 = 5'd0;
        @(posedge clk); #1;
        if (read_data1 !== 0)
            $fatal(1, "FAIL: X0 PROTECTION");
        $display("PASS: X0 PROTECTION");

        $display("PASS: wb_register_file_integration");
        $finish;
    end

endmodule
