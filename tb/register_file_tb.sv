`timescale 1ns/1ps

module register_file_tb;

    logic        clk;
    logic        reset;

    logic [4:0]  read_register1;
    logic [4:0]  read_register2;

    logic [31:0] read_data1;
    logic [31:0] read_data2;

    logic        write_enable;
    logic [4:0]  write_register;
    logic [31:0] write_data;

    register_file dut (
        .clk            (clk),
        .reset          (reset),

        .read_register1 (read_register1),
        .read_register2 (read_register2),

        .read_data1     (read_data1),
        .read_data2     (read_data2),

        .write_enable   (write_enable),
        .write_register (write_register),
        .write_data     (write_data)
    );

    // Clock de período 10 ns.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset          = 1'b1;

        read_register1 = 5'd0;
        read_register2 = 5'd0;

        write_enable   = 1'b0;
        write_register = 5'd0;
        write_data     = 32'd0;

        // Caso 1: reset.
        @(posedge clk);
        #1;

        if (read_data1 !== 32'd0 ||
            read_data2 !== 32'd0)
            $fatal(1, "ERROR: reset incorrecto");

        // Caso 2: escribir 150 en x3.
        @(negedge clk);
        reset          = 1'b0;
        write_enable   = 1'b1;
        write_register = 5'd3;
        write_data     = 32'd150;

        @(posedge clk);
        #1;

        read_register1 = 5'd3;
        #1;

        if (read_data1 !== 32'd150)
            $fatal(1, "ERROR: x3 no contiene 150");

        // Caso 3: escribir 200 en x5.
        @(negedge clk);
        write_register = 5'd5;
        write_data     = 32'd200;

        @(posedge clk);
        #1;

        // Leer dos registros simultáneamente.
        read_register1 = 5'd3;
        read_register2 = 5'd5;
        #1;

        if (read_data1 !== 32'd150)
            $fatal(1, "ERROR: lectura de x3 incorrecta");

        if (read_data2 !== 32'd200)
            $fatal(1, "ERROR: lectura de x5 incorrecta");

        // Caso 4: intentar escribir x0.
        @(negedge clk);
        write_register = 5'd0;
        write_data     = 32'd123;

        @(posedge clk);
        #1;

        read_register1 = 5'd0;
        #1;

        if (read_data1 !== 32'd0)
            $fatal(1, "ERROR: x0 fue modificado");

        // Caso 5: write_enable = 0.
        @(negedge clk);
        write_enable   = 1'b0;
        write_register = 5'd3;
        write_data     = 32'd999;

        @(posedge clk);
        #1;

        read_register1 = 5'd3;
        #1;

        if (read_data1 !== 32'd150)
            $fatal(1, "ERROR: x3 cambio con write_enable=0");

        $display("PASS: register_file");
        $finish;
    end

endmodule
