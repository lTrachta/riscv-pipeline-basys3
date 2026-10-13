`timescale 1ns / 1ps

module load_unit (
    input  logic [2:0]  funct3,
    input  logic [1:0]  address_offset,
    input  logic [31:0] read_data,

    output logic [31:0] load_data,
    output logic        misaligned
);

    localparam logic [2:0] FUNCT3_LB  = 3'b000;
    localparam logic [2:0] FUNCT3_LH  = 3'b001;
    localparam logic [2:0] FUNCT3_LW  = 3'b010;
    localparam logic [2:0] FUNCT3_LBU = 3'b100;
    localparam logic [2:0] FUNCT3_LHU = 3'b101;

    logic [7:0]  selected_byte;
    logic [15:0] selected_halfword;


    always_comb begin

        // ---------------------------------------------------------
        // Selección de byte dentro de la palabra.
        // Little-endian.
        // ---------------------------------------------------------

        case (address_offset)

            2'b00: selected_byte = read_data[7:0];
            2'b01: selected_byte = read_data[15:8];
            2'b10: selected_byte = read_data[23:16];
            2'b11: selected_byte = read_data[31:24];

            default:
                selected_byte = 8'd0;

        endcase


        // ---------------------------------------------------------
        // Selección de halfword.
        //
        // Solo 00 y 10 son posiciones alineadas.
        // ---------------------------------------------------------

        if (address_offset[1])
            selected_halfword = read_data[31:16];
        else
            selected_halfword = read_data[15:0];


        // Valores seguros por defecto.

        load_data  = 32'd0;
        misaligned = 1'b0;


        case (funct3)

            // =====================================================
            // LB - Load Byte signed
            // =====================================================

            FUNCT3_LB: begin
                load_data = {
                    {24{selected_byte[7]}},
                    selected_byte
                };
            end


            // =====================================================
            // LH - Load Halfword signed
            // =====================================================

            FUNCT3_LH: begin

                if (address_offset[0] == 1'b0) begin
                    load_data = {
                        {16{selected_halfword[15]}},
                        selected_halfword
                    };
                end
                else begin
                    load_data  = 32'd0;
                    misaligned = 1'b1;
                end

            end


            // =====================================================
            // LW - Load Word
            // =====================================================

            FUNCT3_LW: begin

                if (address_offset == 2'b00) begin
                    load_data = read_data;
                end
                else begin
                    load_data  = 32'd0;
                    misaligned = 1'b1;
                end

            end


            // =====================================================
            // LBU - Load Byte unsigned
            // =====================================================

            FUNCT3_LBU: begin
                load_data = {
                    24'd0,
                    selected_byte
                };
            end


            // =====================================================
            // LHU - Load Halfword unsigned
            // =====================================================

            FUNCT3_LHU: begin

                if (address_offset[0] == 1'b0) begin
                    load_data = {
                        16'd0,
                        selected_halfword
                    };
                end
                else begin
                    load_data  = 32'd0;
                    misaligned = 1'b1;
                end

            end


            // =====================================================
            // funct3 no soportado
            // =====================================================

            default: begin
                load_data  = 32'd0;
                misaligned = 1'b0;
            end

        endcase

    end

endmodule
