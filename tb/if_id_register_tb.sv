`timescale 1ns/1ps

module if_id_register_tb;

    logic        clk;
    logic        reset;
    logic        enable;
    logic        flush;

    logic [31:0] pc_in;
    logic [31:0] instruction_in;
    logic        valid_in;

    logic [31:0] pc_out;
    logic [31:0] instruction_out;
    logic        valid_out;

    if_id_register dut (
        .clk             (clk),
        .reset           (reset),
        .enable          (enable),
        .flush           (flush),
        .pc_in           (pc_in),
        .instruction_in  (instruction_in),
        .valid_in        (valid_in),
        .pc_out          (pc_out),
        .instruction_out (instruction_out),
        .valid_out       (valid_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset          = 1'b1;
        enable         = 1'b0;
        flush          = 1'b0;
        pc_in          = 32'd0;
        instruction_in = 32'd0;
        valid_in       = 1'b0;

        // Caso 1: reset
        @(posedge clk);
        #1;

        if (pc_out !== 32'd0 ||
            instruction_out !== 32'd0 ||
            valid_out !== 1'b0)
            $fatal(1, "ERROR: reset incorrecto en IF/ID");

        // Caso 2: captura normal
        @(negedge clk);
        reset          = 1'b0;
        enable         = 1'b1;
        flush          = 1'b0;
        pc_in          = 32'd8;
        instruction_in = 32'h12345678;
        valid_in       = 1'b1;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd8 ||
            instruction_out !== 32'h12345678 ||
            valid_out !== 1'b1)
            $fatal(1, "ERROR: captura normal incorrecta");

        // Caso 3: stall
        @(negedge clk);
        enable         = 1'b0;
        pc_in          = 32'd12;
        instruction_in = 32'hAAAAAAAA;
        valid_in       = 1'b1;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd8 ||
            instruction_out !== 32'h12345678 ||
            valid_out !== 1'b1)
            $fatal(1, "ERROR: IF/ID cambio durante stall");

        // Caso 4: flush
        @(negedge clk);
        flush = 1'b1;

        @(posedge clk);
        #1;

        if (valid_out !== 1'b0)
            $fatal(1, "ERROR: flush no invalido IF/ID");

        if (pc_out !== 32'd8 ||
            instruction_out !== 32'h12345678)
            $fatal(1, "ERROR: flush modifico datos que debian conservarse");

        // Caso 5: nueva captura luego del flush
        @(negedge clk);
        flush          = 1'b0;
        enable         = 1'b1;
        pc_in          = 32'd16;
        instruction_in = 32'hDEADBEEF;
        valid_in       = 1'b1;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd16 ||
            instruction_out !== 32'hDEADBEEF ||
            valid_out !== 1'b1)
            $fatal(1, "ERROR: IF/ID no capturo luego del flush");

        // Caso 6: reset tiene prioridad
        @(negedge clk);
        reset          = 1'b1;
        enable         = 1'b1;
        flush          = 1'b1;
        pc_in          = 32'd100;
        instruction_in = 32'hFFFFFFFF;
        valid_in       = 1'b1;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd0 ||
            instruction_out !== 32'd0 ||
            valid_out !== 1'b0)
            $fatal(1, "ERROR: reset no tuvo prioridad");

        $display("PASS: if_id_register");
        $finish;
    end

endmodule
