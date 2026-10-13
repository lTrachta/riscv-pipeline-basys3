`timescale 1ns / 1ps

module mem_wb_register_tb;

    logic        clk;
    logic        reset;
    logic        enable;
    logic        flush;

    logic [31:0] pc_in;
    logic [31:0] alu_result_in;
    logic [31:0] load_data_in;
    logic [4:0]  rd_in;
    logic [6:0]  opcode_in;
    logic        valid_in;

    logic [31:0] pc_out;
    logic [31:0] alu_result_out;
    logic [31:0] load_data_out;
    logic [4:0]  rd_out;
    logic [6:0]  opcode_out;
    logic        valid_out;


    mem_wb_register dut (
        .clk            (clk),
        .reset          (reset),
        .enable         (enable),
        .flush          (flush),

        .pc_in          (pc_in),
        .alu_result_in  (alu_result_in),
        .load_data_in   (load_data_in),
        .rd_in          (rd_in),
        .opcode_in      (opcode_in),
        .valid_in       (valid_in),

        .pc_out         (pc_out),
        .alu_result_out (alu_result_out),
        .load_data_out  (load_data_out),
        .rd_out         (rd_out),
        .opcode_out     (opcode_out),
        .valid_out      (valid_out)
    );


    always #5 clk = ~clk;


    task automatic check_outputs (
        input logic [31:0] expected_pc,
        input logic [31:0] expected_alu_result,
        input logic [31:0] expected_load_data,
        input logic [4:0]  expected_rd,
        input logic [6:0]  expected_opcode,
        input logic        expected_valid,
        input string       test_name
    );
        begin

            #1;

            if (
                pc_out         !== expected_pc         ||
                alu_result_out !== expected_alu_result ||
                load_data_out  !== expected_load_data  ||
                rd_out         !== expected_rd         ||
                opcode_out     !== expected_opcode     ||
                valid_out      !== expected_valid
            ) begin

                $display("FAIL: %s", test_name);
                $display("  pc_out=%h expected=%h",
                         pc_out, expected_pc);
                $display("  alu_result_out=%h expected=%h",
                         alu_result_out, expected_alu_result);
                $display("  load_data_out=%h expected=%h",
                         load_data_out, expected_load_data);
                $display("  rd_out=%0d expected=%0d",
                         rd_out, expected_rd);
                $display("  opcode_out=%b expected=%b",
                         opcode_out, expected_opcode);
                $display("  valid_out=%b expected=%b",
                         valid_out, expected_valid);

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | pc=%h | alu=%h | load=%h | rd=%0d | valid=%b",
                    test_name,
                    pc_out,
                    alu_result_out,
                    load_data_out,
                    rd_out,
                    valid_out
                );

            end

        end
    endtask


    initial begin

        clk           = 1'b0;
        reset         = 1'b1;
        enable        = 1'b1;
        flush         = 1'b0;

        pc_in         = 32'd0;
        alu_result_in = 32'd0;
        load_data_in  = 32'd0;
        rd_in         = 5'd0;
        opcode_in     = 7'd0;
        valid_in      = 1'b0;


        // =========================================================
        // 1. RESET
        // =========================================================

        @(posedge clk);

        check_outputs(
            32'd0,
            32'd0,
            32'd0,
            5'd0,
            7'd0,
            1'b0,
            "RESET"
        );

        reset = 1'b0;


        // =========================================================
        // 2. CAPTURE LOAD
        //
        // Simulamos:
        // lw x5,...
        // =========================================================

        @(negedge clk);

        enable        = 1'b1;
        flush         = 1'b0;

        pc_in         = 32'd100;
        alu_result_in = 32'd200;
        load_data_in  = 32'hAABBCCDD;
        rd_in         = 5'd5;
        opcode_in     = 7'b0000011;
        valid_in      = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd100,
            32'd200,
            32'hAABBCCDD,
            5'd5,
            7'b0000011,
            1'b1,
            "CAPTURE LOAD"
        );


        // =========================================================
        // 3. HOLD
        //
        // Cambiamos entradas pero enable=0.
        // Debe conservar el load anterior.
        // =========================================================

        @(negedge clk);

        enable        = 1'b0;

        pc_in         = 32'd999;
        alu_result_in = 32'h11111111;
        load_data_in  = 32'h22222222;
        rd_in         = 5'd31;
        opcode_in     = 7'b0110011;
        valid_in      = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd100,
            32'd200,
            32'hAABBCCDD,
            5'd5,
            7'b0000011,
            1'b1,
            "HOLD"
        );


        // =========================================================
        // 4. FLUSH
        //
        // Solo valid_out debe pasar a 0.
        // Los demás datos permanecen.
        // =========================================================

        @(negedge clk);

        enable = 1'b1;
        flush  = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd100,
            32'd200,
            32'hAABBCCDD,
            5'd5,
            7'b0000011,
            1'b0,
            "FLUSH"
        );


        // =========================================================
        // 5. CAPTURE ALU AFTER FLUSH
        //
        // Simulamos un ADD:
        // alu_result será el dato útil para WB.
        // =========================================================

        @(negedge clk);

        flush         = 1'b0;
        enable        = 1'b1;

        pc_in         = 32'd104;
        alu_result_in = 32'd42;
        load_data_in  = 32'hDEADBEEF;
        rd_in         = 5'd7;
        opcode_in     = 7'b0110011;
        valid_in      = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd104,
            32'd42,
            32'hDEADBEEF,
            5'd7,
            7'b0110011,
            1'b1,
            "CAPTURE ALU AFTER FLUSH"
        );


        // =========================================================
        // 6. CAPTURE INVALID / BUBBLE
        //
        // enable=1, pero valid_in=0.
        // Los datos pueden capturarse, pero la entrada es una burbuja.
        // =========================================================

        @(negedge clk);

        pc_in         = 32'd108;
        alu_result_in = 32'h12345678;
        load_data_in  = 32'h87654321;
        rd_in         = 5'd8;
        opcode_in     = 7'b0010011;
        valid_in      = 1'b0;

        @(posedge clk);

        check_outputs(
            32'd108,
            32'h12345678,
            32'h87654321,
            5'd8,
            7'b0010011,
            1'b0,
            "CAPTURE INVALID"
        );


        // =========================================================
        // 7. RESET PRIORITY
        //
        // Activamos reset + flush + enable juntos.
        // Debe ganar reset.
        // =========================================================

        @(negedge clk);

        reset         = 1'b1;
        flush         = 1'b1;
        enable        = 1'b1;

        pc_in         = 32'hFFFFFFFF;
        alu_result_in = 32'hFFFFFFFF;
        load_data_in  = 32'hFFFFFFFF;
        rd_in         = 5'h1F;
        opcode_in     = 7'h7F;
        valid_in      = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd0,
            32'd0,
            32'd0,
            5'd0,
            7'd0,
            1'b0,
            "RESET PRIORITY"
        );


        $display("PASS: mem_wb_register");
        $finish;

    end

endmodule
