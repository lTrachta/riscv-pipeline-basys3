`timescale 1ns / 1ps

module id_ex_register_tb;

    logic clk, reset, enable, flush;
    logic [31:0] pc_in, read_data1_in, read_data2_in, immediate_in;
    logic [4:0] rs1_in, rs2_in, rd_in;
    logic [6:0] opcode_in, funct7_in;
    logic [2:0] funct3_in;
    logic valid_in;
    logic alu_src_a_in, alu_src_b_in;
    logic [2:0] alu_op_in;
    logic branch_in;
    logic [1:0] jump_type_in;
    logic mem_read_in, mem_write_in, reg_write_in;
    logic [1:0] wb_sel_in;

    logic [31:0] pc_out, read_data1_out, read_data2_out, immediate_out;
    logic [4:0] rs1_out, rs2_out, rd_out;
    logic [6:0] opcode_out, funct7_out;
    logic [2:0] funct3_out;
    logic valid_out;
    logic alu_src_a_out, alu_src_b_out;
    logic [2:0] alu_op_out;
    logic branch_out;
    logic [1:0] jump_type_out;
    logic mem_read_out, mem_write_out, reg_write_out;
    logic [1:0] wb_sel_out;

    id_ex_register dut (
        .clk(clk), .reset(reset), .enable(enable), .flush(flush),
        .pc_in(pc_in), .read_data1_in(read_data1_in), .read_data2_in(read_data2_in),
        .immediate_in(immediate_in), .rs1_in(rs1_in), .rs2_in(rs2_in), .rd_in(rd_in),
        .opcode_in(opcode_in), .funct3_in(funct3_in), .funct7_in(funct7_in), .valid_in(valid_in),
        .alu_src_a_in(alu_src_a_in), .alu_src_b_in(alu_src_b_in), .alu_op_in(alu_op_in),
        .branch_in(branch_in), .jump_type_in(jump_type_in),
        .mem_read_in(mem_read_in), .mem_write_in(mem_write_in),
        .reg_write_in(reg_write_in), .wb_sel_in(wb_sel_in),
        .pc_out(pc_out), .read_data1_out(read_data1_out), .read_data2_out(read_data2_out),
        .immediate_out(immediate_out), .rs1_out(rs1_out), .rs2_out(rs2_out), .rd_out(rd_out),
        .opcode_out(opcode_out), .funct3_out(funct3_out), .funct7_out(funct7_out), .valid_out(valid_out),
        .alu_src_a_out(alu_src_a_out), .alu_src_b_out(alu_src_b_out), .alu_op_out(alu_op_out),
        .branch_out(branch_out), .jump_type_out(jump_type_out),
        .mem_read_out(mem_read_out), .mem_write_out(mem_write_out),
        .reg_write_out(reg_write_out), .wb_sel_out(wb_sel_out)
    );

    always #5 clk = ~clk;

    task automatic check_zero_bubble(input string name);
        begin
            #1;
            if (pc_out !== 0 || read_data1_out !== 0 || read_data2_out !== 0 || immediate_out !== 0 ||
                rs1_out !== 0 || rs2_out !== 0 || rd_out !== 0 || opcode_out !== 0 || funct3_out !== 0 ||
                funct7_out !== 0 || valid_out !== 0 || alu_src_a_out !== 0 || alu_src_b_out !== 0 ||
                alu_op_out !== 0 || branch_out !== 0 || jump_type_out !== 0 || mem_read_out !== 0 ||
                mem_write_out !== 0 || reg_write_out !== 0 || wb_sel_out !== 0)
                $fatal(1, "FAIL: %s", name);
            $display("PASS: %s", name);
        end
    endtask

    initial begin
        clk = 0; reset = 1; enable = 1; flush = 0;
        pc_in = 0; read_data1_in = 0; read_data2_in = 0; immediate_in = 0;
        rs1_in = 0; rs2_in = 0; rd_in = 0; opcode_in = 0; funct3_in = 0; funct7_in = 0; valid_in = 0;
        alu_src_a_in = 0; alu_src_b_in = 0; alu_op_in = 0; branch_in = 0; jump_type_in = 0;
        mem_read_in = 0; mem_write_in = 0; reg_write_in = 0; wb_sel_in = 0;

        @(posedge clk); check_zero_bubble("RESET");

        @(negedge clk);
        reset = 0; enable = 1; flush = 0;
        pc_in = 32'd100; read_data1_in = 32'd10; read_data2_in = 32'd20; immediate_in = 32'd12;
        rs1_in = 5'd3; rs2_in = 5'd4; rd_in = 5'd5;
        opcode_in = 7'b0000011; funct3_in = 3'b010; funct7_in = 7'd0; valid_in = 1;
        alu_src_a_in = 0; alu_src_b_in = 1; alu_op_in = 3'b000; branch_in = 0; jump_type_in = 0;
        mem_read_in = 1; mem_write_in = 0; reg_write_in = 1; wb_sel_in = 2'b01;

        @(posedge clk); #1;
        if (pc_out !== 32'd100 || read_data1_out !== 32'd10 || read_data2_out !== 32'd20 ||
            immediate_out !== 32'd12 || rs1_out !== 5'd3 || rs2_out !== 5'd4 || rd_out !== 5'd5 ||
            opcode_out !== 7'b0000011 || funct3_out !== 3'b010 || valid_out !== 1 ||
            mem_read_out !== 1 || mem_write_out !== 0 || reg_write_out !== 1 || wb_sel_out !== 2'b01)
            $fatal(1, "FAIL: CAPTURE");
        $display("PASS: CAPTURE");

        @(negedge clk);
        enable = 0;
        pc_in = 32'd999; rd_in = 5'd31; valid_in = 0;
        @(posedge clk); #1;
        if (pc_out !== 32'd100 || rd_out !== 5'd5 || valid_out !== 1)
            $fatal(1, "FAIL: HOLD");
        $display("PASS: HOLD");

        @(negedge clk);
        flush = 1; enable = 0;
        @(posedge clk); check_zero_bubble("FLUSH CREATES BUBBLE");

        $display("PASS: id_ex_register");
        $finish;
    end

endmodule
