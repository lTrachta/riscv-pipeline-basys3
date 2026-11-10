`timescale 1ns / 1ps

module processor_system #(
    parameter integer CLK_FREQ       = 100_000_000,
    parameter integer BAUD_RATE      = 115_200,
    parameter integer OVERSAMPLING   = 16,
    parameter integer IMEM_DEPTH     = 256,
    parameter integer DATA_MEM_DEPTH = 256
) (
    input  logic clk,
    input  logic reset,

    input  logic uart_rx,
    output logic uart_tx,

    output logic [2:0] status_code,
    output logic       program_loaded,

    output logic core_running,
    output logic core_draining,
    output logic core_halted,
    output logic core_pipeline_empty,

    output logic uart_rx_frame_error
);


    // =========================================================
    // BAUD GENERATOR
    // =========================================================

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


    // =========================================================
    // UART RX
    // =========================================================

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


    // =========================================================
    // PROGRAM LOADER
    // =========================================================

    logic       loader_rx_byte_valid;
    logic [7:0] loader_rx_byte_data;

    logic load_active;
    logic load_done;
    logic load_error;

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


    // =========================================================
    // CORE CONTROL
    // =========================================================

    logic core_cycle_enable;

    logic controller_core_reset;
    logic core_reset_combined;


    assign core_reset_combined =
        reset |
        controller_core_reset;


    // =========================================================
    // DEBUG RF ADDRESS ARBITRATION
    //
    // G utiliza controller_debug_register_address.
    //
    // D utiliza snapshot_debug_register_address.
    // =========================================================

    logic [4:0]
        controller_debug_register_address;

    logic [4:0]
        snapshot_debug_register_address;

    logic [4:0]
        core_debug_register_address;

    logic [31:0]
        debug_register_data;


    // =========================================================
    // DEBUG DMEM ADDRESS ARBITRATION
    // =========================================================

    logic [31:0]
        controller_debug_memory_address;

    logic [31:0]
        snapshot_debug_memory_address;

    logic [31:0]
        core_debug_memory_address;

    logic [31:0]
        debug_memory_data;


    // =========================================================
    // SNAPSHOT CONTROL
    // =========================================================

    logic snapshot_start;
    logic snapshot_busy;
    logic snapshot_done;

    logic       snapshot_byte_valid;
    logic [7:0] snapshot_byte_data;
    logic       snapshot_byte_ready;

    logic [15:0] used_memory_count;


    // Durante un snapshot, Debug Unit posee los puertos
    // combinacionales de lectura.

    assign core_debug_register_address =
        snapshot_busy
        ? snapshot_debug_register_address
        : controller_debug_register_address;


    assign core_debug_memory_address =
        snapshot_busy
        ? snapshot_debug_memory_address
        : controller_debug_memory_address;


    // =========================================================
    // PIPELINE OBSERVATION WIRES
    // =========================================================

    logic [31:0] debug_if_pc_current;


    // IF / ID

    logic        debug_if_id_valid;
    logic [31:0] debug_if_id_pc;
    logic [31:0] debug_if_id_instruction;


    // ID / EX

    logic        debug_id_ex_valid;

    logic [31:0] debug_id_ex_pc;
    logic [31:0] debug_id_ex_read_data1;
    logic [31:0] debug_id_ex_read_data2;
    logic [31:0] debug_id_ex_immediate;

    logic [4:0] debug_id_ex_rs1;
    logic [4:0] debug_id_ex_rs2;
    logic [4:0] debug_id_ex_rd;

    logic [6:0] debug_id_ex_opcode;
    logic [2:0] debug_id_ex_funct3;
    logic [6:0] debug_id_ex_funct7;

    logic       debug_id_ex_alu_src_a;
    logic       debug_id_ex_alu_src_b;
    logic [2:0] debug_id_ex_alu_op;

    logic       debug_id_ex_branch;
    logic [1:0] debug_id_ex_jump_type;

    logic debug_id_ex_mem_read;
    logic debug_id_ex_mem_write;

    logic       debug_id_ex_reg_write;
    logic [1:0] debug_id_ex_wb_sel;


    // EX / MEM

    logic        debug_ex_mem_valid;

    logic [31:0] debug_ex_mem_pc;
    logic [31:0] debug_ex_mem_alu_result;
    logic [31:0] debug_ex_mem_store_data;

    logic [4:0] debug_ex_mem_rs2;
    logic [4:0] debug_ex_mem_rd;

    logic [6:0] debug_ex_mem_opcode;
    logic [2:0] debug_ex_mem_funct3;

    logic debug_ex_mem_mem_read;
    logic debug_ex_mem_mem_write;

    logic       debug_ex_mem_reg_write;
    logic [1:0] debug_ex_mem_wb_sel;


    // MEM / WB

    logic        debug_mem_wb_valid;

    logic [31:0] debug_mem_wb_pc;
    logic [31:0] debug_mem_wb_alu_result;
    logic [31:0] debug_mem_wb_load_data;

    logic [4:0] debug_mem_wb_rd;
    logic [6:0] debug_mem_wb_opcode;

    logic       debug_mem_wb_reg_write;
    logic [1:0] debug_mem_wb_wb_sel;


    // DMEM usage monitor

    logic        debug_memory_access_valid;
    logic [31:0] debug_memory_access_address;


    // =========================================================
    // PIPELINE CORE
    // =========================================================

    pipeline_core pipeline_core_inst (
        .clk                    (clk),
        .reset                  (core_reset_combined),

        .cycle_enable           (core_cycle_enable),

        .program_write_enable   (imem_write_enable),
        .program_write_address  (imem_write_address),
        .program_write_data     (imem_write_data),

        .debug_register_address (
            core_debug_register_address
        ),

        .debug_register_data (
            debug_register_data
        ),

        .debug_memory_address (
            core_debug_memory_address
        ),

        .debug_memory_data (
            debug_memory_data
        ),


        // -----------------------------------------------------
        // IF
        // -----------------------------------------------------

        .debug_if_pc_current (
            debug_if_pc_current
        ),


        // -----------------------------------------------------
        // IF / ID
        // -----------------------------------------------------

        .debug_if_id_valid (
            debug_if_id_valid
        ),

        .debug_if_id_pc (
            debug_if_id_pc
        ),

        .debug_if_id_instruction (
            debug_if_id_instruction
        ),


        // -----------------------------------------------------
        // ID / EX
        // -----------------------------------------------------

        .debug_id_ex_valid (
            debug_id_ex_valid
        ),

        .debug_id_ex_pc (
            debug_id_ex_pc
        ),

        .debug_id_ex_read_data1 (
            debug_id_ex_read_data1
        ),

        .debug_id_ex_read_data2 (
            debug_id_ex_read_data2
        ),

        .debug_id_ex_immediate (
            debug_id_ex_immediate
        ),

        .debug_id_ex_rs1 (
            debug_id_ex_rs1
        ),

        .debug_id_ex_rs2 (
            debug_id_ex_rs2
        ),

        .debug_id_ex_rd (
            debug_id_ex_rd
        ),

        .debug_id_ex_opcode (
            debug_id_ex_opcode
        ),

        .debug_id_ex_funct3 (
            debug_id_ex_funct3
        ),

        .debug_id_ex_funct7 (
            debug_id_ex_funct7
        ),

        .debug_id_ex_alu_src_a (
            debug_id_ex_alu_src_a
        ),

        .debug_id_ex_alu_src_b (
            debug_id_ex_alu_src_b
        ),

        .debug_id_ex_alu_op (
            debug_id_ex_alu_op
        ),

        .debug_id_ex_branch (
            debug_id_ex_branch
        ),

        .debug_id_ex_jump_type (
            debug_id_ex_jump_type
        ),

        .debug_id_ex_mem_read (
            debug_id_ex_mem_read
        ),

        .debug_id_ex_mem_write (
            debug_id_ex_mem_write
        ),

        .debug_id_ex_reg_write (
            debug_id_ex_reg_write
        ),

        .debug_id_ex_wb_sel (
            debug_id_ex_wb_sel
        ),


        // -----------------------------------------------------
        // EX / MEM
        // -----------------------------------------------------

        .debug_ex_mem_valid (
            debug_ex_mem_valid
        ),

        .debug_ex_mem_pc (
            debug_ex_mem_pc
        ),

        .debug_ex_mem_alu_result (
            debug_ex_mem_alu_result
        ),

        .debug_ex_mem_store_data (
            debug_ex_mem_store_data
        ),

        .debug_ex_mem_rs2 (
            debug_ex_mem_rs2
        ),

        .debug_ex_mem_rd (
            debug_ex_mem_rd
        ),

        .debug_ex_mem_opcode (
            debug_ex_mem_opcode
        ),

        .debug_ex_mem_funct3 (
            debug_ex_mem_funct3
        ),

        .debug_ex_mem_mem_read (
            debug_ex_mem_mem_read
        ),

        .debug_ex_mem_mem_write (
            debug_ex_mem_mem_write
        ),

        .debug_ex_mem_reg_write (
            debug_ex_mem_reg_write
        ),

        .debug_ex_mem_wb_sel (
            debug_ex_mem_wb_sel
        ),


        // -----------------------------------------------------
        // MEM / WB
        // -----------------------------------------------------

        .debug_mem_wb_valid (
            debug_mem_wb_valid
        ),

        .debug_mem_wb_pc (
            debug_mem_wb_pc
        ),

        .debug_mem_wb_alu_result (
            debug_mem_wb_alu_result
        ),

        .debug_mem_wb_load_data (
            debug_mem_wb_load_data
        ),

        .debug_mem_wb_rd (
            debug_mem_wb_rd
        ),

        .debug_mem_wb_opcode (
            debug_mem_wb_opcode
        ),

        .debug_mem_wb_reg_write (
            debug_mem_wb_reg_write
        ),

        .debug_mem_wb_wb_sel (
            debug_mem_wb_wb_sel
        ),


        // -----------------------------------------------------
        // DMEM usage
        // -----------------------------------------------------

        .debug_memory_access_valid (
            debug_memory_access_valid
        ),

        .debug_memory_access_address (
            debug_memory_access_address
        ),


        // -----------------------------------------------------
        // Core state
        // -----------------------------------------------------

        .running (
            core_running
        ),

        .draining (
            core_draining
        ),

        .halted (
            core_halted
        ),

        .pipeline_empty (
            core_pipeline_empty
        )
    );


    // =========================================================
    // DEBUG UNIT
    // =========================================================

    debug_unit #(
        .DATA_MEM_DEPTH (
            DATA_MEM_DEPTH
        )
    ) debug_unit_inst (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .snapshot_start (
            snapshot_start
        ),

        .snapshot_busy (
            snapshot_busy
        ),

        .snapshot_done (
            snapshot_done
        ),

        .status_code (
            status_code
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

        .core_cycle_enable (
            core_cycle_enable
        ),

        .if_pc_current (
            debug_if_pc_current
        ),

        .if_id_valid (
            debug_if_id_valid
        ),

        .if_id_pc (
            debug_if_id_pc
        ),

        .if_id_instruction (
            debug_if_id_instruction
        ),

        .id_ex_valid (
            debug_id_ex_valid
        ),

        .id_ex_pc (
            debug_id_ex_pc
        ),

        .id_ex_read_data1 (
            debug_id_ex_read_data1
        ),

        .id_ex_read_data2 (
            debug_id_ex_read_data2
        ),

        .id_ex_immediate (
            debug_id_ex_immediate
        ),

        .id_ex_rs1 (
            debug_id_ex_rs1
        ),

        .id_ex_rs2 (
            debug_id_ex_rs2
        ),

        .id_ex_rd (
            debug_id_ex_rd
        ),

        .id_ex_opcode (
            debug_id_ex_opcode
        ),

        .id_ex_funct3 (
            debug_id_ex_funct3
        ),

        .id_ex_funct7 (
            debug_id_ex_funct7
        ),

        .id_ex_alu_src_a (
            debug_id_ex_alu_src_a
        ),

        .id_ex_alu_src_b (
            debug_id_ex_alu_src_b
        ),

        .id_ex_alu_op (
            debug_id_ex_alu_op
        ),

        .id_ex_branch (
            debug_id_ex_branch
        ),

        .id_ex_jump_type (
            debug_id_ex_jump_type
        ),

        .id_ex_mem_read (
            debug_id_ex_mem_read
        ),

        .id_ex_mem_write (
            debug_id_ex_mem_write
        ),

        .id_ex_reg_write (
            debug_id_ex_reg_write
        ),

        .id_ex_wb_sel (
            debug_id_ex_wb_sel
        ),

        .ex_mem_valid (
            debug_ex_mem_valid
        ),

        .ex_mem_pc (
            debug_ex_mem_pc
        ),

        .ex_mem_alu_result (
            debug_ex_mem_alu_result
        ),

        .ex_mem_store_data (
            debug_ex_mem_store_data
        ),

        .ex_mem_rs2 (
            debug_ex_mem_rs2
        ),

        .ex_mem_rd (
            debug_ex_mem_rd
        ),

        .ex_mem_opcode (
            debug_ex_mem_opcode
        ),

        .ex_mem_funct3 (
            debug_ex_mem_funct3
        ),

        .ex_mem_mem_read (
            debug_ex_mem_mem_read
        ),

        .ex_mem_mem_write (
            debug_ex_mem_mem_write
        ),

        .ex_mem_reg_write (
            debug_ex_mem_reg_write
        ),

        .ex_mem_wb_sel (
            debug_ex_mem_wb_sel
        ),

        .mem_wb_valid (
            debug_mem_wb_valid
        ),

        .mem_wb_pc (
            debug_mem_wb_pc
        ),

        .mem_wb_alu_result (
            debug_mem_wb_alu_result
        ),

        .mem_wb_load_data (
            debug_mem_wb_load_data
        ),

        .mem_wb_rd (
            debug_mem_wb_rd
        ),

        .mem_wb_opcode (
            debug_mem_wb_opcode
        ),

        .mem_wb_reg_write (
            debug_mem_wb_reg_write
        ),

        .mem_wb_wb_sel (
            debug_mem_wb_wb_sel
        ),

        .debug_register_address (
            snapshot_debug_register_address
        ),

        .debug_register_data (
            debug_register_data
        ),

        .debug_memory_address (
            snapshot_debug_memory_address
        ),

        .debug_memory_data (
            debug_memory_data
        ),

        .memory_access_valid (
            debug_memory_access_valid
        ),

        .memory_access_address (
            debug_memory_access_address
        ),

        // Cada nueva carga inicia una nueva sesión de memoria.
        .memory_usage_clear (
            controller_core_reset
        ),

        .used_memory_count (
            used_memory_count
        ),

        .snapshot_byte_valid (
            snapshot_byte_valid
        ),

        .snapshot_byte_data (
            snapshot_byte_data
        ),

        .snapshot_byte_ready (
            snapshot_byte_ready
        )
    );


    // =========================================================
    // PROTOCOL CONTROLLER
    // =========================================================

    logic       tx_byte_valid;
    logic [7:0] tx_byte_data;
    logic       tx_byte_ready;


    system_protocol_controller #(
        .DATA_MEM_DEPTH (
            DATA_MEM_DEPTH
        )
    ) protocol_controller_inst (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .rx_byte_valid (
            rx_byte_valid
        ),

        .rx_byte_data (
            rx_byte_data
        ),

        .loader_rx_byte_valid (
            loader_rx_byte_valid
        ),

        .loader_rx_byte_data (
            loader_rx_byte_data
        ),

        .load_active (
            load_active
        ),

        .load_done (
            load_done
        ),

        .load_error (
            load_error
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

        .core_cycle_enable (
            core_cycle_enable
        ),

        .core_reset (
            controller_core_reset
        ),

        .debug_register_address (
            controller_debug_register_address
        ),

        .debug_register_data (
            debug_register_data
        ),

        .debug_memory_address (
            controller_debug_memory_address
        ),

        .debug_memory_data (
            debug_memory_data
        ),

        .snapshot_start (
            snapshot_start
        ),

        .snapshot_busy (
            snapshot_busy
        ),

        .snapshot_done (
            snapshot_done
        ),

        .snapshot_byte_valid (
            snapshot_byte_valid
        ),

        .snapshot_byte_data (
            snapshot_byte_data
        ),

        .snapshot_byte_ready (
            snapshot_byte_ready
        ),

        .tx_byte_valid (
            tx_byte_valid
        ),

        .tx_byte_data (
            tx_byte_data
        ),

        .tx_byte_ready (
            tx_byte_ready
        ),

        .status_code (
            status_code
        ),

        .program_loaded (
            program_loaded
        )
    );


    // =========================================================
    // UART TX
    // =========================================================

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
        .OVERSAMPLING (
            OVERSAMPLING
        )
    ) uart_tx_inst (
        .clk (
            clk
        ),

        .reset (
            reset
        ),

        .baud_tick (
            baud_tick
        ),

        .tx_start (
            uart_tx_start
        ),

        .tx_data (
            tx_byte_data
        ),

        .tx (
            uart_tx
        ),

        .tx_busy (
            uart_tx_busy
        ),

        .tx_done (
            uart_tx_done
        )
    );

endmodule
