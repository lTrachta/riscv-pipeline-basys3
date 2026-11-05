`timescale 1ns / 1ps

module mem_stage_tb;

    logic clk, reset, mem_enable, flush_mem_wb;
    logic [31:0] ex_mem_pc, ex_mem_alu_result, ex_mem_store_data;
    logic [4:0] ex_mem_rs2, ex_mem_rd;
    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;
    logic ex_mem_valid, ex_mem_mem_read, ex_mem_mem_write, ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;
    logic wb_write_enable;
    logic [4:0] wb_write_register;
    logic [31:0] wb_write_data;

    logic [31:0] mem_wb_pc, mem_wb_alu_result, mem_wb_load_data;
    logic [4:0] mem_wb_rd;
    logic [6:0] mem_wb_opcode;
    logic mem_wb_valid, mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;

    mem_stage #(.DATA_MEM_DEPTH(256)) dut (
        .clk(clk), .reset(reset), .mem_enable(mem_enable), .flush_mem_wb(flush_mem_wb),
        .ex_mem_pc(ex_mem_pc), .ex_mem_alu_result(ex_mem_alu_result), .ex_mem_store_data(ex_mem_store_data),
        .ex_mem_rs2(ex_mem_rs2), .ex_mem_rd(ex_mem_rd), .ex_mem_opcode(ex_mem_opcode),
        .ex_mem_funct3(ex_mem_funct3), .ex_mem_valid(ex_mem_valid),
        .ex_mem_mem_read(ex_mem_mem_read), .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_reg_write(ex_mem_reg_write), .ex_mem_wb_sel(ex_mem_wb_sel),
        .wb_write_enable(wb_write_enable), .wb_write_register(wb_write_register), .wb_write_data(wb_write_data),
        .mem_wb_pc(mem_wb_pc), .mem_wb_alu_result(mem_wb_alu_result), .mem_wb_load_data(mem_wb_load_data),
        .mem_wb_rd(mem_wb_rd), .mem_wb_opcode(mem_wb_opcode), .mem_wb_valid(mem_wb_valid),
        .mem_wb_reg_write(mem_wb_reg_write), .mem_wb_wb_sel(mem_wb_wb_sel)
    );

    always #5 clk = ~clk;

    task automatic drive_store(
        input logic [31:0] pc,
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [4:0] rs2,
        input string name
    );
        begin
            @(negedge clk);
            ex_mem_pc = pc; ex_mem_alu_result = address; ex_mem_store_data = data;
            ex_mem_rs2 = rs2; ex_mem_rd = 0; ex_mem_opcode = 7'b0100011; ex_mem_funct3 = 3'b010;
            ex_mem_valid = 1; ex_mem_mem_read = 0; ex_mem_mem_write = 1;
            ex_mem_reg_write = 0; ex_mem_wb_sel = 2'b00;
            @(posedge clk); #1;
            if (!mem_wb_valid || mem_wb_reg_write)
                $fatal(1, "FAIL: %s", name);
            $display("PASS: %s", name);
        end
    endtask

    task automatic drive_load(
        input logic [31:0] pc,
        input logic [31:0] address,
        input logic [4:0] rd,
        input logic [31:0] expected,
        input string name
    );
        begin
            @(negedge clk);
            wb_write_enable = 0;
            ex_mem_pc = pc; ex_mem_alu_result = address; ex_mem_store_data = 0;
            ex_mem_rs2 = 0; ex_mem_rd = rd; ex_mem_opcode = 7'b0000011; ex_mem_funct3 = 3'b010;
            ex_mem_valid = 1; ex_mem_mem_read = 1; ex_mem_mem_write = 0;
            ex_mem_reg_write = 1; ex_mem_wb_sel = 2'b01;
            @(posedge clk); #1;
            if (!mem_wb_valid || mem_wb_load_data !== expected || !mem_wb_reg_write || mem_wb_wb_sel !== 2'b01)
                $fatal(1, "FAIL: %s | data=%h expected=%h valid=%b", name, mem_wb_load_data, expected, mem_wb_valid);
            $display("PASS: %s | data=%h", name, mem_wb_load_data);
        end
    endtask

    initial begin
        clk = 0; reset = 1; mem_enable = 1; flush_mem_wb = 0;
        ex_mem_pc = 0; ex_mem_alu_result = 0; ex_mem_store_data = 0; ex_mem_rs2 = 0; ex_mem_rd = 0;
        ex_mem_opcode = 0; ex_mem_funct3 = 0; ex_mem_valid = 0; ex_mem_mem_read = 0; ex_mem_mem_write = 0;
        ex_mem_reg_write = 0; ex_mem_wb_sel = 0;
        wb_write_enable = 0; wb_write_register = 0; wb_write_data = 0;

        @(posedge clk); #1;
        if (mem_wb_valid !== 0) $fatal(1, "FAIL: RESET");
        $display("PASS: RESET");
        reset = 0;

        drive_store(32'd100, 32'h20, 32'hAABBCCDD, 5'd5, "SW DIRECT");
        drive_load (32'd104, 32'h20, 5'd6, 32'hAABBCCDD, "LW AFTER SW");

        @(negedge clk);
        wb_write_enable = 1; wb_write_register = 5'd7; wb_write_data = 32'h12345678;
        ex_mem_pc = 32'd108; ex_mem_alu_result = 32'h24; ex_mem_store_data = 32'h11111111;
        ex_mem_rs2 = 5'd7; ex_mem_rd = 0; ex_mem_opcode = 7'b0100011; ex_mem_funct3 = 3'b010;
        ex_mem_valid = 1; ex_mem_mem_read = 0; ex_mem_mem_write = 1; ex_mem_reg_write = 0; ex_mem_wb_sel = 0;
        @(posedge clk); #1;
        $display("PASS: WB -> STORE DATA FORWARD");

        drive_load(32'd112, 32'h24, 5'd8, 32'h12345678, "LW AFTER FORWARDED SW");

        @(negedge clk);
        ex_mem_pc = 32'd116; ex_mem_alu_result = 32'h22; ex_mem_rd = 5'd9;
        ex_mem_opcode = 7'b0000011; ex_mem_funct3 = 3'b010; ex_mem_valid = 1;
        ex_mem_mem_read = 1; ex_mem_mem_write = 0; ex_mem_reg_write = 1; ex_mem_wb_sel = 2'b01;
        @(posedge clk); #1;
        if (mem_wb_valid !== 0)
            $fatal(1, "FAIL: MISALIGNED LW SHOULD BE INVALID");
        $display("PASS: MISALIGNED LW BLOCKED");

        @(negedge clk);
        flush_mem_wb = 1;
        @(posedge clk); #1;
        if (mem_wb_valid !== 0 || mem_wb_reg_write !== 0 || mem_wb_pc !== 0)
            $fatal(1, "FAIL: FLUSH");
        $display("PASS: FLUSH");

        $display("PASS: mem_stage");
        $finish;
    end

endmodule
