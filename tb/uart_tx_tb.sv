`timescale 1ns / 1ps

module uart_tx_tb;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer OVERSAMPLING = 16;

    logic clk;
    logic reset;

    logic baud_tick;

    logic       tx_start;
    logic [7:0] tx_data;

    logic tx;
    logic tx_busy;
    logic tx_done;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer i;

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
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .baud_tick (baud_tick),

        .tx_start  (tx_start),
        .tx_data   (tx_data),

        .tx        (tx),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    always #5 clk = ~clk;

    task automatic wait_ticks (
        input integer amount
    );
        integer seen;
        begin

            seen = 0;

            while (seen < amount) begin

                @(posedge clk);
                #1;

                if (baud_tick)
                    seen = seen + 1;

            end

        end
    endtask

    task automatic check_level (
        input logic  expected,
        input string name
    );
        begin

            tests_run = tests_run + 1;

            if (tx === expected) begin

                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-22s | tx=%0d",
                    name,
                    tx
                );

            end
            else begin

                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-22s | tx=%0d expected=%0d",
                    name,
                    tx,
                    expected
                );

            end

        end
    endtask

    task automatic transmit_and_check (
        input logic [7:0] value,
        input string      name
    );
        integer bit_i;
        begin

            while (tx_busy)
                @(posedge clk);

            @(negedge clk);
            tx_data  = value;
            tx_start = 1'b1;

            @(negedge clk);
            tx_start = 1'b0;

            // Centro de START.
            wait_ticks(OVERSAMPLING / 2);
            check_level(1'b0, {name, " START"});

            // Centros D0 ... D7.
            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin

                wait_ticks(OVERSAMPLING);
                check_level(
                    value[bit_i],
                    $sformatf("%s D%0d", name, bit_i)
                );

            end

            // Centro de STOP.
            wait_ticks(OVERSAMPLING);
            check_level(1'b1, {name, " STOP"});

            // Esperar final real de STOP.
            while (!tx_done) begin
                @(posedge clk);
                #1;
            end

            if (tx_busy !== 1'b0) begin
                tests_run    = tests_run + 1;
                tests_failed = tests_failed + 1;
                $display("FAIL: %s busy remains high", name);
            end
            else begin
                tests_run    = tests_run + 1;
                tests_passed = tests_passed + 1;
                $display("PASS: %s completed", name);
            end

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

        #1;
        check_level(1'b1, "IDLE");

        transmit_and_check(8'h4C, "BYTE 4C");
        transmit_and_check(8'hA5, "BYTE A5");
        transmit_and_check(8'h00, "BYTE 00");
        transmit_and_check(8'hFF, "BYTE FF");

        $display("");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);

        if (tests_failed == 0)
            $display("PASS: uart_tx");
        else
            $fatal(1, "FAIL: uart_tx");

        $finish;

    end

endmodule
