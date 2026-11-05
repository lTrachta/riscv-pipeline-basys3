`timescale 1ns / 1ps

module ex_stage_tb;

    logic clk, reset, ex_enable, flush_ex_mem;
    logic id_ex_alu_src_a, id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;
    logic id_ex_branch;
    logic [1:0] id_ex_jump_type;
    logic id_ex_mem_read, id_ex_mem_write, id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;
    logic [31:0] id_ex_pc, id_ex_read_data1, id_ex_read_data2, id_ex_immediate;
    logic [4:0] id_ex_rs2, id_ex_rd;
    logic [6:0] id_ex_opcode, id_ex_funct7;
    logic [2:0] id_ex_funct3;
    logic id_ex_valid;
    logic [1:0] forward_a, forward_b;
    logic [31:0] ex_mem_forward_value, mem_wb_forward_value;

    logic redirect_valid;
    logic [31:0] redirect_target;
    logic [31:0] ex_mem_pc, ex_mem_alu_result, ex_mem_store_data;
    logic [4:0] ex_mem_rs2, ex_mem_rd;
    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;
    logic ex_mem_valid, ex_mem_mem_read, ex_mem_mem_write, ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;

    ex_stage dut (
        .clk(clk), .reset(reset), .ex_enable(ex_enable), .flush_ex_mem(flush_ex_mem),
        .id_ex_alu_src_a(id_ex_alu_src_a), .id_ex_alu_src_b(id_ex_alu_src_b), .id_ex_alu_op(id_ex_alu_op),
        .id_ex_branch(id_ex_branch), .id_ex_jump_type(id_ex_jump_type),
        .id_ex_mem_read(id_ex_mem_read), .id_ex_mem_write(id_ex_mem_write),
        .id_ex_reg_write(id_ex_reg_write), .id_ex_wb_sel(id_ex_wb_sel),
        .id_ex_pc(id_ex_pc), .id_ex_read_data1(id_ex_read_data1), .id_ex_read_data2(id_ex_read_data2),
        .id_ex_immediate(id_ex_immediate), .id_ex_rs2(id_ex_rs2), .id_ex_rd(id_ex_rd),
        .id_ex_opcode(id_ex_opcode), .id_ex_funct3(id_ex_funct3), .id_ex_funct7(id_ex_funct7), .id_ex_valid(id_ex_valid),
        .forward_a(forward_a), .forward_b(forward_b), .ex_mem_forward_value(ex_mem_forward_value),
        .mem_wb_forward_value(mem_wb_forward_value),
        .redirect_valid(redirect_valid), .redirect_target(redirect_target),
        .ex_mem_pc(ex_mem_pc), .ex_mem_alu_result(ex_mem_alu_result), .ex_mem_store_data(ex_mem_store_data),
        .ex_mem_rs2(ex_mem_rs2), .ex_mem_rd(ex_mem_rd), .ex_mem_opcode(ex_mem_opcode),
        .ex_mem_funct3(ex_mem_funct3), .ex_mem_valid(ex_mem_valid),
        .ex_mem_mem_read(ex_mem_mem_read), .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_reg_write(ex_mem_reg_write), .ex_mem_wb_sel(ex_mem_wb_sel)
    );

    always #5 clk = ~clk;

    task automatic set_common;
        begin
            ex_enable = 1; flush_ex_mem = 0;
            id_ex_branch = 0; id_ex_jump_type = 0; id_ex_mem_read = 0; id_ex_mem_write = 0;
            id_ex_reg_write = 1; id_ex_wb_sel = 0; id_ex_rs2 = 5'd4; id_ex_rd = 5'd7;
            id_ex_opcode = 7'b0110011; id_ex_funct3 = 3'b000; id_ex_funct7 = 7'b0000000; id_ex_valid = 1;
            forward_a = 0; forward_b = 0; ex_mem_forward_value = 0; mem_wb_forward_value = 0;
        end
    endtask

    initial begin
        clk = 0; reset = 1; ex_enable = 1; flush_ex_mem = 0;
        id_ex_alu_src_a = 0; id_ex_alu_src_b = 0; id_ex_alu_op = 0; id_ex_branch = 0; id_ex_jump_type = 0;
        id_ex_mem_read = 0; id_ex_mem_write = 0; id_ex_reg_write = 0; id_ex_wb_sel = 0;
        id_ex_pc = 0; id_ex_read_data1 = 0; id_ex_read_data2 = 0; id_ex_immediate = 0;
        id_ex_rs2 = 0; id_ex_rd = 0; id_ex_opcode = 0; id_ex_funct3 = 0; id_ex_funct7 = 0; id_ex_valid = 0;
        forward_a = 0; forward_b = 0; ex_mem_forward_value = 0; mem_wb_forward_value = 0;

        @(posedge clk); #1;
        if (ex_mem_valid !== 0 || ex_mem_pc !== 0) $fatal(1, "FAIL: RESET");
        $display("PASS: RESET");
        reset = 0;

        // Basic R-type ADD.
        @(negedge clk);
        set_common();
        id_ex_alu_src_a = 0; id_ex_alu_src_b = 0; id_ex_alu_op = 3'b010;
        id_ex_pc = 32'd100; id_ex_read_data1 = 32'd25; id_ex_read_data2 = 32'd17; id_ex_immediate = 0;
        @(posedge clk); #1;
        if (ex_mem_alu_result !== 32'd42 || ex_mem_store_data !== 32'd17 || ex_mem_valid !== 1 || ex_mem_reg_write !== 1)
            $fatal(1, "FAIL: ADD");
        $display("PASS: ADD");

        // Mixed forwarding: A from EX/MEM, B from MEM/WB.
        @(negedge clk);
        set_common();
        id_ex_alu_src_a = 0; id_ex_alu_src_b = 0; id_ex_alu_op = 3'b010;
        id_ex_pc = 32'd104; id_ex_read_data1 = 32'd1; id_ex_read_data2 = 32'd2;
        forward_a = 2'b10; forward_b = 2'b01; ex_mem_forward_value = 32'd30; mem_wb_forward_value = 32'd12;
        @(posedge clk); #1;
        if (ex_mem_alu_result !== 32'd42 || ex_mem_store_data !== 32'd12)
            $fatal(1, "FAIL: FORWARDING");
        $display("PASS: FORWARDING");

        // BEQ resolves in EX and redirects to PC+imm.
        @(negedge clk);
        set_common();
        id_ex_reg_write = 0; id_ex_alu_op = 3'b001; id_ex_branch = 1; id_ex_jump_type = 0;
        id_ex_pc = 32'd200; id_ex_read_data1 = 32'd9; id_ex_read_data2 = 32'd9; id_ex_immediate = 32'd16;
        id_ex_opcode = 7'b1100011; id_ex_funct3 = 3'b000;
        #1;
        if (!redirect_valid || redirect_target !== 32'd216)
            $fatal(1, "FAIL: BEQ REDIRECT");
        $display("PASS: BEQ REDIRECT");
        @(posedge clk); #1;

        // JALR uses forwarded rs1 + imm and clears target bit 0.
        @(negedge clk);
        set_common();
        id_ex_alu_src_a = 0; id_ex_alu_src_b = 1; id_ex_alu_op = 3'b000;
        id_ex_jump_type = 2'b10; id_ex_reg_write = 1; id_ex_wb_sel = 2'b10;
        id_ex_pc = 32'd204; id_ex_read_data1 = 32'd101; id_ex_read_data2 = 0; id_ex_immediate = 32'd4;
        id_ex_opcode = 7'b1100111; id_ex_funct3 = 3'b000;
        #1;
        if (!redirect_valid || redirect_target !== 32'd104)
            $fatal(1, "FAIL: JALR TARGET");
        $display("PASS: JALR TARGET ALIGNMENT");
        @(posedge clk); #1;

        // Flush neutralizes EX/MEM.
        @(negedge clk);
        flush_ex_mem = 1; ex_enable = 0;
        @(posedge clk); #1;
        if (ex_mem_valid !== 0 || ex_mem_pc !== 0 || ex_mem_alu_result !== 0 || ex_mem_reg_write !== 0 || ex_mem_mem_write !== 0)
            $fatal(1, "FAIL: FLUSH");
        $display("PASS: FLUSH CREATES BUBBLE");

        $display("PASS: ex_stage");
        $finish;
    end

endmodule
