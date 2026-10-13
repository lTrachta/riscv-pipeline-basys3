`timescale 1ns / 1ps

module load_unit_tb;

    logic [2:0]  funct3;
    logic [1:0]  address_offset;
    logic [31:0] read_data;

    logic [31:0] load_data;
    logic        misaligned;


    load_unit dut (
        .funct3        (funct3),
        .address_offset(address_offset),
        .read_data     (read_data),

        .load_data     (load_data),
        .misaligned    (misaligned)
    );


    task automatic check_case (
        input logic [2:0]  test_funct3,
        input logic [1:0]  test_address_offset,
        input logic [31:0] test_read_data,

        input logic [31:0] expected_load_data,
        input logic        expected_misaligned,

        input string       test_name
    );
        begin

            funct3         = test_funct3;
            address_offset = test_address_offset;
            read_data      = test_read_data;

            #1;

            if (
                load_data  !== expected_load_data ||
                misaligned !== expected_misaligned
            ) begin

                $display("FAIL: %s", test_name);
                $display("  funct3         = %b", funct3);
                $display("  address_offset = %b", address_offset);
                $display("  read_data      = %h", read_data);
                $display("  load_data      = %h expected=%h",
                         load_data, expected_load_data);
                $display("  misaligned     = %b expected=%b",
                         misaligned, expected_misaligned);

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | offset=%b | read_data=%h | load_data=%h | misaligned=%b",
                    test_name,
                    address_offset,
                    read_data,
                    load_data,
                    misaligned
                );

            end

        end
    endtask


    initial begin

        funct3         = 3'b000;
        address_offset = 2'b00;
        read_data      = 32'd0;

        #1;


        // =========================================================
        // Palabra utilizada:
        //
        // read_data = 0x80A53344
        //
        // byte 0 = 44
        // byte 1 = 33
        // byte 2 = A5
        // byte 3 = 80
        // =========================================================


        // =========================================================
        // LB - SIGNED BYTE
        // =========================================================

        check_case(
            3'b000,
            2'b00,
            32'h80A53344,
            32'h00000044,
            1'b0,
            "LB BYTE 0 POSITIVE"
        );

        check_case(
            3'b000,
            2'b01,
            32'h80A53344,
            32'h00000033,
            1'b0,
            "LB BYTE 1 POSITIVE"
        );

        check_case(
            3'b000,
            2'b10,
            32'h80A53344,
            32'hFFFFFFA5,
            1'b0,
            "LB BYTE 2 NEGATIVE"
        );

        check_case(
            3'b000,
            2'b11,
            32'h80A53344,
            32'hFFFFFF80,
            1'b0,
            "LB BYTE 3 NEGATIVE"
        );


        // =========================================================
        // LBU - UNSIGNED BYTE
        // =========================================================

        check_case(
            3'b100,
            2'b00,
            32'h80A53344,
            32'h00000044,
            1'b0,
            "LBU BYTE 0"
        );

        check_case(
            3'b100,
            2'b01,
            32'h80A53344,
            32'h00000033,
            1'b0,
            "LBU BYTE 1"
        );

        check_case(
            3'b100,
            2'b10,
            32'h80A53344,
            32'h000000A5,
            1'b0,
            "LBU BYTE 2"
        );

        check_case(
            3'b100,
            2'b11,
            32'h80A53344,
            32'h00000080,
            1'b0,
            "LBU BYTE 3"
        );


        // =========================================================
        // LH - SIGNED HALFWORD
        //
        // offset 00 -> 3344
        // offset 10 -> 80A5
        // =========================================================

        check_case(
            3'b001,
            2'b00,
            32'h80A53344,
            32'h00003344,
            1'b0,
            "LH LOWER POSITIVE"
        );

        check_case(
            3'b001,
            2'b10,
            32'h80A53344,
            32'hFFFF80A5,
            1'b0,
            "LH UPPER NEGATIVE"
        );


        // =========================================================
        // LH DESALINEADOS
        // =========================================================

        check_case(
            3'b001,
            2'b01,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LH MISALIGNED OFFSET 01"
        );

        check_case(
            3'b001,
            2'b11,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LH MISALIGNED OFFSET 11"
        );


        // =========================================================
        // LHU - UNSIGNED HALFWORD
        // =========================================================

        check_case(
            3'b101,
            2'b00,
            32'h80A53344,
            32'h00003344,
            1'b0,
            "LHU LOWER"
        );

        check_case(
            3'b101,
            2'b10,
            32'h80A53344,
            32'h000080A5,
            1'b0,
            "LHU UPPER"
        );


        // =========================================================
        // LHU DESALINEADOS
        // =========================================================

        check_case(
            3'b101,
            2'b01,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LHU MISALIGNED OFFSET 01"
        );

        check_case(
            3'b101,
            2'b11,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LHU MISALIGNED OFFSET 11"
        );


        // =========================================================
        // LW
        // =========================================================

        check_case(
            3'b010,
            2'b00,
            32'h80A53344,
            32'h80A53344,
            1'b0,
            "LW ALIGNED"
        );


        check_case(
            3'b010,
            2'b01,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LW MISALIGNED OFFSET 01"
        );

        check_case(
            3'b010,
            2'b10,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LW MISALIGNED OFFSET 10"
        );

        check_case(
            3'b010,
            2'b11,
            32'h80A53344,
            32'h00000000,
            1'b1,
            "LW MISALIGNED OFFSET 11"
        );


        // =========================================================
        // FUNCT3 INVÁLIDO
        // =========================================================

        check_case(
            3'b111,
            2'b00,
            32'hDEADBEEF,
            32'h00000000,
            1'b0,
            "INVALID FUNCT3"
        );


        $display("PASS: load_unit");
        $finish;

    end

endmodule
