`timescale 1ns / 1ps

module basys3_top #(
    parameter integer POWER_ON_COUNTER_BITS = 20,
    parameter integer HEARTBEAT_COUNTER_BITS = 26
) (
    input  logic        CLK100MHZ,

    input  logic        btnC,

    input  logic        RsRx,
    output logic        RsTx,

    output logic [15:0] led
);

    // =========================================================
    // CLOCK
    //
    // Basys 3:
    //     100 MHz físicos
    //
    // Clocking Wizard:
    //     100 MHz -> 50 MHz
    //
    // El processor_system funciona a 50 MHz.
    // =========================================================

    logic system_clk;
    logic clock_locked;


    clk_wiz_0 clock_generator_inst (
        .clk_out1 (
            system_clk
        ),

        .locked (
            clock_locked
        ),

        .clk_in1 (
            CLK100MHZ
        )
    );


    // =========================================================
    // RESET
    // =========================================================

    logic reset;


    reset_controller #(
        .POWER_ON_COUNTER_BITS (
            POWER_ON_COUNTER_BITS
        )
    ) reset_controller_inst (
        .clk (
            system_clk
        ),

        .button_async (
            btnC
        ),

        .clock_locked_async (
            clock_locked
        ),

        .reset (
            reset
        )
    );


    // =========================================================
    // PROCESSOR SYSTEM
    // =========================================================

    logic [2:0] status_code;

    logic program_loaded;

    logic core_running;
    logic core_draining;
    logic core_halted;
    logic core_pipeline_empty;

    logic uart_rx_frame_error;


    processor_system #(
        .CLK_FREQ       (50_000_000),
        .BAUD_RATE      (115_200),
        .OVERSAMPLING   (16),
        .IMEM_DEPTH     (256),
        .DATA_MEM_DEPTH (256)
    ) processor_system_inst (
        .clk (
            system_clk
        ),

        .reset (
            reset
        ),

        .uart_rx (
            RsRx
        ),

        .uart_tx (
            RsTx
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
    // UART ERROR LATCH
    // =========================================================

    logic uart_error_latched;


    always_ff @(posedge system_clk) begin

        if (reset) begin

            uart_error_latched <=
                1'b0;

        end
        else if (uart_rx_frame_error) begin

            uart_error_latched <=
                1'b1;

        end

    end


    // =========================================================
    // HEARTBEAT
    //
    // HEARTBEAT_COUNTER_BITS baja de 27 a 26 porque
    // system_clk ahora funciona a 50 MHz.
    //
    // La velocidad visual queda aproximadamente igual.
    // =========================================================

    logic [HEARTBEAT_COUNTER_BITS-1:0]
        heartbeat_counter;


    always_ff @(posedge system_clk) begin

        if (reset) begin

            heartbeat_counter <=
                '0;

        end
        else begin

            heartbeat_counter <=
                heartbeat_counter + 1'b1;

        end

    end


    // =========================================================
    // LEDS
    // =========================================================
    //
    // LED0  program_loaded
    // LED1  running
    // LED2  draining
    // LED3  halted
    // LED4  pipeline_empty
    // LED5  UART frame error
    //
    // LED8:6 status_code
    //
    // LED9  reset
    //
    // LED15 heartbeat
    //
    // =========================================================

    always_comb begin

        led = 16'd0;

        led[0] =
            program_loaded;

        led[1] =
            core_running;

        led[2] =
            core_draining;

        led[3] =
            core_halted;

        led[4] =
            core_pipeline_empty;

        led[5] =
            uart_error_latched;

        led[8:6] =
            status_code;

        led[9] =
            reset;

        led[15] =
            heartbeat_counter[
                HEARTBEAT_COUNTER_BITS - 1
            ];

    end

endmodule
