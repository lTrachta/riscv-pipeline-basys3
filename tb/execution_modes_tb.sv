`timescale 1ns / 1ps

module execution_modes_tb;

    localparam integer CLK_FREQ =
        100_000_000;

    localparam integer BAUD_RATE =
        115_200;

    localparam integer OVERSAMPLING =
        16;

    localparam integer BIT_CLKS =
        (CLK_FREQ + BAUD_RATE/2) /
        BAUD_RATE;


    logic clk;
    logic reset;

    logic pc_to_fpga;
    logic fpga_to_pc;

    logic [2:0] status_code;
    logic       program_loaded;

    logic core_running;
    logic core_draining;
    logic core_halted;
    logic core_pipeline_empty;

    logic uart_rx_frame_error;


    // =========================================================
    // MONITOR UART FPGA -> PC
    // =========================================================

    logic monitor_tick;

    logic [7:0] monitor_byte;
    logic       monitor_valid;
    logic       monitor_frame_error;


    logic [7:0] received_bytes [0:8191];

    integer response_count;
    integer monitor_frame_errors;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer base;
    integer snapshot_base;
    integer timeout;
    integer i;


    // =========================================================
    // DUT
    // =========================================================

    processor_system #(
        .CLK_FREQ       (CLK_FREQ),
        .BAUD_RATE      (BAUD_RATE),
        .OVERSAMPLING   (OVERSAMPLING),
        .IMEM_DEPTH     (256),
        .DATA_MEM_DEPTH (256)
    ) dut (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .uart_rx (
            pc_to_fpga
        ),

        .uart_tx (
            fpga_to_pc
        ),

        .status_code (
            status_code
        ),

        .program_loaded (
            program_loaded
        ),

        .core_running (
            core_running
        ),

        .core_draining (
            core_draining
        ),

        .core_halted (
            core_halted
        ),

        .core_pipeline_empty (
            core_pipeline_empty
        ),

        .uart_rx_frame_error (
            uart_rx_frame_error
        )
    );


    // =========================================================
    // UART RX DEL LADO PC
    // =========================================================

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) monitor_baud_gen (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .tick (
            monitor_tick
        )
    );


    uart_rx #(
        .OVERSAMPLING (
            OVERSAMPLING
        )
    ) monitor_rx (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .baud_tick (
            monitor_tick
        ),

        .rx (
            fpga_to_pc
        ),

        .rx_byte_data (
            monitor_byte
        ),

        .rx_byte_valid (
            monitor_valid
        ),

        .rx_frame_error (
            monitor_frame_error
        )
    );


    // =========================================================
    // CLOCK FÍSICO
    //
    // Este clock nunca se detiene durante toda la prueba.
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // CAPTURA DE RESPUESTAS
    // =========================================================

    always @(posedge clk) begin

        #1;

        if (reset) begin

            response_count =
                0;

            monitor_frame_errors =
                0;

        end
        else begin

            if (monitor_valid) begin

                received_bytes[
                    response_count
                ] = monitor_byte;

                response_count =
                    response_count + 1;

            end


            if (monitor_frame_error)
                monitor_frame_errors =
                    monitor_frame_errors + 1;

        end

    end


    // =========================================================
    // DRIVER UART PC -> FPGA
    // =========================================================

    task automatic hold_line (
        input logic value,
        input integer cycles
    );

        integer j;

        begin

            pc_to_fpga =
                value;

            for (
                j = 0;
                j < cycles;
                j = j + 1
            )
                @(posedge clk);

        end

    endtask


    task automatic send_uart_byte (
        input logic [7:0] value
    );

        integer bit_i;

        begin

            // START
            hold_line(
                1'b0,
                BIT_CLKS
            );


            // DATA - LSB FIRST
            for (
                bit_i = 0;
                bit_i < 8;
                bit_i = bit_i + 1
            )
                hold_line(
                    value[bit_i],
                    BIT_CLKS
                );


            // STOP
            hold_line(
                1'b1,
                BIT_CLKS
            );


            // IDLE
            hold_line(
                1'b1,
                BIT_CLKS / 2
            );

        end

    endtask


    // =========================================================
    // PROGRAM LOADER
    // =========================================================

    task automatic send_write_word (
        input logic [15:0] address,
        input logic [31:0] data
    );

        begin

            send_uart_byte(
                8'h57
            ); // W

            send_uart_byte(
                address[15:8]
            );

            send_uart_byte(
                address[7:0]
            );

            send_uart_byte(
                data[31:24]
            );

            send_uart_byte(
                data[23:16]
            );

            send_uart_byte(
                data[15:8]
            );

            send_uart_byte(
                data[7:0]
            );

        end

    endtask


    // =========================================================
    // ESPERAR RESPUESTAS UART
    // =========================================================

    task automatic wait_responses (
        input integer target
    );

        begin

            timeout =
                0;

            while (
                response_count < target &&
                timeout < 10_000_000
            ) begin

                @(posedge clk);

                #1;

                timeout =
                    timeout + 1;

            end


            if (
                response_count <
                target
            ) begin

                $display(
                    "FAIL: UART timeout target=%0d received=%0d",
                    target,
                    response_count
                );

                $fatal;

            end

        end

    endtask


    // =========================================================
    // SNAPSHOT
    // =========================================================

    task automatic take_snapshot (
        input  integer expected_size,
        output integer first_byte
    );

        begin

            first_byte =
                response_count;

            send_uart_byte(
                8'h44
            ); // D

            wait_responses(
                first_byte +
                expected_size
            );

        end

    endtask


    // =========================================================
    // QUERY
    // =========================================================

    task automatic query_state (
        output integer first_byte
    );

        begin

            first_byte =
                response_count;

            send_uart_byte(
                8'h51
            ); // Q

            wait_responses(
                first_byte + 2
            );

        end

    endtask


    // =========================================================
    // STEP
    // =========================================================

    task automatic do_step;

        integer start;

        begin

            start =
                response_count;

            send_uart_byte(
                8'h53
            ); // S

            wait_responses(
                start + 1
            );

            check8(
                "STEP ACK",
                received_bytes[start],
                8'h06
            );

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
                    "PASS: %-42s | VALUE=%02h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-42s | VALUE=%02h expected=%02h",
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
                    "PASS: %-42s | VALUE=%04h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-42s | VALUE=%04h expected=%04h",
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
                    "PASS: %-42s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-42s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );

            end

        end

    endtask


    function automatic logic [31:0]
    word_at (
        input integer index
    );

        begin

            word_at = {
                received_bytes[index],
                received_bytes[index + 1],
                received_bytes[index + 2],
                received_bytes[index + 3]
            };

        end

    endfunction


    // =========================================================
    // MAIN
    // =========================================================

    initial begin

        clk =
            1'b0;

        reset =
            1'b1;

        pc_to_fpga =
            1'b1;

        tests_run =
            0;

        tests_passed =
            0;

        tests_failed =
            0;


        repeat (8)
            @(posedge clk);


        @(negedge clk);

        reset =
            1'b0;


        // =====================================================
        // PARTE A
        //
        // STEP + PAUSA + STALL + BRANCH + DRAINING
        // =====================================================
        //
        // 00 addi x1,x0,64
        // 04 addi x2,x0,5
        // 08 sw   x2,0(x1)
        // 0C lw   x3,0(x1)
        // 10 add  x4,x3,x2
        // 14 beq  x4,x4,+12
        // 18 addi x5,x0,99   wrong path
        // 1C addi x5,x0,98   wrong path
        // 20 addi x5,x0,7
        // 24 HALT
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h4C
        ); // L

        send_uart_byte(
            8'h00
        );

        send_uart_byte(
            8'h0A
        );


        send_write_word(
            16'h0000,
            32'h04000093
        );

        send_write_word(
            16'h0004,
            32'h00500113
        );

        send_write_word(
            16'h0008,
            32'h0020A023
        );

        send_write_word(
            16'h000C,
            32'h0000A183
        );

        send_write_word(
            16'h0010,
            32'h00218233
        );

        send_write_word(
            16'h0014,
            32'h00420663
        );

        send_write_word(
            16'h0018,
            32'h06300293
        );

        send_write_word(
            16'h001C,
            32'h06200293
        );

        send_write_word(
            16'h0020,
            32'h00700293
        );

        send_write_word(
            16'h0024,
            32'h0000000B
        );


        send_uart_byte(
            8'h45
        ); // E


        wait_responses(
            base + 1
        );


        check8(
            "LOAD ACK - STEP PROGRAM",
            received_bytes[base],
            8'h06
        );


        check32(
            "PROGRAM LOADED",
            program_loaded,
            32'd1
        );


        // =====================================================
        // PROCESADOR PAUSADO
        //
        // Todavía no hubo ni STEP ni RUN.
        // =====================================================

        take_snapshot(
            246,
            snapshot_base
        );


        check8(
            "READY STATUS BEFORE STEP",
            received_bytes[
                snapshot_base + 2
            ],
            8'h00
        );


        // pipeline_empty + core_running
        //
        // bit3 = pipeline_empty
        // bit0 = core_running

        check8(
            "PAUSED FLAGS BEFORE STEP",
            received_bytes[
                snapshot_base + 3
            ],
            8'h09
        );


        check32(
            "INITIAL IF PC",
            word_at(
                snapshot_base + 4
            ),
            32'h00000000
        );


        check8(
            "INITIAL IF/ID INVALID",
            received_bytes[
                snapshot_base + 171
            ],
            8'h00
        );


        // =====================================================
        // DEJAR PASAR MUCHOS CLOCKS FÍSICOS
        //
        // No enviamos ningún comando.
        //
        // El clock continúa funcionando, pero el procesador
        // no debe avanzar.
        // =====================================================

        repeat (50)
            @(posedge clk);


        take_snapshot(
            246,
            snapshot_base
        );


        check32(
            "IF PC UNCHANGED AFTER 50 CLOCKS",
            word_at(
                snapshot_base + 4
            ),
            32'h00000000
        );


        check8(
            "IF/ID STILL INVALID AFTER 50 CLOCKS",
            received_bytes[
                snapshot_base + 171
            ],
            8'h00
        );


        // =====================================================
        // STEP 1
        // =====================================================

        do_step();


        take_snapshot(
            246,
            snapshot_base
        );


        check32(
            "STEP1 IF PC",
            word_at(
                snapshot_base + 4
            ),
            32'h00000004
        );


        check8(
            "STEP1 IF/ID VALID",
            received_bytes[
                snapshot_base + 171
            ],
            8'h01
        );


        check32(
            "STEP1 IF/ID PC",
            word_at(
                snapshot_base + 172
            ),
            32'h00000000
        );


        // =====================================================
        // STEP 2
        // =====================================================

        do_step();


        take_snapshot(
            246,
            snapshot_base
        );


        check32(
            "STEP2 IF PC",
            word_at(
                snapshot_base + 4
            ),
            32'h00000008
        );


        check32(
            "STEP2 IF/ID PC",
            word_at(
                snapshot_base + 172
            ),
            32'h00000004
        );


        check8(
            "STEP2 ID/EX VALID",
            received_bytes[
                snapshot_base + 181
            ],
            8'h01
        );


        check32(
            "STEP2 ID/EX PC",
            word_at(
                snapshot_base + 182
            ),
            32'h00000000
        );


        // =====================================================
        // STEP 3, 4, 5
        //
        // Después del STEP 5:
        //
        // IF/ID  = add x4,x3,x2
        // ID/EX  = lw x3,0(x1)
        //
        // Hay load-use hazard.
        // =====================================================

        do_step();
        do_step();
        do_step();


        take_snapshot(
            246,
            snapshot_base
        );


        check32(
            "PRE-STALL IF PC",
            word_at(
                snapshot_base + 4
            ),
            32'h00000014
        );


        check32(
            "PRE-STALL IF/ID PC",
            word_at(
                snapshot_base + 172
            ),
            32'h00000010
        );


        check8(
            "PRE-STALL ID/EX VALID",
            received_bytes[
                snapshot_base + 181
            ],
            8'h01
        );


        check32(
            "PRE-STALL ID/EX PC",
            word_at(
                snapshot_base + 182
            ),
            32'h0000000C
        );


        // =====================================================
        // STEP 6 - LOAD USE STALL
        //
        // El STEP sí ocurre.
        //
        // Pero la solución del hazard exige:
        //
        // PC      HOLD
        // IF/ID   HOLD
        // ID/EX   BUBBLE
        // =====================================================

        do_step();


        // El store ya alcanzó MEM, por lo que ahora existe
        // una palabra de memoria marcada como utilizada.

        take_snapshot(
            252,
            snapshot_base
        );


        check32(
            "STALL STEP HOLDS IF PC",
            word_at(
                snapshot_base + 4
            ),
            32'h00000014
        );


        check32(
            "STALL STEP HOLDS IF/ID PC",
            word_at(
                snapshot_base + 172
            ),
            32'h00000010
        );


        check8(
            "STALL STEP CREATES ID/EX BUBBLE",
            received_bytes[
                snapshot_base + 181
            ],
            8'h00
        );


        check32(
            "STALL STEP MOVES LOAD TO EX/MEM",
            word_at(
                snapshot_base + 208
            ),
            32'h0000000C
        );


        check16(
            "MEMORY USED AFTER STORE",
            {
                received_bytes[
                    snapshot_base + 243
                ],
                received_bytes[
                    snapshot_base + 244
                ]
            },
            16'd1
        );


        // =====================================================
        // STEP 7 y 8
        //
        // Después del STEP 8:
        //
        // branch está en ID/EX
        // instrucción wrong-path PC=24 está en IF/ID
        // =====================================================

        do_step();
        do_step();


        take_snapshot(
            252,
            snapshot_base
        );


        check32(
            "PRE-BRANCH IF PC",
            word_at(
                snapshot_base + 4
            ),
            32'h0000001C
        );


        check32(
            "PRE-BRANCH IF/ID WRONG-PATH PC",
            word_at(
                snapshot_base + 172
            ),
            32'h00000018
        );


        check32(
            "PRE-BRANCH ID/EX PC",
            word_at(
                snapshot_base + 182
            ),
            32'h00000014
        );


        // =====================================================
        // STEP 9 - BRANCH TAKEN
        //
        // Debe:
        //
        // redirect PC -> 32
        // flush IF/ID
        // flush ID/EX
        // =====================================================

        do_step();


        take_snapshot(
            252,
            snapshot_base
        );


        check32(
            "BRANCH REDIRECT TARGET",
            word_at(
                snapshot_base + 4
            ),
            32'h00000020
        );


        check8(
            "BRANCH FLUSH IF/ID",
            received_bytes[
                snapshot_base + 171
            ],
            8'h00
        );


        check8(
            "BRANCH FLUSH ID/EX",
            received_bytes[
                snapshot_base + 181
            ],
            8'h00
        );


        check32(
            "BRANCH REACHES EX/MEM",
            word_at(
                snapshot_base + 208
            ),
            32'h00000014
        );


        // =====================================================
        // STEP 10 y 11
        //
        // Ahora:
        //
        // IF/ID = HALT en PC 36
        // ID/EX = addi x5,x0,7 en PC 32
        // =====================================================

        do_step();
        do_step();


        take_snapshot(
            252,
            snapshot_base
        );


        check32(
            "HALT READY IF/ID PC",
            word_at(
                snapshot_base + 172
            ),
            32'h00000024
        );


        check32(
            "OLDER INSTRUCTION ID/EX PC",
            word_at(
                snapshot_base + 182
            ),
            32'h00000020
        );


        // =====================================================
        // STEP 12 - ACEPTAR HALT
        //
        // No debe ir directamente a HALTED.
        // =====================================================

        do_step();


        check32(
            "HALT ENTERS DRAINING",
            core_draining,
            32'd1
        );


        check32(
            "NOT HALTED IMMEDIATELY",
            core_halted,
            32'd0
        );


        query_state(
            base
        );


        check8(
            "QUERY RESPONSE TAG - DRAINING",
            received_bytes[base],
            8'h71
        );


        check8(
            "QUERY STATUS - DRAINING",
            received_bytes[base + 1],
            8'h03
        );


        take_snapshot(
            252,
            snapshot_base
        );


        // core_draining = bit1

        check8(
            "DRAINING SNAPSHOT FLAGS",
            received_bytes[
                snapshot_base + 3
            ],
            8'h02
        );


        // =====================================================
        // PAUSA EN DRAINING
        //
        // Incluso durante draining, si no hay STEP,
        // el pipeline no avanza.
        // =====================================================

        repeat (50)
            @(posedge clk);


        check32(
            "STILL DRAINING AFTER 50 PHYSICAL CLOCKS",
            core_draining,
            32'd1
        );


        check32(
            "STILL NOT HALTED WITHOUT STEP",
            core_halted,
            32'd0
        );


        // =====================================================
        // STEP 13
        // =====================================================

        do_step();


        check32(
            "DRAINING AFTER FIRST DRAIN STEP",
            core_draining,
            32'd1
        );


        // =====================================================
        // STEP 14
        //
        // El último resultado llega a WB y el pipeline queda
        // vacío, pero la FSM todavía está en DRAINING.
        // =====================================================

        do_step();


        check32(
            "PIPELINE EMPTY BEFORE HALTED TRANSITION",
            core_pipeline_empty,
            32'd1
        );


        check32(
            "STILL DRAINING WITH EMPTY PIPELINE",
            core_draining,
            32'd1
        );


        // =====================================================
        // STEP 15
        //
        // Ahora sí:
        //
        // DRAINING -> HALTED
        // =====================================================

        do_step();


        check32(
            "HALTED AFTER FINAL STEP",
            core_halted,
            32'd1
        );


        check32(
            "PIPELINE EMPTY AT HALT",
            core_pipeline_empty,
            32'd1
        );


        // =====================================================
        // SNAPSHOT FINAL STEP MODE
        //
        // Wrong-path x5=99/98 no debe haber sobrevivido.
        //
        // x5 debe valer 7.
        // =====================================================

        take_snapshot(
            252,
            snapshot_base
        );


        check8(
            "FINAL STEP STATUS HALTED",
            received_bytes[
                snapshot_base + 2
            ],
            8'h04
        );


        check32(
            "FINAL STEP x1",
            word_at(
                snapshot_base + 16
            ),
            32'd64
        );


        check32(
            "FINAL STEP x2",
            word_at(
                snapshot_base + 21
            ),
            32'd5
        );


        check32(
            "FINAL STEP x3",
            word_at(
                snapshot_base + 26
            ),
            32'd5
        );


        check32(
            "FINAL STEP x4",
            word_at(
                snapshot_base + 31
            ),
            32'd10
        );


        // x5 comienza:
        //
        // 10 + 5*5 = 35
        // dato = 36..39

        check32(
            "WRONG PATH REMOVED - FINAL x5",
            word_at(
                snapshot_base + 36
            ),
            32'd7
        );


        // =====================================================
        // STEP DESPUÉS DE HALT DEBE RECHAZARSE
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h53
        ); // S


        wait_responses(
            base + 2
        );


        check8(
            "STEP AFTER HALT NACK",
            received_bytes[base],
            8'h15
        );


        check8(
            "STEP AFTER HALT INVALID STATE",
            received_bytes[base + 1],
            8'h05
        );


        // =====================================================
        // PARTE B
        //
        // RUN CONTINUO
        //
        // Recargamos un programa suficientemente largo para
        // poder consultar estado mientras RUN sigue activo.
        // =====================================================
        //
        // 00 lui  x1,0xC        -> 49152
        // 04 addi x1,x1,848     -> 50000
        //
        // loop:
        //
        // 08 addi x1,x1,-1
        // 0C bne  x1,x0,-4
        //
        // 10 addi x2,x0,7
        // 14 HALT
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h4C
        ); // L

        send_uart_byte(
            8'h00
        );

        send_uart_byte(
            8'h06
        );


        send_write_word(
            16'h0000,
            32'h0000C0B7
        );

        send_write_word(
            16'h0004,
            32'h35008093
        );

        send_write_word(
            16'h0008,
            32'hFFF08093
        );

        send_write_word(
            16'h000C,
            32'hFE009EE3
        );

        send_write_word(
            16'h0010,
            32'h00700113
        );

        send_write_word(
            16'h0014,
            32'h0000000B
        );


        send_uart_byte(
            8'h45
        ); // E


        wait_responses(
            base + 1
        );


        check8(
            "LOAD ACK - RUN PROGRAM",
            received_bytes[base],
            8'h06
        );


        check32(
            "RUN PROGRAM LOADED",
            program_loaded,
            32'd1
        );


        // =====================================================
        // RUN
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h52
        ); // R


        wait_responses(
            base + 1
        );


        check8(
            "RUN ACK",
            received_bytes[base],
            8'h06
        );


        // El programa debe seguir corriendo sin necesidad de
        // enviar STEP adicionales.

        check32(
            "CORE NOT HALTED IMMEDIATELY AFTER RUN",
            core_halted,
            32'd0
        );


        // =====================================================
        // Q ESTÁ PERMITIDO DURANTE RUN
        // =====================================================

        query_state(
            base
        );


        check8(
            "QUERY DURING RUN TAG",
            received_bytes[base],
            8'h71
        );


        check8(
            "QUERY DURING RUN STATUS",
            received_bytes[base + 1],
            8'h02
        );


        // =====================================================
        // OTROS COMANDOS SE RECHAZAN DURANTE RUN
        //
        // Enviamos solamente G.
        //
        // No enviamos índice porque G ya debe ser rechazado
        // inmediatamente por estado inválido.
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h47
        ); // G


        wait_responses(
            base + 2
        );


        check8(
            "COMMAND DURING RUN NACK",
            received_bytes[base],
            8'h15
        );


        check8(
            "COMMAND DURING RUN INVALID STATE",
            received_bytes[base + 1],
            8'h05
        );


        // =====================================================
        // RUN DEBE CONTINUAR SOLO HASTA HALT
        // =====================================================

        timeout =
            0;


        while (
            !core_halted &&
            timeout < 2_000_000
        ) begin

            @(posedge clk);

            #1;

            timeout =
                timeout + 1;

        end


        if (!core_halted) begin

            $display(
                "FAIL: RUN program did not reach HALT"
            );

            $fatal;

        end


        check32(
            "RUN REACHES HALT AUTOMATICALLY",
            core_halted,
            32'd1
        );


        check32(
            "RUN ENDS WITH EMPTY PIPELINE",
            core_pipeline_empty,
            32'd1
        );


        // =====================================================
        // ESTADO FINAL DEL RUN
        // =====================================================

        query_state(
            base
        );


        check8(
            "FINAL QUERY TAG",
            received_bytes[base],
            8'h71
        );


        check8(
            "FINAL QUERY STATUS HALTED",
            received_bytes[base + 1],
            8'h04
        );


        // =====================================================
        // SNAPSHOT FINAL RUN
        //
        // No hubo accesos a DMEM en este segundo programa.
        //
        // Por eso el snapshot vuelve a tener 246 bytes.
        // =====================================================

        take_snapshot(
            246,
            snapshot_base
        );


        check32(
            "RUN FINAL x1",
            word_at(
                snapshot_base + 16
            ),
            32'd0
        );


        check32(
            "RUN FINAL x2",
            word_at(
                snapshot_base + 21
            ),
            32'd7
        );


        check8(
            "RUN FINAL IF/ID INVALID",
            received_bytes[
                snapshot_base + 171
            ],
            8'h00
        );


        check8(
            "RUN FINAL ID/EX INVALID",
            received_bytes[
                snapshot_base + 181
            ],
            8'h00
        );


        check8(
            "RUN FINAL EX/MEM INVALID",
            received_bytes[
                snapshot_base + 207
            ],
            8'h00
        );


        check8(
            "RUN FINAL MEM/WB INVALID",
            received_bytes[
                snapshot_base + 226
            ],
            8'h00
        );


        // =====================================================
        // UART
        // =====================================================

        check32(
            "UART RX FRAME ERRORS",
            uart_rx_frame_error,
            32'd0
        );


        check32(
            "UART TX MONITOR FRAME ERRORS",
            monitor_frame_errors,
            32'd0
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
            "UART bytes received: %0d",
            response_count
        );


        if (tests_failed == 0)
            $display(
                "PASS: execution_modes"
            );
        else
            $fatal(
                1,
                "FAIL: execution_modes"
            );


        $finish;

    end

endmodule
