`timescale 1ns / 1ps

module pipeline_core_tb;

    logic clk;
    logic reset;

    integer i;
    integer wb_count;


    // =========================================================
    // INSTRUCCIONES DEL PROGRAMA
    // =========================================================
    //
    // I1: addi x5, x0, 10
    // I2: addi x6, x0, 20
    // I3: lui  x7, 0x12345
    // I4: xor  x8, x0, x0
    // I5: addi x9, x0, -3
    //
    // Después se rellenará IMEM con NOP:
    //
    // addi x0, x0, 0
    //
    // No existen dependencias entre estas cinco instrucciones.
    // =========================================================

    localparam logic [31:0] I1 =
        32'h00A00293;

    localparam logic [31:0] I2 =
        32'h01400313;

    localparam logic [31:0] I3 =
        32'h123453B7;

    localparam logic [31:0] I4 =
        32'h00004433;

    localparam logic [31:0] I5 =
        32'hFFD00493;

    localparam logic [31:0] NOP =
        32'h00000013;


    // =========================================================
    // DUT
    // =========================================================

    pipeline_core dut (
        .clk   (clk),
        .reset (reset)
    );


    // =========================================================
    // ALIAS PARA OBSERVAR IF ACTUAL
    // =========================================================

    logic [31:0] if_pc_current;
    logic [31:0] if_instruction_current;

    assign if_pc_current =
        dut.if_stage_inst.pc_current;

    assign if_instruction_current =
        dut.if_stage_inst.instruction;


    // =========================================================
    // ALIAS PARA OBSERVAR REGISTER FILE
    //
    // id_stage contiene:
    //
    // register_file registers (...)
    //
    // y register_file contiene:
    //
    // logic [31:0] registers [0:31]
    // =========================================================

    logic [31:0] x0_value;
    logic [31:0] x5_value;
    logic [31:0] x6_value;
    logic [31:0] x7_value;
    logic [31:0] x8_value;
    logic [31:0] x9_value;

    assign x0_value =
        dut.id_stage_inst.registers.registers[0];

    assign x5_value =
        dut.id_stage_inst.registers.registers[5];

    assign x6_value =
        dut.id_stage_inst.registers.registers[6];

    assign x7_value =
        dut.id_stage_inst.registers.registers[7];

    assign x8_value =
        dut.id_stage_inst.registers.registers[8];

    assign x9_value =
        dut.id_stage_inst.registers.registers[9];


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // MONITOR DE WRITE BACK
    //
    // Miramos WB en negedge porque durante ese ciclo las señales
    // ya están estables y se escribirán en Register File en el
    // próximo posedge.
    // =========================================================

    always @(negedge clk) begin

        if (!reset && dut.wb_write_enable) begin

            case (wb_count)

                // I1
                0: begin

                    if (
                        dut.wb_write_register !== 5'd5 ||
                        dut.wb_write_data     !== 32'd10
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
                        "PASS: WB I1 | x5 <- %h",
                        dut.wb_write_data
                    );

                end


                // I2
                1: begin

                    if (
                        dut.wb_write_register !== 5'd6 ||
                        dut.wb_write_data     !== 32'd20
                    ) begin

                        $display("FAIL: WB I2");
                        $fatal;

                    end

                    $display(
                        "PASS: WB I2 | x6 <- %h",
                        dut.wb_write_data
                    );

                end


                // I3
                2: begin

                    if (
                        dut.wb_write_register !== 5'd7 ||
                        dut.wb_write_data     !== 32'h12345000
                    ) begin

                        $display("FAIL: WB I3");
                        $fatal;

                    end

                    $display(
                        "PASS: WB I3 | x7 <- %h",
                        dut.wb_write_data
                    );

                end


                // I4
                3: begin

                    if (
                        dut.wb_write_register !== 5'd8 ||
                        dut.wb_write_data     !== 32'd0
                    ) begin

                        $display("FAIL: WB I4");
                        $fatal;

                    end

                    $display(
                        "PASS: WB I4 | x8 <- %h",
                        dut.wb_write_data
                    );

                end


                // I5
                4: begin

                    if (
                        dut.wb_write_register !== 5'd9 ||
                        dut.wb_write_data     !== 32'hFFFFFFFD
                    ) begin

                        $display("FAIL: WB I5");
                        $fatal;

                    end

                    $display(
                        "PASS: WB I5 | x9 <- %h",
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
    // TEST PRINCIPAL
    // =========================================================

    initial begin

        clk      = 1'b0;
        reset    = 1'b1;
        wb_count = 0;


        // =====================================================
        // CARGAR IMEM
        //
        // Primero llenamos toda IMEM con NOPs.
        // =====================================================

        for (i = 0; i < 256; i = i + 1) begin

            dut.if_stage_inst.imem.memory[i] = NOP;

        end


        // Programa real.

        dut.if_stage_inst.imem.memory[0] = I1;
        dut.if_stage_inst.imem.memory[1] = I2;
        dut.if_stage_inst.imem.memory[2] = I3;
        dut.if_stage_inst.imem.memory[3] = I4;
        dut.if_stage_inst.imem.memory[4] = I5;


        // =====================================================
        // RESET
        //
        // Dos flancos con reset activo.
        // =====================================================

        repeat (2)
            @(posedge clk);

        @(negedge clk);

        reset = 1'b0;


        // =====================================================
        // DEJAR AVANZAR CUATRO FLANCOS
        //
        // Después del cuarto posedge funcional estamos durante
        // el ciclo donde:
        //
        // IF  = I5
        // ID  = I4
        // EX  = I3
        // MEM = I2
        // WB  = I1
        // =====================================================

        repeat (4)
            @(posedge clk);

        #1;


        // =====================================================
        // COMPROBAR PIPELINE LLENO
        // =====================================================


        // -----------------------------------------------------
        // IF = I5
        // -----------------------------------------------------

        if (
            if_pc_current          !== 32'd16 ||
            if_instruction_current !== I5
        ) begin

            $display("FAIL: PIPELINE FULL - IF");

            $display(
                "  pc=%h instruction=%h",
                if_pc_current,
                if_instruction_current
            );

            $fatal;

        end


        // -----------------------------------------------------
        // ID = I4
        //
        // IF/ID contiene la instrucción que actualmente procesa ID.
        // -----------------------------------------------------

        if (
            dut.if_id_pc          !== 32'd12 ||
            dut.if_id_instruction !== I4     ||
            dut.if_id_valid       !== 1'b1
        ) begin

            $display("FAIL: PIPELINE FULL - ID");
            $fatal;

        end


        // -----------------------------------------------------
        // EX = I3
        //
        // ID/EX contiene LUI x7.
        // -----------------------------------------------------

        if (
            dut.id_ex_pc        !== 32'd8       ||
            dut.id_ex_opcode    !== 7'b0110111 ||
            dut.id_ex_rd        !== 5'd7       ||
            dut.id_ex_immediate !== 32'h12345000 ||
            dut.id_ex_valid     !== 1'b1
        ) begin

            $display("FAIL: PIPELINE FULL - EX");

            $display(
                "  pc=%h opcode=%b rd=%0d immediate=%h valid=%b",
                dut.id_ex_pc,
                dut.id_ex_opcode,
                dut.id_ex_rd,
                dut.id_ex_immediate,
                dut.id_ex_valid
            );

            $fatal;

        end


        // -----------------------------------------------------
        // MEM = I2
        //
        // EX/MEM contiene addi x6,x0,20.
        // -----------------------------------------------------

        if (
            dut.ex_mem_pc         !== 32'd4       ||
            dut.ex_mem_opcode     !== 7'b0010011 ||
            dut.ex_mem_rd         !== 5'd6       ||
            dut.ex_mem_alu_result !== 32'd20     ||
            dut.ex_mem_valid      !== 1'b1
        ) begin

            $display("FAIL: PIPELINE FULL - MEM");

            $display(
                "  pc=%h opcode=%b rd=%0d alu=%h valid=%b",
                dut.ex_mem_pc,
                dut.ex_mem_opcode,
                dut.ex_mem_rd,
                dut.ex_mem_alu_result,
                dut.ex_mem_valid
            );

            $fatal;

        end


        // -----------------------------------------------------
        // WB = I1
        //
        // MEM/WB contiene addi x5,x0,10.
        // -----------------------------------------------------

        if (
            dut.mem_wb_pc         !== 32'd0       ||
            dut.mem_wb_opcode     !== 7'b0010011 ||
            dut.mem_wb_rd         !== 5'd5       ||
            dut.mem_wb_alu_result !== 32'd10     ||
            dut.mem_wb_valid      !== 1'b1
        ) begin

            $display("FAIL: PIPELINE FULL - WB");

            $display(
                "  pc=%h opcode=%b rd=%0d alu=%h valid=%b",
                dut.mem_wb_pc,
                dut.mem_wb_opcode,
                dut.mem_wb_rd,
                dut.mem_wb_alu_result,
                dut.mem_wb_valid
            );

            $fatal;

        end


        $display("");
        $display("PASS: PIPELINE FULL");

        $display(
            "  IF  -> I5 | PC=%0d",
            if_pc_current
        );

        $display(
            "  ID  -> I4 | IF/ID PC=%0d",
            dut.if_id_pc
        );

        $display(
            "  EX  -> I3 | ID/EX PC=%0d",
            dut.id_ex_pc
        );

        $display(
            "  MEM -> I2 | EX/MEM PC=%0d",
            dut.ex_mem_pc
        );

        $display(
            "  WB  -> I1 | MEM/WB PC=%0d",
            dut.mem_wb_pc
        );

        $display("");


        // =====================================================
        // DEJAR DRENAR LAS CINCO INSTRUCCIONES
        //
        // Lo que sigue en IMEM son NOPs.
        // =====================================================

        repeat (6)
            @(posedge clk);

        #1;


        // =====================================================
        // VERIFICACIÓN FINAL DEL REGISTER FILE
        // =====================================================

        if (wb_count !== 5) begin

            $display(
                "FAIL: expected 5 WB writes, got %0d",
                wb_count
            );

            $fatal;

        end


        if (x0_value !== 32'd0) begin

            $display(
                "FAIL: x0 changed | value=%h",
                x0_value
            );

            $fatal;

        end


        if (x5_value !== 32'd10) begin

            $display(
                "FAIL: x5 | value=%h",
                x5_value
            );

            $fatal;

        end


        if (x6_value !== 32'd20) begin

            $display(
                "FAIL: x6 | value=%h",
                x6_value
            );

            $fatal;

        end


        if (x7_value !== 32'h12345000) begin

            $display(
                "FAIL: x7 | value=%h",
                x7_value
            );

            $fatal;

        end


        if (x8_value !== 32'd0) begin

            $display(
                "FAIL: x8 | value=%h",
                x8_value
            );

            $fatal;

        end


        if (x9_value !== 32'hFFFFFFFD) begin

            $display(
                "FAIL: x9 | value=%h",
                x9_value
            );

            $fatal;

        end


        $display("PASS: FINAL REGISTER FILE");

        $display(
            "  x5 = %h",
            x5_value
        );

        $display(
            "  x6 = %h",
            x6_value
        );

        $display(
            "  x7 = %h",
            x7_value
        );

        $display(
            "  x8 = %h",
            x8_value
        );

        $display(
            "  x9 = %h",
            x9_value
        );


        $display("");
        $display("PASS: pipeline_core");
        $finish;

    end

endmodule
