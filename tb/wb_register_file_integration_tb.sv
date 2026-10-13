`timescale 1ns / 1ps

module wb_register_file_integration_tb;

    logic clk;
    logic reset;

    // ---------------------------------------------------------
    // Entrada simulada desde MEM/WB
    // ---------------------------------------------------------

    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;
    logic [4:0]  mem_wb_rd;
    logic [6:0]  mem_wb_opcode;
    logic        mem_wb_valid;

    // ---------------------------------------------------------
    // Salida de WB
    // ---------------------------------------------------------

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;

    // ---------------------------------------------------------
    // Puertos de lectura del Register File
    // ---------------------------------------------------------

    logic [4:0]  read_register1;
    logic [4:0]  read_register2;
    logic [31:0] read_data1;
    logic [31:0] read_data2;


    localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU  = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;


    // =========================================================
    // WB STAGE
    // =========================================================

    wb_stage wb_dut (
        .mem_wb_pc         (mem_wb_pc),
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_load_data  (mem_wb_load_data),
        .mem_wb_rd         (mem_wb_rd),
        .mem_wb_opcode     (mem_wb_opcode),
        .mem_wb_valid      (mem_wb_valid),

        .wb_write_enable   (wb_write_enable),
        .wb_write_register (wb_write_register),
        .wb_write_data     (wb_write_data)
    );


    // =========================================================
    // REGISTER FILE
    // =========================================================

    register_file register_file_dut (
        .clk             (clk),
        .reset           (reset),

        .read_register1  (read_register1),
        .read_register2  (read_register2),

        .write_enable    (wb_write_enable),
        .write_register  (wb_write_register),
        .write_data      (wb_write_data),

        .read_data1      (read_data1),
        .read_data2      (read_data2)
    );


    always #5 clk = ~clk;


    // =========================================================
    // WRITES REGISTER
    // =========================================================

    task automatic issue_write (
        input logic [31:0] test_pc,
        input logic [31:0] test_alu_result,
        input logic [31:0] test_load_data,
        input logic [4:0]  test_rd,
        input logic [6:0]  test_opcode,
        input logic        test_valid,

        input logic [31:0] expected_value,
        input string       test_name
    );
        begin

            @(negedge clk);

            mem_wb_pc         = test_pc;
            mem_wb_alu_result = test_alu_result;
            mem_wb_load_data  = test_load_data;
            mem_wb_rd         = test_rd;
            mem_wb_opcode     = test_opcode;
            mem_wb_valid      = test_valid;

            read_register1    = test_rd;

            #1;

            if (wb_write_enable !== 1'b1) begin
                $display("FAIL: %s - write_enable should be 1", test_name);
                $fatal;
            end

            @(posedge clk);
            #1;

            if (read_data1 !== expected_value) begin

                $display("FAIL: %s", test_name);
                $display(
                    "  x%0d=%h expected=%h",
                    test_rd,
                    read_data1,
                    expected_value
                );

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | x%0d=%h",
                    test_name,
                    test_rd,
                    read_data1
                );

            end

        end
    endtask


    // =========================================================
    // DOES NOT WRITE REGISTER
    // =========================================================

    task automatic issue_no_write (
        input logic [31:0] test_pc,
        input logic [31:0] test_alu_result,
        input logic [31:0] test_load_data,
        input logic [4:0]  test_rd,
        input logic [6:0]  test_opcode,
        input logic        test_valid,

        input logic [31:0] expected_old_value,
        input string       test_name
    );
        begin

            @(negedge clk);

            mem_wb_pc         = test_pc;
            mem_wb_alu_result = test_alu_result;
            mem_wb_load_data  = test_load_data;
            mem_wb_rd         = test_rd;
            mem_wb_opcode     = test_opcode;
            mem_wb_valid      = test_valid;

            read_register1    = test_rd;

            #1;

            if (wb_write_enable !== 1'b0) begin
                $display("FAIL: %s - write_enable should be 0", test_name);
                $fatal;
            end

            @(posedge clk);
            #1;

            if (read_data1 !== expected_old_value) begin

                $display("FAIL: %s", test_name);
                $display(
                    "  x%0d=%h expected unchanged=%h",
                    test_rd,
                    read_data1,
                    expected_old_value
                );

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | x%0d preserved=%h",
                    test_name,
                    test_rd,
                    read_data1
                );

            end

        end
    endtask


    initial begin

        clk               = 1'b0;
        reset             = 1'b1;

        mem_wb_pc         = 32'd0;
        mem_wb_alu_result = 32'd0;
        mem_wb_load_data  = 32'd0;
        mem_wb_rd         = 5'd0;
        mem_wb_opcode     = 7'd0;
        mem_wb_valid      = 1'b0;

        read_register1    = 5'd0;
        read_register2    = 5'd0;


        // =========================================================
        // 1. RESET REGISTER FILE
        // =========================================================

        @(posedge clk);
        #1;

        reset = 1'b0;

        if (read_data1 !== 32'd0) begin
            $display("FAIL: RESET");
            $fatal;
        end

        $display("PASS: RESET");


        // =========================================================
        // 2. R-TYPE
        //
        // x7 <- 42
        // =========================================================

        issue_write(
            32'd100,
            32'd42,
            32'hDEADBEEF,
            5'd7,
            OPCODE_R,
            1'b1,

            32'd42,
            "R-TYPE WRITES X7"
        );


        // =========================================================
        // 3. I-ALU
        //
        // x8 <- 12345678
        // =========================================================

        issue_write(
            32'd104,
            32'h12345678,
            32'hAAAAAAAA,
            5'd8,
            OPCODE_I_ALU,
            1'b1,

            32'h12345678,
            "I-ALU WRITES X8"
        );


        // =========================================================
        // 4. LOAD
        //
        // Debe escribir load_data, no alu_result.
        //
        // x5 <- 80A53344
        // =========================================================

        issue_write(
            32'd108,
            32'h00000020,
            32'h80A53344,
            5'd5,
            OPCODE_LOAD,
            1'b1,

            32'h80A53344,
            "LOAD WRITES X5"
        );


        // =========================================================
        // 5. LUI
        //
        // x9 <- 12345000
        // =========================================================

        issue_write(
            32'd112,
            32'h12345000,
            32'hBBBBBBBB,
            5'd9,
            OPCODE_LUI,
            1'b1,

            32'h12345000,
            "LUI WRITES X9"
        );


        // =========================================================
        // 6. JAL
        //
        // PC=400
        // x1 <- 404
        // =========================================================

        issue_write(
            32'd400,
            32'hAAAAAAAA,
            32'hBBBBBBBB,
            5'd1,
            OPCODE_JAL,
            1'b1,

            32'd404,
            "JAL WRITES LINK X1"
        );


        // =========================================================
        // 7. JALR
        //
        // PC=1000
        // x2 <- 1004
        // =========================================================

        issue_write(
            32'd1000,
            32'hCCCCCCCC,
            32'hDDDDDDDD,
            5'd2,
            OPCODE_JALR,
            1'b1,

            32'd1004,
            "JALR WRITES LINK X2"
        );


        // =========================================================
        // 8. STORE
        //
        // x12 inicialmente es 0.
        // Store no debe modificarlo.
        // =========================================================

        issue_no_write(
            32'd120,
            32'hFFFFFFFF,
            32'hAAAAAAAA,
            5'd12,
            OPCODE_STORE,
            1'b1,

            32'd0,
            "STORE DOES NOT WRITE X12"
        );


        // =========================================================
        // 9. BRANCH
        //
        // x13 debe permanecer 0.
        // =========================================================

        issue_no_write(
            32'd124,
            32'hFFFFFFFF,
            32'hAAAAAAAA,
            5'd13,
            OPCODE_BRANCH,
            1'b1,

            32'd0,
            "BRANCH DOES NOT WRITE X13"
        );


        // =========================================================
        // 10. BURBUJA
        //
        // Parece LOAD pero valid=0.
        // x10 debe permanecer 0.
        // =========================================================

        issue_no_write(
            32'd128,
            32'h00000020,
            32'hCAFEBABE,
            5'd10,
            OPCODE_LOAD,
            1'b0,

            32'd0,
            "BUBBLE DOES NOT WRITE X10"
        );


        // =========================================================
        // 11. X0
        //
        // WB debe bloquearlo y además Register File protege x0.
        // =========================================================

        issue_no_write(
            32'd132,
            32'd57,
            32'hAAAAAAAA,
            5'd0,
            OPCODE_R,
            1'b1,

            32'd0,
            "X0 REMAINS ZERO"
        );


        // =========================================================
        // 12. OPCODE INVÁLIDO
        //
        // x20 debe permanecer 0.
        // =========================================================

        issue_no_write(
            32'd136,
            32'hDEADBEEF,
            32'hCAFEBABE,
            5'd20,
            7'b1111111,
            1'b1,

            32'd0,
            "INVALID OPCODE DOES NOT WRITE X20"
        );


        // =========================================================
        // 13. VERIFICACIÓN DE UN REGISTRO PREVIAMENTE ESCRITO
        //
        // Comprobamos que x7 conserva 42.
        // =========================================================

        read_register1 = 5'd7;
        #1;

        if (read_data1 !== 32'd42) begin

            $display(
                "FAIL: X7 PRESERVED | value=%h",
                read_data1
            );

            $fatal;

        end

        $display(
            "PASS: X7 PRESERVED | value=%h",
            read_data1
        );


        $display("PASS: wb_register_file_integration");
        $finish;

    end

endmodule
