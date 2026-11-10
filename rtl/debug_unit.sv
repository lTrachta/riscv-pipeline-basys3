`timescale 1ns / 1ps

module debug_unit #(
    parameter integer DATA_MEM_DEPTH = 256
) (
    input  logic clk,
    input  logic reset,

    // =========================================================
    // CONTROL DEL SNAPSHOT
    // =========================================================

    input  logic snapshot_start,

    output logic snapshot_busy,
    output logic snapshot_done,


    // =========================================================
    // ESTADO GENERAL
    // =========================================================

    input logic [2:0] status_code,

    input logic core_running,
    input logic core_draining,
    input logic core_halted,
    input logic core_pipeline_empty,
    input logic core_cycle_enable,


    // =========================================================
    // IF
    // =========================================================

    input logic [31:0] if_pc_current,


    // =========================================================
    // IF / ID
    // =========================================================

    input logic        if_id_valid,
    input logic [31:0] if_id_pc,
    input logic [31:0] if_id_instruction,


    // =========================================================
    // ID / EX
    // =========================================================

    input logic        id_ex_valid,

    input logic [31:0] id_ex_pc,
    input logic [31:0] id_ex_read_data1,
    input logic [31:0] id_ex_read_data2,
    input logic [31:0] id_ex_immediate,

    input logic [4:0] id_ex_rs1,
    input logic [4:0] id_ex_rs2,
    input logic [4:0] id_ex_rd,

    input logic [6:0] id_ex_opcode,
    input logic [2:0] id_ex_funct3,
    input logic [6:0] id_ex_funct7,

    input logic       id_ex_alu_src_a,
    input logic       id_ex_alu_src_b,
    input logic [2:0] id_ex_alu_op,

    input logic       id_ex_branch,
    input logic [1:0] id_ex_jump_type,

    input logic id_ex_mem_read,
    input logic id_ex_mem_write,

    input logic       id_ex_reg_write,
    input logic [1:0] id_ex_wb_sel,


    // =========================================================
    // EX / MEM
    // =========================================================

    input logic        ex_mem_valid,

    input logic [31:0] ex_mem_pc,
    input logic [31:0] ex_mem_alu_result,
    input logic [31:0] ex_mem_store_data,

    input logic [4:0] ex_mem_rs2,
    input logic [4:0] ex_mem_rd,

    input logic [6:0] ex_mem_opcode,
    input logic [2:0] ex_mem_funct3,

    input logic ex_mem_mem_read,
    input logic ex_mem_mem_write,

    input logic       ex_mem_reg_write,
    input logic [1:0] ex_mem_wb_sel,


    // =========================================================
    // MEM / WB
    // =========================================================

    input logic        mem_wb_valid,

    input logic [31:0] mem_wb_pc,
    input logic [31:0] mem_wb_alu_result,
    input logic [31:0] mem_wb_load_data,

    input logic [4:0] mem_wb_rd,
    input logic [6:0] mem_wb_opcode,

    input logic       mem_wb_reg_write,
    input logic [1:0] mem_wb_wb_sel,


    // =========================================================
    // REGISTER FILE DEBUG PORT
    // =========================================================

    output logic [4:0]  debug_register_address,
    input  logic [31:0] debug_register_data,


    // =========================================================
    // DATA MEMORY DEBUG PORT
    // =========================================================

    output logic [31:0] debug_memory_address,
    input  logic [31:0] debug_memory_data,


    // =========================================================
    // MONITOREO DE USO DE DATA MEMORY
    //
    // memory_access_valid debe activarse solamente cuando
    // realmente se ejecuta un load/store válido en MEM.
    // =========================================================

    input logic        memory_access_valid,
    input logic [31:0] memory_access_address,

    // Limpia el mapa de memoria utilizada al cargar
    // un nuevo programa.
    input logic memory_usage_clear,

    output logic [15:0] used_memory_count,


    // =========================================================
    // STREAM DEL SNAPSHOT
    // =========================================================

    output logic       snapshot_byte_valid,
    output logic [7:0] snapshot_byte_data,

    input logic snapshot_byte_ready
);


    // =========================================================
    // CONSTANTES DEL FORMATO
    // =========================================================

    localparam logic [7:0] SNAPSHOT_TAG =
        8'h64; // 'd'

    localparam logic [7:0] SNAPSHOT_VERSION =
        8'h01;

    localparam logic [7:0] TAG_REGISTERS =
        8'h52; // 'R'

    localparam logic [7:0] TAG_IF_ID =
        8'h49; // 'I'

    localparam logic [7:0] TAG_ID_EX =
        8'h58; // 'X'

    localparam logic [7:0] TAG_EX_MEM =
        8'h45; // 'E'

    localparam logic [7:0] TAG_MEM_WB =
        8'h42; // 'B'

    localparam logic [7:0] TAG_MEMORY =
        8'h4D; // 'M'

    localparam logic [7:0] TAG_END =
        8'h7E;


    // =========================================================
    // MAPA DE MEMORIA UTILIZADA
    // =========================================================

    localparam integer MEM_INDEX_WIDTH =
        (DATA_MEM_DEPTH <= 1)
        ? 1
        : $clog2(DATA_MEM_DEPTH);

    localparam integer MEM_SCAN_WIDTH =
        (DATA_MEM_DEPTH <= 1)
        ? 1
        : $clog2(DATA_MEM_DEPTH + 1);


    logic [DATA_MEM_DEPTH-1:0] used_memory_bitmap;

    logic [DATA_MEM_DEPTH-1:0]
        snapshot_memory_bitmap;

    logic [15:0] used_memory_count_reg;
    logic [15:0] snapshot_memory_count;


    logic [MEM_INDEX_WIDTH-1:0]
        access_word_index;

    logic memory_access_in_range;


    assign access_word_index =
        memory_access_address[
            MEM_INDEX_WIDTH + 1 : 2
        ];


    assign memory_access_in_range =
        memory_access_address <
        (DATA_MEM_DEPTH * 4);


    assign used_memory_count =
        used_memory_count_reg;


    // ---------------------------------------------------------
    // Registrar qué palabras fueron realmente utilizadas.
    // ---------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset || memory_usage_clear) begin

            used_memory_bitmap    <= '0;
            used_memory_count_reg <= 16'd0;

        end
        else if (
            memory_access_valid &&
            memory_access_in_range
        ) begin

            if (
                !used_memory_bitmap[
                    access_word_index
                ]
            ) begin

                used_memory_bitmap[
                    access_word_index
                ] <= 1'b1;

                used_memory_count_reg <=
                    used_memory_count_reg + 16'd1;

            end

        end

    end


    // =========================================================
    // COPIA DEL ESTADO DEL PIPELINE
    //
    // Estos registros representan la fotografía tomada cuando
    // snapshot_start se activa.
    // =========================================================

    logic [7:0] snapshot_status;
    logic [7:0] snapshot_flags;

    logic [31:0] snapshot_if_pc;


    // IF / ID

    logic        snapshot_if_id_valid;
    logic [31:0] snapshot_if_id_pc;
    logic [31:0] snapshot_if_id_instruction;


    // ID / EX

    logic        snapshot_id_ex_valid;

    logic [31:0] snapshot_id_ex_pc;
    logic [31:0] snapshot_id_ex_read_data1;
    logic [31:0] snapshot_id_ex_read_data2;
    logic [31:0] snapshot_id_ex_immediate;

    logic [4:0] snapshot_id_ex_rs1;
    logic [4:0] snapshot_id_ex_rs2;
    logic [4:0] snapshot_id_ex_rd;

    logic [6:0] snapshot_id_ex_opcode;
    logic [2:0] snapshot_id_ex_funct3;
    logic [6:0] snapshot_id_ex_funct7;

    logic [15:0] snapshot_id_ex_control;


    // EX / MEM

    logic        snapshot_ex_mem_valid;

    logic [31:0] snapshot_ex_mem_pc;
    logic [31:0] snapshot_ex_mem_alu_result;
    logic [31:0] snapshot_ex_mem_store_data;

    logic [4:0] snapshot_ex_mem_rs2;
    logic [4:0] snapshot_ex_mem_rd;

    logic [6:0] snapshot_ex_mem_opcode;
    logic [2:0] snapshot_ex_mem_funct3;

    logic [7:0] snapshot_ex_mem_control;


    // MEM / WB

    logic        snapshot_mem_wb_valid;

    logic [31:0] snapshot_mem_wb_pc;
    logic [31:0] snapshot_mem_wb_alu_result;
    logic [31:0] snapshot_mem_wb_load_data;

    logic [4:0] snapshot_mem_wb_rd;
    logic [6:0] snapshot_mem_wb_opcode;

    logic [7:0] snapshot_mem_wb_control;


    // =========================================================
    // FSM DE TRANSMISIÓN DEL SNAPSHOT
    // =========================================================

    typedef enum logic [3:0] {

        STATE_IDLE,

        STATE_HEADER,

        STATE_REGISTER_HEADER,
        STATE_REGISTERS,

        STATE_IF_ID,
        STATE_ID_EX,
        STATE_EX_MEM,
        STATE_MEM_WB,

        STATE_MEMORY_HEADER,
        STATE_MEMORY_SCAN,
        STATE_MEMORY_ENTRY,

        STATE_END

    } debug_state_t;


    debug_state_t state;


    logic [5:0] byte_index;

    logic [4:0] register_index;

    logic [MEM_SCAN_WIDTH-1:0]
        memory_scan_index;


    // =========================================================
    // DIRECCIONES DE LECTURA DEBUG
    // =========================================================

    always_comb begin

        debug_register_address = register_index;

        debug_memory_address =
            32'd4 * memory_scan_index;

    end


    // =========================================================
    // STREAM VALID
    // =========================================================

    always_comb begin

        snapshot_byte_valid = 1'b0;

        case (state)

            STATE_HEADER,
            STATE_REGISTER_HEADER,
            STATE_REGISTERS,
            STATE_IF_ID,
            STATE_ID_EX,
            STATE_EX_MEM,
            STATE_MEM_WB,
            STATE_MEMORY_HEADER,
            STATE_MEMORY_ENTRY,
            STATE_END:
                snapshot_byte_valid = 1'b1;

            default:
                snapshot_byte_valid = 1'b0;

        endcase

    end


    // =========================================================
    // DATO ACTUAL DEL STREAM
    // =========================================================

    always_comb begin

        snapshot_byte_data = 8'd0;

        case (state)

            // =================================================
            // HEADER
            //
            // 0  'd'
            // 1  version
            // 2  status
            // 3  flags
            // 4..7 IF PC
            // =================================================

            STATE_HEADER: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            SNAPSHOT_TAG;

                    1:
                        snapshot_byte_data =
                            SNAPSHOT_VERSION;

                    2:
                        snapshot_byte_data =
                            snapshot_status;

                    3:
                        snapshot_byte_data =
                            snapshot_flags;

                    4:
                        snapshot_byte_data =
                            snapshot_if_pc[31:24];

                    5:
                        snapshot_byte_data =
                            snapshot_if_pc[23:16];

                    6:
                        snapshot_byte_data =
                            snapshot_if_pc[15:8];

                    7:
                        snapshot_byte_data =
                            snapshot_if_pc[7:0];

                    default:
                        snapshot_byte_data = 8'd0;

                endcase

            end


            // =================================================
            // REGISTER FILE HEADER
            //
            // 'R'
            // 32
            // =================================================

            STATE_REGISTER_HEADER: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            TAG_REGISTERS;

                    1:
                        snapshot_byte_data =
                            8'd32;

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // REGISTER FILE
            //
            // reg_number
            // data[31:24]
            // data[23:16]
            // data[15:8]
            // data[7:0]
            // =================================================

            STATE_REGISTERS: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            {3'd0, register_index};

                    1:
                        snapshot_byte_data =
                            debug_register_data[31:24];

                    2:
                        snapshot_byte_data =
                            debug_register_data[23:16];

                    3:
                        snapshot_byte_data =
                            debug_register_data[15:8];

                    4:
                        snapshot_byte_data =
                            debug_register_data[7:0];

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // IF / ID
            //
            // 'I'
            // valid
            // PC
            // instruction
            // =================================================

            STATE_IF_ID: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            TAG_IF_ID;

                    1:
                        snapshot_byte_data =
                            {7'd0, snapshot_if_id_valid};

                    2:
                        snapshot_byte_data =
                            snapshot_if_id_pc[31:24];

                    3:
                        snapshot_byte_data =
                            snapshot_if_id_pc[23:16];

                    4:
                        snapshot_byte_data =
                            snapshot_if_id_pc[15:8];

                    5:
                        snapshot_byte_data =
                            snapshot_if_id_pc[7:0];

                    6:
                        snapshot_byte_data =
                            snapshot_if_id_instruction[31:24];

                    7:
                        snapshot_byte_data =
                            snapshot_if_id_instruction[23:16];

                    8:
                        snapshot_byte_data =
                            snapshot_if_id_instruction[15:8];

                    9:
                        snapshot_byte_data =
                            snapshot_if_id_instruction[7:0];

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // ID / EX
            // =================================================

            STATE_ID_EX: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            TAG_ID_EX;

                    1:
                        snapshot_byte_data =
                            {7'd0, snapshot_id_ex_valid};

                    2:
                        snapshot_byte_data =
                            snapshot_id_ex_pc[31:24];

                    3:
                        snapshot_byte_data =
                            snapshot_id_ex_pc[23:16];

                    4:
                        snapshot_byte_data =
                            snapshot_id_ex_pc[15:8];

                    5:
                        snapshot_byte_data =
                            snapshot_id_ex_pc[7:0];

                    6:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data1[31:24];

                    7:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data1[23:16];

                    8:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data1[15:8];

                    9:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data1[7:0];

                    10:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data2[31:24];

                    11:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data2[23:16];

                    12:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data2[15:8];

                    13:
                        snapshot_byte_data =
                            snapshot_id_ex_read_data2[7:0];

                    14:
                        snapshot_byte_data =
                            snapshot_id_ex_immediate[31:24];

                    15:
                        snapshot_byte_data =
                            snapshot_id_ex_immediate[23:16];

                    16:
                        snapshot_byte_data =
                            snapshot_id_ex_immediate[15:8];

                    17:
                        snapshot_byte_data =
                            snapshot_id_ex_immediate[7:0];

                    18:
                        snapshot_byte_data =
                            {3'd0, snapshot_id_ex_rs1};

                    19:
                        snapshot_byte_data =
                            {3'd0, snapshot_id_ex_rs2};

                    20:
                        snapshot_byte_data =
                            {3'd0, snapshot_id_ex_rd};

                    21:
                        snapshot_byte_data =
                            {1'b0, snapshot_id_ex_opcode};

                    22:
                        snapshot_byte_data =
                            {5'd0, snapshot_id_ex_funct3};

                    23:
                        snapshot_byte_data =
                            {1'b0, snapshot_id_ex_funct7};

                    24:
                        snapshot_byte_data =
                            snapshot_id_ex_control[15:8];

                    25:
                        snapshot_byte_data =
                            snapshot_id_ex_control[7:0];

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // EX / MEM
            // =================================================

            STATE_EX_MEM: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            TAG_EX_MEM;

                    1:
                        snapshot_byte_data =
                            {7'd0, snapshot_ex_mem_valid};

                    2:
                        snapshot_byte_data =
                            snapshot_ex_mem_pc[31:24];

                    3:
                        snapshot_byte_data =
                            snapshot_ex_mem_pc[23:16];

                    4:
                        snapshot_byte_data =
                            snapshot_ex_mem_pc[15:8];

                    5:
                        snapshot_byte_data =
                            snapshot_ex_mem_pc[7:0];

                    6:
                        snapshot_byte_data =
                            snapshot_ex_mem_alu_result[31:24];

                    7:
                        snapshot_byte_data =
                            snapshot_ex_mem_alu_result[23:16];

                    8:
                        snapshot_byte_data =
                            snapshot_ex_mem_alu_result[15:8];

                    9:
                        snapshot_byte_data =
                            snapshot_ex_mem_alu_result[7:0];

                    10:
                        snapshot_byte_data =
                            snapshot_ex_mem_store_data[31:24];

                    11:
                        snapshot_byte_data =
                            snapshot_ex_mem_store_data[23:16];

                    12:
                        snapshot_byte_data =
                            snapshot_ex_mem_store_data[15:8];

                    13:
                        snapshot_byte_data =
                            snapshot_ex_mem_store_data[7:0];

                    14:
                        snapshot_byte_data =
                            {3'd0, snapshot_ex_mem_rs2};

                    15:
                        snapshot_byte_data =
                            {3'd0, snapshot_ex_mem_rd};

                    16:
                        snapshot_byte_data =
                            {1'b0, snapshot_ex_mem_opcode};

                    17:
                        snapshot_byte_data =
                            {5'd0, snapshot_ex_mem_funct3};

                    18:
                        snapshot_byte_data =
                            snapshot_ex_mem_control;

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // MEM / WB
            // =================================================

            STATE_MEM_WB: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            TAG_MEM_WB;

                    1:
                        snapshot_byte_data =
                            {7'd0, snapshot_mem_wb_valid};

                    2:
                        snapshot_byte_data =
                            snapshot_mem_wb_pc[31:24];

                    3:
                        snapshot_byte_data =
                            snapshot_mem_wb_pc[23:16];

                    4:
                        snapshot_byte_data =
                            snapshot_mem_wb_pc[15:8];

                    5:
                        snapshot_byte_data =
                            snapshot_mem_wb_pc[7:0];

                    6:
                        snapshot_byte_data =
                            snapshot_mem_wb_alu_result[31:24];

                    7:
                        snapshot_byte_data =
                            snapshot_mem_wb_alu_result[23:16];

                    8:
                        snapshot_byte_data =
                            snapshot_mem_wb_alu_result[15:8];

                    9:
                        snapshot_byte_data =
                            snapshot_mem_wb_alu_result[7:0];

                    10:
                        snapshot_byte_data =
                            snapshot_mem_wb_load_data[31:24];

                    11:
                        snapshot_byte_data =
                            snapshot_mem_wb_load_data[23:16];

                    12:
                        snapshot_byte_data =
                            snapshot_mem_wb_load_data[15:8];

                    13:
                        snapshot_byte_data =
                            snapshot_mem_wb_load_data[7:0];

                    14:
                        snapshot_byte_data =
                            {3'd0, snapshot_mem_wb_rd};

                    15:
                        snapshot_byte_data =
                            {1'b0, snapshot_mem_wb_opcode};

                    16:
                        snapshot_byte_data =
                            snapshot_mem_wb_control;

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // DATA MEMORY HEADER
            //
            // 'M'
            // used_count[15:8]
            // used_count[7:0]
            // =================================================

            STATE_MEMORY_HEADER: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            TAG_MEMORY;

                    1:
                        snapshot_byte_data =
                            snapshot_memory_count[15:8];

                    2:
                        snapshot_byte_data =
                            snapshot_memory_count[7:0];

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            // =================================================
            // DATA MEMORY ENTRY
            //
            // address[15:8]
            // address[7:0]
            // data[31:24]
            // data[23:16]
            // data[15:8]
            // data[7:0]
            // =================================================

            STATE_MEMORY_ENTRY: begin

                case (byte_index)

                    0:
                        snapshot_byte_data =
                            debug_memory_address[15:8];

                    1:
                        snapshot_byte_data =
                            debug_memory_address[7:0];

                    2:
                        snapshot_byte_data =
                            debug_memory_data[31:24];

                    3:
                        snapshot_byte_data =
                            debug_memory_data[23:16];

                    4:
                        snapshot_byte_data =
                            debug_memory_data[15:8];

                    5:
                        snapshot_byte_data =
                            debug_memory_data[7:0];

                    default:
                        snapshot_byte_data =
                            8'd0;

                endcase

            end


            STATE_END: begin

                snapshot_byte_data =
                    TAG_END;

            end


            default: begin

                snapshot_byte_data =
                    8'd0;

            end

        endcase

    end


    // =========================================================
    // FSM SECUENCIAL
    // =========================================================

    always_ff @(posedge clk) begin

        if (reset) begin

            state <= STATE_IDLE;

            snapshot_busy <= 1'b0;
            snapshot_done <= 1'b0;

            byte_index <= 6'd0;

            register_index <= 5'd0;

            memory_scan_index <= '0;

            snapshot_status <= 8'd0;
            snapshot_flags  <= 8'd0;

            snapshot_if_pc <= 32'd0;

            snapshot_if_id_valid       <= 1'b0;
            snapshot_if_id_pc          <= 32'd0;
            snapshot_if_id_instruction <= 32'd0;

            snapshot_id_ex_valid      <= 1'b0;
            snapshot_id_ex_pc         <= 32'd0;
            snapshot_id_ex_read_data1 <= 32'd0;
            snapshot_id_ex_read_data2 <= 32'd0;
            snapshot_id_ex_immediate  <= 32'd0;

            snapshot_id_ex_rs1 <= 5'd0;
            snapshot_id_ex_rs2 <= 5'd0;
            snapshot_id_ex_rd  <= 5'd0;

            snapshot_id_ex_opcode <= 7'd0;
            snapshot_id_ex_funct3 <= 3'd0;
            snapshot_id_ex_funct7 <= 7'd0;

            snapshot_id_ex_control <= 16'd0;

            snapshot_ex_mem_valid      <= 1'b0;
            snapshot_ex_mem_pc         <= 32'd0;
            snapshot_ex_mem_alu_result <= 32'd0;
            snapshot_ex_mem_store_data <= 32'd0;

            snapshot_ex_mem_rs2 <= 5'd0;
            snapshot_ex_mem_rd  <= 5'd0;

            snapshot_ex_mem_opcode <= 7'd0;
            snapshot_ex_mem_funct3 <= 3'd0;

            snapshot_ex_mem_control <= 8'd0;

            snapshot_mem_wb_valid      <= 1'b0;
            snapshot_mem_wb_pc         <= 32'd0;
            snapshot_mem_wb_alu_result <= 32'd0;
            snapshot_mem_wb_load_data  <= 32'd0;

            snapshot_mem_wb_rd     <= 5'd0;
            snapshot_mem_wb_opcode <= 7'd0;

            snapshot_mem_wb_control <= 8'd0;

            snapshot_memory_bitmap <= '0;
            snapshot_memory_count  <= 16'd0;

        end
        else begin

            // Pulso de un ciclo.
            snapshot_done <= 1'b0;


            // =================================================
            // INICIAR SNAPSHOT
            // =================================================

            if (
                snapshot_start &&
                !snapshot_busy
            ) begin

                snapshot_busy <= 1'b1;

                state      <= STATE_HEADER;
                byte_index <= 6'd0;

                register_index   <= 5'd0;
                memory_scan_index <= '0;


                // ---------------------------------------------
                // Estado general.
                // ---------------------------------------------

                snapshot_status <=
                    {5'd0, status_code};

                snapshot_flags <= {
                    3'd0,
                    core_cycle_enable,
                    core_pipeline_empty,
                    core_halted,
                    core_draining,
                    core_running
                };


                // ---------------------------------------------
                // IF.
                // ---------------------------------------------

                snapshot_if_pc <=
                    if_pc_current;


                // ---------------------------------------------
                // IF / ID.
                // ---------------------------------------------

                snapshot_if_id_valid <=
                    if_id_valid;

                snapshot_if_id_pc <=
                    if_id_pc;

                snapshot_if_id_instruction <=
                    if_id_instruction;


                // ---------------------------------------------
                // ID / EX.
                // ---------------------------------------------

                snapshot_id_ex_valid <=
                    id_ex_valid;

                snapshot_id_ex_pc <=
                    id_ex_pc;

                snapshot_id_ex_read_data1 <=
                    id_ex_read_data1;

                snapshot_id_ex_read_data2 <=
                    id_ex_read_data2;

                snapshot_id_ex_immediate <=
                    id_ex_immediate;

                snapshot_id_ex_rs1 <=
                    id_ex_rs1;

                snapshot_id_ex_rs2 <=
                    id_ex_rs2;

                snapshot_id_ex_rd <=
                    id_ex_rd;

                snapshot_id_ex_opcode <=
                    id_ex_opcode;

                snapshot_id_ex_funct3 <=
                    id_ex_funct3;

                snapshot_id_ex_funct7 <=
                    id_ex_funct7;


                snapshot_id_ex_control <= {
                    3'd0,
                    id_ex_wb_sel,
                    id_ex_reg_write,
                    id_ex_mem_write,
                    id_ex_mem_read,
                    id_ex_jump_type,
                    id_ex_branch,
                    id_ex_alu_op,
                    id_ex_alu_src_b,
                    id_ex_alu_src_a
                };


                // ---------------------------------------------
                // EX / MEM.
                // ---------------------------------------------

                snapshot_ex_mem_valid <=
                    ex_mem_valid;

                snapshot_ex_mem_pc <=
                    ex_mem_pc;

                snapshot_ex_mem_alu_result <=
                    ex_mem_alu_result;

                snapshot_ex_mem_store_data <=
                    ex_mem_store_data;

                snapshot_ex_mem_rs2 <=
                    ex_mem_rs2;

                snapshot_ex_mem_rd <=
                    ex_mem_rd;

                snapshot_ex_mem_opcode <=
                    ex_mem_opcode;

                snapshot_ex_mem_funct3 <=
                    ex_mem_funct3;


                snapshot_ex_mem_control <= {
                    3'd0,
                    ex_mem_wb_sel,
                    ex_mem_reg_write,
                    ex_mem_mem_write,
                    ex_mem_mem_read
                };


                // ---------------------------------------------
                // MEM / WB.
                // ---------------------------------------------

                snapshot_mem_wb_valid <=
                    mem_wb_valid;

                snapshot_mem_wb_pc <=
                    mem_wb_pc;

                snapshot_mem_wb_alu_result <=
                    mem_wb_alu_result;

                snapshot_mem_wb_load_data <=
                    mem_wb_load_data;

                snapshot_mem_wb_rd <=
                    mem_wb_rd;

                snapshot_mem_wb_opcode <=
                    mem_wb_opcode;


                snapshot_mem_wb_control <= {
                    5'd0,
                    mem_wb_wb_sel,
                    mem_wb_reg_write
                };


                // ---------------------------------------------
                // Congelar mapa de memoria utilizada.
                // ---------------------------------------------

                snapshot_memory_bitmap <=
                    used_memory_bitmap;

                snapshot_memory_count <=
                    used_memory_count_reg;

            end


            // =================================================
            // SNAPSHOT ACTIVO
            // =================================================

            else if (snapshot_busy) begin

                case (state)

                    // =========================================
                    // HEADER
                    // =========================================

                    STATE_HEADER: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd7) begin

                                byte_index <= 6'd0;

                                state <=
                                    STATE_REGISTER_HEADER;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // REGISTER HEADER
                    // =========================================

                    STATE_REGISTER_HEADER: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd1) begin

                                byte_index <= 6'd0;

                                register_index <=
                                    5'd0;

                                state <=
                                    STATE_REGISTERS;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // REGISTER FILE
                    // =========================================

                    STATE_REGISTERS: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd4) begin

                                byte_index <= 6'd0;

                                if (
                                    register_index ==
                                    5'd31
                                ) begin

                                    state <=
                                        STATE_IF_ID;

                                end
                                else begin

                                    register_index <=
                                        register_index + 5'd1;

                                end

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // IF / ID
                    // =========================================

                    STATE_IF_ID: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd9) begin

                                byte_index <= 6'd0;

                                state <=
                                    STATE_ID_EX;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // ID / EX
                    // =========================================

                    STATE_ID_EX: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd25) begin

                                byte_index <= 6'd0;

                                state <=
                                    STATE_EX_MEM;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // EX / MEM
                    // =========================================

                    STATE_EX_MEM: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd18) begin

                                byte_index <= 6'd0;

                                state <=
                                    STATE_MEM_WB;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // MEM / WB
                    // =========================================

                    STATE_MEM_WB: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd16) begin

                                byte_index <= 6'd0;

                                state <=
                                    STATE_MEMORY_HEADER;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // MEMORY HEADER
                    // =========================================

                    STATE_MEMORY_HEADER: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd2) begin

                                byte_index <= 6'd0;

                                memory_scan_index <=
                                    '0;

                                if (
                                    snapshot_memory_count ==
                                    16'd0
                                ) begin

                                    state <= STATE_END;

                                end
                                else begin

                                    state <=
                                        STATE_MEMORY_SCAN;

                                end

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // BUSCAR PRÓXIMA POSICIÓN UTILIZADA
                    // =========================================

                    STATE_MEMORY_SCAN: begin

                        if (
                            memory_scan_index >=
                            DATA_MEM_DEPTH
                        ) begin

                            state <= STATE_END;

                        end
                        else if (
                            snapshot_memory_bitmap[
                                memory_scan_index
                            ]
                        ) begin

                            byte_index <= 6'd0;

                            state <=
                                STATE_MEMORY_ENTRY;

                        end
                        else begin

                            memory_scan_index <=
                                memory_scan_index + 1'b1;

                        end

                    end


                    // =========================================
                    // ENVIAR POSICIÓN DE MEMORIA
                    // =========================================

                    STATE_MEMORY_ENTRY: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            if (byte_index == 6'd5) begin

                                byte_index <= 6'd0;

                                memory_scan_index <=
                                    memory_scan_index + 1'b1;

                                state <=
                                    STATE_MEMORY_SCAN;

                            end
                            else begin

                                byte_index <=
                                    byte_index + 6'd1;

                            end

                        end

                    end


                    // =========================================
                    // FIN DEL SNAPSHOT
                    // =========================================

                    STATE_END: begin

                        if (
                            snapshot_byte_valid &&
                            snapshot_byte_ready
                        ) begin

                            snapshot_busy <= 1'b0;
                            snapshot_done <= 1'b1;

                            state <= STATE_IDLE;

                        end

                    end


                    default: begin

                        snapshot_busy <= 1'b0;

                        state <= STATE_IDLE;

                    end

                endcase

            end

        end

    end

endmodule
