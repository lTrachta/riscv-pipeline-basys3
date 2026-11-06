`timescale 1ns / 1ps

module execution_control_unit #(
    parameter logic [31:0] HALT_INSTRUCTION = 32'h0000000B
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,

    // Instrucción actualmente en ID.
    input  logic [31:0] if_id_instruction,
    input  logic        if_id_valid,

    // Redirect producido por una instrucción más vieja en EX.
    input  logic        redirect_valid,

    // Estado de ocupación del pipeline.
    input  logic        pipeline_empty,

    // Estado de ejecución.
    output logic        running,
    output logic        draining,
    output logic        halted,

    // Observación de HALT.
    output logic        halt_in_id,
    output logic        halt_accept
);


    // =========================================================
    // ESTADOS
    // =========================================================

    typedef enum logic [1:0] {
        STATE_RUNNING  = 2'b00,
        STATE_DRAINING = 2'b01,
        STATE_HALTED   = 2'b10
    } execution_state_t;

    execution_state_t state;
    execution_state_t next_state;


    // =========================================================
    // DETECCIÓN DE HALT EN ID
    //
    // HALT sólo tiene significado si IF/ID contiene una
    // instrucción válida.
    // =========================================================

    always_comb begin

        halt_in_id =
            if_id_valid &&
            (if_id_instruction == HALT_INSTRUCTION);

    end


    // =========================================================
    // ACEPTACIÓN DE HALT
    //
    // El HALT solamente se acepta:
    //
    // - durante RUNNING;
    // - si realmente está en ID;
    // - si no existe un redirect desde una instrucción más vieja.
    //
    // Esto resuelve:
    //
    // EX : branch tomado
    // ID : HALT
    //
    // En ese caso gana el redirect y HALT es wrong-path.
    // =========================================================

    always_comb begin

        halt_accept =
            !reset &&
            enable &&
            (state == STATE_RUNNING) &&
            halt_in_id &&
            !redirect_valid;

    end


    // =========================================================
    // MÁQUINA DE ESTADOS
    // =========================================================

    always_comb begin

        next_state = state;

        case (state)

            STATE_RUNNING: begin

                if (halt_accept)
                    next_state = STATE_DRAINING;

            end


            STATE_DRAINING: begin

                if (pipeline_empty)
                    next_state = STATE_HALTED;

            end


            STATE_HALTED: begin

                next_state = STATE_HALTED;

            end


            default: begin

                next_state = STATE_RUNNING;

            end

        endcase

    end


    // =========================================================
    // REGISTRO DE ESTADO
    // =========================================================

    always_ff @(posedge clk) begin

        if (reset)
            state <= STATE_RUNNING;
        else if (enable)
            state <= next_state;

    end


    // =========================================================
    // SALIDAS DE ESTADO
    // =========================================================

    always_comb begin

        running  = (state == STATE_RUNNING);
        draining = (state == STATE_DRAINING);
        halted   = (state == STATE_HALTED);

    end

endmodule
