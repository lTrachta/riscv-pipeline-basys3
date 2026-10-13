`timescale 1ns / 1ps

module data_memory_tb;

    logic        clk;
    logic [31:0] address;
    logic [31:0] write_data;
    logic        write_enable;
    logic [3:0]  byte_enable;
    logic [31:0] read_data;


    data_memory #(
        .DEPTH(256)
    ) dut (
        .clk          (clk),
        .address      (address),
        .write_data   (write_data),
        .write_enable (write_enable),
        .byte_enable  (byte_enable),
        .read_data    (read_data)
    );


    always #5 clk = ~clk;


    task automatic check_read (
        input logic [31:0] test_address,
        input logic [31:0] expected_data,
        input string       test_name
    );
        begin
            address = test_address;
            #1;

            if (read_data !== expected_data) begin
                $display("FAIL: %s", test_name);
                $display("  address   = %h", test_address);
                $display("  read_data = %h", read_data);
                $display("  expected  = %h", expected_data);
                $fatal;
            end
            else begin
                $display(
                    "PASS: %s | address=%h | read_data=%h",
                    test_name,
                    test_address,
                    read_data
                );
            end
        end
    endtask


    task automatic write_memory (
        input logic [31:0] test_address,
        input logic [31:0] test_write_data,
        input logic [3:0]  test_byte_enable
    );
        begin
            @(negedge clk);

            address      = test_address;
            write_data   = test_write_data;
            byte_enable  = test_byte_enable;
            write_enable = 1'b1;

            @(posedge clk);
            #1;

            write_enable = 1'b0;
        end
    endtask


    initial begin

        clk          = 1'b0;
        address      = 32'd0;
        write_data   = 32'd0;
        write_enable = 1'b0;
        byte_enable  = 4'b0000;


        // =========================================================
        // 1. ESCRITURA COMPLETA
        //
        // Dirección 0x10 = 16 decimal.
        // word_index = 16 / 4 = 4.
        // =========================================================

        write_memory(
            32'h00000010,
            32'h11223344,
            4'b1111
        );

        check_read(
            32'h00000010,
            32'h11223344,
            "FULL WORD WRITE"
        );


        // =========================================================
        // 2. LOS BITS address[1:0] NO CAMBIAN LA PALABRA LEIDA
        //
        // 0x10, 0x11, 0x12 y 0x13 pertenecen a memory[4].
        // DMEM entrega siempre la palabra completa.
        // =========================================================

        check_read(
            32'h00000013,
            32'h11223344,
            "SAME WORD DIFFERENT BYTE ADDRESS"
        );


        // =========================================================
        // 3. ESCRIBIR BYTE 0
        //
        // 11223344 -> 112233AA
        // =========================================================

        write_memory(
            32'h00000010,
            32'h000000AA,
            4'b0001
        );

        check_read(
            32'h00000010,
            32'h112233AA,
            "WRITE BYTE 0"
        );


        // =========================================================
        // 4. ESCRIBIR BYTE 1
        //
        // 112233AA -> 1122BBAA
        // =========================================================

        write_memory(
            32'h00000010,
            32'h0000BB00,
            4'b0010
        );

        check_read(
            32'h00000010,
            32'h1122BBAA,
            "WRITE BYTE 1"
        );


        // =========================================================
        // 5. ESCRIBIR BYTE 2
        //
        // 1122BBAA -> 11CCBBAA
        // =========================================================

        write_memory(
            32'h00000010,
            32'h00CC0000,
            4'b0100
        );

        check_read(
            32'h00000010,
            32'h11CCBBAA,
            "WRITE BYTE 2"
        );


        // =========================================================
        // 6. ESCRIBIR BYTE 3
        //
        // 11CCBBAA -> DDCCBBAA
        // =========================================================

        write_memory(
            32'h00000010,
            32'hDD000000,
            4'b1000
        );

        check_read(
            32'h00000010,
            32'hDDCCBBAA,
            "WRITE BYTE 3"
        );


        // =========================================================
        // 7. HALFWORD INFERIOR
        //
        // DDCCBBAA -> DDCCEEFF
        // =========================================================

        write_memory(
            32'h00000010,
            32'h0000EEFF,
            4'b0011
        );

        check_read(
            32'h00000010,
            32'hDDCCEEFF,
            "WRITE LOWER HALFWORD"
        );


        // =========================================================
        // 8. HALFWORD SUPERIOR
        //
        // DDCCEEFF -> A5B6EEFF
        // =========================================================

        write_memory(
            32'h00000010,
            32'hA5B60000,
            4'b1100
        );

        check_read(
            32'h00000010,
            32'hA5B6EEFF,
            "WRITE UPPER HALFWORD"
        );


        // =========================================================
        // 9. OTRA ESCRITURA COMPLETA
        // =========================================================

        write_memory(
            32'h00000010,
            32'hAABBCCDD,
            4'b1111
        );

        check_read(
            32'h00000010,
            32'hAABBCCDD,
            "SECOND FULL WORD WRITE"
        );


        // =========================================================
        // 10. write_enable = 0
        //
        // Aunque cambien write_data y byte_enable,
        // la memoria NO debe modificarse.
        // =========================================================

        @(negedge clk);

        address      = 32'h00000010;
        write_data   = 32'h55555555;
        byte_enable  = 4'b1111;
        write_enable = 1'b0;

        @(posedge clk);
        #1;

        check_read(
            32'h00000010,
            32'hAABBCCDD,
            "WRITE ENABLE DISABLED"
        );


        // =========================================================
        // 11. byte_enable = 0000
        //
        // write_enable está activo, pero ningún byte está habilitado.
        // =========================================================

        @(negedge clk);

        address      = 32'h00000010;
        write_data   = 32'hFFFFFFFF;
        byte_enable  = 4'b0000;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;

        check_read(
            32'h00000010,
            32'hAABBCCDD,
            "BYTE ENABLE ZERO"
        );


        // =========================================================
        // 12. DIRECCION FUERA DE RANGO
        //
        // DEPTH = 256 palabras = 1024 bytes.
        // Primera dirección inválida = 1024 = 0x400.
        //
        // Una lectura fuera de rango debe devolver cero.
        // =========================================================

        check_read(
            32'h00000400,
            32'h00000000,
            "OUT OF RANGE READ"
        );


        // =========================================================
        // 13. ESCRITURA FUERA DE RANGO
        //
        // Debe ignorarse completamente.
        // =========================================================

        write_memory(
            32'h00000400,
            32'hDEADBEEF,
            4'b1111
        );

        check_read(
            32'h00000400,
            32'h00000000,
            "OUT OF RANGE WRITE IGNORED"
        );


        // La palabra válida anterior debe seguir intacta.

        check_read(
            32'h00000010,
            32'hAABBCCDD,
            "VALID MEMORY PRESERVED"
        );


        $display("PASS: data_memory");
        $finish;

    end

endmodule

