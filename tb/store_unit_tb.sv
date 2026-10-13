`timescale 1ns / 1ps

module store_unit_tb;

    logic [2:0]  funct3;
    logic [1:0]  address_offset;
    logic [31:0] store_data;

    logic [31:0] write_data;
    logic [3:0]  byte_enable;
    logic        misaligned;


    store_unit dut (
        .funct3        (funct3),
        .address_offset(address_offset),
        .store_data    (store_data),

        .write_data    (write_data),
        .byte_enable   (byte_enable),
        .misaligned    (misaligned)
    );


    task automatic check_case (
        input logic [2:0]  test_funct3,
        input logic [1:0]  test_address_offset,
        input logic [31:0] test_store_data,

        input logic [31:0] expected_write_data,
        input logic [3:0]  expected_byte_enable,
        input logic        expected_misaligned,

        input string       test_name
    );
        begin

            funct3         = test_funct3;
            address_offset = test_address_offset;
            store_data     = test_store_data;

            #1;

            if (
                write_data  !== expected_write_data  ||
                byte_enable !== expected_byte_enable ||
                misaligned  !== expected_misaligned
            ) begin

                $display("FAIL: %s", test_name);
                $display("  funct3        = %b", funct3);
                $display("  address_offset = %b", address_offset);
                $display("  store_data     = %h", store_data);
                $display("  write_data     = %h expected=%h",
                         write_data, expected_write_data);
                $display("  byte_enable    = %b expected=%b",
                         byte_enable, expected_byte_enable);
                $display("  misaligned     = %b expected=%b",
                         misaligned, expected_misaligned);

                $fatal;
            end
            else begin

                $display(
                    "PASS: %s | offset=%b | write_data=%h | byte_enable=%b | misaligned=%b",
                    test_name,
                    address_offset,
                    write_data,
                    byte_enable,
                    misaligned
                );

            end

        end
    endtask


    initial begin

        funct3         = 3'b000;
        address_offset = 2'b00;
        store_data     = 32'd0;

        #1;


        // =========================================================
        // SB - STORE BYTE
        //
        // store_data = 0x123456AA
        // Se utiliza solamente store_data[7:0] = AA.
        //
        // Todos los offsets son válidos.
        // =========================================================

        check_case(
            3'b000,
            2'b00,
            32'h123456AA,
            32'h000000AA,
            4'b0001,
            1'b0,
            "SB BYTE 0"
        );


        check_case(
            3'b000,
            2'b01,
            32'h123456AA,
            32'h0000AA00,
            4'b0010,
            1'b0,
            "SB BYTE 1"
        );


        check_case(
            3'b000,
            2'b10,
            32'h123456AA,
            32'h00AA0000,
            4'b0100,
            1'b0,
            "SB BYTE 2"
        );


        check_case(
            3'b000,
            2'b11,
            32'h123456AA,
            32'hAA000000,
            4'b1000,
            1'b0,
            "SB BYTE 3"
        );


        // =========================================================
        // SH - STORE HALFWORD
        //
        // store_data = 0x1234ABCD
        // Se utiliza store_data[15:0] = ABCD.
        //
        // offset 00 -> válido
        // offset 10 -> válido
        // offset 01 -> desalineado
        // offset 11 -> desalineado
        // =========================================================

        check_case(
            3'b001,
            2'b00,
            32'h1234ABCD,
            32'h0000ABCD,
            4'b0011,
            1'b0,
            "SH LOWER HALFWORD"
        );


        check_case(
            3'b001,
            2'b10,
            32'h1234ABCD,
            32'hABCD0000,
            4'b1100,
            1'b0,
            "SH UPPER HALFWORD"
        );


        check_case(
            3'b001,
            2'b01,
            32'h1234ABCD,
            32'h00000000,
            4'b0000,
            1'b1,
            "SH MISALIGNED OFFSET 01"
        );


        check_case(
            3'b001,
            2'b11,
            32'h1234ABCD,
            32'h00000000,
            4'b0000,
            1'b1,
            "SH MISALIGNED OFFSET 11"
        );


        // =========================================================
        // SW - STORE WORD
        //
        // Solamente offset 00 es válido.
        // =========================================================

        check_case(
            3'b010,
            2'b00,
            32'hAABBCCDD,
            32'hAABBCCDD,
            4'b1111,
            1'b0,
            "SW ALIGNED"
        );


        check_case(
            3'b010,
            2'b01,
            32'hAABBCCDD,
            32'h00000000,
            4'b0000,
            1'b1,
            "SW MISALIGNED OFFSET 01"
        );


        check_case(
            3'b010,
            2'b10,
            32'hAABBCCDD,
            32'h00000000,
            4'b0000,
            1'b1,
            "SW MISALIGNED OFFSET 10"
        );


        check_case(
            3'b010,
            2'b11,
            32'hAABBCCDD,
            32'h00000000,
            4'b0000,
            1'b1,
            "SW MISALIGNED OFFSET 11"
        );


        // =========================================================
        // FUNCT3 NO SOPORTADO
        //
        // Debe producir valores seguros:
        // byte_enable = 0000
        // write_data  = 0
        // misaligned  = 0
        // =========================================================

        check_case(
            3'b111,
            2'b10,
            32'hDEADBEEF,
            32'h00000000,
            4'b0000,
            1'b0,
            "INVALID FUNCT3"
        );


        $display("PASS: store_unit");
        $finish;

    end

endmodule
