`timescale 1ns/1ps

module id_ex_register_tb;

    logic        clk;
    logic        reset;
    logic        enable;
    logic        flush;

    logic [31:0] pc_in;
    logic [31:0] read_data1_in;
    logic [31:0] read_data2_in;
    logic [31:0] immediate_in;

    logic [4:0]  rs1_in;
    logic [4:0]  rs2_in;
    logic [4:0]  rd_in;

    logic [6:0]  opcode_in;
    logic [2:0]  funct3_in;
    logic [6:0]  funct7_in;

    logic        valid_in;

    logic [31:0] pc_out;
    logic [31:0] read_data1_out;
    logic [31:0] read_data2_out;
    logic [31:0] immediate_out;

    logic [4:0]  rs1_out;
    logic [4:0]  rs2_out;
    logic [4:0]  rd_out;

    logic [6:0]  opcode_out;
    logic [2:0]  funct3_out;
    logic [6:0]  funct7_out;

    logic        valid_out;

    id_ex_register dut (
        .clk            (clk),
        .reset          (reset),
        .enable         (enable),
        .flush          (flush),

        .pc_in          (pc_in),
        .read_data1_in  (read_data1_in),
        .read_data2_in  (read_data2_in),
        .immediate_in   (immediate_in),

        .rs1_in         (rs1_in),
        .rs2_in         (rs2_in),
        .rd_in          (rd_in),

        .opcode_in      (opcode_in),
        .funct3_in      (funct3_in),
        .funct7_in      (funct7_in),

        .valid_in       (valid_in),

        .pc_out         (pc_out),
        .read_data1_out (read_data1_out),
        .read_data2_out (read_data2_out),
        .immediate_out  (immediate_out),

        .rs1_out        (rs1_out),
        .rs2_out        (rs2_out),
        .rd_out         (rd_out),

        .opcode_out     (opcode_out),
        .funct3_out     (funct3_out),
        .funct7_out     (funct7_out),

        .valid_out      (valid_out)
    );

    // Clock de período 10 ns.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset          = 1'b1;
        enable         = 1'b0;
        flush          = 1'b0;

        pc_in          = 32'd0;
        read_data1_in  = 32'd0;
        read_data2_in  = 32'd0;
        immediate_in   = 32'd0;

        rs1_in         = 5'd0;
        rs2_in         = 5'd0;
        rd_in          = 5'd0;

        opcode_in      = 7'd0;
        funct3_in      = 3'd0;
        funct7_in      = 7'd0;

        valid_in       = 1'b0;


        // Caso 1: reset.
        @(posedge clk);
        #1;

        if (valid_out !== 1'b0)
            $fatal(1, "ERROR RESET: valid_out deberia ser 0");

        if (pc_out !== 32'd0)
            $fatal(1, "ERROR RESET: pc_out deberia ser 0");


        // Caso 2: captura normal.
        @(negedge clk);

        reset          = 1'b0;
        enable         = 1'b1;
        flush          = 1'b0;

        pc_in          = 32'd100;
        read_data1_in  = 32'd150;
        read_data2_in  = 32'd200;
        immediate_in   = 32'd12;

        rs1_in         = 5'd3;
        rs2_in         = 5'd5;
        rd_in          = 5'd6;

        opcode_in      = 7'b0110011;
        funct3_in      = 3'b000;
        funct7_in      = 7'b0000000;

        valid_in       = 1'b1;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd100)
            $fatal(1, "ERROR CAPTURA: pc incorrecto");

        if (read_data1_out !== 32'd150)
            $fatal(1, "ERROR CAPTURA: read_data1 incorrecto");

        if (read_data2_out !== 32'd200)
            $fatal(1, "ERROR CAPTURA: read_data2 incorrecto");

        if (immediate_out !== 32'd12)
            $fatal(1, "ERROR CAPTURA: immediate incorrecto");

        if (rs1_out !== 5'd3 ||
            rs2_out !== 5'd5 ||
            rd_out  !== 5'd6)
            $fatal(1, "ERROR CAPTURA: registros incorrectos");

        if (valid_out !== 1'b1)
            $fatal(1, "ERROR CAPTURA: valid_out incorrecto");


        // Caso 3: stall (enable = 0).
        @(negedge clk);

        enable         = 1'b0;

        pc_in          = 32'd104;
        read_data1_in  = 32'd999;
        read_data2_in  = 32'd888;
        immediate_in   = 32'd44;

        rs1_in         = 5'd10;
        rs2_in         = 5'd11;
        rd_in          = 5'd12;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd100 ||
            read_data1_out !== 32'd150 ||
            read_data2_out !== 32'd200 ||
            immediate_out !== 32'd12)
            $fatal(1, "ERROR STALL: los datos cambiaron con enable=0");

        if (valid_out !== 1'b1)
            $fatal(1, "ERROR STALL: valid_out deberia mantenerse");


        // Caso 4: flush.
        @(negedge clk);

        flush  = 1'b1;
        enable = 1'b0;

        @(posedge clk);
        #1;

        if (valid_out !== 1'b0)
            $fatal(1, "ERROR FLUSH: valid_out deberia ser 0");

        if (pc_out !== 32'd100)
            $fatal(1, "ERROR FLUSH: pc_out no deberia cambiar");


        // Caso 5: nueva captura después del flush.
        @(negedge clk);

        flush          = 1'b0;
        enable         = 1'b1;

        pc_in          = 32'd108;
        read_data1_in  = 32'd300;
        read_data2_in  = 32'd400;
        immediate_in   = 32'hFFFFFFF8;

        rs1_in         = 5'd7;
        rs2_in         = 5'd8;
        rd_in          = 5'd9;

        opcode_in      = 7'b1100011;
        funct3_in      = 3'b000;
        funct7_in      = 7'b1111111;

        valid_in       = 1'b1;

        @(posedge clk);
        #1;

        if (pc_out !== 32'd108)
            $fatal(1, "ERROR RECUPERACION: pc incorrecto");

        if (read_data1_out !== 32'd300 ||
            read_data2_out !== 32'd400)
            $fatal(1, "ERROR RECUPERACION: operandos incorrectos");

        if (immediate_out !== 32'hFFFFFFF8)
            $fatal(1, "ERROR RECUPERACION: immediate incorrecto");

        if (valid_out !== 1'b1)
            $fatal(1, "ERROR RECUPERACION: valid_out deberia ser 1");


        // Caso 6: prioridad del reset.
        @(negedge clk);

        reset    = 1'b1;
        flush    = 1'b1;
        enable   = 1'b1;
        valid_in = 1'b1;

        pc_in = 32'd999;

        @(posedge clk);
        #1;

        if (valid_out !== 1'b0)
            $fatal(1, "ERROR PRIORIDAD: reset debe dominar");

        if (pc_out !== 32'd0)
            $fatal(1, "ERROR PRIORIDAD: pc_out deberia resetearse");

        $display("PASS: id_ex_register");
        $finish;
    end

endmodule
