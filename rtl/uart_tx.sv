`timescale 1ns / 1ps

module uart_tx #(
    parameter integer OVERSAMPLING = 16
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       baud_tick,

    input  logic       tx_start,
    input  logic [7:0] tx_data,

    output logic       tx,
    output logic       tx_busy,
    output logic       tx_done
);

    localparam integer SAMPLE_COUNTER_WIDTH =
        (OVERSAMPLING <= 1) ? 1 : $clog2(OVERSAMPLING);

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_START,
        STATE_DATA,
        STATE_STOP
    } tx_state_t;

    tx_state_t state;

    logic [SAMPLE_COUNTER_WIDTH-1:0] sample_count;
    logic [2:0]                      bit_index;
    logic [7:0]                      data_reg;

    always_ff @(posedge clk) begin

        if (reset) begin

            state        <= STATE_IDLE;
            sample_count <= '0;
            bit_index    <= 3'd0;
            data_reg     <= 8'd0;

            tx      <= 1'b1;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;

        end
        else begin

            // Pulso de un solo ciclo.
            tx_done <= 1'b0;

            case (state)

                // -------------------------------------------------
                // Reposo.
                // -------------------------------------------------

                STATE_IDLE: begin

                    tx           <= 1'b1;
                    tx_busy      <= 1'b0;
                    sample_count <= '0;
                    bit_index    <= 3'd0;

                    if (tx_start) begin

                        data_reg <= tx_data;

                        tx      <= 1'b0; // START
                        tx_busy <= 1'b1;

                        state <= STATE_START;

                    end

                end

                // -------------------------------------------------
                // START dura un bit completo.
                // -------------------------------------------------

                STATE_START: begin

                    if (baud_tick) begin

                        if (sample_count == OVERSAMPLING - 1) begin

                            sample_count <= '0;
                            bit_index    <= 3'd0;

                            tx    <= data_reg[0];
                            state <= STATE_DATA;

                        end
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end

                    end

                end

                // -------------------------------------------------
                // D0 ... D7, LSB first.
                // Cada dato dura un bit completo.
                // -------------------------------------------------

                STATE_DATA: begin

                    if (baud_tick) begin

                        if (sample_count == OVERSAMPLING - 1) begin

                            sample_count <= '0;

                            if (bit_index == 3'd7) begin

                                tx    <= 1'b1; // STOP
                                state <= STATE_STOP;

                            end
                            else begin

                                bit_index <= bit_index + 1'b1;
                                tx        <= data_reg[bit_index + 1'b1];

                            end

                        end
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end

                    end

                end

                // -------------------------------------------------
                // STOP dura un bit completo.
                // -------------------------------------------------

                STATE_STOP: begin

                    if (baud_tick) begin

                        if (sample_count == OVERSAMPLING - 1) begin

                            sample_count <= '0;

                            tx      <= 1'b1;
                            tx_busy <= 1'b0;
                            tx_done <= 1'b1;

                            state <= STATE_IDLE;

                        end
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end

                    end

                end

                default: begin
                    state <= STATE_IDLE;
                end

            endcase

        end

    end

endmodule
