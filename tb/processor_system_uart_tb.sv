`timescale 1ns / 1ps

module processor_system_uart_tb;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer OVERSAMPLING = 16;

    localparam integer BIT_CLKS =
        (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;

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

    logic monitor_tick;
    logic [7:0] monitor_byte;
    logic       monitor_valid;
    logic       monitor_frame_error;

    integer response_count;
    logic [7:0] response_bytes [0:255];

    integer monitor_frame_error_count;
    integer core_cycle_count;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer start_count;
    integer before_cycles;
    integer timeout;

    processor_system #(
        .CLK_FREQ       (CLK_FREQ),
        .BAUD_RATE      (BAUD_RATE),
        .OVERSAMPLING   (OVERSAMPLING),
        .IMEM_DEPTH     (256),
        .DATA_MEM_DEPTH (256)
    ) dut (
        .clk                 (clk),
        .reset               (reset),

        .uart_rx             (pc_to_fpga),
        .uart_tx             (fpga_to_pc),

        .status_code         (status_code),
        .program_loaded      (program_loaded),

        .core_running        (core_running),
        .core_draining       (core_draining),
        .core_halted         (core_halted),
        .core_pipeline_empty (core_pipeline_empty),

        .uart_rx_frame_error (uart_rx_frame_error)
    );

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) monitor_baud_gen (
        .clk   (clk),
        .reset (reset),
        .tick  (monitor_tick)
    );

    uart_rx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) monitor_rx (
        .clk            (clk),
        .reset          (reset),
        .baud_tick      (monitor_tick),
        .rx             (fpga_to_pc),
        .rx_byte_data   (monitor_byte),
        .rx_byte_valid  (monitor_valid),
        .rx_frame_error (monitor_frame_error)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;

        if (reset) begin
            response_count            = 0;
            monitor_frame_error_count = 0;
            core_cycle_count          = 0;
        end
        else begin
            if (monitor_valid) begin
                response_bytes[response_count] = monitor_byte;
                response_count = response_count + 1;
            end

            if (monitor_frame_error)
                monitor_frame_error_count =
                    monitor_frame_error_count + 1;

            if (dut.core_cycle_enable)
                core_cycle_count =
                    core_cycle_count + 1;
        end
    end

    task automatic hold_line (
        input logic value,
        input integer cycles
    );
        integer k;
        begin
            pc_to_fpga = value;

            for (k = 0; k < cycles; k = k + 1)
                @(posedge clk);
        end
    endtask

    task automatic send_uart_byte (
        input logic [7:0] value
    );
        integer bit_i;
        begin
            hold_line(1'b0, BIT_CLKS);

            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1)
                hold_line(value[bit_i], BIT_CLKS);

            hold_line(1'b1, BIT_CLKS);
            hold_line(1'b1, BIT_CLKS / 2);
        end
    endtask

    task automatic send_write_word (
        input logic [15:0] address,
        input logic [31:0] data
    );
        begin
            send_uart_byte(8'h57);

            send_uart_byte(address[15:8]);
            send_uart_byte(address[7:0]);

            send_uart_byte(data[31:24]);
            send_uart_byte(data[23:16]);
            send_uart_byte(data[15:8]);
            send_uart_byte(data[7:0]);
        end
    endtask

    task automatic wait_responses (
        input integer target
    );
        begin
            timeout = 0;

            while (
                (response_count < target) &&
                (timeout < 2_000_000)
            ) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end

            if (response_count < target) begin
                $display(
                    "FAIL: UART response timeout target=%0d got=%0d",
                    target,
                    response_count
                );
                $fatal;
            end
        end
    endtask

    task automatic check8 (
        input string      name,
        input logic [7:0] received,
        input logic [7:0] expected
    );
        begin
            tests_run = tests_run + 1;

            if (received === expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-34s | VALUE=%02h",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-34s | VALUE=%02h expected=%02h",
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
            tests_run = tests_run + 1;

            if (received === expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-34s | VALUE=%08h",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-34s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );
            end
        end
    endtask

    function automatic logic [31:0] response_word (
        input integer base
    );
        begin
            response_word = {
                response_bytes[base],
                response_bytes[base + 1],
                response_bytes[base + 2],
                response_bytes[base + 3]
            };
        end
    endfunction

    initial begin

        clk        = 1'b0;
        reset      = 1'b1;
        pc_to_fpga = 1'b1;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        repeat (8) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        #3;

        $display("");
        $display("FULL UART PROCESSOR SESSION");
        $display("===========================");

        // LOAD:
        // addi x1,x0,64
        // addi x2,x0,85
        // sw   x2,0(x1)
        // addi x3,x0,33
        // HALT

        start_count = response_count;

        send_uart_byte(8'h4C);
        send_uart_byte(8'h00);
        send_uart_byte(8'h05);

        send_write_word(16'h0000, 32'h04000093);
        send_write_word(16'h0004, 32'h05500113);
        send_write_word(16'h0008, 32'h0020A023);
        send_write_word(16'h000C, 32'h02100193);
        send_write_word(16'h0010, 32'h0000000B);

        send_uart_byte(8'h45);

        wait_responses(start_count + 1);

        check8("LOAD ACK", response_bytes[start_count], 8'h06);
        check32("PROGRAM LOADED", program_loaded, 32'd1);
        check32("READY AFTER LOAD", status_code, 32'd0);

        // STEP.
        before_cycles = core_cycle_count;
        start_count   = response_count;

        send_uart_byte(8'h53);

        wait_responses(start_count + 1);
        check8("STEP ACK", response_bytes[start_count], 8'h06);

        repeat (4) @(posedge clk);

        check32(
            "STEP EXACTLY ONE CYCLE",
            core_cycle_count - before_cycles,
            32'd1
        );

        // RUN.
        start_count = response_count;

        send_uart_byte(8'h52);

        wait_responses(start_count + 1);
        check8("RUN ACK", response_bytes[start_count], 8'h06);

        timeout = 0;

        while (
            !core_halted &&
            timeout < 5000
        ) begin
            @(posedge clk);
            #1;
            timeout = timeout + 1;
        end

        if (!core_halted) begin
            $display("FAIL: core did not halt");
            $fatal;
        end

        check32(
            "PIPELINE EMPTY AT HALT",
            core_pipeline_empty,
            32'd1
        );

        // QUERY STATE.
        start_count = response_count;

        send_uart_byte(8'h51);

        wait_responses(start_count + 2);

        check8("STATE RESPONSE TAG", response_bytes[start_count], 8'h71);
        check8("STATE HALTED", response_bytes[start_count+1], 8'h04);

        // READ x1.
        start_count = response_count;

        send_uart_byte(8'h47);
        send_uart_byte(8'h01);

        wait_responses(start_count + 6);

        check8("x1 TAG", response_bytes[start_count], 8'h67);
        check8("x1 ID",  response_bytes[start_count+1], 8'h01);

        check32(
            "x1 VALUE",
            response_word(start_count + 2),
            32'd64
        );

        // READ x2.
        start_count = response_count;

        send_uart_byte(8'h47);
        send_uart_byte(8'h02);

        wait_responses(start_count + 6);

        check8("x2 TAG", response_bytes[start_count], 8'h67);
        check8("x2 ID",  response_bytes[start_count+1], 8'h02);

        check32(
            "x2 VALUE",
            response_word(start_count + 2),
            32'd85
        );

        // READ x3.
        start_count = response_count;

        send_uart_byte(8'h47);
        send_uart_byte(8'h03);

        wait_responses(start_count + 6);

        check8("x3 TAG", response_bytes[start_count], 8'h67);
        check8("x3 ID",  response_bytes[start_count+1], 8'h03);

        check32(
            "x3 VALUE",
            response_word(start_count + 2),
            32'd33
        );

        // READ DMEM[64].
        start_count = response_count;

        send_uart_byte(8'h4D);
        send_uart_byte(8'h00);
        send_uart_byte(8'h40);

        wait_responses(start_count + 7);

        check8("MEM TAG",     response_bytes[start_count],   8'h6D);
        check8("MEM ADDR HI", response_bytes[start_count+1], 8'h00);
        check8("MEM ADDR LO", response_bytes[start_count+2], 8'h40);

        check32(
            "MEM[64] VALUE",
            response_word(start_count + 3),
            32'd85
        );

        // Dirección desalineada.
        start_count = response_count;

        send_uart_byte(8'h4D);
        send_uart_byte(8'h00);
        send_uart_byte(8'h02);

        wait_responses(start_count + 2);

        check8("BAD MEM NACK", response_bytes[start_count],   8'h15);
        check8("BAD MEM CODE", response_bytes[start_count+1], 8'h03);

        // Comando desconocido.
        start_count = response_count;

        send_uart_byte(8'h99);

        wait_responses(start_count + 2);

        check8("UNKNOWN NACK", response_bytes[start_count],   8'h15);
        check8("UNKNOWN CODE", response_bytes[start_count+1], 8'h01);

        check32(
            "TX MONITOR FRAME ERRORS",
            monitor_frame_error_count,
            32'd0
        );

        $display("");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("Responses RX : %0d", response_count);
        $display("Core cycles  : %0d", core_cycle_count);

        if (tests_failed == 0)
            $display("PASS: processor_system_uart");
        else
            $fatal(1, "FAIL: processor_system_uart");

        $finish;
    end

endmodule
