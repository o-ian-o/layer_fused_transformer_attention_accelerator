`timescale 1ns / 1ps

module tb_boundary_attention;

    localparam int N = 4;
    localparam int D = 64;
    localparam int W = 16;
    localparam int A = 40;

    logic clk = 0;
    logic reset = 0;
    logic start = 0;

    logic signed [W-1:0] q [0:N-1][0:D-1];
    logic signed [W-1:0] k [0:N-1][0:D-1];
    logic signed [W-1:0] v [0:N-1][0:D-1];

    logic signed [W-1:0] output_matrix [0:N-1][0:D-1];

    logic busy, done;

    always #5 clk = ~clk;

    layer_fused_attention #(
        .N(N),
        .D(D),
        .DATA_WIDTH(W),
        .ACC_WIDTH(A),
        .OUTPUT_WIDTH(W)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .q(q),
        .k(k),
        .v(v),
        .output_matrix(output_matrix),
        .busy(busy),
        .done(done)
    );

    task automatic run_test(input string test_name);
        begin
            @(negedge clk);
            start = 1;

            @(negedge clk);
            start = 0;

            wait(done === 1'b1);
            #1;

            if (busy !== 1'b0)
                $fatal(1, "FAIL: %s - busy did not clear", test_name);

            $display("PASS: %s", test_name);
        end
    endtask

    initial begin

        // Initial reset
        reset = 1;
        repeat(3) @(negedge clk);
        reset = 0;

        // TEST 1: All zeros
        for(int i=0; i<N; i++)
            for(int j=0; j<D; j++) begin
                q[i][j] = 0;
                k[i][j] = 0;
                v[i][j] = 0;
            end

        run_test("All-zero inputs");

        // TEST 2: Negative values
        for(int i=0; i<N; i++)
            for(int j=0; j<D; j++) begin
                q[i][j] = -10;
                k[i][j] = -5;
                v[i][j] = -20;
            end

        run_test("Negative inputs");

        // TEST 3: Large positive and negative values
        for(int i=0; i<N; i++)
            for(int j=0; j<D; j++) begin
                q[i][j] = (i % 2 == 0) ? 32767 : -32768;
                k[i][j] = (j % 2 == 0) ? 32767 : -32768;
                v[i][j] = (i % 2 == 0) ? 32767 : -32768;
            end

        run_test("Large signed inputs");

        $display("--------------------------------");
        $display("ALL BOUNDARY TESTS COMPLETED");
        $display("--------------------------------");

        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "TIMEOUT: Boundary testing did not complete");
    end

endmodule