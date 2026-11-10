`timescale 1ns / 1ps

module debug_core_integration_tb;

    logic clk;
    logic reset;
    logic cycle_enable;


    // =========================================================
    // PROGRAMMING PORT
    // =========================================================

    logic        program_write_enable;
    logic [31:0] program_write_address;
    logic [31:0] program_write_data;


    // =========================================================
    // CORE STATE
    // =========================================================

    logic running;
    logic draining;
    logic halted;
    logic pipeline_empty;


    // =========================================================
    // DEBUG REGISTER FILE
    // =========================================================

    logic [4:0]  debug_register_address;
    logic [31:0] debug_register_data;


    // =========================================================
    // DEBUG DATA MEMORY
    // =========================================================

    logic [31:0] debug_memory_address;
    logic [31:0] debug_memory_data;

    logic        debug_memory_access_valid;
    logic [31:0] debug_memory_access_address;


    // =========================================================
    // PIPELINE OBSERVATION
    // =========================================================

    logic [31:0] debug_if_pc_current;


    logic        debug_if_id_valid;
    logic [31:0] debug_if_id_pc;
    logic [31:0] debug_if_id_instruction;


    logic        debug_id_ex_valid;

    logic [31:0] debug_id_ex_pc;
    logic [31:0] debug_id_ex_read_data1;
    logic [31:0] debug_id_ex_read_data2;
    logic [31:0] debug_id_ex_immediate;

    logic [4:0] debug_id_ex_rs1;
    logic [4:0] debug_id_ex_rs2;
    logic [4:0] debug_id_ex_rd;

    logic [6:0] debug_id_ex_opcode;
    logic [2:0] debug_id_ex_funct3;
    logic [6:0] debug_id_ex_funct7;

    logic       debug_id_ex_alu_src_a;
    logic       debug_id_ex_alu_src_b;
    logic [2:0] debug_id_ex_alu_op;

    logic       debug_id_ex_branch;
    logic [1:0] debug_id_ex_jump_type;

    logic debug_id_ex_mem_read;
    logic debug_id_ex_mem_write;

    logic       debug_id_ex_reg_write;
    logic [1:0] debug_id_ex_wb_sel;


    logic        debug_ex_mem_valid;

    logic [31:0] debug_ex_mem_pc;
    logic [31:0] debug_ex_mem_alu_result;
    logic [31:0] debug_ex_mem_store_data;

    logic [4:0] debug_ex_mem_rs2;
    logic [4:0] debug_ex_mem_rd;

    logic [6:0] debug_ex_mem_opcode;
    logic [2:0] debug_ex_mem_funct3;

    logic debug_ex_mem_mem_read;
    logic debug_ex_mem_mem_write;

    logic       debug_ex_mem_reg_write;
    logic [1:0] debug_ex_mem_wb_sel;


    logic        debug_mem_wb_valid;

    logic [31:0] debug_mem_wb_pc;
    logic [31:0] debug_mem_wb_alu_result;
    logic [31:0] debug_mem_wb_load_data;

    logic [4:0] debug_mem_wb_rd;
    logic [6:0] debug_mem_wb_opcode;

    logic       debug_mem_wb_reg_write;
    logic [1:0] debug_mem_wb_wb_sel;


    // =========================================================
    // DEBUG UNIT
    // =========================================================

    logic snapshot_start;
    logic snapshot_busy;
    logic snapshot_done;

    logic [2:0] status_code;

    logic memory_usage_clear;
    logic [15:0] used_memory_count;

    logic       snapshot_byte_valid;
    logic [7:0] snapshot_byte_data;
    logic       snapshot_byte_ready;


    // =========================================================
    // CAPTURE BUFFER
    // =========================================================

    logic [7:0] received_bytes [0:511];

    integer received_count;

    logic clear_capture;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer timeout;


    // =========================================================
    // CORE
    // =========================================================

    pipeline_core core (
        .clk                    (clk),
        .reset                  (reset),

        .cycle_enable           (cycle_enable),

        .program_write_enable   (program_write_enable),
        .program_write_address  (program_write_address),
        .program_write_data     (program_write_data),

        .debug_register_address (debug_register_address),
        .debug_register_data    (debug_register_data),

        .debug_memory_address   (debug_memory_address),
        .debug_memory_data      (debug_memory_data),

        .debug_if_pc_current (
            debug_if_pc_current
        ),

        .debug_if_id_valid (
            debug_if_id_valid
        ),

        .debug_if_id_pc (
            debug_if_id_pc
        ),

        .debug_if_id_instruction (
            debug_if_id_instruction
        ),

        .debug_id_ex_valid (
            debug_id_ex_valid
        ),

        .debug_id_ex_pc (
            debug_id_ex_pc
        ),

        .debug_id_ex_read_data1 (
            debug_id_ex_read_data1
        ),

        .debug_id_ex_read_data2 (
            debug_id_ex_read_data2
        ),

        .debug_id_ex_immediate (
            debug_id_ex_immediate
        ),

        .debug_id_ex_rs1 (
            debug_id_ex_rs1
        ),

        .debug_id_ex_rs2 (
            debug_id_ex_rs2
        ),

        .debug_id_ex_rd (
            debug_id_ex_rd
        ),

        .debug_id_ex_opcode (
            debug_id_ex_opcode
        ),

        .debug_id_ex_funct3 (
            debug_id_ex_funct3
        ),

        .debug_id_ex_funct7 (
            debug_id_ex_funct7
        ),

        .debug_id_ex_alu_src_a (
            debug_id_ex_alu_src_a
        ),

        .debug_id_ex_alu_src_b (
            debug_id_ex_alu_src_b
        ),

        .debug_id_ex_alu_op (
            debug_id_ex_alu_op
        ),

        .debug_id_ex_branch (
            debug_id_ex_branch
        ),

        .debug_id_ex_jump_type (
            debug_id_ex_jump_type
        ),

        .debug_id_ex_mem_read (
            debug_id_ex_mem_read
        ),

        .debug_id_ex_mem_write (
            debug_id_ex_mem_write
        ),

        .debug_id_ex_reg_write (
            debug_id_ex_reg_write
        ),

        .debug_id_ex_wb_sel (
            debug_id_ex_wb_sel
        ),

        .debug_ex_mem_valid (
            debug_ex_mem_valid
        ),

        .debug_ex_mem_pc (
            debug_ex_mem_pc
        ),

        .debug_ex_mem_alu_result (
            debug_ex_mem_alu_result
        ),

        .debug_ex_mem_store_data (
            debug_ex_mem_store_data
        ),

        .debug_ex_mem_rs2 (
            debug_ex_mem_rs2
        ),

        .debug_ex_mem_rd (
            debug_ex_mem_rd
        ),

        .debug_ex_mem_opcode (
            debug_ex_mem_opcode
        ),

        .debug_ex_mem_funct3 (
            debug_ex_mem_funct3
        ),

        .debug_ex_mem_mem_read (
            debug_ex_mem_mem_read
        ),

        .debug_ex_mem_mem_write (
            debug_ex_mem_mem_write
        ),

        .debug_ex_mem_reg_write (
            debug_ex_mem_reg_write
        ),

        .debug_ex_mem_wb_sel (
            debug_ex_mem_wb_sel
        ),

        .debug_mem_wb_valid (
            debug_mem_wb_valid
        ),

        .debug_mem_wb_pc (
            debug_mem_wb_pc
        ),

        .debug_mem_wb_alu_result (
            debug_mem_wb_alu_result
        ),

        .debug_mem_wb_load_data (
            debug_mem_wb_load_data
        ),

        .debug_mem_wb_rd (
            debug_mem_wb_rd
        ),

        .debug_mem_wb_opcode (
            debug_mem_wb_opcode
        ),

        .debug_mem_wb_reg_write (
            debug_mem_wb_reg_write
        ),

        .debug_mem_wb_wb_sel (
            debug_mem_wb_wb_sel
        ),

        .debug_memory_access_valid (
            debug_memory_access_valid
        ),

        .debug_memory_access_address (
            debug_memory_access_address
        ),

        .running        (running),
        .draining       (draining),
        .halted         (halted),
        .pipeline_empty (pipeline_empty)
    );


    // =========================================================
    // STATUS CODE PARA EL SNAPSHOT
    // =========================================================

    always_comb begin

        if (halted)
            status_code = 3'd4;

        else if (draining)
            status_code = 3'd3;

        else if (cycle_enable)
            status_code = 3'd2;

        else
            status_code = 3'd0;

    end


    // =========================================================
    // DEBUG UNIT
    // =========================================================

    debug_unit #(
        .DATA_MEM_DEPTH (256)
    ) debug (
        .clk                 (clk),
        .reset               (reset),

        .snapshot_start      (snapshot_start),
        .snapshot_busy       (snapshot_busy),
        .snapshot_done       (snapshot_done),

        .status_code         (status_code),

        .core_running        (running),
        .core_draining       (draining),
        .core_halted         (halted),
        .core_pipeline_empty (pipeline_empty),
        .core_cycle_enable   (cycle_enable),

        .if_pc_current       (debug_if_pc_current),

        .if_id_valid         (debug_if_id_valid),
        .if_id_pc            (debug_if_id_pc),
        .if_id_instruction   (debug_if_id_instruction),

        .id_ex_valid         (debug_id_ex_valid),

        .id_ex_pc            (debug_id_ex_pc),
        .id_ex_read_data1    (debug_id_ex_read_data1),
        .id_ex_read_data2    (debug_id_ex_read_data2),
        .id_ex_immediate     (debug_id_ex_immediate),

        .id_ex_rs1           (debug_id_ex_rs1),
        .id_ex_rs2           (debug_id_ex_rs2),
        .id_ex_rd            (debug_id_ex_rd),

        .id_ex_opcode        (debug_id_ex_opcode),
        .id_ex_funct3        (debug_id_ex_funct3),
        .id_ex_funct7        (debug_id_ex_funct7),

        .id_ex_alu_src_a     (debug_id_ex_alu_src_a),
        .id_ex_alu_src_b     (debug_id_ex_alu_src_b),
        .id_ex_alu_op        (debug_id_ex_alu_op),

        .id_ex_branch        (debug_id_ex_branch),
        .id_ex_jump_type     (debug_id_ex_jump_type),

        .id_ex_mem_read      (debug_id_ex_mem_read),
        .id_ex_mem_write     (debug_id_ex_mem_write),

        .id_ex_reg_write     (debug_id_ex_reg_write),
        .id_ex_wb_sel        (debug_id_ex_wb_sel),

        .ex_mem_valid        (debug_ex_mem_valid),

        .ex_mem_pc           (debug_ex_mem_pc),
        .ex_mem_alu_result   (debug_ex_mem_alu_result),
        .ex_mem_store_data   (debug_ex_mem_store_data),

        .ex_mem_rs2          (debug_ex_mem_rs2),
        .ex_mem_rd           (debug_ex_mem_rd),

        .ex_mem_opcode       (debug_ex_mem_opcode),
        .ex_mem_funct3       (debug_ex_mem_funct3),

        .ex_mem_mem_read     (debug_ex_mem_mem_read),
        .ex_mem_mem_write    (debug_ex_mem_mem_write),

        .ex_mem_reg_write    (debug_ex_mem_reg_write),
        .ex_mem_wb_sel       (debug_ex_mem_wb_sel),

        .mem_wb_valid        (debug_mem_wb_valid),

        .mem_wb_pc           (debug_mem_wb_pc),
        .mem_wb_alu_result   (debug_mem_wb_alu_result),
        .mem_wb_load_data    (debug_mem_wb_load_data),

        .mem_wb_rd           (debug_mem_wb_rd),
        .mem_wb_opcode       (debug_mem_wb_opcode),

        .mem_wb_reg_write    (debug_mem_wb_reg_write),
        .mem_wb_wb_sel       (debug_mem_wb_wb_sel),

        .debug_register_address (
            debug_register_address
        ),

        .debug_register_data (
            debug_register_data
        ),

        .debug_memory_address (
            debug_memory_address
        ),

        .debug_memory_data (
            debug_memory_data
        ),

        .memory_access_valid (
            debug_memory_access_valid
        ),

        .memory_access_address (
            debug_memory_access_address
        ),

        .memory_usage_clear (
            memory_usage_clear
        ),

        .used_memory_count (
            used_memory_count
        ),

        .snapshot_byte_valid (
            snapshot_byte_valid
        ),

        .snapshot_byte_data (
            snapshot_byte_data
        ),

        .snapshot_byte_ready (
            snapshot_byte_ready
        )
    );


    // =========================================================
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // CAPTURE SNAPSHOT STREAM
    // =========================================================

    always @(posedge clk) begin

        #1;

        if (reset || clear_capture) begin

            received_count = 0;

        end
        else if (
            snapshot_byte_valid &&
            snapshot_byte_ready
        ) begin

            received_bytes[
                received_count
            ] = snapshot_byte_data;

            received_count =
                received_count + 1;

        end

    end


    // =========================================================
    // PROGRAM WORD
    // =========================================================

    task automatic program_word (
        input logic [31:0] address,
        input logic [31:0] data
    );

        begin

            @(negedge clk);

            program_write_address =
                address;

            program_write_data =
                data;

            program_write_enable =
                1'b1;

            @(negedge clk);

            program_write_enable =
                1'b0;

        end

    endtask


    // =========================================================
    // EJECUTAR N CICLOS
    // =========================================================

    task automatic run_cycles (
        input integer count
    );

        integer i;

        begin

            @(negedge clk);

            cycle_enable =
                1'b1;

            for (i = 0; i < count; i = i + 1)
                @(posedge clk);

            @(negedge clk);

            cycle_enable =
                1'b0;

        end

    endtask


    // =========================================================
    // INICIAR Y ESPERAR SNAPSHOT
    // =========================================================

    task automatic take_snapshot;

        begin

            @(negedge clk);

            clear_capture =
                1'b1;

            @(negedge clk);

            clear_capture =
                1'b0;

            snapshot_start =
                1'b1;

            @(negedge clk);

            snapshot_start =
                1'b0;


            timeout =
                0;

            while (
                !snapshot_done &&
                timeout < 3000
            ) begin

                @(posedge clk);

                #1;

                timeout =
                    timeout + 1;

            end


            if (!snapshot_done) begin

                $display(
                    "FAIL: snapshot timeout"
                );

                $fatal;

            end

        end

    endtask


    // =========================================================
    // CHECKS
    // =========================================================

    task automatic check8 (
        input string      name,
        input logic [7:0] received,
        input logic [7:0] expected
    );

        begin

            tests_run =
                tests_run + 1;

            if (received === expected) begin

                tests_passed =
                    tests_passed + 1;

                $display(
                    "PASS: %-36s | VALUE=%02h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-36s | VALUE=%02h expected=%02h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    task automatic check16 (
        input string       name,
        input logic [15:0] received,
        input logic [15:0] expected
    );

        begin

            tests_run =
                tests_run + 1;

            if (received === expected) begin

                tests_passed =
                    tests_passed + 1;

                $display(
                    "PASS: %-36s | VALUE=%04h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-36s | VALUE=%04h expected=%04h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    task automatic check32 (
        input string       name,
        input logic [31:0] received,
        input logic [31:0] expected
    );

        begin

            tests_run =
                tests_run + 1;

            if (received === expected) begin

                tests_passed =
                    tests_passed + 1;

                $display(
                    "PASS: %-36s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-36s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    function automatic logic [31:0]
    bytes_to_word (
        input integer base
    );

        begin

            bytes_to_word = {
                received_bytes[base],
                received_bytes[base + 1],
                received_bytes[base + 2],
                received_bytes[base + 3]
            };

        end

    endfunction


    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        clk =
            1'b0;

        reset =
            1'b1;

        cycle_enable =
            1'b0;

        program_write_enable =
            1'b0;

        program_write_address =
            32'd0;

        program_write_data =
            32'd0;

        snapshot_start =
            1'b0;

        snapshot_byte_ready =
            1'b1;

        memory_usage_clear =
            1'b0;

        clear_capture =
            1'b0;

        received_count =
            0;

        tests_run =
            0;

        tests_passed =
            0;

        tests_failed =
            0;


        // =====================================================
        // PROGRAM
        //
        // 0x00: addi x1,x0,64
        // 0x04: addi x2,x0,85
        // 0x08: sw   x2,0(x1)
        // 0x0C: lw   x3,0(x1)
        // 0x10: addi x4,x3,1
        // 0x14: HALT
        // =====================================================

        program_word(
            32'h00000000,
            32'h04000093
        );

        program_word(
            32'h00000004,
            32'h05500113
        );

        program_word(
            32'h00000008,
            32'h0020A023
        );

        program_word(
            32'h0000000C,
            32'h0000A183
        );

        program_word(
            32'h00000010,
            32'h00118213
        );

        program_word(
            32'h00000014,
            32'h0000000B
        );


        // =====================================================
        // LIBERAR RESET
        // =====================================================

        repeat (2)
            @(posedge clk);

        @(negedge clk);

        reset =
            1'b0;


        // Limpieza explícita del mapa de memoria usada.

        @(negedge clk);

        memory_usage_clear =
            1'b1;

        @(negedge clk);

        memory_usage_clear =
            1'b0;


        // =====================================================
        // PRIMEROS 4 CICLOS
        //
        // Después de cuatro ciclos esperamos:
        //
        // IF     PC = 16
        // IF/ID  PC = 12
        // ID/EX  PC = 8
        // EX/MEM PC = 4
        // MEM/WB PC = 0
        //
        // Ningún load/store llegó todavía a MEM.
        // =====================================================

        run_cycles(4);


        check32(
            "CORE PAUSED AFTER 4 CYCLES",
            cycle_enable,
            32'd0
        );

        check32(
            "USED MEMORY BEFORE MEM ACCESS",
            used_memory_count,
            32'd0
        );


        // =====================================================
        // SNAPSHOT INTERMEDIO
        // =====================================================

        take_snapshot;


        check32(
            "MID SNAPSHOT BYTE COUNT",
            received_count,
            32'd246
        );


        check8(
            "MID SNAPSHOT TAG",
            received_bytes[0],
            8'h64
        );


        check8(
            "MID SNAPSHOT FLAGS",
            received_bytes[3],
            8'h01
        );


        check32(
            "MID IF PC",
            bytes_to_word(4),
            32'h00000010
        );


        // IF/ID empieza en 170.

        check8(
            "MID IF/ID VALID",
            received_bytes[171],
            8'h01
        );

        check32(
            "MID IF/ID PC",
            bytes_to_word(172),
            32'h0000000C
        );

        check32(
            "MID IF/ID INSTRUCTION",
            bytes_to_word(176),
            32'h0000A183
        );


        // ID/EX empieza en 180.

        check8(
            "MID ID/EX VALID",
            received_bytes[181],
            8'h01
        );

        check32(
            "MID ID/EX PC",
            bytes_to_word(182),
            32'h00000008
        );


        // EX/MEM empieza en 206.

        check8(
            "MID EX/MEM VALID",
            received_bytes[207],
            8'h01
        );

        check32(
            "MID EX/MEM PC",
            bytes_to_word(208),
            32'h00000004
        );


        // MEM/WB empieza en 225.

        check8(
            "MID MEM/WB VALID",
            received_bytes[226],
            8'h01
        );

        check32(
            "MID MEM/WB PC",
            bytes_to_word(227),
            32'h00000000
        );


        check16(
            "MID MEMORY USED COUNT",
            {
                received_bytes[243],
                received_bytes[244]
            },
            16'd0
        );


        check8(
            "MID END TAG",
            received_bytes[245],
            8'h7E
        );


        // =====================================================
        // REANUDAR HASTA HALT
        // =====================================================

        @(negedge clk);

        cycle_enable =
            1'b1;


        timeout =
            0;

        while (
            !halted &&
            timeout < 100
        ) begin

            @(posedge clk);

            #1;

            timeout =
                timeout + 1;

        end


        if (!halted) begin

            $display(
                "FAIL: processor did not reach HALT"
            );

            $fatal;

        end


        @(negedge clk);

        cycle_enable =
            1'b0;


        check32(
            "HALTED",
            halted,
            32'd1
        );

        check32(
            "PIPELINE EMPTY",
            pipeline_empty,
            32'd1
        );


        // Store y load utilizaron la misma palabra.
        //
        // Por lo tanto debe existir una sola palabra marcada.

        check32(
            "USED MEMORY FINAL COUNT",
            used_memory_count,
            32'd1
        );


        // =====================================================
        // SNAPSHOT FINAL
        // =====================================================

        take_snapshot;


        // 246 bytes fijos + 6 bytes de una palabra DMEM.

        check32(
            "FINAL SNAPSHOT BYTE COUNT",
            received_count,
            32'd252
        );


        check8(
            "FINAL STATUS HALTED",
            received_bytes[2],
            8'h04
        );


        // halted + pipeline_empty:
        //
        // bit3 = pipeline_empty
        // bit2 = halted
        //
        // 00001100 = 0x0C

        check8(
            "FINAL FLAGS",
            received_bytes[3],
            8'h0C
        );


        // =====================================================
        // REGISTER FILE FINAL
        //
        // x1 = 64
        // x2 = 85
        // x3 = 85
        // x4 = 86
        // =====================================================

        check32(
            "FINAL x1",
            bytes_to_word(16),
            32'd64
        );


        check32(
            "FINAL x2",
            bytes_to_word(21),
            32'd85
        );


        check32(
            "FINAL x3",
            bytes_to_word(26),
            32'd85
        );


        check32(
            "FINAL x4",
            bytes_to_word(31),
            32'd86
        );


        // =====================================================
        // PIPELINE FINAL VACÍO
        // =====================================================

        check8(
            "FINAL IF/ID INVALID",
            received_bytes[171],
            8'h00
        );

        check8(
            "FINAL ID/EX INVALID",
            received_bytes[181],
            8'h00
        );

        check8(
            "FINAL EX/MEM INVALID",
            received_bytes[207],
            8'h00
        );

        check8(
            "FINAL MEM/WB INVALID",
            received_bytes[226],
            8'h00
        );


        // =====================================================
        // DATA MEMORY UTILIZADA
        // =====================================================

        check16(
            "FINAL MEMORY COUNT",
            {
                received_bytes[243],
                received_bytes[244]
            },
            16'd1
        );


        check16(
            "FINAL MEMORY ADDRESS",
            {
                received_bytes[245],
                received_bytes[246]
            },
            16'h0040
        );


        check32(
            "FINAL MEMORY VALUE",
            bytes_to_word(247),
            32'd85
        );


        check8(
            "FINAL END TAG",
            received_bytes[251],
            8'h7E
        );


        // =====================================================
        // RESULT
        // =====================================================

        $display("");

        $display(
            "Tests run    : %0d",
            tests_run
        );

        $display(
            "Tests passed : %0d",
            tests_passed
        );

        $display(
            "Tests failed : %0d",
            tests_failed
        );


        if (tests_failed == 0)
            $display(
                "PASS: debug_core_integration"
            );
        else
            $fatal(
                1,
                "FAIL: debug_core_integration"
            );


        $finish;

    end

endmodule
