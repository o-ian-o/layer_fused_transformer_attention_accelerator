`timescale 1ns / 1ps

module tb_exp_lut;

    logic [39:0] delta_q8;
    logic [15:0] exp_q15;

    exp_lut dut (
        .delta_q8(delta_q8),
        .exp_q15(exp_q15)
    );

    initial begin

        $display("\nExponential LUT Test");

        // Test 1: exp(0) = 1
        delta_q8 = 40'd0;
        #5;

        $display(
            "Delta = 0.0, Output Q15 = %0d",
            exp_q15
        );

        if (exp_q15 !== 16'd32768)
            $error("Test 1 FAILED");

        // Test 2: exp(-1)
        delta_q8 = 40'd256;
        #5;

        $display(
            "Delta = 1.0, Output Q15 = %0d",
            exp_q15
        );

        if (exp_q15 !== 16'd12055)
            $error("Test 2 FAILED");

        // Test 3: exp(-2)
        delta_q8 = 40'd512;
        #5;

        $display(
            "Delta = 2.0, Output Q15 = %0d",
            exp_q15
        );

        if (exp_q15 !== 16'd4435)
            $error("Test 3 FAILED");

        // Test 4: exp(-4)
        delta_q8 = 40'd1024;
        #5;

        $display(
            "Delta = 4.0, Output Q15 = %0d",
            exp_q15
        );

        if (exp_q15 !== 16'd600)
            $error("Test 4 FAILED");

        // Test 5: exp(-8)
        delta_q8 = 40'd2048;
        #5;

        $display(
            "Delta = 8.0, Output Q15 = %0d",
            exp_q15
        );

        if (exp_q15 !== 16'd11)
            $error("Test 5 FAILED");

        // Test 6: Saturation above 8.0
        delta_q8 = 40'd2560;
        #5;

        $display(
            "Delta = 10.0, Output Q15 = %0d",
            exp_q15
        );

        if (exp_q15 !== 16'd11)
            $error("Test 6 FAILED");

        $display("\nExponential LUT test completed.");

        #10;
        $finish;

    end

endmodule

