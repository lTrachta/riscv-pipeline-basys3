`timescale 1ns / 1ps

module pipeline_core (
    input  logic clk,
    input  logic reset,

    input  logic cycle_enable,

    // =========================================================
    // PUERTO DE PROGRAMACIÓN DE INSTRUCTION MEMORY
    //
    // Este puerto NO es UART.
    //
    // Program Loader transforma los bytes recibidos en estas
    // tres señales.
    // =========================================================

    input  logic        program_write_enable,
    input  logic [31:0] program_write_address,
    input  logic [31:0] program_write_data,

    input  logic [4:0]  debug_register_address,
    output logic [31:0] debug_register_data,

    input  logic [31:0] debug_memory_address,
    output logic [31:0] debug_memory_data,

    // =========================================================
    // OBSERVACIÓN PARA DEBUG UNIT
    //
    // Todas estas señales son solamente de salida.
    // La Debug Unit puede observar el pipeline pero no modificarlo.
    // =========================================================

    // IF

    output logic [31:0] debug_if_pc_current,


    // IF / ID

    output logic        debug_if_id_valid,
    output logic [31:0] debug_if_id_pc,
    output logic [31:0] debug_if_id_instruction,


    // ID / EX

    output logic        debug_id_ex_valid,

    output logic [31:0] debug_id_ex_pc,
    output logic [31:0] debug_id_ex_read_data1,
    output logic [31:0] debug_id_ex_read_data2,
    output logic [31:0] debug_id_ex_immediate,

    output logic [4:0]  debug_id_ex_rs1,
    output logic [4:0]  debug_id_ex_rs2,
    output logic [4:0]  debug_id_ex_rd,

    output logic [6:0]  debug_id_ex_opcode,
    output logic [2:0]  debug_id_ex_funct3,
    output logic [6:0]  debug_id_ex_funct7,

    output logic        debug_id_ex_alu_src_a,
    output logic        debug_id_ex_alu_src_b,
    output logic [2:0]  debug_id_ex_alu_op,

    output logic        debug_id_ex_branch,
    output logic [1:0]  debug_id_ex_jump_type,

    output logic        debug_id_ex_mem_read,
    output logic        debug_id_ex_mem_write,

    output logic        debug_id_ex_reg_write,
    output logic [1:0]  debug_id_ex_wb_sel,


    // EX / MEM

    output logic        debug_ex_mem_valid,

    output logic [31:0] debug_ex_mem_pc,
    output logic [31:0] debug_ex_mem_alu_result,
    output logic [31:0] debug_ex_mem_store_data,

    output logic [4:0]  debug_ex_mem_rs2,
    output logic [4:0]  debug_ex_mem_rd,

    output logic [6:0]  debug_ex_mem_opcode,
    output logic [2:0]  debug_ex_mem_funct3,

    output logic        debug_ex_mem_mem_read,
    output logic        debug_ex_mem_mem_write,

    output logic        debug_ex_mem_reg_write,
    output logic [1:0]  debug_ex_mem_wb_sel,


    // MEM / WB

    output logic        debug_mem_wb_valid,

    output logic [31:0] debug_mem_wb_pc,
    output logic [31:0] debug_mem_wb_alu_result,
    output logic [31:0] debug_mem_wb_load_data,

    output logic [4:0]  debug_mem_wb_rd,
    output logic [6:0]  debug_mem_wb_opcode,

    output logic        debug_mem_wb_reg_write,
    output logic [1:0]  debug_mem_wb_wb_sel,


    // Acceso real a Data Memory.

    output logic        debug_memory_access_valid,
    output logic [31:0] debug_memory_access_address,

    output logic running,
    output logic draining,
    output logic halted,
    output logic pipeline_empty
);

    // =========================================================
    // CONTROL GENERAL DEL PIPELINE
    //
    // Actualmente:
    //
    // - existe detección automática de load-use hazards;
    // - PC e IF/ID pueden congelarse por stall;
    // - ID/EX puede recibir una burbuja;
    // - forwarding de datos está implementado;
    // - todavía no hay redirects reales;
    // - todavía no hay flushes por hazards de control.
    // =========================================================

    logic if_enable;
    logic id_enable;
    logic ex_enable;
    logic mem_enable;

    logic flush_if_id;
    logic flush_id_ex;
    logic flush_ex_mem;
    logic flush_mem_wb;

    logic        redirect_valid;
    logic [31:0] redirect_target;

    logic load_use_stall;

    // =========================================================
    // HALT / EXECUTION CONTROL
    // =========================================================

    logic halt_in_id;
    logic halt_accept;


    // =========================================================
    // CONTROL DE STALL LOAD-USE
    //
    // Si hay hazard:
    //
    // PC / IF-ID -> HOLD
    // ID/EX      -> BUBBLE
    //
    // EX/MEM y MEM/WB continúan normalmente.
    // =========================================================

    // =========================================================
    // CONTROL GLOBAL DE STALL + REDIRECT
    //
    // LOAD-USE:
    //
    //      PC      HOLD
    //      IF/ID   HOLD
    //      ID/EX   BUBBLE
    //
    // REDIRECT:
    //
    //      PC      <- redirect_target
    //      IF/ID   BUBBLE
    //      ID/EX   BUBBLE
    //
    // EX/MEM NO se flushea porque contiene la propia
    // instrucción branch/jump que produjo el redirect.
    // =========================================================

    // =========================================================
    // CONTROL GLOBAL
    //
    // RUNNING:
    //      funcionamiento normal.
    //
    // DRAINING:
    //      no entra ninguna instrucción nueva;
    //      las instrucciones anteriores siguen avanzando.
    //
    // HALTED:
    //      pipeline vacío y ejecución finalizada.
    // =========================================================


    // ---------------------------------------------------------
    // IF
    //
    // Durante RUNNING puede avanzar salvo:
    //
    // - load-use stall;
    // - aceptación del HALT.
    //
    // halt_accept se incluye para evitar avanzar el PC en el
    // mismo ciclo en que aceptamos la parada.
    // ---------------------------------------------------------

    assign if_enable =
        cycle_enable &&
        running &&
        !load_use_stall &&
        !halt_accept;


    // ---------------------------------------------------------
    // ETAPAS POSTERIORES
    //
    // Durante DRAINING deben seguir avanzando.
    //
    // Recién una vez HALTED se congelan.
    // ---------------------------------------------------------

    assign id_enable  = cycle_enable && !halted;
    assign ex_enable  = cycle_enable && !halted;
    assign mem_enable = cycle_enable && !halted;


    // ---------------------------------------------------------
    // IF/ID FLUSH
    //
    // Dos situaciones invalidan la instrucción joven:
    //
    // 1. redirect;
    // 2. HALT aceptado.
    // ---------------------------------------------------------

    assign flush_if_id =
        redirect_valid |
        halt_accept;


    // ---------------------------------------------------------
    // ID/EX FLUSH
    //
    // Puede aparecer una burbuja por:
    //
    // - load-use stall;
    // - redirect;
    // - HALT aceptado.
    //
    // En el último caso evitamos que HALT ingrese a EX.
    // ---------------------------------------------------------

    assign flush_id_ex =
        load_use_stall |
        redirect_valid |
        halt_accept;


    // La instrucción actualmente en EX es más vieja que HALT
    // y debe poder terminar.
    assign flush_ex_mem = 1'b0;

    // MEM/WB también debe poder drenarse normalmente.
    assign flush_mem_wb = 1'b0;


    // =========================================================
    // IF / ID
    // =========================================================

    logic [31:0] if_pc_current;

    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;


    if_stage if_stage_inst (
        .clk               (clk),
        .reset             (reset),

        .program_write_enable  (program_write_enable),
        .program_write_address (program_write_address),
        .program_write_data    (program_write_data),

        .if_enable         (if_enable),

        .redirect_valid    (redirect_valid),
        .redirect_pc       (redirect_target),

        .flush_if_id       (flush_if_id),

        .pc_current        (if_pc_current),

        .if_id_pc          (if_id_pc),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid)
    );


    // =========================================================
    // ID / EX DATAPATH
    // =========================================================

    logic [31:0] id_ex_pc;

    logic [31:0] id_ex_read_data1;
    logic [31:0] id_ex_read_data2;

    logic [31:0] id_ex_immediate;

    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;
    logic [4:0] id_ex_rd;

    logic [6:0] id_ex_opcode;
    logic [2:0] id_ex_funct3;
    logic [6:0] id_ex_funct7;

    logic id_ex_valid;


    // =========================================================
    // ID / EX CONTROL
    //
    // Generado por Control Unit en ID.
    //
    // ID/EX contiene:
    //
    // - control EX
    // - control MEM
    // - control WB
    // =========================================================

    // EX control

    logic       id_ex_alu_src_a;
    logic       id_ex_alu_src_b;
    logic [2:0] id_ex_alu_op;

    logic       id_ex_branch;
    logic [1:0] id_ex_jump_type;

    // MEM control

    logic id_ex_mem_read;
    logic id_ex_mem_write;

    // WB control

    logic       id_ex_reg_write;
    logic [1:0] id_ex_wb_sel;


    // =========================================================
    // WB -> REGISTER FILE
    //
    // Estas mismas señales también se reutilizan para:
    //
    // - forwarding MEM/WB -> EX;
    // - bypass WB -> ID dentro del Register File;
    // - forwarding WB -> store-data en MEM.
    // =========================================================

    logic        wb_write_enable_raw;
    logic        wb_write_enable;
    logic [4:0]  wb_write_register;
    logic [31:0] wb_write_data;

    assign wb_write_enable =
        wb_write_enable_raw &&
        cycle_enable;


    // =========================================================
    // ID STAGE
    //
    // Control Unit se encuentra dentro de id_stage.
    //
    // La instrucción se decodifica una vez en ID y sus señales
    // de control quedan capturadas junto con los datos en ID/EX.
    // =========================================================

    id_stage id_stage_inst (
        .clk                 (clk),
        .reset               (reset),

        .id_enable           (id_enable),
        .flush_id_ex         (flush_id_ex),

        .if_id_pc            (if_id_pc),
        .if_id_instruction   (if_id_instruction),
        .if_id_valid         (if_id_valid),

        .wb_write_enable     (wb_write_enable),
        .wb_write_register   (wb_write_register),
        .wb_write_data       (wb_write_data),

        .debug_register_address (debug_register_address),
        .debug_register_data    (debug_register_data),

        // -----------------------------------------------------
        // Datapath
        // -----------------------------------------------------

        .id_ex_pc            (id_ex_pc),

        .id_ex_read_data1    (id_ex_read_data1),
        .id_ex_read_data2    (id_ex_read_data2),

        .id_ex_immediate     (id_ex_immediate),

        .id_ex_rs1           (id_ex_rs1),
        .id_ex_rs2           (id_ex_rs2),
        .id_ex_rd            (id_ex_rd),

        .id_ex_opcode        (id_ex_opcode),
        .id_ex_funct3        (id_ex_funct3),
        .id_ex_funct7        (id_ex_funct7),

        .id_ex_valid         (id_ex_valid),

        // -----------------------------------------------------
        // EX control
        // -----------------------------------------------------

        .id_ex_alu_src_a     (id_ex_alu_src_a),
        .id_ex_alu_src_b     (id_ex_alu_src_b),
        .id_ex_alu_op        (id_ex_alu_op),

        .id_ex_branch        (id_ex_branch),
        .id_ex_jump_type     (id_ex_jump_type),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .id_ex_mem_read      (id_ex_mem_read),
        .id_ex_mem_write     (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .id_ex_reg_write     (id_ex_reg_write),
        .id_ex_wb_sel        (id_ex_wb_sel)
    );


    // =========================================================
    // HAZARD DETECTION UNIT
    //
    // Detecta load-use hazards cuyo dato se necesita en EX
    // durante el ciclo siguiente.
    //
    // Importante:
    //
    // STORE.rs1:
    //     se necesita en EX para calcular la dirección
    //     -> puede provocar stall.
    //
    // STORE.rs2:
    //     se necesita recién en MEM como dato
    //     -> NO provoca stall.
    //
    // Este último caso se resuelve mediante WB -> MEM
    // store-data forwarding.
    // =========================================================

    hazard_detection_unit hazard_detection_unit_inst (
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),

        .id_ex_valid       (id_ex_valid),
        .id_ex_mem_read    (id_ex_mem_read),
        .id_ex_rd          (id_ex_rd),

        .stall             (load_use_stall)
    );


    // =========================================================
    // EX / MEM DATAPATH
    // =========================================================

    logic [31:0] ex_mem_pc;

    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;

    // rs2 debe conservarse hasta MEM para poder comparar
    // el registro fuente del store con el rd de WB.
    logic [4:0] ex_mem_rs2;

    logic [4:0] ex_mem_rd;

    logic [6:0] ex_mem_opcode;
    logic [2:0] ex_mem_funct3;

    logic ex_mem_valid;


    // =========================================================
    // EX / MEM CONTROL
    //
    // EX ya consumió sus controles.
    //
    // Solamente continúan:
    //
    // MEM + WB
    // =========================================================

    logic ex_mem_mem_read;
    logic ex_mem_mem_write;

    logic       ex_mem_reg_write;
    logic [1:0] ex_mem_wb_sel;


    // =========================================================
    // FORWARDING HACIA EX
    //
    // ForwardA y ForwardB seleccionan qué versión de rs1/rs2
    // debe utilizar la instrucción actualmente en EX.
    //
    // 00 -> ID/EX
    // 01 -> MEM/WB
    // 10 -> EX/MEM
    // =========================================================

    logic [1:0] forward_a;
    logic [1:0] forward_b;

    logic ex_mem_forward_reg_write;
    logic mem_wb_forward_reg_write;


    // =========================================================
    // EX STAGE
    // =========================================================

    ex_stage ex_stage_inst (
        .clk                  (clk),
        .reset                (reset),

        .ex_enable            (ex_enable),
        .flush_ex_mem         (flush_ex_mem),

        // -----------------------------------------------------
        // EX control
        // -----------------------------------------------------

        .id_ex_alu_src_a      (id_ex_alu_src_a),
        .id_ex_alu_src_b      (id_ex_alu_src_b),
        .id_ex_alu_op         (id_ex_alu_op),

        .id_ex_branch         (id_ex_branch),
        .id_ex_jump_type      (id_ex_jump_type),

        // -----------------------------------------------------
        // MEM control que debe continuar
        // -----------------------------------------------------

        .id_ex_mem_read       (id_ex_mem_read),
        .id_ex_mem_write      (id_ex_mem_write),

        // -----------------------------------------------------
        // WB control que debe continuar
        // -----------------------------------------------------

        .id_ex_reg_write      (id_ex_reg_write),
        .id_ex_wb_sel         (id_ex_wb_sel),

        // -----------------------------------------------------
        // Datapath ID/EX
        // -----------------------------------------------------

        .id_ex_pc             (id_ex_pc),

        .id_ex_read_data1     (id_ex_read_data1),
        .id_ex_read_data2     (id_ex_read_data2),

        .id_ex_immediate      (id_ex_immediate),

        // rs2 se necesita también como identificador,
        // no solamente como valor.
        .id_ex_rs2            (id_ex_rs2),

        .id_ex_rd             (id_ex_rd),

        .id_ex_opcode         (id_ex_opcode),
        .id_ex_funct3         (id_ex_funct3),
        .id_ex_funct7         (id_ex_funct7),

        .id_ex_valid          (id_ex_valid),

        // -----------------------------------------------------
        // Forwarding hacia EX
        //
        // EX/MEM:
        // resultado ALU de la instrucción inmediatamente
        // anterior.
        //
        // MEM/WB:
        // wb_write_data contiene el valor final seleccionado
        // entre ALU, memoria o PC+4.
        // -----------------------------------------------------

        .forward_a            (forward_a),
        .forward_b            (forward_b),

        .ex_mem_forward_value (ex_mem_alu_result),
        .mem_wb_forward_value (wb_write_data),

        // -----------------------------------------------------
        // CONTROL HAZARDS
        // -----------------------------------------------------

        .redirect_valid       (redirect_valid),
        .redirect_target      (redirect_target),

        // -----------------------------------------------------
        // Datapath EX/MEM
        // -----------------------------------------------------

        .ex_mem_pc            (ex_mem_pc),

        .ex_mem_alu_result    (ex_mem_alu_result),
        .ex_mem_store_data    (ex_mem_store_data),

        // Identidad del registro fuente del store.
        .ex_mem_rs2           (ex_mem_rs2),

        .ex_mem_rd            (ex_mem_rd),

        .ex_mem_opcode        (ex_mem_opcode),
        .ex_mem_funct3        (ex_mem_funct3),

        .ex_mem_valid         (ex_mem_valid),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .ex_mem_reg_write     (ex_mem_reg_write),
        .ex_mem_wb_sel        (ex_mem_wb_sel)
    );


    // =========================================================
    // MEM / WB DATAPATH
    // =========================================================

    logic [31:0] mem_wb_pc;

    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_load_data;

    logic [4:0] mem_wb_rd;

    logic [6:0] mem_wb_opcode;

    logic mem_wb_valid;

    // =========================================================
    // PIPELINE EMPTY
    //
    // Esto significa únicamente que no existe ninguna
    // instrucción válida dentro del pipeline.
    //
    // NO significa por sí solo que el programa haya terminado.
    //
    // HALTED solamente puede alcanzarse después de haber
    // aceptado HALT y haber pasado por DRAINING.
    // =========================================================

    assign pipeline_empty =
        !if_id_valid  &&
        !id_ex_valid  &&
        !ex_mem_valid &&
        !mem_wb_valid;


    // =========================================================
    // EXECUTION CONTROL UNIT
    // =========================================================

    execution_control_unit execution_control_unit_inst (
        .clk               (clk),
        .reset             (reset),
        .enable            (cycle_enable),

        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid),

        .redirect_valid    (redirect_valid),

        .pipeline_empty    (pipeline_empty),

        .running           (running),
        .draining          (draining),
        .halted            (halted),

        .halt_in_id        (halt_in_id),
        .halt_accept       (halt_accept)
    );


    // =========================================================
    // MEM / WB CONTROL
    //
    // MEM ya consumió MemRead/MemWrite.
    //
    // Solamente continúa control WB.
    // =========================================================

    logic       mem_wb_reg_write;
    logic [1:0] mem_wb_wb_sel;


    // =========================================================
    // MEM STAGE
    //
    // Además del acceso normal a memoria, MEM puede corregir
    // el dato de un store mediante WB -> MEM forwarding.
    //
    // Ejemplo:
    //
    // lw x5,0(x1)
    // sw x5,0(x2)
    //
    // Cuando sw está en MEM:
    //
    // WB contiene el valor cargado para x5.
    //
    // Si:
    //
    // wb_write_register == ex_mem_rs2
    //
    // se utiliza wb_write_data como dato del store.
    // =========================================================

    mem_stage mem_stage_inst (
        .clk                 (clk),
        .reset               (reset),

        .mem_enable          (mem_enable),
        .flush_mem_wb        (flush_mem_wb),

        // -----------------------------------------------------
        // Datapath EX/MEM
        // -----------------------------------------------------

        .ex_mem_pc           (ex_mem_pc),

        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_store_data   (ex_mem_store_data),

        // rs2 original del store.
        .ex_mem_rs2          (ex_mem_rs2),

        .ex_mem_rd           (ex_mem_rd),

        .ex_mem_opcode       (ex_mem_opcode),
        .ex_mem_funct3       (ex_mem_funct3),

        .ex_mem_valid        (ex_mem_valid),

        // -----------------------------------------------------
        // MEM control
        // -----------------------------------------------------

        .ex_mem_mem_read     (ex_mem_mem_read),
        .ex_mem_mem_write    (ex_mem_mem_write),

        // -----------------------------------------------------
        // WB control que debe continuar
        // -----------------------------------------------------

        .ex_mem_reg_write    (ex_mem_reg_write),
        .ex_mem_wb_sel       (ex_mem_wb_sel),

        // -----------------------------------------------------
        // WB -> MEM STORE-DATA FORWARDING
        //
        // Estas señales ya representan el valor final de la
        // instrucción actualmente en WB.
        // -----------------------------------------------------

        .wb_write_enable     (wb_write_enable),
        .wb_write_register   (wb_write_register),
        .wb_write_data       (wb_write_data),

        .debug_memory_address (debug_memory_address),
        .debug_memory_data    (debug_memory_data),

        .debug_memory_access_valid (
            debug_memory_access_valid
        ),

        .debug_memory_access_address (
            debug_memory_access_address
        ),

        // -----------------------------------------------------
        // Datapath MEM/WB
        // -----------------------------------------------------

        .mem_wb_pc           (mem_wb_pc),

        .mem_wb_alu_result   (mem_wb_alu_result),
        .mem_wb_load_data    (mem_wb_load_data),

        .mem_wb_rd           (mem_wb_rd),
        .mem_wb_opcode       (mem_wb_opcode),

        .mem_wb_valid        (mem_wb_valid),

        // -----------------------------------------------------
        // WB control
        // -----------------------------------------------------

        .mem_wb_reg_write    (mem_wb_reg_write),
        .mem_wb_wb_sel       (mem_wb_wb_sel)
    );


    // =========================================================
    // WRITE BACK
    //
    // WB consume:
    //
    // - RegWrite
    // - WBSel
    //
    // wb_write_data se reutiliza como:
    //
    // - dato para el Register File;
    // - forwarding MEM/WB -> EX;
    // - bypass WB -> ID;
    // - forwarding WB -> store-data en MEM.
    // =========================================================

    wb_stage wb_stage_inst (
        .mem_wb_pc             (mem_wb_pc),

        .mem_wb_alu_result     (mem_wb_alu_result),
        .mem_wb_load_data      (mem_wb_load_data),

        .mem_wb_rd             (mem_wb_rd),

        // Temporal para debug/compatibilidad.
        .mem_wb_opcode         (mem_wb_opcode),

        .mem_wb_valid          (mem_wb_valid),

        .mem_wb_reg_write      (mem_wb_reg_write),
        .mem_wb_wb_sel         (mem_wb_wb_sel),

        .wb_write_enable       (wb_write_enable_raw),
        .wb_write_register     (wb_write_register),
        .wb_write_data         (wb_write_data)
    );


    // =========================================================
    // PRODUCTORES VÁLIDOS PARA FORWARDING HACIA EX
    // =========================================================

    // ---------------------------------------------------------
    // EX/MEM
    //
    // Solamente se permite forwarding si:
    //
    // - la instrucción es válida;
    // - escribe Register File;
    // - NO es un load.
    //
    // Para un load:
    //
    // EX/MEM.alu_result = dirección efectiva
    //
    // todavía NO contiene el dato cargado.
    //
    // Si una instrucción inmediatamente posterior necesita
    // ese dato en EX, Hazard Detection Unit inserta un stall.
    // ---------------------------------------------------------

    assign ex_mem_forward_reg_write =
        ex_mem_valid     &&
        ex_mem_reg_write &&
        !ex_mem_mem_read;


    // ---------------------------------------------------------
    // MEM/WB
    //
    // En MEM/WB el valor final ya está disponible.
    // ---------------------------------------------------------

    assign mem_wb_forward_reg_write =
        mem_wb_valid     &&
        mem_wb_reg_write;


    // =========================================================
    // FORWARDING UNIT HACIA EX
    //
    // Compara:
    //
    // ID/EX.rs1 / rs2
    //
    // contra:
    //
    // EX/MEM.rd
    // MEM/WB.rd
    //
    // Prioridad:
    //
    // EX/MEM > MEM/WB > ID/EX
    //
    // Este forwarding es distinto del WB -> MEM forwarding
    // utilizado específicamente para el dato de stores.
    // =========================================================

    forwarding_unit forwarding_unit_inst (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),

        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_write (ex_mem_forward_reg_write),

        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_write (mem_wb_forward_reg_write),

        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    // =========================================================
    // DEBUG OBSERVATION PORTS
    //
    // Son copias exclusivamente de lectura de las señales
    // internas del pipeline.
    // =========================================================


    // ---------------------------------------------------------
    // IF
    // ---------------------------------------------------------

    assign debug_if_pc_current =
        if_pc_current;


    // ---------------------------------------------------------
    // IF / ID
    // ---------------------------------------------------------

    assign debug_if_id_valid =
        if_id_valid;

    assign debug_if_id_pc =
        if_id_pc;

    assign debug_if_id_instruction =
        if_id_instruction;


    // ---------------------------------------------------------
    // ID / EX
    // ---------------------------------------------------------

    assign debug_id_ex_valid =
        id_ex_valid;

    assign debug_id_ex_pc =
        id_ex_pc;

    assign debug_id_ex_read_data1 =
        id_ex_read_data1;

    assign debug_id_ex_read_data2 =
        id_ex_read_data2;

    assign debug_id_ex_immediate =
        id_ex_immediate;


    assign debug_id_ex_rs1 =
        id_ex_rs1;

    assign debug_id_ex_rs2 =
        id_ex_rs2;

    assign debug_id_ex_rd =
        id_ex_rd;


    assign debug_id_ex_opcode =
        id_ex_opcode;

    assign debug_id_ex_funct3 =
        id_ex_funct3;

    assign debug_id_ex_funct7 =
        id_ex_funct7;


    assign debug_id_ex_alu_src_a =
        id_ex_alu_src_a;

    assign debug_id_ex_alu_src_b =
        id_ex_alu_src_b;

    assign debug_id_ex_alu_op =
        id_ex_alu_op;


    assign debug_id_ex_branch =
        id_ex_branch;

    assign debug_id_ex_jump_type =
        id_ex_jump_type;


    assign debug_id_ex_mem_read =
        id_ex_mem_read;

    assign debug_id_ex_mem_write =
        id_ex_mem_write;


    assign debug_id_ex_reg_write =
        id_ex_reg_write;

    assign debug_id_ex_wb_sel =
        id_ex_wb_sel;


    // ---------------------------------------------------------
    // EX / MEM
    // ---------------------------------------------------------

    assign debug_ex_mem_valid =
        ex_mem_valid;

    assign debug_ex_mem_pc =
        ex_mem_pc;

    assign debug_ex_mem_alu_result =
        ex_mem_alu_result;

    assign debug_ex_mem_store_data =
        ex_mem_store_data;


    assign debug_ex_mem_rs2 =
        ex_mem_rs2;

    assign debug_ex_mem_rd =
        ex_mem_rd;


    assign debug_ex_mem_opcode =
        ex_mem_opcode;

    assign debug_ex_mem_funct3 =
        ex_mem_funct3;


    assign debug_ex_mem_mem_read =
        ex_mem_mem_read;

    assign debug_ex_mem_mem_write =
        ex_mem_mem_write;


    assign debug_ex_mem_reg_write =
        ex_mem_reg_write;

    assign debug_ex_mem_wb_sel =
        ex_mem_wb_sel;


    // ---------------------------------------------------------
    // MEM / WB
    // ---------------------------------------------------------

    assign debug_mem_wb_valid =
        mem_wb_valid;

    assign debug_mem_wb_pc =
        mem_wb_pc;

    assign debug_mem_wb_alu_result =
        mem_wb_alu_result;

    assign debug_mem_wb_load_data =
        mem_wb_load_data;


    assign debug_mem_wb_rd =
        mem_wb_rd;

    assign debug_mem_wb_opcode =
        mem_wb_opcode;


    assign debug_mem_wb_reg_write =
        mem_wb_reg_write;

    assign debug_mem_wb_wb_sel =
        mem_wb_wb_sel;

endmodule
