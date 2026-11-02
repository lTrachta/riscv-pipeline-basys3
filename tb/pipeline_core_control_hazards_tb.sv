`timescale 1ns / 1ps

module pipeline_core_control_hazards_tb;

    logic clk;
    logic reset;

    integer i;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer redirect_count;
    integer stall_count;

    logic saw_bne_not_taken;

    logic saw_flush_controls;
    logic saw_post_redirect_bubbles;

    logic saw_alu_branch_forward;
    logic saw_alu_jalr_forward;

    logic saw_load_branch_stall;
    logic saw_load_jalr_stall;

    logic saw_load_branch_forward;
    logic saw_load_jalr_forward;

    logic        expect_redirect_edge;
    logic [31:0] expected_ex_mem_pc;


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
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // CHECK 32
    // =========================================================

    task automatic check32 (
        input string       name,
        input logic [31:0] received,
        input logic [31:0] expected
    );

        begin

            tests_run = tests_run + 1;

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-28s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-28s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // CHECK BOOLEAN
    // =========================================================

    task automatic check_bool (
        input string name,
        input logic  received,
        input logic  expected
    );

        begin

            tests_run = tests_run + 1;

            if (received === expected) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-28s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-28s | VALUE=%0d expected=%0d",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    // =========================================================
    // CHECK REGISTER
    // =========================================================

    task automatic check_register (
        input string       name,
        input integer      reg_number,
        input logic [31:0] expected
    );

        begin

            check32(
                name,
                dut.id_stage_inst.registers.registers[reg_number],
                expected
            );

        end

    endtask


    // =========================================================
    // MONITOR DE STALLS
    // =========================================================

    always @(negedge clk) begin

        if (!reset && dut.load_use_stall) begin

            stall_count = stall_count + 1;

            case (dut.id_ex_pc)

                // lw x23 -> beq
                32'd152: begin
                    saw_load_branch_stall = 1'b1;
                end

                // lw x27 -> jalr
                32'd176: begin
                    saw_load_jalr_stall = 1'b1;
                end

                default: begin

                    $display(
                        "FAIL: unexpected stall at ID/EX PC=%0d",
                        dut.id_ex_pc
                    );

                    $fatal;

                end

            endcase

        end

    end


    // =========================================================
    // MONITOR DE FORWARDING HACIA CONTROL
    // =========================================================

    always @(negedge clk) begin

        if (!reset && dut.id_ex_valid) begin

            // add x15,... -> beq x15,...
            if (
                dut.id_ex_pc == 32'd108 &&
                dut.forward_a == 2'b10
            ) begin

                saw_alu_branch_forward = 1'b1;

            end


            // addi x19,... -> jalr x20,0(x19)
            if (
                dut.id_ex_pc == 32'd132 &&
                dut.forward_a == 2'b10
            ) begin

                saw_alu_jalr_forward = 1'b1;

            end


            // lw x23 -> stall -> beq
            //
            // Después del stall el valor llega desde MEM/WB.
            if (
                dut.id_ex_pc == 32'd156 &&
                dut.forward_a == 2'b01
            ) begin

                saw_load_branch_forward = 1'b1;

            end


            // lw x27 -> stall -> jalr
            if (
                dut.id_ex_pc == 32'd180 &&
                dut.forward_a == 2'b01
            ) begin

                saw_load_jalr_forward = 1'b1;

            end

        end

    end


    // =========================================================
    // BNE NO TOMADO
    // =========================================================

    always @(negedge clk) begin

        if (
            !reset &&
            dut.id_ex_valid &&
            dut.id_ex_pc == 32'd24
        ) begin

            saw_bne_not_taken = 1'b1;

            if (dut.redirect_valid !== 1'b0) begin

                $display(
                    "FAIL: BNE NOT TAKEN generated redirect"
                );

                $fatal;

            end

        end

    end


    // =========================================================
    // MONITOR DE REDIRECTS
    //
    // También valida cada target individual.
    // =========================================================

    always @(negedge clk) begin

        if (!reset && dut.redirect_valid) begin

            redirect_count = redirect_count + 1;


            // -------------------------------------------------
            // Durante redirect:
            //
            // IF/ID = flush
            // ID/EX = flush
            // EX/MEM = NO flush
            // -------------------------------------------------

            if (
                dut.flush_if_id  !== 1'b1 ||
                dut.flush_id_ex  !== 1'b1 ||
                dut.flush_ex_mem !== 1'b0
            ) begin

                $display("FAIL: incorrect redirect flush controls");

                $display(
                    "flush_if_id=%0d flush_id_ex=%0d flush_ex_mem=%0d",
                    dut.flush_if_id,
                    dut.flush_id_ex,
                    dut.flush_ex_mem
                );

                $fatal;

            end

            saw_flush_controls = 1'b1;


            // -------------------------------------------------
            // TARGET ESPERADO SEGÚN PC DE LA INSTRUCCIÓN
            // -------------------------------------------------

            case (dut.id_ex_pc)

                // beq x1,x2,+12
                32'd8: begin

                    if (dut.redirect_target !== 32'd20) begin
                        $display("FAIL: BEQ target");
                        $fatal;
                    end

                end


                // bne x1,x2,+12
                32'd36: begin

                    if (dut.redirect_target !== 32'd48) begin
                        $display("FAIL: BNE target");
                        $fatal;
                    end

                end


                // jal x6,+12
                32'd52: begin

                    if (dut.redirect_target !== 32'd64) begin
                        $display("FAIL: JAL target");
                        $fatal;
                    end

                end


                // jalr x9,0(x8)
                //
                // x8 = 89
                //
                // 89 & ~1 = 88
                32'd72: begin

                    if (dut.redirect_target !== 32'd88) begin

                        $display(
                            "FAIL: JALR bit0 target | got=%0d",
                            dut.redirect_target
                        );

                        $fatal;

                    end

                end


                // add -> beq
                32'd108: begin

                    if (dut.redirect_target !== 32'd120) begin
                        $display("FAIL: forwarded BEQ target");
                        $fatal;
                    end

                end


                // addi -> jalr
                32'd132: begin

                    if (dut.redirect_target !== 32'd140) begin
                        $display("FAIL: forwarded JALR target");
                        $fatal;
                    end

                end


                // lw -> stall -> beq
                32'd156: begin

                    if (dut.redirect_target !== 32'd168) begin
                        $display("FAIL: load-use BEQ target");
                        $fatal;
                    end

                end


                // lw -> stall -> jalr
                //
                // loaded value = 193
                //
                // 193 & ~1 = 192
                32'd180: begin

                    if (dut.redirect_target !== 32'd192) begin

                        $display(
                            "FAIL: load-use JALR target | got=%0d",
                            dut.redirect_target
                        );

                        $fatal;

                    end

                end


                default: begin

                    $display(
                        "FAIL: unexpected redirect from PC=%0d target=%0d",
                        dut.id_ex_pc,
                        dut.redirect_target
                    );

                    $fatal;

                end

            endcase


            // Guardamos el PC de la instrucción de control.
            // Después del flanco debe aparecer en EX/MEM.

            expected_ex_mem_pc = dut.id_ex_pc;
            expect_redirect_edge = 1'b1;

        end

    end


    // =========================================================
    // VALIDAR ESTADO DESPUÉS DEL FLANCO DE REDIRECT
    // =========================================================

    always @(posedge clk) begin

        if (reset) begin

            expect_redirect_edge = 1'b0;

        end
        else if (expect_redirect_edge) begin

            #1;

            // IF/ID e ID/EX deben haber sido eliminados.

            if (
                dut.if_id_valid !== 1'b0 ||
                dut.id_ex_valid !== 1'b0
            ) begin

                $display(
                    "FAIL: younger instructions survived redirect"
                );

                $display(
                    "IF/ID.valid=%0d ID/EX.valid=%0d",
                    dut.if_id_valid,
                    dut.id_ex_valid
                );

                $fatal;

            end


            // La propia instrucción de control debe sobrevivir.

            if (
                dut.ex_mem_valid !== 1'b1 ||
                dut.ex_mem_pc !== expected_ex_mem_pc
            ) begin

                $display(
                    "FAIL: redirect instruction did not reach EX/MEM"
                );

                $fatal;

            end


            saw_post_redirect_bubbles = 1'b1;

            expect_redirect_edge = 1'b0;

        end

    end


    // =========================================================
    // TEST PRINCIPAL
    // =========================================================

    initial begin

        clk   = 1'b0;
        reset = 1'b1;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        redirect_count = 0;
        stall_count    = 0;

        saw_bne_not_taken = 1'b0;

        saw_flush_controls          = 1'b0;
        saw_post_redirect_bubbles   = 1'b0;

        saw_alu_branch_forward = 1'b0;
        saw_alu_jalr_forward   = 1'b0;

        saw_load_branch_stall = 1'b0;
        saw_load_jalr_stall   = 1'b0;

        saw_load_branch_forward = 1'b0;
        saw_load_jalr_forward   = 1'b0;

        expect_redirect_edge = 1'b0;
        expected_ex_mem_pc   = 32'd0;


        // =====================================================
        // INSTRUCTION MEMORY = NOP
        // =====================================================

        for (i = 0; i < 256; i = i + 1) begin

            dut.if_stage_inst.imem.memory[i] = NOP;

        end


        // =====================================================
        // DATA MEMORY
        // =====================================================

        // byte address 64
        dut.mem_stage_inst.data_memory_inst.memory[16] =
            32'd7;

        // byte address 68
        //
        // Se carga 193 para comprobar que JALR limpia bit 0:
        //
        // 193 -> 192
        dut.mem_stage_inst.data_memory_inst.memory[17] =
            32'd193;


        // =====================================================
        // PROGRAMA
        // =====================================================


        // -----------------------------------------------------
        // BEQ TOMADO
        //
        // x1 = 5
        // x2 = 5
        //
        // PC 8 -> PC 20
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[0] =
            32'h00500093; // addi x1,x0,5

        dut.if_stage_inst.imem.memory[1] =
            32'h00500113; // addi x2,x0,5

        dut.if_stage_inst.imem.memory[2] =
            32'h00208663; // beq x1,x2,+12

        dut.if_stage_inst.imem.memory[3] =
            32'h00100F13; // WRONG: addi x30,x0,1

        dut.if_stage_inst.imem.memory[4] =
            32'h00100F93; // WRONG: addi x31,x0,1

        dut.if_stage_inst.imem.memory[5] =
            32'h02100193; // addi x3,x0,33


        // -----------------------------------------------------
        // BNE NO TOMADO
        //
        // x1 == x2
        //
        // PC 24 continúa en 28.
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[6] =
            32'h00209663; // bne x1,x2,+12

        dut.if_stage_inst.imem.memory[7] =
            32'h02C00213; // addi x4,x0,44


        // -----------------------------------------------------
        // BNE TOMADO + FORWARDING
        //
        // x2 cambia a 6 inmediatamente antes.
        //
        // PC 36 -> 48
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[8] =
            32'h00600113; // addi x2,x0,6

        dut.if_stage_inst.imem.memory[9] =
            32'h00209663; // bne x1,x2,+12

        dut.if_stage_inst.imem.memory[10] =
            32'h00200F13; // WRONG

        dut.if_stage_inst.imem.memory[11] =
            32'h00200F93; // WRONG

        dut.if_stage_inst.imem.memory[12] =
            32'h03700293; // addi x5,x0,55


        // -----------------------------------------------------
        // JAL
        //
        // PC 52 -> 64
        //
        // x6 = PC+4 = 56
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[13] =
            32'h00C0036F; // jal x6,+12

        dut.if_stage_inst.imem.memory[14] =
            32'h00300F13; // WRONG

        dut.if_stage_inst.imem.memory[15] =
            32'h00300F93; // WRONG

        dut.if_stage_inst.imem.memory[16] =
            32'h04D00393; // addi x7,x0,77


        // -----------------------------------------------------
        // JALR + LIMPIEZA DEL BIT 0
        //
        // x8 = 89
        //
        // jalr:
        //      raw target = 89
        //      target     = 88
        //
        // x9 = 76
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[17] =
            32'h05900413; // addi x8,x0,89

        dut.if_stage_inst.imem.memory[18] =
            32'h000404E7; // jalr x9,0(x8)

        dut.if_stage_inst.imem.memory[19] =
            32'h00400F13; // WRONG

        dut.if_stage_inst.imem.memory[20] =
            32'h00400F93; // WRONG

        dut.if_stage_inst.imem.memory[21] =
            NOP;

        dut.if_stage_inst.imem.memory[22] =
            32'h00C00613; // addi x12,x0,12


        // -----------------------------------------------------
        // ALU -> BRANCH FORWARDING
        //
        // x15 = x13 + x14 = 3
        //
        // beq x15,x16
        //
        // x15 viene de EX/MEM.
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[23] =
            32'h00300813; // addi x16,x0,3

        dut.if_stage_inst.imem.memory[24] =
            32'h00100693; // addi x13,x0,1

        dut.if_stage_inst.imem.memory[25] =
            32'h00200713; // addi x14,x0,2

        dut.if_stage_inst.imem.memory[26] =
            32'h00E687B3; // add x15,x13,x14

        dut.if_stage_inst.imem.memory[27] =
            32'h01078663; // beq x15,x16,+12

        dut.if_stage_inst.imem.memory[28] =
            32'h00500F13; // WRONG

        dut.if_stage_inst.imem.memory[29] =
            32'h00500F93; // WRONG

        dut.if_stage_inst.imem.memory[30] =
            32'h01100893; // addi x17,x0,17


        // -----------------------------------------------------
        // ALU -> JALR FORWARDING
        //
        // x18 = 141
        // x19 = x18 - 1 = 140
        //
        // jalr usa x19 inmediatamente.
        //
        // x20 = PC+4 = 136
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[31] =
            32'h08D00913; // addi x18,x0,141

        dut.if_stage_inst.imem.memory[32] =
            32'hFFF90993; // addi x19,x18,-1

        dut.if_stage_inst.imem.memory[33] =
            32'h00098A67; // jalr x20,0(x19)

        dut.if_stage_inst.imem.memory[34] =
            32'h00600F13; // WRONG

        dut.if_stage_inst.imem.memory[35] =
            32'h01500A93; // addi x21,x0,21


        // -----------------------------------------------------
        // LOAD -> BRANCH
        //
        // Debe producir:
        //
        // 1 stall
        // MEM/WB -> EX forwarding
        // redirect 156 -> 168
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[36] =
            32'h04000B13; // addi x22,x0,64

        dut.if_stage_inst.imem.memory[37] =
            32'h00700C13; // addi x24,x0,7

        dut.if_stage_inst.imem.memory[38] =
            32'h000B2B83; // lw x23,0(x22)

        dut.if_stage_inst.imem.memory[39] =
            32'h018B8663; // beq x23,x24,+12

        dut.if_stage_inst.imem.memory[40] =
            32'h00700F13; // WRONG

        dut.if_stage_inst.imem.memory[41] =
            32'h00700F93; // WRONG

        dut.if_stage_inst.imem.memory[42] =
            32'h01900C93; // addi x25,x0,25


        // -----------------------------------------------------
        // LOAD -> JALR
        //
        // DMEM[68] = 193
        //
        // 1 stall
        //
        // raw target = 193
        // target     = 192
        //
        // x28 = PC+4 = 184
        // -----------------------------------------------------

        dut.if_stage_inst.imem.memory[43] =
            32'h04400D13; // addi x26,x0,68

        dut.if_stage_inst.imem.memory[44] =
            32'h000D2D83; // lw x27,0(x26)

        dut.if_stage_inst.imem.memory[45] =
            32'h000D8E67; // jalr x28,0(x27)

        dut.if_stage_inst.imem.memory[46] =
            32'h00800F13; // WRONG

        dut.if_stage_inst.imem.memory[47] =
            32'h00800F93; // WRONG

        dut.if_stage_inst.imem.memory[48] =
            32'h01D00E93; // addi x29,x0,29


        // =====================================================
        // RESET
        // =====================================================

        repeat (3) @(posedge clk);

        reset = 1'b0;


        // =====================================================
        // EJECUTAR
        // =====================================================

        repeat (90) @(posedge clk);

        #1;


        // =====================================================
        // RESULTADOS DE BRANCHES
        // =====================================================

        check_register(
            "BEQ TARGET x3",
            3,
            32'd33
        );

        check_register(
            "BNE NOT TAKEN x4",
            4,
            32'd44
        );

        check_register(
            "BNE TARGET x5",
            5,
            32'd55
        );


        // =====================================================
        // JAL
        // =====================================================

        check_register(
            "JAL LINK x6",
            6,
            32'd56
        );

        check_register(
            "JAL TARGET x7",
            7,
            32'd77
        );


        // =====================================================
        // JALR
        // =====================================================

        check_register(
            "JALR SOURCE x8",
            8,
            32'd89
        );

        check_register(
            "JALR LINK x9",
            9,
            32'd76
        );

        check_register(
            "JALR TARGET x12",
            12,
            32'd12
        );


        // =====================================================
        // ALU -> BRANCH
        // =====================================================

        check_register(
            "ALU RESULT x15",
            15,
            32'd3
        );

        check_register(
            "ALU->BEQ TARGET x17",
            17,
            32'd17
        );


        // =====================================================
        // ALU -> JALR
        // =====================================================

        check_register(
            "ALU JALR SOURCE x19",
            19,
            32'd140
        );

        check_register(
            "ALU->JALR LINK x20",
            20,
            32'd136
        );

        check_register(
            "ALU->JALR TARGET x21",
            21,
            32'd21
        );


        // =====================================================
        // LOAD -> BRANCH
        // =====================================================

        check_register(
            "LOAD VALUE x23",
            23,
            32'd7
        );

        check_register(
            "LOAD->BEQ TARGET x25",
            25,
            32'd25
        );


        // =====================================================
        // LOAD -> JALR
        // =====================================================

        check_register(
            "LOAD JALR SOURCE x27",
            27,
            32'd193
        );

        check_register(
            "LOAD->JALR LINK x28",
            28,
            32'd184
        );

        check_register(
            "LOAD->JALR TARGET x29",
            29,
            32'd29
        );


        // =====================================================
        // INSTRUCCIONES DEL CAMINO INCORRECTO
        //
        // Todas intentaban escribir x30/x31.
        // Ninguna debe haber sobrevivido.
        // =====================================================

        check_register(
            "WRONG PATH x30",
            30,
            32'd0
        );

        check_register(
            "WRONG PATH x31",
            31,
            32'd0
        );


        // =====================================================
        // CONTADORES
        // =====================================================

        check32(
            "REDIRECT COUNT",
            redirect_count,
            32'd8
        );

        check32(
            "STALL COUNT",
            stall_count,
            32'd2
        );


        // =====================================================
        // OBSERVACIONES DE CONTROL
        // =====================================================

        check_bool(
            "BNE NOT TAKEN SEEN",
            saw_bne_not_taken,
            1'b1
        );

        check_bool(
            "FLUSH CONTROLS",
            saw_flush_controls,
            1'b1
        );

        check_bool(
            "POST REDIRECT BUBBLES",
            saw_post_redirect_bubbles,
            1'b1
        );


        // =====================================================
        // FORWARDING DE CONTROL
        // =====================================================

        check_bool(
            "ALU->BRANCH FORWARD",
            saw_alu_branch_forward,
            1'b1
        );

        check_bool(
            "ALU->JALR FORWARD",
            saw_alu_jalr_forward,
            1'b1
        );


        // =====================================================
        // LOAD-USE + CONTROL
        // =====================================================

        check_bool(
            "LOAD->BRANCH STALL",
            saw_load_branch_stall,
            1'b1
        );

        check_bool(
            "LOAD->JALR STALL",
            saw_load_jalr_stall,
            1'b1
        );

        check_bool(
            "LOAD->BRANCH FORWARD",
            saw_load_branch_forward,
            1'b1
        );

        check_bool(
            "LOAD->JALR FORWARD",
            saw_load_jalr_forward,
            1'b1
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PIPELINE CONTROL HAZARDS TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("Redirects    : %0d", redirect_count);
        $display("Stalls       : %0d", stall_count);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: pipeline_core_control_hazards");

        end
        else begin

            $fatal(
                1,
                "FAIL: pipeline_core_control_hazards"
            );

        end

        $finish;

    end

endmodule
