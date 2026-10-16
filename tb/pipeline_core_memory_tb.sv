`timescale 1ns / 1ps

module pipeline_core_memory_tb;

    logic clk;
    logic reset;

    integer i;
    integer wb_count;

    logic saw_store_mem;
    logic saw_load_wb;


    // =========================================================
    // PROGRAMA
    // =========================================================
    //
    // I1: addi x1, x0, 64
    // I2: addi x2, x0, 85
    //
    // NOPs para evitar RAW hazards antes del store.
    //
    // I3: sw x2, 0(x1)
    // I4: lw x3, 0(x1)
    //
    // =========================================================

    localparam logic [31:0] I1 =
        32'h04000093;   // addi x1, x0, 64

    localparam logic [31:0] I2 =
        32'h05500113;   // addi x2, x0, 85

    localparam logic [31:0] I3 =
        32'h0020A023;   // sw x2, 0(x1)

    localparam logic [31:0] I4 =
        32'h0000A183;   // lw x3, 0(x1)

    localparam logic [31:0] NOP =
        32'h00000013;   // addi x0, x0, 0


    localparam logic [6:0] OPCODE_LOAD  = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE = 7'b0100011;


    // =========================================================
    // DUT
    // =========================================================

    pipeline_core dut (
        .clk   (clk),
        .reset (reset)
    );


    // =========================================================
    // REGISTER FILE ALIASES
    // =========================================================

    logic [31:0] x0_value;
    logic [31:0] x1_value;
    logic [31:0] x2_value;
    logic [31:0] x3_value;

    assign x0_value =
        dut.id_stage_inst.registers.registers[0];

    assign x1_value =
        dut.id_stage_inst.registers.registers[1];

    assign x2_value =
        dut.id_stage_inst.registers.registers[2];

    assign x3_value =
        dut.id_stage_inst.registers.registers[3];


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // MONITOR DE WRITE BACK
    // =========================================================

    always @(negedge clk) begin

        if (!reset && dut.wb_write_enable) begin

            case (wb_count)

                // -------------------------------------------------
                // I1: x1 <- 64
                // -------------------------------------------------

                0: begin

                    if (
                        dut.wb_write_register !== 5'd1 ||
                        dut.wb_write_data     !== 32'd64
                    ) begin

                        $display("FAIL: WB I1");

                        $display(
                            "  rd=%0d data=%h",
                            dut.wb_write_register,
                            dut.wb_write_data
                        );

                        $fatal;

                    end

                    $display(
                        "PASS: WB I1 | x1 <- %h",
                        dut.wb_write_data
                    );

                end


                // -------------------------------------------------
                // I2: x2 <- 85
                // -------------------------------------------------

                1: begin

                    if (
                        dut.wb_write_register !== 5'd2 ||
                        dut.wb_write_data     !== 32'd85
                    ) begin

                        $display("FAIL: WB I2");
                        $fatal;

                    end

                    $display(
                        "PASS: WB I2 | x2 <- %h",
                        dut.wb_write_data
                    );

                end


                // -------------------------------------------------
                // I4: lw -> x3 <- 85
                //
                // I3 es STORE, por lo tanto NO genera WB write.
                // -------------------------------------------------

                2: begin

                    if (
                        dut.wb_write_register !== 5'd3 ||
                        dut.wb_write_data     !== 32'd85
                    ) begin

                        $display("FAIL: WB I4 LOAD");

                        $display(
                            "  rd=%0d data=%h",
                            dut.wb_write_register,
                            dut.wb_write_data
                        );

                        $fatal;

                    end

                    $display(
                        "PASS: WB I4 LOAD | x3 <- %h",
                        dut.wb_write_data
                    );

                end


                default: begin

                    $display(
                        "FAIL: unexpected WB write | rd=%0d data=%h",
                        dut.wb_write_register,
                        dut.wb_write_data
                    );

                    $fatal;

                end

            endcase

            wb_count = wb_count + 1;

        end

    end


    // =========================================================
    // MONITOR DEL STORE EN MEM
    // =========================================================

    always @(negedge clk) begin

        if (
            !reset &&
            dut.ex_mem_valid &&
            dut.ex_mem_opcode == OPCODE_STORE
        ) begin

            if (
                dut.ex_mem_alu_result !== 32'd64 ||
                dut.ex_mem_store_data !== 32'd85
            ) begin

                $display("FAIL: STORE ARRIVED INCORRECTLY AT MEM");

                $display(
                    "  address=%h store_data=%h",
                    dut.ex_mem_alu_result,
                    dut.ex_mem_store_data
                );

                $fatal;

            end


            if (
                dut.mem_stage_inst.memory_write_enable !== 1'b1
            ) begin

                $display(
                    "FAIL: STORE IN MEM BUT memory_write_enable=0"
                );

                $fatal;

            end


            saw_store_mem = 1'b1;

            $display(
                "PASS: STORE IN MEM | address=%h | data=%h",
                dut.ex_mem_alu_result,
                dut.ex_mem_store_data
            );

        end

    end


    // =========================================================
    // MONITOR DEL LOAD EN MEM/WB
    // =========================================================

    always @(negedge clk) begin

        if (
            !reset &&
            dut.mem_wb_valid &&
            dut.mem_wb_opcode == OPCODE_LOAD
        ) begin

            if (
                dut.mem_wb_alu_result !== 32'd64 ||
                dut.mem_wb_load_data  !== 32'd85 ||
                dut.mem_wb_rd         !== 5'd3
            ) begin

                $display("FAIL: LOAD ARRIVED INCORRECTLY AT MEM/WB");

                $display(
                    "  address=%h load_data=%h rd=%0d",
                    dut.mem_wb_alu_result,
                    dut.mem_wb_load_data,
                    dut.mem_wb_rd
                );

                $fatal;

            end


            saw_load_wb = 1'b1;

            $display(
                "PASS: LOAD IN MEM/WB | address=%h | data=%h | rd=%0d",
                dut.mem_wb_alu_result,
                dut.mem_wb_load_data,
                dut.mem_wb_rd
            );

        end

    end


    // =========================================================
    // TEST PRINCIPAL
    // =========================================================

    initial begin

        clk           = 1'b0;
        reset         = 1'b1;
        wb_count      = 0;
        saw_store_mem = 1'b0;
        saw_load_wb   = 1'b0;


        // =====================================================
        // IMEM COMPLETA CON NOP
        // =====================================================

        for (i = 0; i < 256; i = i + 1) begin

            dut.if_stage_inst.imem.memory[i] = NOP;

        end


        // =====================================================
        // PROGRAMA
        // =====================================================

        dut.if_stage_inst.imem.memory[0] = I1;
        dut.if_stage_inst.imem.memory[1] = I2;

        dut.if_stage_inst.imem.memory[2] = NOP;
        dut.if_stage_inst.imem.memory[3] = NOP;
        dut.if_stage_inst.imem.memory[4] = NOP;
        dut.if_stage_inst.imem.memory[5] = NOP;

        dut.if_stage_inst.imem.memory[6] = I3;
        dut.if_stage_inst.imem.memory[7] = I4;


        // =====================================================
        // RESET
        // =====================================================

        repeat (2)
            @(posedge clk);

        @(negedge clk);

        reset = 1'b0;


        // =====================================================
        // DEJAR EJECUTAR EL PROGRAMA
        // =====================================================

        repeat (16)
            @(posedge clk);

        #1;


        // =====================================================
        // COMPROBACIONES FINALES
        // =====================================================


        // -----------------------------------------------------
        // Debieron ocurrir exactamente tres escrituras reales:
        //
        // x1
        // x2
        // x3
        //
        // El SW no escribe Register File.
        // Los NOP tampoco.
        // -----------------------------------------------------

        if (wb_count !== 3) begin

            $display(
                "FAIL: expected 3 WB writes, got %0d",
                wb_count
            );

            $fatal;

        end


        if (!saw_store_mem) begin

            $display(
                "FAIL: store was never observed in MEM"
            );

            $fatal;

        end


        if (!saw_load_wb) begin

            $display(
                "FAIL: load was never observed in MEM/WB"
            );

            $fatal;

        end


        // -----------------------------------------------------
        // Register File
        // -----------------------------------------------------

        if (x0_value !== 32'd0) begin

            $display(
                "FAIL: x0 changed | value=%h",
                x0_value
            );

            $fatal;

        end


        if (x1_value !== 32'd64) begin

            $display(
                "FAIL: x1 | value=%h",
                x1_value
            );

            $fatal;

        end


        if (x2_value !== 32'd85) begin

            $display(
                "FAIL: x2 | value=%h",
                x2_value
            );

            $fatal;

        end


        if (x3_value !== 32'd85) begin

            $display(
                "FAIL: x3 | value=%h",
                x3_value
            );

            $fatal;

        end


        // -----------------------------------------------------
        // DMEM
        //
        // Dirección 64 bytes:
        //
        // 64 / 4 = word index 16.
        // -----------------------------------------------------

        if (
            dut.mem_stage_inst.data_memory_inst.memory[16]
            !== 32'd85
        ) begin

            $display(
                "FAIL: DMEM[64] | word=%h",
                dut.mem_stage_inst.data_memory_inst.memory[16]
            );

            $fatal;

        end


        $display("");
        $display("PASS: FINAL MEMORY PIPELINE STATE");

        $display(
            "  x1 = %h",
            x1_value
        );

        $display(
            "  x2 = %h",
            x2_value
        );

        $display(
            "  x3 = %h",
            x3_value
        );

        $display(
            "  DMEM[64] = %h",
            dut.mem_stage_inst.data_memory_inst.memory[16]
        );


        $display("");
        $display("PASS: pipeline_core_memory");
        $finish;

    end

endmodule
