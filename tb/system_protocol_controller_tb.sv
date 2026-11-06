`timescale 1ns / 1ps

module system_protocol_controller_tb;

    logic clk;
    logic reset;

    logic       rx_byte_valid;
    logic [7:0] rx_byte_data;

    logic       loader_rx_byte_valid;
    logic [7:0] loader_rx_byte_data;

    logic load_active;
    logic load_done;
    logic load_error;

    logic core_running;
    logic core_draining;
    logic core_halted;

    logic core_cycle_enable;
    logic core_reset;

    logic [4:0]  debug_register_address;
    logic [31:0] debug_register_data;

    logic [31:0] debug_memory_address;
    logic [31:0] debug_memory_data;

    logic       tx_byte_valid;
    logic [7:0] tx_byte_data;
    logic       tx_byte_ready;

    logic [2:0] status_code;
    logic       program_loaded;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    integer response_count;
    logic [7:0] response_bytes [0:127];

    integer core_cycle_count;
    integer loader_byte_count;

    integer start_count;
    integer before_cycles;
    integer timeout;

    system_protocol_controller #(
        .DATA_MEM_DEPTH (256)
    ) dut (
        .clk                    (clk),
        .reset                  (reset),

        .rx_byte_valid          (rx_byte_valid),
        .rx_byte_data           (rx_byte_data),

        .loader_rx_byte_valid   (loader_rx_byte_valid),
        .loader_rx_byte_data    (loader_rx_byte_data),

        .load_active            (load_active),
        .load_done              (load_done),
        .load_error             (load_error),

        .core_running           (core_running),
        .core_draining          (core_draining),
        .core_halted            (core_halted),

        .core_cycle_enable      (core_cycle_enable),
        .core_reset             (core_reset),

        .debug_register_address (debug_register_address),
        .debug_register_data    (debug_register_data),

        .debug_memory_address   (debug_memory_address),
        .debug_memory_data      (debug_memory_data),

        .tx_byte_valid          (tx_byte_valid),
        .tx_byte_data           (tx_byte_data),
        .tx_byte_ready          (tx_byte_ready),

        .status_code            (status_code),
        .program_loaded         (program_loaded)
    );

    always #5 clk = ~clk;

    always_comb begin
        if (debug_register_address == 5'd5)
            debug_register_data = 32'h12345678;
        else
            debug_register_data = 32'd0;

        if (debug_memory_address == 32'h00000010)
            debug_memory_data = 32'hAABBCCDD;
        else
            debug_memory_data = 32'd0;
    end

    always @(posedge clk) begin

        if (reset) begin
            response_count    = 0;
            core_cycle_count  = 0;
            loader_byte_count = 0;
        end
        else begin

            if (tx_byte_valid && tx_byte_ready) begin
                response_bytes[response_count] = tx_byte_data;
                response_count = response_count + 1;
            end

            if (core_cycle_enable)
                core_cycle_count = core_cycle_count + 1;

            if (loader_rx_byte_valid)
                loader_byte_count = loader_byte_count + 1;
        end
    end

    task automatic send_byte (
        input logic [7:0] value
    );
        begin
            @(negedge clk);
            rx_byte_data  = value;
            rx_byte_valid = 1'b1;

            @(negedge clk);
            rx_byte_valid = 1'b0;
        end
    endtask

    task automatic wait_responses (
        input integer target
    );
        begin
            timeout = 0;

            while (
                (response_count < target) &&
                (timeout < 200)
            ) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end

            if (response_count < target) begin
                $display(
                    "FAIL: response timeout target=%0d got=%0d",
                    target,
                    response_count
                );
                $fatal;
            end
        end
    endtask

    task automatic check8 (
        input string      name,
        input logic [7:0] received,
        input logic [7:0] expected
    );
        begin
            tests_run = tests_run + 1;

            if (received === expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-32s | VALUE=%02h",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-32s | VALUE=%02h expected=%02h",
                    name,
                    received,
                    expected
                );
            end
        end
    endtask

    task automatic check32 (
        input string       name,
        input logic [31:0] received,
        input logic [31:0] expected
    );
        begin
            tests_run = tests_run + 1;

            if (received === expected) begin
                tests_passed = tests_passed + 1;
                $display(
                    "PASS: %-32s | VALUE=%08h",
                    name,
                    received
                );
            end
            else begin
                tests_failed = tests_failed + 1;
                $display(
                    "FAIL: %-32s | VALUE=%08h expected=%08h",
                    name,
                    received,
                    expected
                );
            end
        end
    endtask

    initial begin

        clk           = 1'b0;
        reset         = 1'b1;
        rx_byte_valid = 1'b0;
        rx_byte_data  = 8'd0;

        load_active = 1'b0;
        load_done   = 1'b0;
        load_error  = 1'b0;

        core_running  = 1'b1;
        core_draining = 1'b0;
        core_halted   = 1'b0;

        tx_byte_ready = 1'b1;

        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // RUN sin programa -> NACK 05.
        start_count = response_count;
        send_byte(8'h52);
        wait_responses(start_count + 2);
        check8("RUN WITHOUT PROGRAM NACK", response_bytes[start_count], 8'h15);
        check8("RUN WITHOUT PROGRAM ERROR", response_bytes[start_count+1], 8'h05);

        // LOAD abstracto.
        start_count = response_count;
        send_byte(8'h4C);
        repeat (2) @(posedge clk);

        check32(
            "LOAD COMMAND FORWARDED",
            loader_byte_count,
            32'd1
        );

        load_active = 1'b1;
        repeat (2) @(posedge clk);

        @(negedge clk);
        load_active = 1'b0;
        load_done   = 1'b1;

        @(negedge clk);
        load_done = 1'b0;

        wait_responses(start_count + 1);
        check8("LOAD ACK", response_bytes[start_count], 8'h06);
        check32("PROGRAM LOADED", program_loaded, 32'd1);

        // STEP = exactamente un ciclo.
        before_cycles = core_cycle_count;
        start_count   = response_count;

        send_byte(8'h53);
        wait_responses(start_count + 1);
        repeat (2) @(posedge clk);

        check8("STEP ACK", response_bytes[start_count], 8'h06);
        check32(
            "STEP ONE CORE CYCLE",
            core_cycle_count - before_cycles,
            32'd1
        );

        // READ REGISTER x5.
        start_count = response_count;
        send_byte(8'h47);
        send_byte(8'h05);
        wait_responses(start_count + 6);

        check8("REG RESPONSE TAG", response_bytes[start_count], 8'h67);
        check8("REG RESPONSE ID",  response_bytes[start_count+1], 8'h05);
        check8("REG DATA 31:24",   response_bytes[start_count+2], 8'h12);
        check8("REG DATA 23:16",   response_bytes[start_count+3], 8'h34);
        check8("REG DATA 15:8",    response_bytes[start_count+4], 8'h56);
        check8("REG DATA 7:0",     response_bytes[start_count+5], 8'h78);

        // READ MEMORY 0x0010.
        start_count = response_count;
        send_byte(8'h4D);
        send_byte(8'h00);
        send_byte(8'h10);
        wait_responses(start_count + 7);

        check8("MEM RESPONSE TAG", response_bytes[start_count],   8'h6D);
        check8("MEM ADDR HI",      response_bytes[start_count+1], 8'h00);
        check8("MEM ADDR LO",      response_bytes[start_count+2], 8'h10);
        check8("MEM DATA 31:24",   response_bytes[start_count+3], 8'hAA);
        check8("MEM DATA 23:16",   response_bytes[start_count+4], 8'hBB);
        check8("MEM DATA 15:8",    response_bytes[start_count+5], 8'hCC);
        check8("MEM DATA 7:0",     response_bytes[start_count+6], 8'hDD);

        // QUERY DRAINING.
        core_draining = 1'b1;
        start_count = response_count;
        send_byte(8'h51);
        wait_responses(start_count + 2);
        check8("QUERY TAG",   response_bytes[start_count],   8'h71);
        check8("QUERY DRAIN", response_bytes[start_count+1], 8'h03);
        core_draining = 1'b0;

        // RUN continuo.
        start_count   = response_count;
        before_cycles = core_cycle_count;

        send_byte(8'h52);
        wait_responses(start_count + 1);
        check8("RUN ACK", response_bytes[start_count], 8'h06);

        repeat (5) @(posedge clk);

        if (core_cycle_count <= before_cycles) begin
            $display("FAIL: RUN did not enable core");
            $fatal;
        end

        core_halted  = 1'b1;
        core_running = 1'b0;

        repeat (3) @(posedge clk);

        check32(
            "RUN STOPS ON HALT",
            core_cycle_enable,
            32'd0
        );

        // QUERY HALTED.
        start_count = response_count;
        send_byte(8'h51);
        wait_responses(start_count + 2);
        check8("HALTED TAG",   response_bytes[start_count],   8'h71);
        check8("HALTED STATE", response_bytes[start_count+1], 8'h04);

        // Registro inválido.
        start_count = response_count;
        send_byte(8'h47);
        send_byte(8'h20);
        wait_responses(start_count + 2);
        check8("BAD REG NACK", response_bytes[start_count],   8'h15);
        check8("BAD REG CODE", response_bytes[start_count+1], 8'h02);

        // Comando desconocido.
        start_count = response_count;
        send_byte(8'h99);
        wait_responses(start_count + 2);
        check8("UNKNOWN NACK", response_bytes[start_count],   8'h15);
        check8("UNKNOWN CODE", response_bytes[start_count+1], 8'h01);

        $display("");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);

        if (tests_failed == 0)
            $display("PASS: system_protocol_controller");
        else
            $fatal(1, "FAIL: system_protocol_controller");

        $finish;
    end

endmodule
