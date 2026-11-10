`timescale 1ns / 1ps

module system_protocol_controller #(
    parameter integer DATA_MEM_DEPTH = 256
) (
    input  logic        clk,
    input  logic        reset,

    input  logic        rx_byte_valid,
    input  logic [7:0]  rx_byte_data,

    output logic        loader_rx_byte_valid,
    output logic [7:0]  loader_rx_byte_data,

    input  logic        load_active,
    input  logic        load_done,
    input  logic        load_error,

    input  logic        core_running,
    input  logic        core_draining,
    input  logic        core_halted,

    output logic        core_cycle_enable,
    output logic        core_reset,

    output logic [4:0]  debug_register_address,
    input  logic [31:0] debug_register_data,

    output logic [31:0] debug_memory_address,
    input  logic [31:0] debug_memory_data,

    // =========================================================
    // DEBUG SNAPSHOT
    // =========================================================

    output logic       snapshot_start,

    input  logic       snapshot_busy,
    input  logic       snapshot_done,

    input  logic       snapshot_byte_valid,
    input  logic [7:0] snapshot_byte_data,

    output logic       snapshot_byte_ready,

    output logic        tx_byte_valid,
    output logic [7:0]  tx_byte_data,
    input  logic        tx_byte_ready,

    output logic [2:0]  status_code,
    output logic        program_loaded
);

    localparam logic [7:0] CMD_LOAD  = 8'h4C; // 'L'
    localparam logic [7:0] CMD_RUN   = 8'h52; // 'R'
    localparam logic [7:0] CMD_STEP  = 8'h53; // 'S'
    localparam logic [7:0] CMD_REG   = 8'h47; // 'G'
    localparam logic [7:0] CMD_MEM   = 8'h4D; // 'M'
    localparam logic [7:0] CMD_QUERY = 8'h51; // 'Q'
    localparam logic [7:0] CMD_DEBUG = 8'h44; // 'D'

    localparam logic [7:0] RESP_ACK   = 8'h06;
    localparam logic [7:0] RESP_NACK  = 8'h15;
    localparam logic [7:0] RESP_REG   = 8'h67; // 'g'
    localparam logic [7:0] RESP_MEM   = 8'h6D; // 'm'
    localparam logic [7:0] RESP_STATE = 8'h71; // 'q'

    localparam logic [7:0] ERR_UNKNOWN_COMMAND = 8'h01;
    localparam logic [7:0] ERR_INVALID_ARGUMENT = 8'h02;
    localparam logic [7:0] ERR_INVALID_ADDRESS  = 8'h03;
    localparam logic [7:0] ERR_LOAD             = 8'h04;
    localparam logic [7:0] ERR_INVALID_STATE    = 8'h05;

    localparam logic [2:0] STATUS_READY    = 3'd0;
    localparam logic [2:0] STATUS_LOADING  = 3'd1;
    localparam logic [2:0] STATUS_RUNNING  = 3'd2;
    localparam logic [2:0] STATUS_DRAINING = 3'd3;
    localparam logic [2:0] STATUS_HALTED   = 3'd4;
    localparam logic [2:0] STATUS_ERROR    = 3'd5;

    typedef enum logic [3:0] {
        STATE_WAIT_COMMAND,
        STATE_LOAD_MODE,
        STATE_WAIT_REGISTER,
        STATE_REGISTER_CAPTURE,
        STATE_WAIT_MEMORY_HI,
        STATE_WAIT_MEMORY_LO,
        STATE_MEMORY_CAPTURE,
        STATE_STEP_EXECUTE,
        STATE_DEBUG_SNAPSHOT
    } protocol_state_t;

    protocol_state_t state;

    logic        run_active;
    logic [7:0]  memory_address_hi;
    logic [15:0] memory_address_16;

    logic [7:0] response_buffer [0:6];
    logic [2:0] response_length;
    logic [2:0] response_index;
    logic       response_active;

    integer i;

    // =========================================================
    // SALIDA HACIA UART TX
    //
    // Normalmente se transmiten respuestas del protocolo.
    //
    // Durante STATE_DEBUG_SNAPSHOT, el stream queda directamente
    // conectado a Debug Unit.
    // =========================================================

    always_comb begin

        tx_byte_valid =
            1'b0;

        tx_byte_data =
            8'd0;

        snapshot_byte_ready =
            1'b0;


        if (
            state ==
            STATE_DEBUG_SNAPSHOT
        ) begin

            tx_byte_valid =
                snapshot_byte_valid;

            tx_byte_data =
                snapshot_byte_data;

            snapshot_byte_ready =
                tx_byte_ready;

        end
        else if (response_active) begin

            tx_byte_valid =
                1'b1;

            tx_byte_data =
                response_buffer[
                    response_index
                ];

        end

    end

    always_comb begin
        loader_rx_byte_data = rx_byte_data;

        loader_rx_byte_valid =
            rx_byte_valid &&
            (
                (state == STATE_LOAD_MODE) ||
                (
                    (state == STATE_WAIT_COMMAND) &&
                    !run_active &&
                    !response_active &&
                    (rx_byte_data == CMD_LOAD)
                )
            );
    end

    always_comb begin
        core_cycle_enable =
            run_active ||
            (state == STATE_STEP_EXECUTE);

        core_reset =
            (state == STATE_LOAD_MODE);
    end

    always_comb begin
        if (state == STATE_LOAD_MODE)
            status_code = STATUS_LOADING;
        else if (load_error && !program_loaded)
            status_code = STATUS_ERROR;
        else if (core_halted)
            status_code = STATUS_HALTED;
        else if (core_draining)
            status_code = STATUS_DRAINING;
        else if (run_active)
            status_code = STATUS_RUNNING;
        else
            status_code = STATUS_READY;
    end

    always_ff @(posedge clk) begin

        if (reset) begin

            state <= STATE_WAIT_COMMAND;

            snapshot_start <= 1'b0;

            run_active     <= 1'b0;
            program_loaded <= 1'b0;

            debug_register_address <= 5'd0;
            debug_memory_address   <= 32'd0;

            memory_address_hi <= 8'd0;
            memory_address_16 <= 16'd0;

            response_length <= 3'd0;
            response_index  <= 3'd0;
            response_active <= 1'b0;

            for (i = 0; i < 7; i = i + 1)
                response_buffer[i] <= 8'd0;

        end
        else begin

            // snapshot_start siempre es un pulso de un ciclo.
            snapshot_start <= 1'b0;

            if (core_halted)
                run_active <= 1'b0;

            if (response_active && tx_byte_ready) begin
                if ((response_index + 3'd1) >= response_length) begin
                    response_active <= 1'b0;
                    response_index  <= 3'd0;
                end
                else begin
                    response_index <= response_index + 3'd1;
                end
            end

            case (state)

                STATE_WAIT_COMMAND: begin

                    if (rx_byte_valid && !response_active) begin

                        if (run_active) begin

                            if (rx_byte_data == CMD_QUERY) begin
                                response_buffer[0] <= RESP_STATE;
                                response_buffer[1] <= {5'd0, status_code};
                                response_length <= 3'd2;
                                response_index  <= 3'd0;
                                response_active <= 1'b1;
                            end
                            else begin
                                response_buffer[0] <= RESP_NACK;
                                response_buffer[1] <= ERR_INVALID_STATE;
                                response_length <= 3'd2;
                                response_index  <= 3'd0;
                                response_active <= 1'b1;
                            end

                        end
                        else begin

                            case (rx_byte_data)

                                CMD_LOAD: begin
                                    program_loaded <= 1'b0;
                                    run_active     <= 1'b0;
                                    state          <= STATE_LOAD_MODE;
                                end

                                CMD_RUN: begin
                                    if (program_loaded && !core_halted) begin
                                        run_active <= 1'b1;
                                        response_buffer[0] <= RESP_ACK;
                                        response_length <= 3'd1;
                                        response_index  <= 3'd0;
                                        response_active <= 1'b1;
                                    end
                                    else begin
                                        response_buffer[0] <= RESP_NACK;
                                        response_buffer[1] <= ERR_INVALID_STATE;
                                        response_length <= 3'd2;
                                        response_index  <= 3'd0;
                                        response_active <= 1'b1;
                                    end
                                end

                                CMD_STEP: begin
                                    if (program_loaded && !core_halted) begin
                                        state <= STATE_STEP_EXECUTE;
                                    end
                                    else begin
                                        response_buffer[0] <= RESP_NACK;
                                        response_buffer[1] <= ERR_INVALID_STATE;
                                        response_length <= 3'd2;
                                        response_index  <= 3'd0;
                                        response_active <= 1'b1;
                                    end
                                end

                                CMD_REG: begin
                                    state <= STATE_WAIT_REGISTER;
                                end

                                CMD_MEM: begin
                                    state <= STATE_WAIT_MEMORY_HI;
                                end

                                CMD_QUERY: begin
                                    response_buffer[0] <= RESP_STATE;
                                    response_buffer[1] <= {5'd0, status_code};
                                    response_length <= 3'd2;
                                    response_index  <= 3'd0;
                                    response_active <= 1'b1;
                                end

                                // -----------------------------
                                // DEBUG SNAPSHOT
                                // -----------------------------

                                CMD_DEBUG: begin

                                    if (!snapshot_busy) begin

                                        snapshot_start <=
                                            1'b1;

                                        state <=
                                            STATE_DEBUG_SNAPSHOT;

                                    end
                                    else begin

                                        response_buffer[0] <=
                                            RESP_NACK;

                                        response_buffer[1] <=
                                            ERR_INVALID_STATE;

                                        response_length <=
                                            3'd2;

                                        response_index <=
                                            3'd0;

                                        response_active <=
                                            1'b1;

                                    end

                                end

                                default: begin
                                    response_buffer[0] <= RESP_NACK;
                                    response_buffer[1] <= ERR_UNKNOWN_COMMAND;
                                    response_length <= 3'd2;
                                    response_index  <= 3'd0;
                                    response_active <= 1'b1;
                                end

                            endcase

                        end
                    end
                end

                STATE_LOAD_MODE: begin

                    if (load_done) begin
                        program_loaded <= 1'b1;

                        response_buffer[0] <= RESP_ACK;
                        response_length <= 3'd1;
                        response_index  <= 3'd0;
                        response_active <= 1'b1;

                        state <= STATE_WAIT_COMMAND;
                    end
                    else if (load_error && !load_active) begin
                        program_loaded <= 1'b0;

                        response_buffer[0] <= RESP_NACK;
                        response_buffer[1] <= ERR_LOAD;
                        response_length <= 3'd2;
                        response_index  <= 3'd0;
                        response_active <= 1'b1;

                        state <= STATE_WAIT_COMMAND;
                    end
                end

                STATE_WAIT_REGISTER: begin

                    if (rx_byte_valid && !response_active) begin

                        if (rx_byte_data <= 8'h1F) begin
                            debug_register_address <= rx_byte_data[4:0];
                            state <= STATE_REGISTER_CAPTURE;
                        end
                        else begin
                            response_buffer[0] <= RESP_NACK;
                            response_buffer[1] <= ERR_INVALID_ARGUMENT;
                            response_length <= 3'd2;
                            response_index  <= 3'd0;
                            response_active <= 1'b1;

                            state <= STATE_WAIT_COMMAND;
                        end
                    end
                end

                STATE_REGISTER_CAPTURE: begin

                    if (!response_active) begin
                        response_buffer[0] <= RESP_REG;
                        response_buffer[1] <= {3'd0, debug_register_address};
                        response_buffer[2] <= debug_register_data[31:24];
                        response_buffer[3] <= debug_register_data[23:16];
                        response_buffer[4] <= debug_register_data[15:8];
                        response_buffer[5] <= debug_register_data[7:0];

                        response_length <= 3'd6;
                        response_index  <= 3'd0;
                        response_active <= 1'b1;

                        state <= STATE_WAIT_COMMAND;
                    end
                end

                STATE_WAIT_MEMORY_HI: begin

                    if (rx_byte_valid && !response_active) begin
                        memory_address_hi <= rx_byte_data;
                        state <= STATE_WAIT_MEMORY_LO;
                    end
                end

                STATE_WAIT_MEMORY_LO: begin

                    if (rx_byte_valid && !response_active) begin

                        memory_address_16 <= {
                            memory_address_hi,
                            rx_byte_data
                        };

                        if (
                            ({memory_address_hi, rx_byte_data} < (DATA_MEM_DEPTH * 4)) &&
                            (rx_byte_data[1:0] == 2'b00)
                        ) begin
                            debug_memory_address <= {
                                16'd0,
                                memory_address_hi,
                                rx_byte_data
                            };

                            state <= STATE_MEMORY_CAPTURE;
                        end
                        else begin
                            response_buffer[0] <= RESP_NACK;
                            response_buffer[1] <= ERR_INVALID_ADDRESS;
                            response_length <= 3'd2;
                            response_index  <= 3'd0;
                            response_active <= 1'b1;

                            state <= STATE_WAIT_COMMAND;
                        end
                    end
                end

                STATE_MEMORY_CAPTURE: begin

                    if (!response_active) begin
                        response_buffer[0] <= RESP_MEM;
                        response_buffer[1] <= memory_address_16[15:8];
                        response_buffer[2] <= memory_address_16[7:0];
                        response_buffer[3] <= debug_memory_data[31:24];
                        response_buffer[4] <= debug_memory_data[23:16];
                        response_buffer[5] <= debug_memory_data[15:8];
                        response_buffer[6] <= debug_memory_data[7:0];

                        response_length <= 3'd7;
                        response_index  <= 3'd0;
                        response_active <= 1'b1;

                        state <= STATE_WAIT_COMMAND;
                    end
                end

                STATE_STEP_EXECUTE: begin

                    if (!response_active) begin
                        response_buffer[0] <= RESP_ACK;
                        response_length <= 3'd1;
                        response_index  <= 3'd0;
                        response_active <= 1'b1;

                        state <= STATE_WAIT_COMMAND;
                    end
                end

                // =============================================
                // DEBUG SNAPSHOT
                //
                // Debug Unit controla el stream de bytes.
                //
                // El core permanece detenido porque:
                // run_active = 0
                // state != STATE_STEP_EXECUTE
                // =============================================

                STATE_DEBUG_SNAPSHOT: begin

                    if (snapshot_done) begin

                        state <=
                            STATE_WAIT_COMMAND;

                    end

                end

                default: begin
                    state      <= STATE_WAIT_COMMAND;
                    run_active <= 1'b0;
                end

            endcase
        end
    end

endmodule
