`timescale 1ns / 1ps

module reset_controller #(
    parameter integer POWER_ON_COUNTER_BITS = 20
) (
    input  logic clk,

    input  logic button_async,
    input  logic clock_locked_async,

    output logic reset
);

    // =========================================================
    // RESET ASÍNCRONO SOLICITADO
    //
    // El sistema se mantiene en reset cuando:
    //
    // - btnC está presionado;
    // - el Clocking Wizard todavía no está locked.
    //
    // =========================================================

    logic async_reset_request;


    assign async_reset_request =
        button_async |
        !clock_locked_async;


    // =========================================================
    // ASYNCHRONOUS ASSERT / SYNCHRONOUS RELEASE
    //
    // Reset se puede afirmar inmediatamente.
    // Su liberación queda sincronizada con system_clk.
    // =========================================================

    (* ASYNC_REG = "TRUE" *)
    logic reset_meta;

    (* ASYNC_REG = "TRUE" *)
    logic reset_sync;


    always_ff @(
        posedge clk
        or posedge async_reset_request
    ) begin

        if (async_reset_request) begin

            reset_meta <= 1'b1;
            reset_sync <= 1'b1;

        end
        else begin

            reset_meta <= 1'b0;
            reset_sync <= reset_meta;

        end

    end


    // =========================================================
    // RESET DE ENCENDIDO
    //
    // Con:
    //
    // system_clk = 50 MHz
    // POWER_ON_COUNTER_BITS = 20
    //
    // 2^19 / 50 MHz ~= 10.49 ms
    //
    // =========================================================

    logic [POWER_ON_COUNTER_BITS-1:0]
        power_on_counter;

    logic power_on_reset;


    always_ff @(posedge clk) begin

        if (reset_sync) begin

            power_on_counter <= '0;

        end
        else if (
            !power_on_counter[
                POWER_ON_COUNTER_BITS - 1
            ]
        ) begin

            power_on_counter <=
                power_on_counter + 1'b1;

        end

    end


    assign power_on_reset =
        !power_on_counter[
            POWER_ON_COUNTER_BITS - 1
        ];


    // =========================================================
    // RESET FINAL
    // =========================================================

    assign reset =
        reset_sync |
        power_on_reset;

endmodule
