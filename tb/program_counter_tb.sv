`timescale 1ns/1ps

module program_counter_tb;

    logic        clk;
    logic        reset;
    logic        enable;
    logic [31:0] next_pc;

    logic [31:0] pc_current;

    program_counter dut (
        .clk        (clk),
        .reset      (reset),
        .enable     (enable),
        .next_pc    (next_pc),
        .pc_current (pc_current)
    );

    // Clock de período 10 ns.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Estado inicial de las entradas.
        reset   = 1'b1;
        enable  = 1'b0;
        next_pc = 32'd0;

        // Caso 1: reset.
        @(posedge clk);
        #1;

        if (pc_current !== 32'd0)
            $fatal(1, "ERROR: reset no llevo el PC a 0");

        // Caso 2: enable = 1.
        @(negedge clk);
        reset   = 1'b0;
        enable  = 1'b1;
        next_pc = 32'd44;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd44)
            $fatal(1, "ERROR: PC no capturo 44");

        // Caso 3: enable = 0.
        @(negedge clk);
        enable  = 1'b0;
        next_pc = 32'd100;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd44)
            $fatal(1, "ERROR: PC cambio aunque enable era 0");

        // Caso 4: vuelve a avanzar.
        @(negedge clk);
        enable  = 1'b1;
        next_pc = 32'd80;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd80)
            $fatal(1, "ERROR: PC no capturo 80");

        // Caso 5: reset tiene prioridad sobre enable.
        @(negedge clk);
        reset   = 1'b1;
        enable  = 1'b1;
        next_pc = 32'd200;

        @(posedge clk);
        #1;

        if (pc_current !== 32'd0)
            $fatal(1, "ERROR: reset no tuvo prioridad");

        $display("PASS: program_counter");
        $finish;
    end

endmodule
