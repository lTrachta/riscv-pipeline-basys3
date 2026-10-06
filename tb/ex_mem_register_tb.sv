`timescale 1ns / 1ps

module ex_mem_register_tb;

    logic        clk;
    logic        reset;
    logic        enable;
    logic        flush;

    logic [31:0] pc_in;
    logic [31:0] alu_result_in;
    logic [31:0] store_data_in;
    logic [4:0]  rd_in;
    logic [6:0]  opcode_in;
    logic [2:0]  funct3_in;
    logic        valid_in;

    logic [31:0] pc_out;
    logic [31:0] alu_result_out;
    logic [31:0] store_data_out;
    logic [4:0]  rd_out;
    logic [6:0]  opcode_out;
    logic [2:0]  funct3_out;
    logic        valid_out;

    ex_mem_register dut (
        .clk             (clk),
        .reset           (reset),
        .enable          (enable),
        .flush           (flush),

        .pc_in           (pc_in),
        .alu_result_in   (alu_result_in),
        .store_data_in   (store_data_in),
        .rd_in           (rd_in),
        .opcode_in       (opcode_in),
        .funct3_in       (funct3_in),
        .valid_in        (valid_in),

        .pc_out          (pc_out),
        .alu_result_out  (alu_result_out),
        .store_data_out  (store_data_out),
        .rd_out          (rd_out),
        .opcode_out      (opcode_out),
        .funct3_out      (funct3_out),
        .valid_out       (valid_out)
    );

    always #5 clk = ~clk;

    task automatic check_outputs (
        input logic [31:0] expected_pc,
        input logic [31:0] expected_alu_result,
        input logic [31:0] expected_store_data,
        input logic [4:0]  expected_rd,
        input logic [6:0]  expected_opcode,
        input logic [2:0]  expected_funct3,
        input logic        expected_valid,
        input string       test_name
    );
        begin
            #1;

            if (
                pc_out         !== expected_pc         ||
                alu_result_out !== expected_alu_result ||
                store_data_out !== expected_store_data ||
                rd_out         !== expected_rd         ||
                opcode_out     !== expected_opcode     ||
                funct3_out     !== expected_funct3     ||
                valid_out      !== expected_valid
            ) begin

                $display("FAIL: %s", test_name);
                $display("  pc_out=%h expected=%h", pc_out, expected_pc);
                $display("  alu_result_out=%h expected=%h",
                         alu_result_out, expected_alu_result);
                $display("  store_data_out=%h expected=%h",
                         store_data_out, expected_store_data);
                $display("  rd_out=%0d expected=%0d", rd_out, expected_rd);
                $display("  opcode_out=%b expected=%b",
                         opcode_out, expected_opcode);
                $display("  funct3_out=%b expected=%b",
                         funct3_out, expected_funct3);
                $display("  valid_out=%b expected=%b",
                         valid_out, expected_valid);

                $fatal;
            end
            else begin
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin

        clk             = 1'b0;
        reset           = 1'b0;
        enable          = 1'b0;
        flush           = 1'b0;

        pc_in           = 32'd0;
        alu_result_in   = 32'd0;
        store_data_in   = 32'd0;
        rd_in           = 5'd0;
        opcode_in       = 7'd0;
        funct3_in       = 3'd0;
        valid_in        = 1'b0;


        // =========================================================
        // RESET
        // =========================================================

        reset = 1'b1;

        @(posedge clk);
        check_outputs(
            32'd0,
            32'd0,
            32'd0,
            5'd0,
            7'd0,
            3'd0,
            1'b0,
            "RESET"
        );

        reset = 1'b0;


        // =========================================================
        // CAPTURE
        // Simulamos por ejemplo un SW
        // =========================================================

        enable        = 1'b1;
        flush         = 1'b0;

        pc_in         = 32'd100;
        alu_result_in = 32'd1012;
        store_data_in = 32'd777;
        rd_in         = 5'd0;
        opcode_in     = 7'b0100011;
        funct3_in     = 3'b010;
        valid_in      = 1'b1;

        @(posedge clk);
        check_outputs(
            32'd100,
            32'd1012,
            32'd777,
            5'd0,
            7'b0100011,
            3'b010,
            1'b1,
            "CAPTURE"
        );


        // =========================================================
        // HOLD
        // Cambiamos entradas, pero enable=0
        // Las salidas deben conservar valores anteriores
        // =========================================================

        enable        = 1'b0;

        pc_in         = 32'd200;
        alu_result_in = 32'd9999;
        store_data_in = 32'd1234;
        rd_in         = 5'd7;
        opcode_in     = 7'b0110011;
        funct3_in     = 3'b000;
        valid_in      = 1'b1;

        @(posedge clk);
        check_outputs(
            32'd100,
            32'd1012,
            32'd777,
            5'd0,
            7'b0100011,
            3'b010,
            1'b1,
            "HOLD"
        );


        // =========================================================
        // FLUSH
        // Solo valid debe pasar a 0
        // Los demás datos quedan como estaban
        // =========================================================

        flush = 1'b1;

        @(posedge clk);
        check_outputs(
            32'd100,
            32'd1012,
            32'd777,
            5'd0,
            7'b0100011,
            3'b010,
            1'b0,
            "FLUSH"
        );

        flush = 1'b0;


        // =========================================================
        // NEW CAPTURE AFTER FLUSH
        // =========================================================

        enable        = 1'b1;

        pc_in         = 32'd300;
        alu_result_in = 32'd42;
        store_data_in = 32'd17;
        rd_in         = 5'd7;
        opcode_in     = 7'b0110011;
        funct3_in     = 3'b000;
        valid_in      = 1'b1;

        @(posedge clk);
        check_outputs(
            32'd300,
            32'd42,
            32'd17,
            5'd7,
            7'b0110011,
            3'b000,
            1'b1,
            "CAPTURE AFTER FLUSH"
        );


        // =========================================================
        // RESET PRIORITY
        // reset debe ganar incluso si flush=1 y enable=1
        // =========================================================

        reset         = 1'b1;
        flush         = 1'b1;
        enable        = 1'b1;

        pc_in         = 32'hFFFFFFFF;
        alu_result_in = 32'hFFFFFFFF;
        store_data_in = 32'hFFFFFFFF;
        rd_in         = 5'b11111;
        opcode_in     = 7'b1111111;
        funct3_in     = 3'b111;
        valid_in      = 1'b1;

        @(posedge clk);
        check_outputs(
            32'd0,
            32'd0,
            32'd0,
            5'd0,
            7'd0,
            3'd0,
            1'b0,
            "RESET PRIORITY"
        );

        $display("PASS: ex_mem_register");
        $finish;

    end

endmodule
