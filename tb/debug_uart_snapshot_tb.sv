`timescale 1ns / 1ps

module debug_uart_snapshot_tb;

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

    logic program_loaded;

    logic core_running;
    logic core_draining;
    logic core_halted;
    logic core_pipeline_empty;

    logic uart_rx_frame_error;


    // =========================================================
    // MONITOR FPGA -> PC
    // =========================================================

    logic monitor_tick;

    logic [7:0] monitor_byte;
    logic       monitor_valid;
    logic       monitor_frame_error;


    logic [7:0] received_bytes [0:2047];

    integer response_count;
    integer monitor_frame_errors;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer base;
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
    // PC-SIDE UART RECEIVER
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
    // CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // RECEIVE BUFFER
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
    // PC UART DRIVER
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


            // DATA LSB FIRST
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


            // pequeño idle
            hold_line(
                1'b1,
                BIT_CLKS / 2
            );

        end

    endtask


    // =========================================================
    // LOAD WRITE WORD
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
    // WAIT RESPONSES
    // =========================================================

    task automatic wait_responses (
        input integer target
    );

        begin

            timeout =
                0;

            while (
                response_count < target &&
                timeout < 5_000_000
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
                    "FAIL: UART response timeout target=%0d received=%0d",
                    target,
                    response_count
                );

                $fatal;

            end

        end

    endtask


    // =========================================================
    // CHECK HELPERS
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
                    "PASS: %-38s | VALUE=%02h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-38s | VALUE=%02h expected=%02h",
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
                    "PASS: %-38s | VALUE=%04h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-38s | VALUE=%04h expected=%04h",
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
                    "PASS: %-38s | VALUE=%08h",
                    name,
                    received
                );

            end
            else begin

                tests_failed =
                    tests_failed + 1;

                $display(
                    "FAIL: %-38s | VALUE=%08h expected=%08h",
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
    // TEST
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
        // LOAD PROGRAM
        //
        // 00 addi x1,x0,64
        // 04 addi x2,x0,85
        // 08 sw   x2,0(x1)
        // 0C lw   x3,0(x1)
        // 10 addi x4,x3,1
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
            32'h04000093
        );

        send_write_word(
            16'h0004,
            32'h05500113
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
            32'h00118213
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
            "LOAD ACK",
            received_bytes[base],
            8'h06
        );


        check32(
            "PROGRAM LOADED",
            program_loaded,
            32'd1
        );


        // =====================================================
        // 4 STEP COMMANDS
        // =====================================================

        for (
            i = 0;
            i < 4;
            i = i + 1
        ) begin

            base =
                response_count;

            send_uart_byte(
                8'h53
            ); // S

            wait_responses(
                base + 1
            );

            check8(
                "STEP ACK",
                received_bytes[base],
                8'h06
            );

        end


        // =====================================================
        // MID-PIPELINE DEBUG SNAPSHOT
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h44
        ); // D


        // No ACK:
        // la respuesta es directamente el snapshot.
        //
        // Sin memoria usada:
        // 246 bytes.

        wait_responses(
            base + 246
        );


        check8(
            "MID DEBUG TAG",
            received_bytes[base],
            8'h64
        );


        check8(
            "MID DEBUG VERSION",
            received_bytes[base + 1],
            8'h01
        );


        check8(
            "MID STATUS READY",
            received_bytes[base + 2],
            8'h00
        );


        check8(
            "MID FLAGS",
            received_bytes[base + 3],
            8'h01
        );


        check32(
            "MID IF PC",
            word_at(base + 4),
            32'h00000010
        );


        // IF/ID starts +170.

        check8(
            "MID IF/ID VALID",
            received_bytes[
                base + 171
            ],
            8'h01
        );


        check32(
            "MID IF/ID PC",
            word_at(
                base + 172
            ),
            32'h0000000C
        );


        check32(
            "MID IF/ID INSTRUCTION",
            word_at(
                base + 176
            ),
            32'h0000A183
        );


        // ID/EX

        check8(
            "MID ID/EX VALID",
            received_bytes[
                base + 181
            ],
            8'h01
        );


        check32(
            "MID ID/EX PC",
            word_at(
                base + 182
            ),
            32'h00000008
        );


        // EX/MEM

        check8(
            "MID EX/MEM VALID",
            received_bytes[
                base + 207
            ],
            8'h01
        );


        check32(
            "MID EX/MEM PC",
            word_at(
                base + 208
            ),
            32'h00000004
        );


        // MEM/WB

        check8(
            "MID MEM/WB VALID",
            received_bytes[
                base + 226
            ],
            8'h01
        );


        check32(
            "MID MEM/WB PC",
            word_at(
                base + 227
            ),
            32'h00000000
        );


        check16(
            "MID USED MEMORY COUNT",
            {
                received_bytes[
                    base + 243
                ],
                received_bytes[
                    base + 244
                ]
            },
            16'd0
        );


        check8(
            "MID END TAG",
            received_bytes[
                base + 245
            ],
            8'h7E
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


        timeout =
            0;


        while (
            !core_halted &&
            timeout < 5000
        ) begin

            @(posedge clk);

            #1;

            timeout =
                timeout + 1;

        end


        if (!core_halted) begin

            $display(
                "FAIL: core did not halt"
            );

            $fatal;

        end


        check32(
            "HALTED",
            core_halted,
            32'd1
        );


        check32(
            "PIPELINE EMPTY",
            core_pipeline_empty,
            32'd1
        );


        // =====================================================
        // FINAL DEBUG SNAPSHOT
        //
        // Una palabra de DMEM utilizada:
        //
        // 246 + 6 = 252 bytes.
        // =====================================================

        base =
            response_count;


        send_uart_byte(
            8'h44
        ); // D


        wait_responses(
            base + 252
        );


        check8(
            "FINAL DEBUG TAG",
            received_bytes[base],
            8'h64
        );


        check8(
            "FINAL DEBUG VERSION",
            received_bytes[base + 1],
            8'h01
        );


        check8(
            "FINAL STATUS HALTED",
            received_bytes[base + 2],
            8'h04
        );


        check8(
            "FINAL FLAGS",
            received_bytes[base + 3],
            8'h0C
        );


        // =====================================================
        // REGISTER FILE
        // =====================================================

        check8(
            "REGISTER TAG",
            received_bytes[
                base + 8
            ],
            8'h52
        );


        check8(
            "REGISTER COUNT",
            received_bytes[
                base + 9
            ],
            8'd32
        );


        check32(
            "FINAL x1",
            word_at(
                base + 16
            ),
            32'd64
        );


        check32(
            "FINAL x2",
            word_at(
                base + 21
            ),
            32'd85
        );


        check32(
            "FINAL x3",
            word_at(
                base + 26
            ),
            32'd85
        );


        check32(
            "FINAL x4",
            word_at(
                base + 31
            ),
            32'd86
        );


        // =====================================================
        // PIPELINE FINAL VACÍO
        // =====================================================

        check8(
            "FINAL IF/ID INVALID",
            received_bytes[
                base + 171
            ],
            8'h00
        );


        check8(
            "FINAL ID/EX INVALID",
            received_bytes[
                base + 181
            ],
            8'h00
        );


        check8(
            "FINAL EX/MEM INVALID",
            received_bytes[
                base + 207
            ],
            8'h00
        );


        check8(
            "FINAL MEM/WB INVALID",
            received_bytes[
                base + 226
            ],
            8'h00
        );


        // =====================================================
        // DMEM USED
        // =====================================================

        check8(
            "MEMORY TAG",
            received_bytes[
                base + 242
            ],
            8'h4D
        );


        check16(
            "FINAL MEMORY COUNT",
            {
                received_bytes[
                    base + 243
                ],
                received_bytes[
                    base + 244
                ]
            },
            16'd1
        );


        check16(
            "FINAL MEMORY ADDRESS",
            {
                received_bytes[
                    base + 245
                ],
                received_bytes[
                    base + 246
                ]
            },
            16'h0040
        );


        check32(
            "FINAL MEMORY VALUE",
            word_at(
                base + 247
            ),
            32'd85
        );


        check8(
            "FINAL END TAG",
            received_bytes[
                base + 251
            ],
            8'h7E
        );


        check32(
            "UART TX FRAME ERRORS",
            monitor_frame_errors,
            32'd0
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

        $display(
            "UART bytes received: %0d",
            response_count
        );


        if (tests_failed == 0)
            $display(
                "PASS: debug_uart_snapshot"
            );
        else
            $fatal(
                1,
                "FAIL: debug_uart_snapshot"
            );


        $finish;

    end

endmodule
