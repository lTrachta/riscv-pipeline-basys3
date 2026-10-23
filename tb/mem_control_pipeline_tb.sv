`timescale 1ns / 1ps

module mem_control_pipeline_tb;

    logic clk;
    logic reset;

    logic mem_enable;
    logic flush_mem_wb;

    // =========================================================
    // DATAPATH EX/MEM
    // =========================================================

    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;

    logic [4:0] ex_mem_rd;
    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;

    logic ex_mem_valid;

    // =========================================================
    // CONTROL MEM
    // =========================================================

    logic ex_mem_mem_read;
    logic ex_mem_mem_write;

    // =========================================================
    // CONTROL WB
    // =========================================================

    logic       ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;

    // =========================================================
    // MEM/WB OUTPUTS
    // =========================================================

    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;

    logic [4:0] mem_wb_rd;
    logic [6:0] mem_wb_opcode;

    logic mem_wb_valid;

    logic       mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;


    // =========================================================
    // WB SELECT
    // =========================================================

    localparam logic [1:0] WB_SEL_ALU = 2'b00;
    localparam logic [1:0] WB_SEL_MEM = 2'b01;
    localparam logic [1:0] WB_SEL_PC4 = 2'b10;


    // =========================================================
    // OPCODES
    //
    // MEM ya no decide utilizando opcode.
    // Los mantenemos porque el datapath todavía los transporta.
    // =========================================================

    localparam logic [6:0] OPCODE_R     = 7'b0110011;
    localparam logic [6:0] OPCODE_LOAD  = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE = 7'b0100011;
    localparam logic [6:0] OPCODE_JAL   = 7'b1101111;


    // =========================================================
    // CONTROL WB EMPAQUETADO
    // =========================================================

    logic [2:0] mem_wb_control_bus;

    assign mem_wb_control_bus = {
        mem_wb_reg_write,
        mem_wb_wb_sel
    };


    localparam logic [2:0] CTRL_WB_NONE = {
        1'b0,
        2'b00
    };

    localparam logic [2:0] CTRL_WB_ALU = {
        1'b1,
        2'b00
    };

    localparam logic [2:0] CTRL_WB_MEM = {
        1'b1,
        2'b01
    };

    localparam logic [2:0] CTRL_WB_PC4 = {
        1'b1,
        2'b10
    };


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    // =========================================================
    // ACCESO DIRECTO A LA PALABRA EN DMEM
    //
    // Dirección byte 0x40 = 64
    //
    // 64 / 4 = índice 16
    // =========================================================

    wire [31:0] dmem_word_16;

    assign dmem_word_16 =
        dut.data_memory_inst.memory[16];


    // =========================================================
    // DUT
    // =========================================================

    mem_stage #(
        .DATA_MEM_DEPTH(256)
    ) dut (
        .clk               (clk),
        .reset             (reset),

        .mem_enable        (mem_enable),
        .flush_mem_wb      (flush_mem_wb),

        .ex_mem_pc         (ex_mem_pc),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_store_data (ex_mem_store_data),

        .ex_mem_rd         (ex_mem_rd),
        .ex_mem_opcode     (ex_mem_opcode),
        .ex_mem_funct3     (ex_mem_funct3),

        .ex_mem_valid      (ex_mem_valid),

        .ex_mem_mem_read   (ex_mem_mem_read),
        .ex_mem_mem_write  (ex_mem_mem_write),

        .ex_mem_reg_write  (ex_mem_reg_write),
        .ex_mem_wb_sel     (ex_mem_wb_sel),

        .mem_wb_pc         (mem_wb_pc),
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_load_data  (mem_wb_load_data),

        .mem_wb_rd         (mem_wb_rd),
        .mem_wb_opcode     (mem_wb_opcode),

        .mem_wb_valid      (mem_wb_valid),

        .mem_wb_reg_write  (mem_wb_reg_write),
        .mem_wb_wb_sel     (mem_wb_wb_sel)
    );


    // =========================================================
    // CLOCK
    // =========================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // =========================================================
    // CHECK MEM/WB
    // =========================================================

    task automatic check_snapshot (
        input string       name,

        input logic [31:0] expected_pc,
        input logic [31:0] expected_alu_result,
        input logic [31:0] expected_load_data,

        input logic [4:0]  expected_rd,

        input logic        expected_valid,
        input logic [2:0]  expected_control
    );

        begin

            tests_run = tests_run + 1;

            if (
                mem_wb_pc          === expected_pc         &&
                mem_wb_alu_result  === expected_alu_result &&
                mem_wb_load_data   === expected_load_data  &&
                mem_wb_rd          === expected_rd         &&
                mem_wb_valid       === expected_valid      &&
                mem_wb_control_bus === expected_control
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-12s | PC=%08h ALU=%08h LOAD=%08h RD=%0d VALID=%0d CTRL=%03b",
                    name,
                    mem_wb_pc,
                    mem_wb_alu_result,
                    mem_wb_load_data,
                    mem_wb_rd,
                    mem_wb_valid,
                    mem_wb_control_bus
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display("");
                $display("FAIL: %s", name);

                $display(
                    "  PC       received=%08h expected=%08h",
                    mem_wb_pc,
                    expected_pc
                );

                $display(
                    "  ALU      received=%08h expected=%08h",
                    mem_wb_alu_result,
                    expected_alu_result
                );

                $display(
                    "  LOAD     received=%08h expected=%08h",
                    mem_wb_load_data,
                    expected_load_data
                );

                $display(
                    "  RD       received=%0d expected=%0d",
                    mem_wb_rd,
                    expected_rd
                );

                $display(
                    "  VALID    received=%0d expected=%0d",
                    mem_wb_valid,
                    expected_valid
                );

                $display(
                    "  CONTROL  received=%03b expected=%03b",
                    mem_wb_control_bus,
                    expected_control
                );

                $display("");

            end

        end

    endtask


    // =========================================================
    // TEST
    // =========================================================

    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        reset        = 1'b1;

        mem_enable   = 1'b1;
        flush_mem_wb = 1'b0;

        ex_mem_pc         = 32'b0;
        ex_mem_alu_result = 32'b0;
        ex_mem_store_data = 32'b0;

        ex_mem_rd         = 5'b0;
        ex_mem_opcode     = 7'b0;
        ex_mem_funct3     = 3'b0;

        ex_mem_valid      = 1'b0;

        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b0;

        ex_mem_reg_write  = 1'b0;
        ex_mem_wb_sel     = WB_SEL_ALU;


        // =====================================================
        // RESET
        // =====================================================

        repeat (2) @(posedge clk);
        #1;

        if (
            mem_wb_valid !== 1'b0 ||
            mem_wb_control_bus !== CTRL_WB_NONE
        ) begin
            $fatal(1, "FAIL: reset did not clear MEM/WB");
        end

        @(negedge clk);
        reset = 1'b0;


        // =====================================================
        // TEST 1: SW
        //
        // sw a dirección 0x40
        //
        // DMEM[0x40] <- 0x55
        //
        // La escritura ocurre en este posedge.
        // =====================================================

        ex_mem_pc         = 32'h00000100;

        ex_mem_alu_result = 32'h00000040;
        ex_mem_store_data = 32'h00000055;

        ex_mem_rd         = 5'd0;

        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b010;       // sw

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b1;

        ex_mem_reg_write  = 1'b0;
        ex_mem_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "SW",
            32'h00000100,
            32'h00000040,
            32'h00000000,
            5'd0,
            1'b1,
            CTRL_WB_NONE
        );

        if (dmem_word_16 !== 32'h00000055) begin
            $fatal(
                1,
                "FAIL: SW | DMEM[0x40]=%08h expected=00000055",
                dmem_word_16
            );
        end

        $display(
            "PASS: SW MEMORY    | DMEM[0x40]=%08h",
            dmem_word_16
        );


        // =====================================================
        // TEST 2: LW
        //
        // Leemos exactamente el dato escrito por SW.
        //
        // MEM consume MemRead.
        //
        // MEM/WB conserva:
        // RegWrite = 1
        // WBSel = MEM
        // =====================================================

        @(negedge clk);

        ex_mem_pc         = 32'h00000104;

        ex_mem_alu_result = 32'h00000040;
        ex_mem_store_data = 32'hAAAAAAAA;

        ex_mem_rd         = 5'd5;

        ex_mem_opcode     = OPCODE_LOAD;
        ex_mem_funct3     = 3'b010;       // lw

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b1;
        ex_mem_mem_write  = 1'b0;

        ex_mem_reg_write  = 1'b1;
        ex_mem_wb_sel     = WB_SEL_MEM;

        @(posedge clk);
        #1;

        check_snapshot(
            "LW",
            32'h00000104,
            32'h00000040,
            32'h00000055,
            5'd5,
            1'b1,
            CTRL_WB_MEM
        );


        // =====================================================
        // TEST 3: RESULTADO ALU
        //
        // Una instrucción aritmética no debe tocar DMEM.
        //
        // ALU result simplemente atraviesa MEM.
        // =====================================================

        @(negedge clk);

        ex_mem_pc         = 32'h00000108;

        ex_mem_alu_result = 32'h12345678;
        ex_mem_store_data = 32'hDEADBEEF;

        ex_mem_rd         = 5'd7;

        ex_mem_opcode     = OPCODE_R;
        ex_mem_funct3     = 3'b100;

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b0;

        ex_mem_reg_write  = 1'b1;
        ex_mem_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "ALU",
            32'h00000108,
            32'h12345678,
            32'h00000000,
            5'd7,
            1'b1,
            CTRL_WB_ALU
        );

        if (dmem_word_16 !== 32'h00000055) begin
            $fatal(1, "FAIL: ALU modified DMEM");
        end


        // =====================================================
        // TEST 4: JAL
        //
        // MEM no tiene nada que hacer.
        //
        // Solamente continúa:
        //
        // RegWrite = 1
        // WBSel = PC+4
        // =====================================================

        @(negedge clk);

        ex_mem_pc         = 32'h00000200;

        // Target calculado en EX.
        // WB no utilizará este resultado para JAL.
        ex_mem_alu_result = 32'h00000220;

        ex_mem_store_data = 32'b0;

        ex_mem_rd         = 5'd1;

        ex_mem_opcode     = OPCODE_JAL;
        ex_mem_funct3     = 3'b000;

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b0;

        ex_mem_reg_write  = 1'b1;
        ex_mem_wb_sel     = WB_SEL_PC4;

        @(posedge clk);
        #1;

        check_snapshot(
            "JAL",
            32'h00000200,
            32'h00000220,
            32'h00000000,
            5'd1,
            1'b1,
            CTRL_WB_PC4
        );


        // =====================================================
        // TEST 5: HOLD
        //
        // Cambiamos completamente las entradas.
        //
        // Como mem_enable=0:
        //
        // - MEM/WB debe conservar JAL.
        // - DMEM tampoco debe escribirse.
        // =====================================================

        @(negedge clk);

        mem_enable = 1'b0;

        ex_mem_pc         = 32'hFFFFFFFF;
        ex_mem_alu_result = 32'h00000040;
        ex_mem_store_data = 32'hDEADBEEF;

        ex_mem_rd         = 5'd31;

        ex_mem_opcode     = OPCODE_STORE;
        ex_mem_funct3     = 3'b010;

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b0;
        ex_mem_mem_write  = 1'b1;

        ex_mem_reg_write  = 1'b0;
        ex_mem_wb_sel     = WB_SEL_ALU;

        @(posedge clk);
        #1;

        check_snapshot(
            "HOLD",
            32'h00000200,
            32'h00000220,
            32'h00000000,
            5'd1,
            1'b1,
            CTRL_WB_PC4
        );

        if (dmem_word_16 !== 32'h00000055) begin
            $fatal(1, "FAIL: HOLD allowed DMEM write");
        end


        // =====================================================
        // TEST 6: LW DESALINEADO
        //
        // lw desde 0x41.
        //
        // Word debe estar alineada a múltiplo de 4.
        //
        // Por lo tanto MEM/WB debe recibir valid=0.
        //
        // El control WB todavía puede estar almacenado, pero
        // valid=0 impedirá cualquier efecto arquitectónico.
        // =====================================================

        @(negedge clk);

        mem_enable = 1'b1;

        ex_mem_pc         = 32'h00000110;

        ex_mem_alu_result = 32'h00000041;
        ex_mem_store_data = 32'b0;

        ex_mem_rd         = 5'd8;

        ex_mem_opcode     = OPCODE_LOAD;
        ex_mem_funct3     = 3'b010;

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b1;
        ex_mem_mem_write  = 1'b0;

        ex_mem_reg_write  = 1'b1;
        ex_mem_wb_sel     = WB_SEL_MEM;

        @(posedge clk);
        #1;

        check_snapshot(
            "MISALIGNED",
            32'h00000110,
            32'h00000041,
            32'h00000000,
            5'd8,
            1'b0,
            CTRL_WB_MEM
        );


        // =====================================================
        // TEST 7: MEMREAD + MEMWRITE SIMULTÁNEOS
        //
        // Estado ilegal de control.
        //
        // Debe:
        //
        // - producir valid=0;
        // - NO modificar DMEM;
        // - NO entregar un load válido.
        // =====================================================

        @(negedge clk);

        ex_mem_pc         = 32'h00000114;

        ex_mem_alu_result = 32'h00000040;
        ex_mem_store_data = 32'hDEADBEEF;

        ex_mem_rd         = 5'd9;

        ex_mem_opcode     = OPCODE_LOAD;
        ex_mem_funct3     = 3'b010;

        ex_mem_valid      = 1'b1;

        ex_mem_mem_read   = 1'b1;
        ex_mem_mem_write  = 1'b1;

        ex_mem_reg_write  = 1'b1;
        ex_mem_wb_sel     = WB_SEL_MEM;

        @(posedge clk);
        #1;

        check_snapshot(
            "ILLEGAL MEM",
            32'h00000114,
            32'h00000040,
            32'h00000000,
            5'd9,
            1'b0,
            CTRL_WB_MEM
        );

        if (dmem_word_16 !== 32'h00000055) begin
            $fatal(
                1,
                "FAIL: illegal MemRead+MemWrite modified DMEM"
            );
        end

        $display(
            "PASS: ILLEGAL SAFE | DMEM[0x40]=%08h",
            dmem_word_16
        );


        // =====================================================
        // TEST 8: FLUSH
        // =====================================================

        @(negedge clk);

        flush_mem_wb = 1'b1;

        @(posedge clk);
        #1;

        check_snapshot(
            "FLUSH",
            32'h00000000,
            32'h00000000,
            32'h00000000,
            5'd0,
            1'b0,
            CTRL_WB_NONE
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("MEM + CONTROL + MEM/WB TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: mem_control_pipeline");

        end
        else begin

            $fatal(
                1,
                "FAIL: mem_control_pipeline | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
