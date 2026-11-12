`timescale 1ns / 1ps

module clk_wiz_0 (
    output logic clk_out1,
    output logic locked,
    input  logic clk_in1
);

    logic [3:0] lock_counter;

    initial begin
        clk_out1    = 1'b0;
        locked      = 1'b0;
        lock_counter = 4'd0;
    end


    // Divide 100 MHz por 2.
    always @(posedge clk_in1) begin

        clk_out1 <=
            ~clk_out1;

        if (!locked) begin

            if (lock_counter == 4'd5) begin

                locked <=
                    1'b1;

            end
            else begin

                lock_counter <=
                    lock_counter + 1'b1;

            end

        end

    end

endmodule
