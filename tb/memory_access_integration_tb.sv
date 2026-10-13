`timescale 1ns / 1ps

module memory_access_integration_tb;

    logic        clk;

    logic [31:0] address;
    logic [2:0]  funct3;
    logic [31:0] store_data;

    logic        store_request;

    logic [31:0] store_write_data;
    logic [3:0]  store_byte_enable;
    logic        store_misaligned;

    logic        memory_write_enable;
    logic [31:0] memory_read_data;

    logic [31:0] load_data;
    logic        load_misaligned;


    // =============================================================
    // STORE UNIT
    // =============================================================

    store_unit store_unit_dut (
        .funct3         (funct3),
        .address_offset (address[1:0]),
        .store_data     (store_data),

        .write_data     (store_write_data),
        .byte_enable    (store_byte_enable),
        .misaligned     (store_misaligned)
    );


    // Solo permitimos escribir si:
    // - realmente estamos ejecutando un store
    // - el acceso está alineado

    assign memory_write_enable =
        store_request && !store_misaligned;


    // =============================================================
    // DATA MEMORY
    // =============================================================

    data_memory #(
        .DEPTH(256)
    ) data_memory_dut (
        .clk          (clk),

        .address      (address),

        .write_data   (store_write_data),
        .write_enable (memory_write_enable),
        .byte_enable  (store_byte_enable),

        .read_data    (memory_read_data)
    );


    // =============================================================
    // LOAD UNIT
    // =============================================================

    load_unit load_unit_dut (
        .funct3         (funct3),
        .address_offset (address[1:0]),
        .read_data      (memory_read_data),

        .load_data      (load_data),
        .misaligned     (load_misaligned)
    );


    always #5 clk = ~clk;


    // =============================================================
    // TASK PARA STORE
    // =============================================================

    task automatic perform_store (
        input logic [31:0] test_address,
        input logic [2:0]  test_funct3,
        input logic [31:0] test_store_data,
        input string       test_name
    );
        begin

            @(negedge clk);

            address       = test_address;
            funct3        = test_funct3;
            store_data    = test_store_data;
            store_request = 1'b1;

            #1;

            if (store_misaligned) begin
                $display(
                    "FAIL: %s unexpectedly misaligned",
                    test_name
                );
                $fatal;
            end

            @(posedge clk);
            #1;

            store_request = 1'b0;

            $display(
                "PASS: %s | address=%h | write_data=%h | byte_enable=%b",
                test_name,
                test_address,
                store_write_data,
                store_byte_enable
            );

        end
    endtask


    // =============================================================
    // TASK PARA LOAD
    // =============================================================

    task automatic perform_load (
        input logic [31:0] test_address,
        input logic [2:0]  test_funct3,
        input logic [31:0] expected_load_data,
        input string       test_name
    );
        begin

            @(negedge clk);

            store_request = 1'b0;
            address       = test_address;
            funct3        = test_funct3;

            #1;

            if (
                load_data !== expected_load_data ||
                load_misaligned !== 1'b0
            ) begin

                $display("FAIL: %s", test_name);
                $display(
                    "  address=%h funct3=%b",
                    test_address,
                    test_funct3
                );
                $display(
                    "  memory_read_data=%h",
                    memory_read_data
                );
                $display(
                    "  load_data=%h expected=%h",
                    load_data,
                    expected_load_data
                );
                $display(
                    "  misaligned=%b",
                    load_misaligned
                );

                $fatal;

            end
            else begin

                $display(
                    "PASS: %s | address=%h | memory=%h | load_data=%h",
                    test_name,
                    test_address,
                    memory_read_data,
                    load_data
                );

            end

        end
    endtask


    initial begin

        clk           = 1'b0;
        address       = 32'd0;
        funct3        = 3'd0;
        store_data    = 32'd0;
        store_request = 1'b0;


        // =========================================================
        // 1. SW
        //
        // Guardamos:
        //
        // 0x80A53344
        //
        // en la palabra que comienza en 0x20.
        // =========================================================

        perform_store(
            32'h00000020,
            3'b010,
            32'h80A53344,
            "SW INITIAL WORD"
        );


        // =========================================================
        // 2. LW
        // =========================================================

        perform_load(
            32'h00000020,
            3'b010,
            32'h80A53344,
            "LW COMPLETE WORD"
        );


        // =========================================================
        // 3. LB BYTE 0
        //
        // byte 0 = 44
        // =========================================================

        perform_load(
            32'h00000020,
            3'b000,
            32'h00000044,
            "LB BYTE 0"
        );


        // =========================================================
        // 4. LB BYTE 2
        //
        // byte 2 = A5
        // signed -> FFFFFFA5
        // =========================================================

        perform_load(
            32'h00000022,
            3'b000,
            32'hFFFFFFA5,
            "LB BYTE 2 SIGNED"
        );


        // =========================================================
        // 5. LBU BYTE 2
        //
        // byte 2 = A5
        // unsigned -> 000000A5
        // =========================================================

        perform_load(
            32'h00000022,
            3'b100,
            32'h000000A5,
            "LBU BYTE 2 UNSIGNED"
        );


        // =========================================================
        // 6. LH LOWER
        //
        // bytes 0 y 1 = 3344
        // =========================================================

        perform_load(
            32'h00000020,
            3'b001,
            32'h00003344,
            "LH LOWER"
        );


        // =========================================================
        // 7. LH UPPER
        //
        // bytes 2 y 3 = 80A5
        // signed -> FFFF80A5
        // =========================================================

        perform_load(
            32'h00000022,
            3'b001,
            32'hFFFF80A5,
            "LH UPPER SIGNED"
        );


        // =========================================================
        // 8. LHU UPPER
        //
        // unsigned -> 000080A5
        // =========================================================

        perform_load(
            32'h00000022,
            3'b101,
            32'h000080A5,
            "LHU UPPER UNSIGNED"
        );


        // =========================================================
        // 9. SB EN BYTE 1
        //
        // memoria antes:
        //
        // 80 A5 33 44
        //
        // store_data[7:0] = EE
        //
        // queda:
        //
        // 80 A5 EE 44
        //
        // palabra = 80A5EE44
        // =========================================================

        perform_store(
            32'h00000021,
            3'b000,
            32'h123456EE,
            "SB BYTE 1"
        );


        perform_load(
            32'h00000020,
            3'b010,
            32'h80A5EE44,
            "LW AFTER SB"
        );


        // =========================================================
        // 10. LBU DEL BYTE MODIFICADO
        // =========================================================

        perform_load(
            32'h00000021,
            3'b100,
            32'h000000EE,
            "LBU AFTER SB"
        );


        // =========================================================
        // 11. SH EN MITAD SUPERIOR
        //
        // memoria antes:
        //
        // 80A5EE44
        //
        // escribimos ABCD en bytes 2 y 3.
        //
        // queda:
        //
        // ABCDEE44
        // =========================================================

        perform_store(
            32'h00000022,
            3'b001,
            32'h1234ABCD,
            "SH UPPER"
        );


        perform_load(
            32'h00000020,
            3'b010,
            32'hABCDEE44,
            "LW AFTER SH"
        );


        // =========================================================
        // 12. LHU DEL HALFWORD MODIFICADO
        // =========================================================

        perform_load(
            32'h00000022,
            3'b101,
            32'h0000ABCD,
            "LHU AFTER SH"
        );


        // =========================================================
        // 13. STORE DESALINEADO
        //
        // SH en dirección 0x21.
        //
        // No debe escribir memoria.
        // =========================================================

        @(negedge clk);

        address       = 32'h00000021;
        funct3        = 3'b001;
        store_data    = 32'h00001234;
        store_request = 1'b1;

        #1;

        if (
            store_misaligned !== 1'b1 ||
            memory_write_enable !== 1'b0
        ) begin

            $display("FAIL: MISALIGNED SH BLOCK");
            $fatal;
        end

        @(posedge clk);
        #1;

        store_request = 1'b0;

        $display(
            "PASS: MISALIGNED SH BLOCKED | misaligned=%b | memory_write_enable=%b",
            store_misaligned,
            memory_write_enable
        );


        // Debe seguir intacta.

        perform_load(
            32'h00000020,
            3'b010,
            32'hABCDEE44,
            "MEMORY PRESERVED AFTER MISALIGNED SH"
        );


        $display("PASS: memory_access_integration");
        $finish;

    end

endmodule

