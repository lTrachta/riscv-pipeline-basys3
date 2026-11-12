`timescale 1ns / 1ps

module basys3_top_tb;

    logic CLK100MHZ;
    logic btnC;
    logic RsRx;

    logic RsTx;
    logic [15:0] led;

    logic heartbeat_before;


    integer tests_run;
    integer tests_passed;
    integer tests_failed;


    basys3_top #(
        .POWER_ON_COUNTER_BITS  (4),
        .HEARTBEAT_COUNTER_BITS (4)
    ) dut (
        .CLK100MHZ (CLK100MHZ),
        .btnC      (btnC),
        .RsRx      (RsRx),
        .RsTx      (RsTx),
        .led       (led)
    );


    always #5 CLK100MHZ =
        ~CLK100MHZ;


    task automatic check(
        input logic condition,
        input string name
    );

        tests_run =
            tests_run + 1;

        if (condition) begin

            tests_passed =
                tests_passed + 1;

            $display(
                "PASS: %s",
                name
            );

        end
        else begin

            tests_failed =
                tests_failed + 1;

            $display(
                "FAIL: %s",
                name
            );

        end

    endtask


    initial begin

        CLK100MHZ = 1'b0;
        btnC      = 1'b0;
        RsRx      = 1'b1;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;


        // =====================================================
        // El sistema debe permanecer en reset mientras
        // Clocking Wizard no esté locked.
        // =====================================================

        repeat (3)
            @(posedge CLK100MHZ);

        check(
            led[9] == 1'b1,
            "RESET ACTIVO ANTES DE CLOCK LOCK"
        );


        // =====================================================
        // Esperar lock del Clocking Wizard.
        // =====================================================

        wait (
            dut.clock_locked
            === 1'b1
        );


        // POWER_ON_COUNTER_BITS=4:
        // dejamos suficientes clocks de 50 MHz
        // para terminar el reset de encendido.

        repeat (12)
            @(posedge dut.system_clk);


        check(
            led[9] == 1'b0,
            "POWER-ON RESET FINALIZA"
        );


        check(
            RsTx == 1'b1,
            "UART TX IDLE EN ALTO"
        );


        check(
            led[0] == 1'b0,
            "SIN PROGRAMA CARGADO"
        );


        // =====================================================
        // Heartbeat.
        // =====================================================

        heartbeat_before =
            led[15];

        repeat (8)
            @(posedge dut.system_clk);


        check(
            led[15]
            != heartbeat_before,
            "HEARTBEAT FUNCIONA"
        );


        // =====================================================
        // Reset físico mediante btnC.
        // =====================================================

        btnC =
            1'b1;

        #1;


        check(
            led[9] == 1'b1,
            "RESET POR BTNC"
        );


        btnC =
            1'b0;


        repeat (12)
            @(posedge dut.system_clk);


        check(
            led[9] == 1'b0,
            "RESET LIBERADO"
        );


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
                "PASS: basys3_top"
            );
        else
            $display(
                "FAIL: basys3_top"
            );


        $finish;

    end

endmodule
