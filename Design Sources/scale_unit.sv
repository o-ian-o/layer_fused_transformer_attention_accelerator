module scale_unit #(
    parameter int N = 4,
    parameter int ACC_WIDTH = 40,
    parameter int FRAC_BITS = 8,
    parameter int OUT_WIDTH = 40,
    parameter int SCALE_DENOM = 2
) (
    input  logic signed [ACC_WIDTH-1:0] scores
                      [0:N-1][0:N-1],

    output logic signed [OUT_WIDTH-1:0] scaled_scores
                      [0:N-1][0:N-1]
);

    always_comb begin

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin

                // Convert the integer score into fixed-point format.
                // Then divide by the scaling denominator.
                scaled_scores[i][j] =
                    (scores[i][j] <<< FRAC_BITS) / SCALE_DENOM;

            end
        end

    end

endmodule

