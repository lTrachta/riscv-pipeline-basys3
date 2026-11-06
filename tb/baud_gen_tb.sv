`timescale 1ns / 1ps

module baud_gen_tb;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115_200;
    localparam integer OVERSAMPLING = 16;

    localparam integer TICK_RATE =
        BAUD_RATE * OVERSAMPLING;

    localparam integer EXPECTED_CLKS_PER_TICK =
        (CLK_FREQ + (TICK_RATE / 2)) / TICK_RATE;

    logic clk;
    logic reset;
    logic tick;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer clocks;
    integer i;

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .tick  (tick)
    );

    always #5 clk = ~clk;

    task automatic check_interval;
        begin

            clocks = 0;

            do begin
                @(posedge clk);
                #1;
                clocks = clocks + 1;
            end
            while (!tick);

            tests_run = tests_run + 1;

            if (clocks == EXPECTED_CLKS_PER_TICK) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: tick interval = %0d clocks",
                    clocks
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: tick interval = %0d clocks, expected %0d",
                    clocks,
                    EXPECTED_CLKS_PER_TICK
                );
            end

        end
    endtask

    initial begin

        clk          = 1'b0;
        reset        = 1'b1;
        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display(
            "EXPECTED CLKS PER TICK: %0d",
            EXPECTED_CLKS_PER_TICK
        );

        for (i = 0; i < 6; i = i + 1)
            check_interval();

        $display("");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);

        if (tests_failed == 0)
            $display("PASS: baud_gen");
        else
            $fatal(1, "FAIL: baud_gen");

        $finish;

    end

endmodule
