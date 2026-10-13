`timescale 1ns / 1ps

module store_unit (
    input  logic [2:0]  funct3,
    input  logic [1:0]  address_offset,
    input  logic [31:0] store_data,

    output logic [31:0] write_data,
    output logic [3:0]  byte_enable,
    output logic        misaligned
);

    localparam logic [2:0] FUNCT3_SB = 3'b000;
    localparam logic [2:0] FUNCT3_SH = 3'b001;
    localparam logic [2:0] FUNCT3_SW = 3'b010;


    always_comb begin

        // Valores seguros por defecto.
        write_data  = 32'd0;
        byte_enable = 4'b0000;
        misaligned  = 1'b0;


        case (funct3)

            // =====================================================
            // SB - Store Byte
            //
            // Siempre toma store_data[7:0].
            // Cualquier offset es válido.
            // =====================================================

            FUNCT3_SB: begin

                case (address_offset)

                    2'b00: begin
                        write_data  = {24'd0, store_data[7:0]};
                        byte_enable = 4'b0001;
                    end

                    2'b01: begin
                        write_data  = {16'd0, store_data[7:0], 8'd0};
                        byte_enable = 4'b0010;
                    end

                    2'b10: begin
                        write_data  = {8'd0, store_data[7:0], 16'd0};
                        byte_enable = 4'b0100;
                    end

                    2'b11: begin
                        write_data  = {store_data[7:0], 24'd0};
                        byte_enable = 4'b1000;
                    end

                    default: begin
                        write_data  = 32'd0;
                        byte_enable = 4'b0000;
                    end

                endcase

            end


            // =====================================================
            // SH - Store Halfword
            //
            // Usa store_data[15:0].
            //
            // Direcciones válidas:
            //   offset 00 -> halfword inferior
            //   offset 10 -> halfword superior
            //
            // offset 01 y 11 son desalineados.
            // =====================================================

            FUNCT3_SH: begin

                case (address_offset)

                    2'b00: begin
                        write_data  = {16'd0, store_data[15:0]};
                        byte_enable = 4'b0011;
                    end

                    2'b10: begin
                        write_data  = {store_data[15:0], 16'd0};
                        byte_enable = 4'b1100;
                    end

                    2'b01,
                    2'b11: begin
                        write_data  = 32'd0;
                        byte_enable = 4'b0000;
                        misaligned  = 1'b1;
                    end

                    default: begin
                        write_data  = 32'd0;
                        byte_enable = 4'b0000;
                    end

                endcase

            end


            // =====================================================
            // SW - Store Word
            //
            // Solo es válido si address_offset = 00.
            // =====================================================

            FUNCT3_SW: begin

                if (address_offset == 2'b00) begin
                    write_data  = store_data;
                    byte_enable = 4'b1111;
                end
                else begin
                    write_data  = 32'd0;
                    byte_enable = 4'b0000;
                    misaligned  = 1'b1;
                end

            end


            // =====================================================
            // funct3 no soportado
            // =====================================================

            default: begin
                write_data  = 32'd0;
                byte_enable = 4'b0000;
                misaligned  = 1'b0;
            end

        endcase

    end

endmodule
