`timescale 1ns/1ps

module if_stage_tb;

    logic        clk;
    logic        reset;
    logic        if_enable;
    logic        redirect_valid;
    logic [31:0] redirect_pc;
    logic        flush_if_id;

    logic [31:0] pc_current;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic        if_id_valid;

    if_stage #(
        .IMEM_DEPTH(256)
    ) dut (
        .clk               (clk),
        .reset             (reset),
        .if_enable         (if_enable),
        .redirect_valid    (redirect_valid),
        .redirect_pc       (redirect_pc),
        .flush_if_id       (flush_if_id),
        .pc_current        (pc_current),
        .if_id_pc          (if_id_pc),
        .if_id_instruction (if_id_instruction),
        .if_id_valid       (if_id_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Programa de prueba.
        dut.imem.memory[0]  = 32'hAAAAAAAA; // PC = 0
        dut.imem.memory[1]  = 32'hBBBBBBBB; // PC = 4
        dut.imem.memory[2]  = 32'hCCCCCCCC; // PC = 8
        dut.imem.memory[3]  = 32'hDDDDDDDD; // PC = 12
        dut.imem.memory[10] = 32'hEEEEEEEE; // PC = 40

        reset          = 1'b1;
        if_enable      = 1'b0;
        redirect_valid = 1'b0;
        redirect_pc    = 32'd0;
        flush_if_id    = 1'b0;

        // Caso 1: reset.
        @(posedge clk);
        #1;

        if (pc_current !== 32'd0 ||
            if_id_valid !== 1'b0)
            $fatal(1, "ERROR: reset incorrecto en IF");

        // Caso 2: primer avance normal.
        @(negedge clk);
        reset     = 1'b0;
        if_enable = 1'b1;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd4 ||
            if_id_pc !== 32'd0 ||
            if_id_instruction !== 32'hAAAAAAAA ||
            if_id_valid !== 1'b1)
            $fatal(1, "ERROR: primer avance normal incorrecto");

        // Caso 3: segundo avance normal.
        @(posedge clk);
        #1;

        if (pc_current !== 32'd8 ||
            if_id_pc !== 32'd4 ||
            if_id_instruction !== 32'hBBBBBBBB ||
            if_id_valid !== 1'b1)
            $fatal(1, "ERROR: segundo avance normal incorrecto");

        // Caso 4: stall.
        @(negedge clk);
        if_enable = 1'b0;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd8 ||
            if_id_pc !== 32'd4 ||
            if_id_instruction !== 32'hBBBBBBBB ||
            if_id_valid !== 1'b1)
            $fatal(1, "ERROR: IF cambio durante stall");

        // Caso 5: reanudar.
        @(negedge clk);
        if_enable = 1'b1;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd12 ||
            if_id_pc !== 32'd8 ||
            if_id_instruction !== 32'hCCCCCCCC ||
            if_id_valid !== 1'b1)
            $fatal(1, "ERROR: IF no reanudo correctamente");

        // Caso 6: redirect + flush durante stall.
        @(negedge clk);
        if_enable      = 1'b0;
        redirect_valid = 1'b1;
        redirect_pc    = 32'd40;
        flush_if_id    = 1'b1;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd40)
            $fatal(1, "ERROR: redirect no tuvo prioridad sobre stall");

        if (if_id_valid !== 1'b0)
            $fatal(1, "ERROR: flush no invalido IF/ID");

        // Caso 7: continuar desde la dirección redirigida.
        @(negedge clk);
        if_enable      = 1'b1;
        redirect_valid = 1'b0;
        flush_if_id    = 1'b0;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd44 ||
            if_id_pc !== 32'd40 ||
            if_id_instruction !== 32'hEEEEEEEE ||
            if_id_valid !== 1'b1)
            $fatal(1, "ERROR: IF no continuo correctamente luego del redirect");

        $display("PASS: if_stage");
        $finish;
    end

endmodule
