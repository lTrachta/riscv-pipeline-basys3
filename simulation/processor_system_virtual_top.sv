`timescale 1ns / 1ps

module processor_system_virtual_top (
    input  logic       clk,
    input  logic       reset,

    input  logic       uart_rx,
    output logic       uart_tx,

    output logic [2:0] status_code,
    output logic       program_loaded,

    output logic core_running,
    output logic core_draining,
    output logic core_halted,
    output logic core_pipeline_empty,

    output logic uart_rx_frame_error
);

    // ---------------------------------------------------------
    // Timing acelerado exclusivamente para simulacion.
    //
    // 1 MHz / (62500 * 16) = 1 clock por tick.
    // Cada bit UART dura exactamente 16 clocks.
    //
    // processor_system.sv NO se modifica.
    // ---------------------------------------------------------

    localparam integer SIM_CLK_FREQ =
        1_000_000;

    localparam integer SIM_BAUD_RATE =
        62_500;

    localparam integer SIM_OVERSAMPLING =
        16;


    processor_system #(
        .CLK_FREQ (
            SIM_CLK_FREQ
        ),

        .BAUD_RATE (
            SIM_BAUD_RATE
        ),

        .OVERSAMPLING (
            SIM_OVERSAMPLING
        ),

        .IMEM_DEPTH (
            256
        ),

        .DATA_MEM_DEPTH (
            256
        )
    ) processor_system_inst (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .uart_rx (
            uart_rx
        ),

        .uart_tx (
            uart_tx
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

endmodule
