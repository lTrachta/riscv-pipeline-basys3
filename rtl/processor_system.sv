`timescale 1ns / 1ps

module processor_system #(
    parameter integer CLK_FREQ       = 100_000_000,
    parameter integer BAUD_RATE      = 115_200,
    parameter integer OVERSAMPLING   = 16,
    parameter integer IMEM_DEPTH     = 256,
    parameter integer DATA_MEM_DEPTH = 256
) (
    input  logic       clk,
    input  logic       reset,

    input  logic       uart_rx,
    output logic       uart_tx,

    output logic [2:0] status_code,
    output logic       program_loaded,

    output logic       core_running,
    output logic       core_draining,
    output logic       core_halted,
    output logic       core_pipeline_empty,

    output logic       uart_rx_frame_error
);

    logic baud_tick;

    baud_gen #(
        .CLK_FREQ     (CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) baud_gen_inst (
        .clk   (clk),
        .reset (reset),
        .tick  (baud_tick)
    );

    logic [7:0] rx_byte_data;
    logic       rx_byte_valid;

    uart_rx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) uart_rx_inst (
        .clk            (clk),
        .reset          (reset),
        .baud_tick      (baud_tick),
        .rx             (uart_rx),
        .rx_byte_data   (rx_byte_data),
        .rx_byte_valid  (rx_byte_valid),
        .rx_frame_error (uart_rx_frame_error)
    );

    logic       loader_rx_byte_valid;
    logic [7:0] loader_rx_byte_data;

    logic        load_active;
    logic        load_done;
    logic        load_error;
    logic [15:0] expected_instructions;
    logic [15:0] received_instructions;

    logic        imem_write_enable;
    logic [31:0] imem_write_address;
    logic [31:0] imem_write_data;

    program_loader #(
        .IMEM_DEPTH (IMEM_DEPTH)
    ) program_loader_inst (
        .clk                   (clk),
        .reset                 (reset),
        .rx_byte_valid         (loader_rx_byte_valid),
        .rx_byte_data          (loader_rx_byte_data),
        .load_active           (load_active),
        .load_done             (load_done),
        .load_error            (load_error),
        .expected_instructions (expected_instructions),
        .received_instructions (received_instructions),
        .imem_write_enable     (imem_write_enable),
        .imem_write_address    (imem_write_address),
        .imem_write_data       (imem_write_data)
    );

    logic       core_cycle_enable;
    logic       controller_core_reset;
    logic       core_reset_combined;

    logic [4:0]  debug_register_address;
    logic [31:0] debug_register_data;

    logic [31:0] debug_memory_address;
    logic [31:0] debug_memory_data;

    assign core_reset_combined =
        reset | controller_core_reset;

    pipeline_core pipeline_core_inst (
        .clk                    (clk),
        .reset                  (core_reset_combined),
        .cycle_enable           (core_cycle_enable),

        .program_write_enable   (imem_write_enable),
        .program_write_address  (imem_write_address),
        .program_write_data     (imem_write_data),

        .debug_register_address (debug_register_address),
        .debug_register_data    (debug_register_data),

        .debug_memory_address   (debug_memory_address),
        .debug_memory_data      (debug_memory_data),

        .running                (core_running),
        .draining               (core_draining),
        .halted                 (core_halted),
        .pipeline_empty         (core_pipeline_empty)
    );

    logic       tx_byte_valid;
    logic [7:0] tx_byte_data;
    logic       tx_byte_ready;

    system_protocol_controller #(
        .DATA_MEM_DEPTH (DATA_MEM_DEPTH)
    ) protocol_controller_inst (
        .clk                    (clk),
        .reset                  (reset),

        .rx_byte_valid          (rx_byte_valid),
        .rx_byte_data           (rx_byte_data),

        .loader_rx_byte_valid   (loader_rx_byte_valid),
        .loader_rx_byte_data    (loader_rx_byte_data),

        .load_active            (load_active),
        .load_done              (load_done),
        .load_error             (load_error),

        .core_running           (core_running),
        .core_draining          (core_draining),
        .core_halted            (core_halted),

        .core_cycle_enable      (core_cycle_enable),
        .core_reset             (controller_core_reset),

        .debug_register_address (debug_register_address),
        .debug_register_data    (debug_register_data),

        .debug_memory_address   (debug_memory_address),
        .debug_memory_data      (debug_memory_data),

        .tx_byte_valid          (tx_byte_valid),
        .tx_byte_data           (tx_byte_data),
        .tx_byte_ready          (tx_byte_ready),

        .status_code            (status_code),
        .program_loaded         (program_loaded)
    );

    logic uart_tx_start;
    logic uart_tx_busy;
    logic uart_tx_done;

    assign uart_tx_start =
        tx_byte_valid &&
        !uart_tx_busy;

    assign tx_byte_ready =
        tx_byte_valid &&
        !uart_tx_busy;

    uart_tx #(
        .OVERSAMPLING (OVERSAMPLING)
    ) uart_tx_inst (
        .clk       (clk),
        .reset     (reset),
        .baud_tick (baud_tick),
        .tx_start  (uart_tx_start),
        .tx_data   (tx_byte_data),
        .tx        (uart_tx),
        .tx_busy   (uart_tx_busy),
        .tx_done   (uart_tx_done)
    );

endmodule
