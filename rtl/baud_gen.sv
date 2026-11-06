`timescale 1ns / 1ps

module baud_gen #(
    parameter integer CLK_FREQ     = 100_000_000,
    parameter integer BAUD_RATE    = 115_200,
    parameter integer OVERSAMPLING = 16
) (
    input  logic clk,
    input  logic reset,
    output logic tick
);

    localparam integer TICK_RATE =
        BAUD_RATE * OVERSAMPLING;

    // Redondeo al entero más cercano.
    localparam integer CLKS_PER_TICK =
        (CLK_FREQ + (TICK_RATE / 2)) / TICK_RATE;

    localparam integer COUNTER_WIDTH =
        (CLKS_PER_TICK <= 1) ? 1 : $clog2(CLKS_PER_TICK);

    logic [COUNTER_WIDTH-1:0] counter;

    always_ff @(posedge clk) begin

        if (reset) begin
            counter <= '0;
            tick    <= 1'b0;
        end
        else begin

            tick <= 1'b0;

            if (counter == CLKS_PER_TICK - 1) begin
                counter <= '0;
                tick    <= 1'b1;
            end
            else begin
                counter <= counter + 1'b1;
            end

        end

    end

endmodule
