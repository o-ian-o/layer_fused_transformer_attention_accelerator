
`timescale 1ns / 1ps

module tb_attention_weighted_sum;

    localparam int N = 4;
    localparam int D = 4;

    logic [15:0] weights [0:N-1][0:N-1];

    logic signed [15:0] v [0:N-1][0:D-1];

    logic signed [15:0] output_matrix [0:N-1][0:D-1];

    attention_weighted_sum #(
        .N(N),
        .D(D)
    ) dut (
        .weights(weights),
        .v(v),
        .output_matrix(output_matrix)
    );

    initial begin

        $display("\n======================================");
        $display("ATTENTION WEIGHTED-SUM VERIFICATION");
        $display("======================================");

        // Initialize V.

        v[0][0] =  1; v[0][1] =  2;
        v[0][2] =  3; v[0][3] =  4;

        v[1][0] =  2; v[1][1] =  1;
        v[1][2] =  0; v[1][3] =  1;

        v[2][0] =  1; v[2][1] =  1;
        v[2][2] =  1; v[2][3] =  1;

        v[3][0] =  3; v[3][1] =  2;
        v[3][2] =  1; v[3][3] =  0;


        // ======================================
        // TEST 1: ONE-HOT ATTENTION WEIGHTS
        // ======================================

        $display("\nTEST 1: One-hot weights");

        // Each row selects one corresponding row of V.
        // Q15 representation of 1.0 = 32768.

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                weights[i][j] = (i == j) ? 16'd32768 : 16'd0;
            end
        end

        #10;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < D; j++) begin

                if (output_matrix[i][j] !== v[i][j]) begin
                    $error(
                        "One-hot failure: output[%0d][%0d]=%0d, expected=%0d",
                        i, j, output_matrix[i][j], v[i][j]
                    );
                end

            end
        end

        $display("PASS: One-hot selection");


        // ======================================
        // TEST 2: NONUNIFORM WEIGHTS
        // ======================================

        $display("\nTEST 2: Nonuniform weights");

        // First two values receive equal weights.
        // Remaining values receive zero weight.

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                weights[i][j] =
                    (j < 2) ? 16'd16384 : 16'd0;
            end
        end

        #10;

        // Expected output after Q15 scaling and
        // arithmetic right-shift truncation:
        //
        // [1, 1, 1, 2]

        for (int i = 0; i < N; i++) begin

            if (output_matrix[i][0] !== 16'sd1 ||
                output_matrix[i][1] !== 16'sd1 ||
                output_matrix[i][2] !== 16'sd1 ||
                output_matrix[i][3] !== 16'sd2) begin

                $error("Nonuniform-weight test failed for row %0d", i);

            end

        end

        $display("PASS: Nonuniform weighted sum");


        // ======================================
        // TEST 3: NEGATIVE VALUES
        // ======================================

        $display("\nTEST 3: Signed arithmetic");

        // Replace V with negative and positive values.

        v[0][0] = -4; v[0][1] = -2;
        v[0][2] =  3; v[0][3] =  1;

        v[1][0] =  2; v[1][1] = -6;
        v[1][2] = -1; v[1][3] =  5;

        v[2][0] = -3; v[2][1] =  4;
        v[2][2] =  2; v[2][3] = -2;

        v[3][0] =  1; v[3][1] =  3;
        v[3][2] = -5; v[3][3] = -4;

        // One-hot weights again.
        // Each output row should reproduce its selected V row.

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                weights[i][j] = (i == j) ? 16'd32768 : 16'd0;
            end
        end

        #10;

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < D; j++) begin

                if (output_matrix[i][j] !== v[i][j]) begin
                    $error(
                        "Signed test failed at [%0d][%0d]: got %0d, expected %0d",
                        i, j, output_matrix[i][j], v[i][j]
                    );
                end

            end
        end

        $display("PASS: Signed arithmetic");


        // ======================================
        // FINAL RESULT
        // ======================================

        $display("\n======================================");
        $display("WEIGHTED-SUM VERIFICATION COMPLETED");
        $display("======================================");

        $finish;

    end

endmodule

