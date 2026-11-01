`timescale 1ns / 1ps

module pipeline_core_load_use_tb;

    logic clk;
    logic reset;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer stall_count;

    logic saw_add_stall;
    logic saw_sub_stall;
    logic saw_load_base_stall;
    logic saw_store_base_stall;

    logic saw_mem_wb_forward;


    logic [31:0] pc_before_stall;
    logic [31:0] if_id_pc_before_stall;
    logic [31:0] if_id_instruction_before_stall;


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

    initial clk = 1'b0;

    always #5 clk = ~clk;


    // =========================================================
    // MONITOR
    // =========================================================

    always @(posedge clk) begin

        if (!reset) begin

            if (dut.load_use_stall) begin

                stall_count = stall_count + 1;

                case (dut.if_id_pc)

                    // add x6,x5,x2
                    32'd12:
                        saw_add_stall = 1'b1;

                    // sub x10,x7,x2
                    32'd20:
                        saw_sub_stall = 1'b1;

                    // lw x9,0(x8)
                    32'd28:
                        saw_load_base_stall = 1'b1;

                    // sw x2,0(x11)
                    32'd36:
                        saw_store_base_stall = 1'b1;

                    default: begin
                    end

                endcase

            end


            if (
                dut.forward_a == 2'b01 ||
                dut.forward_b == 2'b01
            ) begin

                saw_mem_wb_forward = 1'b1;

            end

        end

    end


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
                    "PASS: %-24s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-24s | VALUE=%08h expected=%08h",
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
                    "PASS: %-24s | VALUE=%0d",
                    name,
                    received
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-24s | VALUE=%0d expected=%0d",
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
    // TEST
    // =========================================================

    initial begin

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        stall_count = 0;

        saw_add_stall        = 1'b0;
        saw_sub_stall        = 1'b0;
        saw_load_base_stall  = 1'b0;
        saw_store_base_stall = 1'b0;

        saw_mem_wb_forward = 1'b0;


        // =====================================================
        // DATA MEMORY
        //
        // byte 64 -> word 16 = 68 decimal = 0x44
        // byte 68 -> word 17 = 99 decimal = 0x63
        // =====================================================

        dut.mem_stage_inst.data_memory_inst.memory[16] =
            32'd68;

        dut.mem_stage_inst.data_memory_inst.memory[17] =
            32'd99;


        // =====================================================
        // PROGRAMA
        // =====================================================

        // I1: addi x1,x0,64
        dut.if_stage_inst.imem.memory[0] = 32'h04000093;

        // I2: addi x2,x0,10
        dut.if_stage_inst.imem.memory[1] = 32'h00A00113;


        // -----------------------------------------------------
        // LOAD-USE 1: lw -> add
        //
        // x5 = 68
        // x6 = 68 + 10 = 78
        // -----------------------------------------------------

        // I3: lw x5,0(x1)
        dut.if_stage_inst.imem.memory[2] = 32'h0000A283;

        // I4: add x6,x5,x2
        dut.if_stage_inst.imem.memory[3] = 32'h00228333;


        // -----------------------------------------------------
        // LOAD-USE 2: lw -> sub
        //
        // x7  = 68
        // x10 = 68 - 10 = 58
        // -----------------------------------------------------

        // I5: lw x7,0(x1)
        dut.if_stage_inst.imem.memory[4] = 32'h0000A383;

        // I6: sub x10,x7,x2
        dut.if_stage_inst.imem.memory[5] = 32'h40238533;


        // -----------------------------------------------------
        // LOAD-USE 3: load -> load base
        //
        // x8 = 68
        //
        // luego:
        // lw x9,0(x8)
        //
        // address = 68
        // DMEM[68] = 99
        //
        // x9 = 99
        // -----------------------------------------------------

        // I7: lw x8,0(x1)
        dut.if_stage_inst.imem.memory[6] = 32'h0000A403;

        // I8: lw x9,0(x8)
        dut.if_stage_inst.imem.memory[7] = 32'h00042483;


        // -----------------------------------------------------
        // LOAD-USE 4: load -> store base
        //
        // x11 = 68
        //
        // sw x2,0(x11)
        //
        // DMEM[68] <- 10
        // -----------------------------------------------------

        // I9: lw x11,0(x1)
        dut.if_stage_inst.imem.memory[8] = 32'h0000A583;

        // I10: sw x2,0(x11)
        dut.if_stage_inst.imem.memory[9] = 32'h0025A023;


        // =====================================================
        // NOPS
        // =====================================================

        dut.if_stage_inst.imem.memory[10] = 32'h00000013;
        dut.if_stage_inst.imem.memory[11] = 32'h00000013;
        dut.if_stage_inst.imem.memory[12] = 32'h00000013;
        dut.if_stage_inst.imem.memory[13] = 32'h00000013;
        dut.if_stage_inst.imem.memory[14] = 32'h00000013;
        dut.if_stage_inst.imem.memory[15] = 32'h00000013;
        dut.if_stage_inst.imem.memory[16] = 32'h00000013;
        dut.if_stage_inst.imem.memory[17] = 32'h00000013;
        dut.if_stage_inst.imem.memory[18] = 32'h00000013;
        dut.if_stage_inst.imem.memory[19] = 32'h00000013;


        // =====================================================
        // RESET
        // =====================================================

        reset = 1'b1;

        repeat (3) @(posedge clk);

        reset = 1'b0;


        // =====================================================
        // ESPERAR PRIMER STALL
        //
        // En ese momento:
        //
        // lw x5 -> EX
        // add   -> ID
        // =====================================================

        wait (dut.load_use_stall === 1'b1);

        #1;

        pc_before_stall =
            dut.if_pc_current;

        if_id_pc_before_stall =
            dut.if_id_pc;

        if_id_instruction_before_stall =
            dut.if_id_instruction;


        // =====================================================
        // APLICACIÓN DEL STALL
        // =====================================================

        @(posedge clk);
        #1;


        // -----------------------------------------------------
        // PC debe quedar congelado
        // -----------------------------------------------------

        check32(
            "PC HOLD",
            dut.if_pc_current,
            pc_before_stall
        );


        // -----------------------------------------------------
        // IF/ID debe mantener la misma instrucción
        // -----------------------------------------------------

        check32(
            "IF/ID PC HOLD",
            dut.if_id_pc,
            if_id_pc_before_stall
        );


        check32(
            "IF/ID INSTR HOLD",
            dut.if_id_instruction,
            if_id_instruction_before_stall
        );


        // -----------------------------------------------------
        // ID/EX debe transformarse en burbuja
        // -----------------------------------------------------

        check_bool(
            "ID/EX BUBBLE",
            dut.id_ex_valid,
            1'b0
        );


        // -----------------------------------------------------
        // El load debe haber avanzado a EX/MEM.
        // -----------------------------------------------------

        check_bool(
            "LOAD ADVANCED TO MEM",
            dut.ex_mem_mem_read,
            1'b1
        );


        check32(
            "LOAD RD IN EX/MEM",
            {27'd0, dut.ex_mem_rd},
            32'd5
        );


        // =====================================================
        // EJECUTAR RESTO DEL PROGRAMA
        // =====================================================

        repeat (35) @(posedge clk);

        #1;


        // =====================================================
        // RESULTADOS
        // =====================================================

        check_register(
            "x1 BASE",
            1,
            32'd64
        );

        check_register(
            "x2 VALUE",
            2,
            32'd10
        );

        check_register(
            "LW -> x5",
            5,
            32'd68
        );

        check_register(
            "LW->ADD x6",
            6,
            32'd78
        );

        check_register(
            "LW -> x7",
            7,
            32'd68
        );

        check_register(
            "LW->SUB x10",
            10,
            32'd58
        );

        check_register(
            "LW -> x8",
            8,
            32'd68
        );

        check_register(
            "LW->LW x9",
            9,
            32'd99
        );

        check_register(
            "LW -> x11",
            11,
            32'd68
        );


        // Después del store:
        //
        // DMEM byte 68 = word index 17 = 10

        check32(
            "LW->STORE BASE",
            dut.mem_stage_inst.data_memory_inst.memory[17],
            32'd10
        );


        // =====================================================
        // STALL COUNT
        //
        // Esperamos exactamente cuatro:
        //
        // lw->add
        // lw->sub
        // lw->load-base
        // lw->store-base
        // =====================================================

        check32(
            "STALL COUNT",
            stall_count,
            32'd4
        );


        // =====================================================
        // CADA HAZARD DEBIÓ SER DETECTADO
        // =====================================================

        check_bool(
            "ADD STALL SEEN",
            saw_add_stall,
            1'b1
        );

        check_bool(
            "SUB STALL SEEN",
            saw_sub_stall,
            1'b1
        );

        check_bool(
            "LOAD BASE STALL SEEN",
            saw_load_base_stall,
            1'b1
        );

        check_bool(
            "STORE BASE STALL SEEN",
            saw_store_base_stall,
            1'b1
        );


        // =====================================================
        // DESPUÉS DEL STALL DEBE APARECER FORWARDING MEM/WB
        // =====================================================

        check_bool(
            "MEM/WB FORWARD SEEN",
            saw_mem_wb_forward,
            1'b1
        );


        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("==============================================");
        $display("PIPELINE LOAD-USE TEST SUMMARY");
        $display("==============================================");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("Stalls       : %0d", stall_count);
        $display("==============================================");
        $display("");

        if (tests_failed == 0) begin

            $display("PASS: pipeline_core_load_use");

        end
        else begin

            $fatal(
                1,
                "FAIL: pipeline_core_load_use | %0d test(s) failed",
                tests_failed
            );

        end

        #5;
        $finish;

    end

endmodule
