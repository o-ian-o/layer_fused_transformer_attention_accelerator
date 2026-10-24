`timescale 1ns / 1ps

module tb_qk_matmul;

    localparam int N = 4;
    localparam int D = 4;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH = 40;

    logic clk;
    logic reset;
    logic start;

    logic signed [DATA_WIDTH-1:0] q [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] k [0:N-1][0:D-1];

    logic signed [ACC_WIDTH-1:0] scores [0:N-1][0:N-1];

    logic busy;
    logic done;

    int expected [0:N-1][0:N-1];

    // Device under test.
    qk_matmul #(
        .N(N),
        .D(D),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .q(q),
        .k(k),
        .scores(scores),
        .busy(busy),
        .done(done)
    );

    // 10 ns clock period.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        reset = 1'b1;
        start = 1'b0;

        // Initialize Q.
        q[0][0] = 1; q[0][1] = 2;
        q[0][2] = 3; q[0][3] = 4;

        q[1][0] = 2; q[1][1] = 1;
        q[1][2] = 0; q[1][3] = 1;

        q[2][0] = 1; q[2][1] = 1;
        q[2][2] = 1; q[2][3] = 1;

        q[3][0] = 3; q[3][1] = 2;
        q[3][2] = 1; q[3][3] = 0;

        // Initialize K.
        k[0][0] = 1; k[0][1] = 0;
        k[0][2] = 1; k[0][3] = 0;

        k[1][0] = 0; k[1][1] = 1;
        k[1][2] = 0; k[1][3] = 1;

        k[2][0] = 1; k[2][1] = 1;
        k[2][2] = 0; k[2][3] = 0;

        k[3][0] = 0; k[3][1] = 0;
        k[3][2] = 1; k[3][3] = 1;

       // Expected Q * K^T.
        expected[0][0] = 4; expected[0][1] = 6;
        expected[0][2] = 3; expected[0][3] = 7;

        expected[1][0] = 2; expected[1][1] = 2;
        expected[1][2] = 3; expected[1][3] = 1;

        expected[2][0] = 2; expected[2][1] = 2;
        expected[2][2] = 2; expected[2][3] = 2;

        expected[3][0] = 4; expected[3][1] = 2;
        expected[3][2] = 5; expected[3][3] = 1;

        // Reset for two clock cycles.
        repeat (2) @(negedge clk);
        reset = 1'b0;

        // Start the operation.
        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        // Wait for completion.
        wait (done === 1'b1);
        #1;

        $display("\nQK^T output matrix:");

        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                $write("%0d ", scores[r][c]);

                if (scores[r][c] !== expected[r][c]) begin
                    $error(
                        "Mismatch at [%0d][%0d]: got %0d, expected %0d",
                        r, c, scores[r][c], expected[r][c]
                    );
                end
            end

            $display("");
        end

        $display("\nMatrix multiplication test completed.");

        #20;
        $finish;
    end

    // Simulation timeout.
    initial begin
        #10000;
        $fatal(1, "TIMEOUT: Accelerator did not finish.");
    end

endmodule
