`timescale 1ns / 1ps

module ex_stage_tb;

    logic        clk;
    logic        reset;
    logic        ex_enable;
    logic        flush_ex_mem;

    logic        alu_src_a;
    logic        alu_src_b;

    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;
    logic [31:0] id_ex_immediate;
    logic [4:0]  id_ex_rd;
    logic [6:0]  id_ex_opcode;
    logic [2:0]  id_ex_funct3;
    logic [6:0]  id_ex_funct7;
    logic        id_ex_valid;

    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [4:0]  ex_mem_rd;
    logic [6:0]  ex_mem_opcode;
    logic [2:0]  ex_mem_funct3;
    logic        ex_mem_valid;


    ex_stage dut (
        .clk                (clk),
        .reset              (reset),
        .ex_enable          (ex_enable),
        .flush_ex_mem       (flush_ex_mem),

        .alu_src_a          (alu_src_a),
        .alu_src_b          (alu_src_b),

        .id_ex_pc           (id_ex_pc),
        .id_ex_read_data1   (id_ex_read_data1),
        .id_ex_read_data2   (id_ex_read_data2),
        .id_ex_immediate    (id_ex_immediate),
        .id_ex_rd           (id_ex_rd),
        .id_ex_opcode       (id_ex_opcode),
        .id_ex_funct3       (id_ex_funct3),
        .id_ex_funct7       (id_ex_funct7),
        .id_ex_valid        (id_ex_valid),

        .ex_mem_pc          (ex_mem_pc),
        .ex_mem_alu_result  (ex_mem_alu_result),
        .ex_mem_store_data  (ex_mem_store_data),
        .ex_mem_rd          (ex_mem_rd),
        .ex_mem_opcode      (ex_mem_opcode),
        .ex_mem_funct3      (ex_mem_funct3),
        .ex_mem_valid       (ex_mem_valid)
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
                ex_mem_pc         !== expected_pc         ||
                ex_mem_alu_result !== expected_alu_result ||
                ex_mem_store_data !== expected_store_data ||
                ex_mem_rd         !== expected_rd         ||
                ex_mem_opcode     !== expected_opcode     ||
                ex_mem_funct3     !== expected_funct3     ||
                ex_mem_valid      !== expected_valid
            ) begin

                $display("FAIL: %s", test_name);
                $display("  pc=%h expected=%h",
                         ex_mem_pc, expected_pc);
                $display("  alu_result=%h expected=%h",
                         ex_mem_alu_result, expected_alu_result);
                $display("  store_data=%h expected=%h",
                         ex_mem_store_data, expected_store_data);
                $display("  rd=%0d expected=%0d",
                         ex_mem_rd, expected_rd);
                $display("  opcode=%b expected=%b",
                         ex_mem_opcode, expected_opcode);
                $display("  funct3=%b expected=%b",
                         ex_mem_funct3, expected_funct3);
                $display("  valid=%b expected=%b",
                         ex_mem_valid, expected_valid);

                $fatal;
            end
            else begin
                $display(
                    "PASS: %s | alu_result=%h | store_data=%h",
                    test_name,
                    ex_mem_alu_result,
                    ex_mem_store_data
                );
            end
        end
    endtask


    task automatic execute_case (
        input logic        test_alu_src_a,
        input logic        test_alu_src_b,

        input logic [31:0] test_pc,
        input logic [31:0] test_read_data1,
        input logic [31:0] test_read_data2,
        input logic [31:0] test_immediate,

        input logic [4:0]  test_rd,
        input logic [6:0]  test_opcode,
        input logic [2:0]  test_funct3,
        input logic [6:0]  test_funct7,

        input logic [31:0] expected_alu_result,
        input logic [31:0] expected_store_data,

        input string       test_name
    );
        begin

            @(negedge clk);

            ex_enable       = 1'b1;
            flush_ex_mem    = 1'b0;

            alu_src_a       = test_alu_src_a;
            alu_src_b       = test_alu_src_b;

            id_ex_pc        = test_pc;
            id_ex_read_data1 = test_read_data1;
            id_ex_read_data2 = test_read_data2;
            id_ex_immediate  = test_immediate;

            id_ex_rd        = test_rd;
            id_ex_opcode    = test_opcode;
            id_ex_funct3    = test_funct3;
            id_ex_funct7    = test_funct7;
            id_ex_valid     = 1'b1;

            @(posedge clk);

            check_outputs(
                test_pc,
                expected_alu_result,
                expected_store_data,
                test_rd,
                test_opcode,
                test_funct3,
                1'b1,
                test_name
            );

        end
    endtask


    initial begin

        clk              = 1'b0;
        reset            = 1'b1;
        ex_enable        = 1'b1;
        flush_ex_mem     = 1'b0;

        alu_src_a        = 1'b0;
        alu_src_b        = 1'b0;

        id_ex_pc         = 32'd0;
        id_ex_read_data1 = 32'd0;
        id_ex_read_data2 = 32'd0;
        id_ex_immediate  = 32'd0;
        id_ex_rd         = 5'd0;
        id_ex_opcode     = 7'd0;
        id_ex_funct3     = 3'd0;
        id_ex_funct7     = 7'd0;
        id_ex_valid      = 1'b0;


        // =========================================================
        // RESET
        // =========================================================

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
        // ADD x7,x3,x5
        // 25 + 17 = 42
        // A = rs1
        // B = rs2
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd100,
            32'd25,
            32'd17,
            32'd0,
            5'd7,
            7'b0110011,
            3'b000,
            7'b0000000,
            32'd42,
            32'd17,
            "ADD"
        );


        // =========================================================
        // SUB
        // 25 - 17 = 8
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd104,
            32'd25,
            32'd17,
            32'd0,
            5'd8,
            7'b0110011,
            3'b000,
            7'b0100000,
            32'd8,
            32'd17,
            "SUB"
        );


        // =========================================================
        // ADDI
        // 100 + (-20) = 80
        // A = rs1
        // B = immediate
        // =========================================================

        execute_case(
            1'b0,
            1'b1,
            32'd108,
            32'd100,
            32'hAAAAAAAA,
            32'hFFFFFFEC,
            5'd9,
            7'b0010011,
            3'b000,
            7'b1111111,
            32'd80,
            32'hAAAAAAAA,
            "ADDI NEGATIVE"
        );


        // =========================================================
        // XOR
        // B4 XOR 6C = D8
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd112,
            32'h000000B4,
            32'h0000006C,
            32'd0,
            5'd10,
            7'b0110011,
            3'b100,
            7'b0000000,
            32'h000000D8,
            32'h0000006C,
            "XOR"
        );


        // =========================================================
        // SLL
        // 5 << 2 = 20
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd116,
            32'd5,
            32'd2,
            32'd0,
            5'd11,
            7'b0110011,
            3'b001,
            7'b0000000,
            32'd20,
            32'd2,
            "SLL"
        );


        // =========================================================
        // SRA
        // FFFFFFF0 (-16) >>> 2 = FFFFFFFC
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd120,
            32'hFFFFFFF0,
            32'd2,
            32'd0,
            5'd12,
            7'b0110011,
            3'b101,
            7'b0100000,
            32'hFFFFFFFC,
            32'd2,
            "SRA"
        );


        // =========================================================
        // SLT signed
        // -5 < 3 -> 1
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd124,
            32'hFFFFFFFB,
            32'd3,
            32'd0,
            5'd13,
            7'b0110011,
            3'b010,
            7'b0000000,
            32'd1,
            32'd3,
            "SLT SIGNED"
        );


        // =========================================================
        // SLTU
        // 4294967291 < 3 -> false -> 0
        // =========================================================

        execute_case(
            1'b0,
            1'b0,
            32'd128,
            32'hFFFFFFFB,
            32'd3,
            32'd0,
            5'd14,
            7'b0110011,
            3'b011,
            7'b0000000,
            32'd0,
            32'd3,
            "SLTU UNSIGNED"
        );


        // =========================================================
        // LW x7,12(x3)
        // x3 = 100
        // direccion = 112
        // =========================================================

        execute_case(
            1'b0,
            1'b1,
            32'd132,
            32'd100,
            32'hDEADBEEF,
            32'd12,
            5'd7,
            7'b0000011,
            3'b010,
            7'b0000000,
            32'd112,
            32'hDEADBEEF,
            "LW ADDRESS"
        );


        // =========================================================
        // SW x5,12(x6)
        //
        // x6 = 1000
        // x5 = 777
        //
        // direccion = 1012
        // store_data = 777
        // =========================================================

        execute_case(
            1'b0,
            1'b1,
            32'd136,
            32'd1000,
            32'd777,
            32'd12,
            5'd0,
            7'b0100011,
            3'b010,
            7'b0000000,
            32'd1012,
            32'd777,
            "SW ADDRESS AND DATA"
        );


        // =========================================================
        // LUI x5,0x12345
        //
        // ImmGen ya entregaria:
        // immediate = 12345000
        //
        // ALU_PASS_B -> result = immediate
        // =========================================================

        execute_case(
            1'b0,
            1'b1,
            32'd140,
            32'hAAAAAAAA,
            32'hBBBBBBBB,
            32'h12345000,
            5'd5,
            7'b0110111,
            3'b000,
            7'b0000000,
            32'h12345000,
            32'hBBBBBBBB,
            "LUI"
        );


        // =========================================================
        // JAL - SOLO CALCULO DEL TARGET EN ESTA ETAPA
        //
        // PC = 400
        // immediate = 20
        // target = 420
        //
        // Prueba que alu_src_a puede seleccionar PC.
        //
        // El redirect y PC+4 se implementaran mas adelante.
        // =========================================================

        execute_case(
            1'b1,
            1'b1,
            32'd400,
            32'hAAAAAAAA,
            32'hBBBBBBBB,
            32'd20,
            5'd1,
            7'b1101111,
            3'b000,
            7'b0000000,
            32'd420,
            32'hBBBBBBBB,
            "JAL TARGET CALCULATION"
        );


        // =========================================================
        // HOLD INTEGRADO
        //
        // Cambiamos entradas, pero ex_enable=0.
        // Debe conservar el JAL anterior.
        // =========================================================

        @(negedge clk);

        ex_enable        = 1'b0;

        alu_src_a        = 1'b0;
        alu_src_b        = 1'b0;

        id_ex_pc         = 32'd999;
        id_ex_read_data1 = 32'd1;
        id_ex_read_data2 = 32'd2;
        id_ex_immediate  = 32'd3;
        id_ex_rd         = 5'd31;
        id_ex_opcode     = 7'b0110011;
        id_ex_funct3     = 3'b000;
        id_ex_funct7     = 7'b0000000;
        id_ex_valid      = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd400,
            32'd420,
            32'hBBBBBBBB,
            5'd1,
            7'b1101111,
            3'b000,
            1'b1,
            "HOLD INTEGRATED"
        );


        // =========================================================
        // FLUSH INTEGRADO
        //
        // Solo valid debe bajar a 0.
        // =========================================================

        @(negedge clk);

        ex_enable     = 1'b1;
        flush_ex_mem  = 1'b1;

        @(posedge clk);

        check_outputs(
            32'd400,
            32'd420,
            32'hBBBBBBBB,
            5'd1,
            7'b1101111,
            3'b000,
            1'b0,
            "FLUSH INTEGRATED"
        );


        $display("PASS: ex_stage");
        $finish;

    end

endmodule
