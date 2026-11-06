`timescale 1ns / 1ps

module uart_rx #(
    parameter integer OVERSAMPLING = 16
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       baud_tick,

    input  logic       rx,

    output logic [7:0] rx_byte_data,
    output logic       rx_byte_valid,
    output logic       rx_frame_error
);

    localparam integer HALF_TICKS =
        OVERSAMPLING / 2;

    localparam integer SAMPLE_COUNTER_WIDTH =
        (OVERSAMPLING <= 1) ? 1 : $clog2(OVERSAMPLING);

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_START,
        STATE_DATA,
        STATE_STOP
    } rx_state_t;

    rx_state_t state;

    // ---------------------------------------------------------
    // Sincronizador de dos flip-flops.
    //
    // rx proviene del exterior y es asíncrono respecto de clk.
    // ---------------------------------------------------------

    logic rx_meta;
    logic rx_sync;

    always_ff @(posedge clk) begin

        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end
        else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end

    end

    // ---------------------------------------------------------
    // FSM de recepción.
    // ---------------------------------------------------------

    logic [SAMPLE_COUNTER_WIDTH-1:0] sample_count;
    logic [2:0]                      bit_index;
    logic [7:0]                      data_reg;

    always_ff @(posedge clk) begin

        if (reset) begin

            state          <= STATE_IDLE;
            sample_count   <= '0;
            bit_index      <= 3'd0;
            data_reg       <= 8'd0;

            rx_byte_data   <= 8'd0;
            rx_byte_valid  <= 1'b0;
            rx_frame_error <= 1'b0;

        end
        else begin

            // Pulsos de un solo ciclo.
            rx_byte_valid  <= 1'b0;
            rx_frame_error <= 1'b0;

            case (state)

                // -------------------------------------------------
                // Línea en reposo = 1.
                // Un 0 puede indicar el comienzo de START.
                // -------------------------------------------------

                STATE_IDLE: begin

                    sample_count <= '0;
                    bit_index    <= 3'd0;

                    if (!rx_sync) begin
                        state <= STATE_START;
                    end

                end

                // -------------------------------------------------
                // Esperamos medio bit para verificar START cerca
                // de su centro.
                // -------------------------------------------------

                STATE_START: begin

                    if (baud_tick) begin

                        if (sample_count == HALF_TICKS - 1) begin

                            sample_count <= '0;

                            if (!rx_sync) begin
                                bit_index <= 3'd0;
                                state     <= STATE_DATA;
                            end
                            else begin
                                // Falso START.
                                state <= STATE_IDLE;
                            end

                        end
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end

                    end

                end

                // -------------------------------------------------
                // Desde el centro de START esperamos un bit
                // completo para llegar al centro de D0.
                //
                // Luego repetimos cada OVERSAMPLING ticks.
                //
                // UART transmite D0 primero.
                // -------------------------------------------------

                STATE_DATA: begin

                    if (baud_tick) begin

                        if (sample_count == OVERSAMPLING - 1) begin

                            sample_count       <= '0;
                            data_reg[bit_index] <= rx_sync;

                            if (bit_index == 3'd7) begin
                                state <= STATE_STOP;
                            end
                            else begin
                                bit_index <= bit_index + 1'b1;
                            end

                        end
                        else begin
                            sample_count <= sample_count + 1'b1;
                        end

                    end

                end

                // -------------------------------------------------
                // Verificamos el STOP cerca de su centro.
                // STOP válido = 1.
                // -------------------------------------------------

                STATE_STOP: begin

                    if (baud_tick) begin

                        if (sample_count == OVERSAMPLING - 1) begin

                            sample_count <= '0;
                            state        <= STATE_IDLE;

                            if (rx_sync) begin
                                rx_byte_data  <= data_reg;
                                rx_byte_valid <= 1'b1;
                            end
                            else begin
                                rx_frame_error <= 1'b1;
                            end

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
