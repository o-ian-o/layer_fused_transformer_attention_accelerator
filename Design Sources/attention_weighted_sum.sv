module attention_weighted_sum #(
    parameter int N = 4,
    parameter int D = 4,
    parameter int WEIGHT_WIDTH = 16,
    parameter int VALUE_WIDTH = 16,
    parameter int ACC_WIDTH = 40,
    parameter int OUTPUT_WIDTH = 16
) (
    input  logic [WEIGHT_WIDTH-1:0]
        weights [0:N-1][0:N-1],

    input  logic signed [VALUE_WIDTH-1:0]
        v [0:N-1][0:D-1],

    output logic signed [OUTPUT_WIDTH-1:0]
        output_matrix [0:N-1][0:D-1]
);

    logic signed [ACC_WIDTH-1:0] accumulator;

    logic signed [ACC_WIDTH-1:0]
        product;

    always_comb begin

        for (int i = 0; i < N; i++) begin

            for (int j = 0; j < D; j++) begin

                accumulator = '0;

                for (int k = 0; k < N; k++) begin

                    product =
                        $signed({1'b0, weights[i][k]}) *
                        $signed(v[k][j]);

                    accumulator = accumulator + product;

                end

                // Convert from Q15 back to integer scale.
                output_matrix[i][j] =
                    accumulator >>> 15;

            end

        end

    end

endmodule

