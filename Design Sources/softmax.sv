module softmax #(
    parameter int N = 4,
    parameter int SCORE_WIDTH = 40,
    parameter int WEIGHT_WIDTH = 16,
    parameter int SUM_WIDTH = 20
) (
    input logic signed [SCORE_WIDTH-1:0]
        scaled_scores [0:N-1][0:N-1],

    output logic [WEIGHT_WIDTH-1:0]
        weights [0:N-1][0:N-1]
);

    // Maximum score for each row, in Q8.
    logic signed [SCORE_WIDTH-1:0]
        row_max [0:N-1];

    // Nonnegative score differences, in Q8.
    logic [SCORE_WIDTH-1:0]
        delta_q8 [0:N-1][0:N-1];

    // Exponential values, in Q15.
    logic [15:0]
        exp_q15 [0:N-1][0:N-1];

    // Sum of exponentials for each row.
    logic [SUM_WIDTH-1:0]
        sum_exp [0:N-1];

    // Numerator for Q15 normalization.
    logic [31:0]
        numerator [0:N-1][0:N-1];


    // --------------------------------------------------
    // Stage 1: Find each row's maximum and calculate
    //          nonnegative score differences.
    // --------------------------------------------------

    always_comb begin

        for (int i = 0; i < N; i++) begin

            row_max[i] = scaled_scores[i][0];

            for (int j = 1; j < N; j++) begin

                if (scaled_scores[i][j] > row_max[i])
                    row_max[i] = scaled_scores[i][j];

            end

            for (int j = 0; j < N; j++) begin

                delta_q8[i][j] =
                    $unsigned(row_max[i] - scaled_scores[i][j]);

            end

        end

    end


    // --------------------------------------------------
    // Stage 2: Instantiate one exponential LUT per
    //          score.
    // --------------------------------------------------

    generate
        for (genvar r = 0; r < N; r++) begin : GEN_ROW

            for (genvar c = 0; c < N; c++) begin : GEN_COL

                exp_lut u_exp_lut (
                    .delta_q8(delta_q8[r][c]),
                    .exp_q15(exp_q15[r][c])
                );

            end

        end
    endgenerate


    // --------------------------------------------------
    // Stage 3: Sum the exponential values in each row.
    // --------------------------------------------------

    always_comb begin

        for (int i = 0; i < N; i++) begin

            sum_exp[i] = '0;

            for (int j = 0; j < N; j++) begin

                sum_exp[i] =
                    sum_exp[i] + exp_q15[i][j];

            end

        end

    end


    // --------------------------------------------------
    // Stage 4: Normalize each exponential value.
    //
    // Q15 output = (exp_q15 / sum_exp) * 32768
    // --------------------------------------------------

    always_comb begin

        for (int i = 0; i < N; i++) begin

            for (int j = 0; j < N; j++) begin

                numerator[i][j] =
                    {16'b0, exp_q15[i][j]} << 15;

                if (sum_exp[i] != 0) begin

                    weights[i][j] =
                        numerator[i][j] / sum_exp[i];

                end
                else begin

                    weights[i][j] = '0;

                end

            end

        end

    end

endmodule