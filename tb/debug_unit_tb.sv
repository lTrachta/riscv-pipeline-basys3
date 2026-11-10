`timescale 1ns / 1ps

module debug_unit_tb;

    localparam integer DATA_MEM_DEPTH = 256;

    logic clk;
    logic reset;

    logic snapshot_start;
    logic snapshot_busy;
    logic snapshot_done;

    logic [2:0] status_code;

    logic core_running;
    logic core_draining;
    logic core_halted;
    logic core_pipeline_empty;
    logic core_cycle_enable;

    logic [31:0] if_pc_current;

    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;

    logic        id_ex_valid;
    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;
    logic [31:0] id_ex_immediate;

    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;
    logic [4:0] id_ex_rd;

    logic [6:0] id_ex_opcode;
    logic [2:0] id_ex_funct3;
    logic [6:0] id_ex_funct7;

    logic       id_ex_alu_src_a;
    logic       id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;

    logic       id_ex_branch;
    logic [1:0] id_ex_jump_type;

    logic id_ex_mem_read;
    logic id_ex_mem_write;

    logic       id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;


    logic        ex_mem_valid;
    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;

    logic [4:0] ex_mem_rs2;
    logic [4:0] ex_mem_rd;

    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;

    logic ex_mem_mem_read;
    logic ex_mem_mem_write;

    logic       ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;


    logic        mem_wb_valid;
    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;

    logic [4:0] mem_wb_rd;
    logic [6:0] mem_wb_opcode;

    logic       mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;


    logic [4:0]  debug_register_address;
    logic [31:0] debug_register_data;

    logic [31:0] debug_memory_address;
    logic [31:0] debug_memory_data;

    logic        memory_access_valid;
    logic [31:0] memory_access_address;
    logic        memory_usage_clear;

    logic [15:0] used_memory_count;

    logic       snapshot_byte_valid;
    logic [7:0] snapshot_byte_data;
    logic       snapshot_byte_ready;


    // =========================================================
    // CAPTURA DEL STREAM
    // =========================================================

    logic [7:0] received_bytes [0:511];

    integer received_count;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer timeout;


    // =========================================================
    // DUT
    // =========================================================

    debug_unit #(
        .DATA_MEM_DEPTH (DATA_MEM_DEPTH)
    ) dut (
        .clk                  (clk),
        .reset                (reset),

        .snapshot_start       (snapshot_start),

        .snapshot_busy        (snapshot_busy),
        .snapshot_done        (snapshot_done),

        .status_code          (status_code),

        .core_running         (core_running),
        .core_draining        (core_draining),
        .core_halted          (core_halted),
        .core_pipeline_empty  (core_pipeline_empty),
        .core_cycle_enable    (core_cycle_enable),

        .if_pc_current        (if_pc_current),

        .if_id_valid          (if_id_valid),
        .if_id_pc             (if_id_pc),
        .if_id_instruction    (if_id_instruction),

        .id_ex_valid          (id_ex_valid),

        .id_ex_pc             (id_ex_pc),
        .id_ex_read_data1     (id_ex_read_data1),
        .id_ex_read_data2     (id_ex_read_data2),
        .id_ex_immediate      (id_ex_immediate),

        .id_ex_rs1            (id_ex_rs1),
        .id_ex_rs2            (id_ex_rs2),
        .id_ex_rd             (id_ex_rd),

        .id_ex_opcode         (id_ex_opcode),
        .id_ex_funct3         (id_ex_funct3),
        .id_ex_funct7         (id_ex_funct7),

        .id_ex_alu_src_a      (id_ex_alu_src_a),
        .id_ex_alu_src_b      (id_ex_alu_src_b),
        .id_ex_alu_op         (id_ex_alu_op),

        .id_ex_branch         (id_ex_branch),
        .id_ex_jump_type      (id_ex_jump_type),

        .id_ex_mem_read       (id_ex_mem_read),
        .id_ex_mem_write      (id_ex_mem_write),

        .id_ex_reg_write      (id_ex_reg_write),
        .id_ex_wb_sel         (id_ex_wb_sel),

        .ex_mem_valid         (ex_mem_valid),

        .ex_mem_pc            (ex_mem_pc),
        .ex_mem_alu_result    (ex_mem_alu_result),
        .ex_mem_store_data    (ex_mem_store_data),

        .ex_mem_rs2           (ex_mem_rs2),
        .ex_mem_rd            (ex_mem_rd),

        .ex_mem_opcode        (ex_mem_opcode),
        .ex_mem_funct3        (ex_mem_funct3),

        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),

        .ex_mem_reg_write     (ex_mem_reg_write),
        .ex_mem_wb_sel        (ex_mem_wb_sel),

        .mem_wb_valid         (mem_wb_valid),

        .mem_wb_pc            (mem_wb_pc),
        .mem_wb_alu_result    (mem_wb_alu_result),
        .mem_wb_load_data     (mem_wb_load_data),

        .mem_wb_rd            (mem_wb_rd),
        .mem_wb_opcode        (mem_wb_opcode),

        .mem_wb_reg_write     (mem_wb_reg_write),
        .mem_wb_wb_sel        (mem_wb_wb_sel),

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
            memory_access_valid
        ),

        .memory_access_address (
            memory_access_address
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
    // REGISTER FILE SIMULADO
    //
    // Cada registro devuelve:
    //
    // xN = 0x10000000 + N
    //
    // x0 se fuerza a cero.
    // =========================================================

    always_comb begin

        if (debug_register_address == 5'd0)
            debug_register_data =
                32'd0;
        else
            debug_register_data =
                32'h10000000 +
                debug_register_address;

    end


    // =========================================================
    // DATA MEMORY SIMULADA
    // =========================================================

    always_comb begin

        case (debug_memory_address)

            32'h00000010:
                debug_memory_data =
                    32'hAABBCCDD;

            32'h00000040:
                debug_memory_data =
                    32'h00000000;

            default:
                debug_memory_data =
                    32'hDEADBEEF;

        endcase

    end


    // =========================================================
    // CAPTURA DE BYTES
    // =========================================================

    always @(posedge clk) begin

        #1;

        if (reset) begin

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
    // HELPERS
    // =========================================================

    task automatic mark_memory_used (
        input logic [31:0] address
    );

        begin

            @(negedge clk);

            memory_access_address =
                address;

            memory_access_valid =
                1'b1;

            @(negedge clk);

            memory_access_valid =
                1'b0;

        end

    endtask


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
                    "PASS: %-34s | VALUE=%02h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-34s | VALUE=%02h expected=%02h",
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
                    "PASS: %-34s | VALUE=%04h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-34s | VALUE=%04h expected=%04h",
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
                    "PASS: %-34s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-34s | VALUE=%08h expected=%08h",
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
    // TEST
    // =========================================================

    initial begin

        clk   = 1'b0;
        reset = 1'b1;

        snapshot_start =
            1'b0;

        snapshot_byte_ready =
            1'b1;

        memory_access_valid =
            1'b0;

        memory_access_address =
            32'd0;

        memory_usage_clear =
            1'b0;


        // -----------------------------------------------------
        // Estado global.
        // -----------------------------------------------------

        status_code =
            3'd0;

        core_running =
            1'b1;

        core_draining =
            1'b0;

        core_halted =
            1'b0;

        core_pipeline_empty =
            1'b0;

        core_cycle_enable =
            1'b0;


        // -----------------------------------------------------
        // IF.
        // -----------------------------------------------------

        if_pc_current =
            32'h00000014;


        // -----------------------------------------------------
        // IF / ID.
        // -----------------------------------------------------

        if_id_valid =
            1'b1;

        if_id_pc =
            32'h00000010;

        if_id_instruction =
            32'h12345678;


        // -----------------------------------------------------
        // ID / EX.
        // -----------------------------------------------------

        id_ex_valid =
            1'b1;

        id_ex_pc =
            32'h0000000C;

        id_ex_read_data1 =
            32'h11111111;

        id_ex_read_data2 =
            32'h22222222;

        id_ex_immediate =
            32'hFFFFFFFC;

        id_ex_rs1 =
            5'd1;

        id_ex_rs2 =
            5'd2;

        id_ex_rd =
            5'd3;

        id_ex_opcode =
            7'h33;

        id_ex_funct3 =
            3'b000;

        id_ex_funct7 =
            7'h00;

        id_ex_alu_src_a =
            1'b0;

        id_ex_alu_src_b =
            1'b0;

        id_ex_alu_op =
            3'b010;

        id_ex_branch =
            1'b0;

        id_ex_jump_type =
            2'b00;

        id_ex_mem_read =
            1'b0;

        id_ex_mem_write =
            1'b0;

        id_ex_reg_write =
            1'b1;

        id_ex_wb_sel =
            2'b00;


        // -----------------------------------------------------
        // EX / MEM.
        // -----------------------------------------------------

        ex_mem_valid =
            1'b1;

        ex_mem_pc =
            32'h00000008;

        ex_mem_alu_result =
            32'h33333333;

        ex_mem_store_data =
            32'h44444444;

        ex_mem_rs2 =
            5'd4;

        ex_mem_rd =
            5'd5;

        ex_mem_opcode =
            7'h23;

        ex_mem_funct3 =
            3'b010;

        ex_mem_mem_read =
            1'b0;

        ex_mem_mem_write =
            1'b1;

        ex_mem_reg_write =
            1'b0;

        ex_mem_wb_sel =
            2'b00;


        // -----------------------------------------------------
        // MEM / WB.
        // -----------------------------------------------------

        mem_wb_valid =
            1'b1;

        mem_wb_pc =
            32'h00000004;

        mem_wb_alu_result =
            32'h55555555;

        mem_wb_load_data =
            32'h66666666;

        mem_wb_rd =
            5'd6;

        mem_wb_opcode =
            7'h03;

        mem_wb_reg_write =
            1'b1;

        mem_wb_wb_sel =
            2'b01;


        tests_run =
            0;

        tests_passed =
            0;

        tests_failed =
            0;


        // =====================================================
        // RESET
        // =====================================================

        repeat (4)
            @(posedge clk);

        @(negedge clk);

        reset =
            1'b0;


        // =====================================================
        // MEMORIA UTILIZADA
        //
        // 0x10 se marca dos veces.
        //
        // Debe contarse una sola vez.
        //
        // 0x40 contiene cero, pero igualmente debe aparecer
        // porque fue utilizada.
        // =====================================================

        mark_memory_used(
            32'h00000010
        );

        mark_memory_used(
            32'h00000010
        );

        mark_memory_used(
            32'h00000040
        );


        repeat (2)
            @(posedge clk);

        #1;


        check16(
            "USED MEMORY UNIQUE COUNT",
            used_memory_count,
            16'd2
        );


        // =====================================================
        // INICIAR SNAPSHOT
        // =====================================================

        @(negedge clk);

        snapshot_start =
            1'b1;

        @(negedge clk);

        snapshot_start =
            1'b0;


        // -----------------------------------------------------
        // Cambiamos los valores vivos DEL PIPELINE después de
        // tomar la fotografía.
        //
        // El stream debe conservar los anteriores.
        // -----------------------------------------------------

        if_pc_current =
            32'hAAAAAAAA;

        if_id_pc =
            32'hBBBBBBBB;

        if_id_instruction =
            32'hCCCCCCCC;

        id_ex_pc =
            32'hDDDDDDDD;

        ex_mem_pc =
            32'hEEEEEEEE;

        mem_wb_pc =
            32'hFFFFFFFF;


        // =====================================================
        // ESPERAR FINALIZACIÓN
        // =====================================================

        timeout =
            0;

        while (
            !snapshot_done &&
            timeout < 2000
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


        // =====================================================
        // TAMAÑO
        //
        // Fijo = 246 bytes.
        //
        // Dos palabras de memoria:
        //
        // 2 * 6 = 12 bytes.
        //
        // Total = 258.
        // =====================================================

        check32(
            "SNAPSHOT BYTE COUNT",
            received_count,
            32'd258
        );


        // =====================================================
        // HEADER
        // =====================================================

        check8(
            "SNAPSHOT TAG",
            received_bytes[0],
            8'h64
        );

        check8(
            "SNAPSHOT VERSION",
            received_bytes[1],
            8'h01
        );

        check8(
            "STATUS READY",
            received_bytes[2],
            8'h00
        );

        check8(
            "FLAGS",
            received_bytes[3],
            8'h01
        );


        check32(
            "FROZEN IF PC",
            bytes_to_word(4),
            32'h00000014
        );


        // =====================================================
        // REGISTER FILE
        //
        // Byte 8  = 'R'
        // Byte 9  = 32
        //
        // x0 comienza en byte 10.
        // Cada registro ocupa 5 bytes.
        // =====================================================

        check8(
            "REGISTER TAG",
            received_bytes[8],
            8'h52
        );

        check8(
            "REGISTER COUNT",
            received_bytes[9],
            8'd32
        );


        // x0

        check8(
            "x0 NUMBER",
            received_bytes[10],
            8'd0
        );

        check32(
            "x0 VALUE",
            bytes_to_word(11),
            32'd0
        );


        // x1 comienza en byte 15.

        check8(
            "x1 NUMBER",
            received_bytes[15],
            8'd1
        );

        check32(
            "x1 VALUE",
            bytes_to_word(16),
            32'h10000001
        );


        // x31:
        //
        // 10 + (31 * 5) = 165
        // data empieza en 166.
        // -----------------------------------------------------

        check8(
            "x31 NUMBER",
            received_bytes[165],
            8'd31
        );

        check32(
            "x31 VALUE",
            bytes_to_word(166),
            32'h1000001F
        );


        // =====================================================
        // IF / ID
        //
        // Header 8
        // Register header 2
        // Registers 160
        //
        // IF/ID empieza en 170.
        // =====================================================

        check8(
            "IF/ID TAG",
            received_bytes[170],
            8'h49
        );

        check8(
            "IF/ID VALID",
            received_bytes[171],
            8'h01
        );

        check32(
            "IF/ID FROZEN PC",
            bytes_to_word(172),
            32'h00000010
        );

        check32(
            "IF/ID FROZEN INSTRUCTION",
            bytes_to_word(176),
            32'h12345678
        );


        // =====================================================
        // ID / EX
        //
        // Empieza en 180.
        // =====================================================

        check8(
            "ID/EX TAG",
            received_bytes[180],
            8'h58
        );

        check8(
            "ID/EX VALID",
            received_bytes[181],
            8'h01
        );

        check32(
            "ID/EX FROZEN PC",
            bytes_to_word(182),
            32'h0000000C
        );

        check32(
            "ID/EX DATA1",
            bytes_to_word(186),
            32'h11111111
        );

        check32(
            "ID/EX DATA2",
            bytes_to_word(190),
            32'h22222222
        );

        check32(
            "ID/EX IMMEDIATE",
            bytes_to_word(194),
            32'hFFFFFFFC
        );

        check8(
            "ID/EX RS1",
            received_bytes[198],
            8'd1
        );

        check8(
            "ID/EX RS2",
            received_bytes[199],
            8'd2
        );

        check8(
            "ID/EX RD",
            received_bytes[200],
            8'd3
        );


        // =====================================================
        // EX / MEM
        //
        // ID/EX ocupa 26 bytes:
        //
        // 180 .. 205
        //
        // EX/MEM empieza en 206.
        // =====================================================

        check8(
            "EX/MEM TAG",
            received_bytes[206],
            8'h45
        );

        check8(
            "EX/MEM VALID",
            received_bytes[207],
            8'h01
        );

        check32(
            "EX/MEM FROZEN PC",
            bytes_to_word(208),
            32'h00000008
        );

        check32(
            "EX/MEM ALU",
            bytes_to_word(212),
            32'h33333333
        );

        check32(
            "EX/MEM STORE DATA",
            bytes_to_word(216),
            32'h44444444
        );


        // =====================================================
        // MEM / WB
        //
        // EX/MEM ocupa 19 bytes:
        //
        // 206 .. 224
        //
        // MEM/WB empieza en 225.
        // =====================================================

        check8(
            "MEM/WB TAG",
            received_bytes[225],
            8'h42
        );

        check8(
            "MEM/WB VALID",
            received_bytes[226],
            8'h01
        );

        check32(
            "MEM/WB FROZEN PC",
            bytes_to_word(227),
            32'h00000004
        );

        check32(
            "MEM/WB ALU",
            bytes_to_word(231),
            32'h55555555
        );

        check32(
            "MEM/WB LOAD DATA",
            bytes_to_word(235),
            32'h66666666
        );


        // =====================================================
        // MEMORY
        //
        // MEM/WB ocupa 17 bytes:
        //
        // 225 .. 241
        //
        // Memory header:
        //
        // 242 'M'
        // 243 count hi
        // 244 count lo
        // =====================================================

        check8(
            "MEMORY TAG",
            received_bytes[242],
            8'h4D
        );

        check16(
            "MEMORY COUNT",
            {
                received_bytes[243],
                received_bytes[244]
            },
            16'd2
        );


        // -----------------------------------------------------
        // Primera posición usada: 0x0010.
        //
        // Entrada empieza en 245.
        // -----------------------------------------------------

        check16(
            "MEMORY ENTRY0 ADDRESS",
            {
                received_bytes[245],
                received_bytes[246]
            },
            16'h0010
        );

        check32(
            "MEMORY ENTRY0 DATA",
            bytes_to_word(247),
            32'hAABBCCDD
        );


        // -----------------------------------------------------
        // Segunda posición usada: 0x0040.
        //
        // Debe aparecer incluso conteniendo cero.
        // -----------------------------------------------------

        check16(
            "MEMORY ENTRY1 ADDRESS",
            {
                received_bytes[251],
                received_bytes[252]
            },
            16'h0040
        );

        check32(
            "MEMORY ENTRY1 ZERO DATA",
            bytes_to_word(253),
            32'h00000000
        );


        // =====================================================
        // END
        // =====================================================

        check8(
            "END TAG",
            received_bytes[257],
            8'h7E
        );


        // =====================================================
        // LIMPIEZA DEL MAPA
        // =====================================================

        @(negedge clk);

        memory_usage_clear =
            1'b1;

        @(negedge clk);

        memory_usage_clear =
            1'b0;


        repeat (2)
            @(posedge clk);

        #1;


        check16(
            "MEMORY USAGE CLEAR",
            used_memory_count,
            16'd0
        );


        // =====================================================
        // RESULTADO
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

        $display(
            "Snapshot bytes: %0d",
            received_count
        );


        if (tests_failed == 0)
            $display(
                "PASS: debug_unit"
            );
        else
            $fatal(
                1,
                "FAIL: debug_unit"
            );


        $finish;

    end

endmodule
