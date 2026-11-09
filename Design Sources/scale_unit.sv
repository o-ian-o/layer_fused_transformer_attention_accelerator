module scale_unit #(
    parameter int N = 4,
    parameter int ACC_WIDTH = 40,
    parameter int FRAC_BITS = 8,
    parameter int OUT_WIDTH = 40,
    // For Q/K quantization scale S=128 and D=64:
    // Q8 score = (Qint*Kint^T) * 2^8 / (128^2 * sqrt(64))
    //          = raw_score / 512.
    // Since this module shifts left by FRAC_BITS, denominator is 512*256=131072.
    parameter int SCALE_DENOM = 131072
) (
    input  logic signed [ACC_WIDTH-1:0] scores [0:N-1][0:N-1],
    output logic signed [OUT_WIDTH-1:0] scaled_scores [0:N-1][0:N-1]
);
    localparam int WIDE_WIDTH = ACC_WIDTH + FRAC_BITS + 1;
    logic signed [WIDE_WIDTH-1:0] wide_score;
    logic signed [WIDE_WIDTH-1:0] wide_scaled;

    always_comb begin
        wide_score = '0;
        wide_scaled = '0;
        for (int i=0; i<N; i++) begin
            for (int j=0; j<N; j++) begin
                wide_score = {{(WIDE_WIDTH-ACC_WIDTH){scores[i][j][ACC_WIDTH-1]}}, scores[i][j]};
                wide_scaled = (wide_score <<< FRAC_BITS) / SCALE_DENOM;
                scaled_scores[i][j] = wide_scaled[OUT_WIDTH-1:0];
            end
        end
    end
endmodule
