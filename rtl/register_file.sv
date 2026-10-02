`timescale 1ns/1ps

module register_file (
    input  logic        clk,
    input  logic        reset,

    input  logic [4:0]  read_register1,
    input  logic [4:0]  read_register2,

    output logic [31:0] read_data1,
    output logic [31:0] read_data2,

    input  logic        write_enable,
    input  logic [4:0]  write_register,
    input  logic [31:0] write_data
);

    logic [31:0] registers [0:31];

    integer i;

    // Lecturas combinacionales.
    always_comb begin
        if (read_register1 == 5'd0)
            read_data1 = 32'd0;
        else
            read_data1 = registers[read_register1];

        if (read_register2 == 5'd0)
            read_data2 = 32'd0;
        else
            read_data2 = registers[read_register2];
    end

    // Escritura secuencial.
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;
        end
        else begin
            if (write_enable && (write_register != 5'd0))
                registers[write_register] <= write_data;

            registers[0] <= 32'd0;
        end
    end

endmodule
