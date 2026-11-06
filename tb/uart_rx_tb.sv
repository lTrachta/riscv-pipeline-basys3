`timescale 1ns / 1ps

module uart_rx_tb;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer OVERSAMPLING = 16;

    // Duración aproximada del bit generado por una PC ideal,
    // medida en clocks de 100 MHz.
    localparam integer BIT_CLKS =
        (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;

    logic clk;
    logic reset;

    logic baud_tick;
    logic rx_line;

    logic [7:0] rx_byte_data;
    logic       rx_byte_valid;
    logic       rx_frame_error;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer rx_count;
    integer frame_error_count;

    logic [7:0] last_rx_byte;

    integer before_count;
    integer before_errors;

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) baud_gen_inst (
        .clk   (clk),
        .reset (reset),
        .tick  (baud_tick)
    );

    uart_rx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .baud_tick      (baud_tick),

        .rx             (rx_line),

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

    task automatic hold_line (
        input logic value,
        input integer cycles
    );
        integer k;
        begin

            rx_line = value;

            for (k = 0; k < cycles; k = k + 1)
                @(posedge clk);

        end
    endtask

    task automatic send_uart_byte (
        input logic [7:0] value
    );
        integer bit_i;
        begin

            // START
            hold_line(1'b0, BIT_CLKS);

            // D0 ... D7
            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1)
                hold_line(value[bit_i], BIT_CLKS);

            // STOP
            hold_line(1'b1, BIT_CLKS);

            // Pequeño idle entre bytes.
            hold_line(1'b1, BIT_CLKS / 2);

        end
    endtask

    task automatic send_and_expect (
        input logic [7:0] value,
        input string      name
    );
        begin

            before_count = rx_count;

            send_uart_byte(value);

            tests_run = tests_run + 1;

            if (
                (rx_count == before_count + 1) &&
                (last_rx_byte === value)
            ) begin

                tests_passed = tests_passed + 1;

                $display(
                    "PASS: %-20s | received=%02h",
                    name,
                    last_rx_byte
                );

            end
            else begin

                tests_failed = tests_failed + 1;

                $display(
                    "FAIL: %-20s | received=%02h count_delta=%0d",
                    name,
                    last_rx_byte,
                    rx_count - before_count
                );

            end

        end
    endtask

    initial begin

        clk          = 1'b0;
        reset        = 1'b1;
        rx_line      = 1'b1;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Desfasamos el comienzo respecto del clock.
        #3;

        send_and_expect(8'h4C, "BYTE 4C");
        send_and_expect(8'hA5, "BYTE A5");
        send_and_expect(8'h00, "BYTE 00");
        send_and_expect(8'hFF, "BYTE FF");

        // -----------------------------------------------------
        // Falso START:
        // mantenemos RX en 0 menos de medio bit.
        // No debe aparecer un byte válido.
        // -----------------------------------------------------

        before_count = rx_count;

        hold_line(1'b0, BIT_CLKS / 4);
        hold_line(1'b1, BIT_CLKS);

        tests_run = tests_run + 1;

        if (rx_count == before_count) begin
            tests_passed = tests_passed + 1;
            $display("PASS: false start rejected");
        end
        else begin
            tests_failed = tests_failed + 1;
            $display("FAIL: false start generated a byte");
        end

        $display("");
        $display("RX bytes      : %0d", rx_count);
        $display("Frame errors  : %0d", frame_error_count);
        $display("Tests run     : %0d", tests_run);
        $display("Tests passed  : %0d", tests_passed);
        $display("Tests failed  : %0d", tests_failed);

        if (tests_failed == 0)
            $display("PASS: uart_rx");
        else
            $fatal(1, "FAIL: uart_rx");

        $finish;

    end

endmodule
