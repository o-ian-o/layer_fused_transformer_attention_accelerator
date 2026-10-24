`timescale 1ns / 1ps

module tb_softmax;

    localparam int N = 4;
    localparam int SCORE_WIDTH = 40;
    localparam int WEIGHT_WIDTH = 16;
    localparam int SUM_WIDTH = 20;

    logic signed [SCORE_WIDTH-1:0]
        scaled_scores [0:N-1][0:N-1];

    logic [WEIGHT_WIDTH-1:0]
        weights [0:N-1][0:N-1];

    int row_sum;


    softmax #(
        .N(N),
        .SCORE_WIDTH(SCORE_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .SUM_WIDTH(SUM_WIDTH)
    ) dut (
        .scaled_scores(scaled_scores),
        .weights(weights)
    );


    initial begin

        $display("\nStarting Softmax testbench");


        // Row 0: [2.0, 3.0, 1.5, 3.5]
        scaled_scores[0][0] = 512;
        scaled_scores[0][1] = 768;
        scaled_scores[0][2] = 384;
        scaled_scores[0][3] = 896;


        // Row 1: [1.0, 1.0, 1.5, 0.5]
        scaled_scores[1][0] = 256;
        scaled_scores[1][1] = 256;
        scaled_scores[1][2] = 384;
        scaled_scores[1][3] = 128;


        // Row 2: [1.0, 1.0, 1.0, 1.0]
        scaled_scores[2][0] = 256;
        scaled_scores[2][1] = 256;
        scaled_scores[2][2] = 256;
        scaled_scores[2][3] = 256;


        // Row 3: [2.0, 1.0, 2.5, 0.5]
        scaled_scores[3][0] = 512;
        scaled_scores[3][1] = 256;
        scaled_scores[3][2] = 640;
        scaled_scores[3][3] = 128;


        // Allow combinational logic to settle.
        #10;


        $display("\nSoftmax output (Q15):");

        for (int i = 0; i < N; i++) begin

            row_sum = 0;

            for (int j = 0; j < N; j++) begin

                $write("%0d ", weights[i][j]);

                row_sum = row_sum + weights[i][j];

            end

            $display("");

            $display(
                "Row %0d weight sum = %0d",
                i, row_sum
            );

            // Each row should sum approximately to 1.0.
            // Q15 representation of 1.0 is 32768.
            if (row_sum < 32760 || row_sum > 32776) begin

                $error(
                    "Row %0d normalization failed: sum = %0d",
                    i, row_sum
                );

            end

        end


        // Equal scores should produce approximately
        // equal weights.
        for (int j = 0; j < N; j++) begin

            if (weights[2][j] < 8190 ||
                weights[2][j] > 8194) begin

                $error(
                    "Equal-score Softmax check failed at column %0d",
                    j
                );

            end

        end


        $display("\nSoftmax test completed.");

        #10;
        $finish;

    end

endmodule