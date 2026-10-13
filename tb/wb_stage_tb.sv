`timescale 1ns / 1ps

module wb_stage_tb;

    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;
    logic [4:0]  mem_wb_rd;
    logic [6:0]  mem_wb_opcode;
    logic        mem_wb_valid;

    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;


    localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I_ALU  = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;


    wb_stage dut (
        .mem_wb_pc             (mem_wb_pc),
        .mem_wb_alu_result     (mem_wb_alu_result),
        .mem_wb_load_data      (mem_wb_load_data),
        .mem_wb_rd             (mem_wb_rd),
        .mem_wb_opcode         (mem_wb_opcode),
        .mem_wb_valid          (mem_wb_valid),

        .wb_write_enable       (wb_write_enable),
        .wb_write_register     (wb_write_register),
        .wb_write_data         (wb_write_data)
    );


    task automatic check_case (
        input logic [31:0] test_pc,
        input logic [31:0] test_alu_result,
        input logic [31:0] test_load_data,
        input logic [4:0]  test_rd,
        input logic [6:0]  test_opcode,
        input logic        test_valid,

        input logic        expected_write_enable,
        input logic [4:0]  expected_write_register,
        input logic [31:0] expected_write_data,

        input string       test_name
    );
        begin

            mem_wb_pc         = test_pc;
            mem_wb_alu_result = test_alu_result;
            mem_wb_load_data  = test_load_data;
            mem_wb_rd         = test_rd;
            mem_wb_opcode     = test_opcode;
            mem_wb_valid      = test_valid;

            #1;

            if (
                wb_write_enable   !== expected_write_enable   ||
                wb_write_register !== expected_write_register ||
                wb_write_data     !== expected_write_data
            ) begin

                $display("FAIL: %s", test_name);

                $display(
                    "  write_enable=%b expected=%b",
                    wb_write_enable,
                    expected_write_enable
                );

                $display(
                    "  write_register=%0d expected=%0d",
                    wb_write_register,
                    expected_write_register
                );

                $display(
                    "  write_data=%h expected=%h",
                    wb_write_data,
                    expected_write_data
                );

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | enable=%b | rd=%0d | data=%h",
                    test_name,
                    wb_write_enable,
                    wb_write_register,
                    wb_write_data
                );

            end

        end
    endtask


    initial begin

        mem_wb_pc         = 32'd0;
        mem_wb_alu_result = 32'd0;
        mem_wb_load_data  = 32'd0;
        mem_wb_rd         = 5'd0;
        mem_wb_opcode     = 7'd0;
        mem_wb_valid      = 1'b0;

        #1;


        // =========================================================
        // 1. R-TYPE
        //
        // add x7,...
        // Debe seleccionar alu_result.
        // =========================================================

        check_case(
            32'd100,
            32'd42,
            32'hDEADBEEF,
            5'd7,
            OPCODE_R,
            1'b1,

            1'b1,
            5'd7,
            32'd42,

            "R-TYPE ALU RESULT"
        );


        // =========================================================
        // 2. I-TYPE ALU
        //
        // addi x8,...
        // =========================================================

        check_case(
            32'd104,
            32'h12345678,
            32'hAAAAAAAA,
            5'd8,
            OPCODE_I_ALU,
            1'b1,

            1'b1,
            5'd8,
            32'h12345678,

            "I-ALU RESULT"
        );


        // =========================================================
        // 3. LUI
        //
        // En nuestro diseño el resultado ya viene desde la ALU.
        // =========================================================

        check_case(
            32'd108,
            32'h12345000,
            32'hBBBBBBBB,
            5'd9,
            OPCODE_LUI,
            1'b1,

            1'b1,
            5'd9,
            32'h12345000,

            "LUI ALU RESULT"
        );


        // =========================================================
        // 4. LOAD
        //
        // Debe seleccionar load_data y NO alu_result.
        //
        // alu_result representa aquí la dirección efectiva.
        // =========================================================

        check_case(
            32'd112,
            32'h00000020,
            32'h80A53344,
            5'd5,
            OPCODE_LOAD,
            1'b1,

            1'b1,
            5'd5,
            32'h80A53344,

            "LOAD MEMORY DATA"
        );


        // =========================================================
        // 5. JAL
        //
        // PC = 400
        // rd <- PC + 4 = 404
        // =========================================================

        check_case(
            32'd400,
            32'hAAAAAAAA,
            32'hBBBBBBBB,
            5'd1,
            OPCODE_JAL,
            1'b1,

            1'b1,
            5'd1,
            32'd404,

            "JAL PC PLUS 4"
        );


        // =========================================================
        // 6. JALR
        //
        // PC = 1000
        // rd <- 1004
        // =========================================================

        check_case(
            32'd1000,
            32'hCCCCCCCC,
            32'hDDDDDDDD,
            5'd1,
            OPCODE_JALR,
            1'b1,

            1'b1,
            5'd1,
            32'd1004,

            "JALR PC PLUS 4"
        );


        // =========================================================
        // 7. STORE
        //
        // No escribe Register File.
        //
        // write_data sigue siendo combinacional y puede mostrar
        // alu_result. Lo importante es enable = 0.
        // =========================================================

        check_case(
            32'd120,
            32'h00000040,
            32'hAAAAAAAA,
            5'd0,
            OPCODE_STORE,
            1'b1,

            1'b0,
            5'd0,
            32'h00000040,

            "STORE NO REGISTER WRITE"
        );


        // =========================================================
        // 8. BRANCH
        //
        // No escribe Register File.
        // =========================================================

        check_case(
            32'd124,
            32'h00000000,
            32'hAAAAAAAA,
            5'd15,
            OPCODE_BRANCH,
            1'b1,

            1'b0,
            5'd15,
            32'h00000000,

            "BRANCH NO REGISTER WRITE"
        );


        // =========================================================
        // 9. BURBUJA
        //
        // Opcode de LOAD pero valid=0.
        //
        // No debe escribir.
        // =========================================================

        check_case(
            32'd128,
            32'h00000020,
            32'hCAFEBABE,
            5'd10,
            OPCODE_LOAD,
            1'b0,

            1'b0,
            5'd10,
            32'hCAFEBABE,

            "INVALID BUBBLE"
        );


        // =========================================================
        // 10. RD = X0
        //
        // Instrucción R válida, pero destino x0.
        //
        // No produce modificación arquitectónica.
        // =========================================================

        check_case(
            32'd132,
            32'd57,
            32'hAAAAAAAA,
            5'd0,
            OPCODE_R,
            1'b1,

            1'b0,
            5'd0,
            32'd57,

            "RD X0 BLOCKED"
        );


        // =========================================================
        // 11. JAL CON RD = X0
        //
        // Caso típico de jump sin guardar link.
        //
        // PC+4 se calcula, pero no hay escritura real.
        // =========================================================

        check_case(
            32'd200,
            32'hAAAAAAAA,
            32'hBBBBBBBB,
            5'd0,
            OPCODE_JAL,
            1'b1,

            1'b0,
            5'd0,
            32'd204,

            "JAL X0 NO LINK WRITE"
        );


        // =========================================================
        // 12. OPCODE INVÁLIDO
        //
        // No escribe.
        // =========================================================

        check_case(
            32'd300,
            32'hDEADBEEF,
            32'hCAFEBABE,
            5'd20,
            7'b1111111,
            1'b1,

            1'b0,
            5'd20,
            32'hDEADBEEF,

            "INVALID OPCODE"
        );


        $display("PASS: wb_stage");
        $finish;

    end

endmodule
