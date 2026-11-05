`timescale 1ns / 1ps

module mem_wb_register_tb;

    logic clk, reset, enable, flush;
    logic [31:0] pc_in, alu_result_in, load_data_in;
    logic [4:0] rd_in;
    logic [6:0] opcode_in;
    logic valid_in, reg_write_in;
    logic [1:0] wb_sel_in;

    logic [31:0] pc_out, alu_result_out, load_data_out;
    logic [4:0] rd_out;
    logic [6:0] opcode_out;
    logic valid_out, reg_write_out;
    logic [1:0] wb_sel_out;

    mem_wb_register dut (
        .clk(clk), .reset(reset), .enable(enable), .flush(flush),
        .pc_in(pc_in), .alu_result_in(alu_result_in), .load_data_in(load_data_in),
        .rd_in(rd_in), .opcode_in(opcode_in), .valid_in(valid_in),
        .reg_write_in(reg_write_in), .wb_sel_in(wb_sel_in),
        .pc_out(pc_out), .alu_result_out(alu_result_out), .load_data_out(load_data_out),
        .rd_out(rd_out), .opcode_out(opcode_out), .valid_out(valid_out),
        .reg_write_out(reg_write_out), .wb_sel_out(wb_sel_out)
    );

    always #5 clk = ~clk;

    task automatic check_zero(input string name);
        begin
            #1;
            if (pc_out !== 0 || alu_result_out !== 0 || load_data_out !== 0 || rd_out !== 0 ||
                opcode_out !== 0 || valid_out !== 0 || reg_write_out !== 0 || wb_sel_out !== 0)
                $fatal(1, "FAIL: %s", name);
            $display("PASS: %s", name);
        end
    endtask

    initial begin
        clk = 0; reset = 1; enable = 1; flush = 0;
        pc_in = 0; alu_result_in = 0; load_data_in = 0; rd_in = 0; opcode_in = 0;
        valid_in = 0; reg_write_in = 0; wb_sel_in = 0;

        @(posedge clk); check_zero("RESET");

        @(negedge clk);
        reset = 0; enable = 1;
        pc_in = 32'd100; alu_result_in = 32'd32; load_data_in = 32'hAABBCCDD;
        rd_in = 5'd5; opcode_in = 7'b0000011; valid_in = 1; reg_write_in = 1; wb_sel_in = 2'b01;

        @(posedge clk); #1;
        if (pc_out !== 32'd100 || alu_result_out !== 32'd32 || load_data_out !== 32'hAABBCCDD ||
            rd_out !== 5'd5 || valid_out !== 1 || reg_write_out !== 1 || wb_sel_out !== 2'b01)
            $fatal(1, "FAIL: CAPTURE");
        $display("PASS: CAPTURE");

        @(negedge clk);
        enable = 0; pc_in = 32'd999; valid_in = 0;
        @(posedge clk); #1;
        if (pc_out !== 32'd100 || rd_out !== 5'd5 || valid_out !== 1)
            $fatal(1, "FAIL: HOLD");
        $display("PASS: HOLD");

        @(negedge clk);
        flush = 1; enable = 0;
        @(posedge clk); check_zero("FLUSH CREATES BUBBLE");

        $display("PASS: mem_wb_register");
        $finish;
    end

endmodule
