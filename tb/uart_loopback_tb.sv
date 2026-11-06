`timescale 1ns / 1ps

module uart_loopback_tb;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer OVERSAMPLING = 16;

    logic clk;
    logic reset;

    logic baud_tick;

    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_line;
    logic       tx_busy;
    logic       tx_done;

    logic [7:0] rx_byte_data;
    logic       rx_byte_valid;
    logic       rx_frame_error;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer rx_count;
    integer frame_error_count;

    logic [7:0] last_rx_byte;

    integer target_count;
    integer timeout;

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) baud_gen_inst (
        .clk   (clk),
        .reset (reset),
        .tick  (baud_tick)
    );

    uart_tx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) tx_inst (
        .clk       (clk),
        .reset     (reset),
        .baud_tick (baud_tick),

        .tx_start  (tx_start),
        .tx_data   (tx_data),

        .tx        (tx_line),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    uart_rx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) rx_inst (
        .clk            (clk),
        .reset          (reset),
        .baud_tick      (baud_tick),

        .rx             (tx_line),

        .rx_byte_data   (rx_byte_data),
        .rx_byte_valid  (rx_byte_valid),
        .rx_frame_error (rx_frame_error)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;

        if (reset) begin

            rx_count          = 0;
            frame_error_count = 0;
            last_rx_byte      = 8'd0;

        end
        else begin

            if (rx_byte_valid) begin
                rx_count     = rx_count + 1;
                last_rx_byte = rx_byte_data;
            end

            if (rx_frame_error)
                frame_error_count = frame_error_count + 1;

        end
    end

    task automatic send_and_expect (
        input logic [7:0] value,
        input string      name
    );
        begin

            while (tx_busy)
                @(posedge clk);

            target_count = rx_count + 1;

            @(negedge clk);
            tx_data  = value;
            tx_start = 1'b1;

            @(negedge clk);
            tx_start = 1'b0;

            timeout = 0;

            while (
                (rx_count < target_count) &&
                (timeout < 20_000)
            ) begin

                @(posedge clk);
                #1;
                timeout = timeout + 1;

            end

            tests_run = tests_run + 1;

            if (
                (rx_count == target_count) &&
                (last_rx_byte === value)
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-20s | sent=%02h received=%02h",
                    name,
                    value,
                    last_rx_byte
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-20s | sent=%02h received=%02h timeout=%0d",
                    name,
                    value,
                    last_rx_byte,
                    timeout
                );

            end

            while (tx_busy)
                @(posedge clk);

        end
    endtask

    initial begin

        clk          = 1'b0;
        reset        = 1'b1;

        tx_start     = 1'b0;
        tx_data      = 8'd0;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        send_and_expect(8'h4C, "BYTE 4C");
        send_and_expect(8'hA5, "BYTE A5");
        send_and_expect(8'h00, "BYTE 00");
        send_and_expect(8'hFF, "BYTE FF");

        tests_run = tests_run + 1;

        if (frame_error_count == 0) begin
            tests_passed = tests_passed + 1;
            $display("PASS: no frame errors");
        end
        else begin
            tests_failed = tests_failed + 1;
            $display(
                "FAIL: frame errors = %0d",
                frame_error_count
            );
        end

        $display("");
        $display("RX bytes      : %0d", rx_count);
        $display("Frame errors  : %0d", frame_error_count);
        $display("Tests run     : %0d", tests_run);
        $display("Tests passed  : %0d", tests_passed);
        $display("Tests failed  : %0d", tests_failed);

        if (tests_failed == 0)
            $display("PASS: uart_loopback");
        else
            $fatal(1, "FAIL: uart_loopback");

        $finish;

    end

endmodule
