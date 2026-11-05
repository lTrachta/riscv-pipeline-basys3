`timescale 1ns / 1ps

module program_loader #(
    parameter integer IMEM_DEPTH = 256
) (
    input  logic       clk,
    input  logic       reset,

    // =========================================================
    // BYTE INPUT
    //
    // En simulación será generado por el testbench.
    // Más adelante vendrá directamente desde uart_rx.
    // =========================================================

    input  logic       rx_byte_valid,
    input  logic [7:0] rx_byte_data,


    // =========================================================
    // ESTADO DE LA CARGA
    // =========================================================

    output logic        load_active,
    output logic        load_done,
    output logic        load_error,

    output logic [15:0] expected_instructions,
    output logic [15:0] received_instructions,


    // =========================================================
    // PUERTO DE ESCRITURA HACIA INSTRUCTION MEMORY
    // =========================================================

    output logic        imem_write_enable,
    output logic [31:0] imem_write_address,
    output logic [31:0] imem_write_data
);


    // =========================================================
    // COMANDOS DEL PROTOCOLO
    // =========================================================

    localparam logic [7:0] CMD_BEGIN_LOAD = 8'h4C; // 'L'
    localparam logic [7:0] CMD_WRITE_WORD = 8'h57; // 'W'
    localparam logic [7:0] CMD_END_LOAD   = 8'h45; // 'E'


    localparam integer IMEM_SIZE_BYTES =
        IMEM_DEPTH * 4;


    // =========================================================
    // FSM
    // =========================================================

    typedef enum logic [3:0] {

        STATE_IDLE,

        STATE_COUNT_HI,
        STATE_COUNT_LO,

        STATE_WAIT_COMMAND,

        STATE_ADDRESS_HI,
        STATE_ADDRESS_LO,

        STATE_DATA_31_24,
        STATE_DATA_23_16,
        STATE_DATA_15_8,
        STATE_DATA_7_0

    } loader_state_t;


    loader_state_t state;


    // =========================================================
    // REGISTROS TEMPORALES
    // =========================================================

    logic [7:0] count_hi;

    logic [7:0] address_hi;
    logic [7:0] address_lo;

    logic [7:0] data_31_24;
    logic [7:0] data_23_16;
    logic [7:0] data_15_8;


    logic [15:0] assembled_address;
    logic [31:0] assembled_data;


    // =========================================================
    // VALORES ENSAMBLADOS
    // =========================================================

    always_comb begin

        assembled_address = {
            address_hi,
            address_lo
        };


        assembled_data = {
            data_31_24,
            data_23_16,
            data_15_8,
            rx_byte_data
        };

    end


    // =========================================================
    // FSM PRINCIPAL
    // =========================================================

    always_ff @(posedge clk) begin

        if (reset) begin

            state <= STATE_IDLE;

            load_active <= 1'b0;
            load_done   <= 1'b0;
            load_error  <= 1'b0;

            expected_instructions <= 16'd0;
            received_instructions <= 16'd0;

            imem_write_enable  <= 1'b0;
            imem_write_address <= 32'd0;
            imem_write_data    <= 32'd0;

            count_hi <= 8'd0;

            address_hi <= 8'd0;
            address_lo <= 8'd0;

            data_31_24 <= 8'd0;
            data_23_16 <= 8'd0;
            data_15_8  <= 8'd0;

        end
        else begin

            // -------------------------------------------------
            // Pulsos de un solo ciclo.
            // -------------------------------------------------

            load_done         <= 1'b0;
            imem_write_enable <= 1'b0;


            if (rx_byte_valid) begin

                case (state)

                    // =========================================
                    // IDLE
                    //
                    // Ignoramos cualquier byte hasta recibir L.
                    // Esto además permite resincronizar el
                    // protocolo fácilmente.
                    // =========================================

                    STATE_IDLE: begin

                        if (rx_byte_data == CMD_BEGIN_LOAD) begin

                            load_active <= 1'b0;
                            load_error  <= 1'b0;

                            expected_instructions <= 16'd0;
                            received_instructions <= 16'd0;

                            state <= STATE_COUNT_HI;

                        end

                    end


                    // =========================================
                    // CANTIDAD DE INSTRUCCIONES
                    //
                    // Big endian:
                    //
                    // primero N[15:8]
                    // después N[7:0]
                    // =========================================

                    STATE_COUNT_HI: begin

                        count_hi <= rx_byte_data;

                        state <= STATE_COUNT_LO;

                    end


                    STATE_COUNT_LO: begin

                        expected_instructions <= {
                            count_hi,
                            rx_byte_data
                        };


                        if (
                            ({count_hi, rx_byte_data} == 16'd0) ||
                            ({count_hi, rx_byte_data} > IMEM_DEPTH)
                        ) begin

                            load_error  <= 1'b1;
                            load_active <= 1'b0;

                            state <= STATE_IDLE;

                        end
                        else begin

                            load_active <= 1'b1;
                            load_error  <= 1'b0;

                            received_instructions <= 16'd0;

                            state <= STATE_WAIT_COMMAND;

                        end

                    end


                    // =========================================
                    // ESPERA DE COMANDOS DURANTE LA CARGA
                    // =========================================

                    STATE_WAIT_COMMAND: begin

                        if (
                            rx_byte_data ==
                            CMD_WRITE_WORD
                        ) begin

                            state <= STATE_ADDRESS_HI;

                        end
                        else if (
                            rx_byte_data ==
                            CMD_END_LOAD
                        ) begin

                            load_active <= 1'b0;


                            if (
                                !load_error &&
                                (
                                    received_instructions ==
                                    expected_instructions
                                )
                            ) begin

                                load_done <= 1'b1;

                            end
                            else begin

                                load_error <= 1'b1;

                            end


                            state <= STATE_IDLE;

                        end
                        else begin

                            // Comando desconocido.
                            load_error <= 1'b1;

                        end

                    end


                    // =========================================
                    // DIRECCIÓN
                    //
                    // 16 bits, big endian.
                    // =========================================

                    STATE_ADDRESS_HI: begin

                        address_hi <= rx_byte_data;

                        state <= STATE_ADDRESS_LO;

                    end


                    STATE_ADDRESS_LO: begin

                        address_lo <= rx_byte_data;

                        state <= STATE_DATA_31_24;

                    end


                    // =========================================
                    // DATA
                    //
                    // Instrucción de 32 bits:
                    //
                    // [31:24]
                    // [23:16]
                    // [15:8]
                    // [7:0]
                    // =========================================

                    STATE_DATA_31_24: begin

                        data_31_24 <= rx_byte_data;

                        state <= STATE_DATA_23_16;

                    end


                    STATE_DATA_23_16: begin

                        data_23_16 <= rx_byte_data;

                        state <= STATE_DATA_15_8;

                    end


                    STATE_DATA_15_8: begin

                        data_15_8 <= rx_byte_data;

                        state <= STATE_DATA_7_0;

                    end


                    STATE_DATA_7_0: begin

                        // -------------------------------------
                        // Validar dirección.
                        //
                        // Debe:
                        //
                        // - estar alineada a 4 bytes;
                        // - pertenecer a Instruction Memory;
                        // - no superar la cantidad anunciada.
                        // -------------------------------------

                        if (
                            (assembled_address[1:0] == 2'b00) &&
                            (assembled_address < IMEM_SIZE_BYTES) &&
                            (
                                received_instructions <
                                expected_instructions
                            )
                        ) begin

                            imem_write_enable <= 1'b1;

                            imem_write_address <= {
                                16'd0,
                                assembled_address
                            };

                            imem_write_data <= assembled_data;

                            received_instructions <=
                                received_instructions + 16'd1;

                        end
                        else begin

                            load_error <= 1'b1;

                        end


                        state <= STATE_WAIT_COMMAND;

                    end


                    default: begin

                        state <= STATE_IDLE;

                        load_active <= 1'b0;
                        load_error  <= 1'b1;

                    end

                endcase

            end

        end

    end

endmodule
