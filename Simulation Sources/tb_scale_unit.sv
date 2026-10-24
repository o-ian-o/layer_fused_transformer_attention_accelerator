`timescale 1ns / 1ps

module tb_scale_unit;

    localparam int N = 4;
    localparam int ACC_WIDTH = 40;
    localparam int FRAC_BITS = 8;
    localparam int OUT_WIDTH = 40;
    localparam int SCALE_DENOM = 2;

    logic signed [ACC_WIDTH-1:0] scores
                       [0:N-1][0:N-1];

    logic signed [OUT_WIDTH-1:0] scaled_scores
                       [0:N-1][0:N-1];

    int expected [0:N-1][0:N-1];

    scale_unit #(
        .N(N),
        .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .OUT_WIDTH(OUT_WIDTH),
        .SCALE_DENOM(SCALE_DENOM)
    ) dut (
        .scores(scores),
        .scaled_scores(scaled_scores)
    );

    initial begin

        // Input score matrix.
        scores[0][0] = 4;
        scores[0][1] = 6;
        scores[0][2] = 3;
        scores[0][3] = 7;

        scores[1][0] = 2;
        scores[1][1] = 2;
        scores[1][2] = 3;
        scores[1][3] = 1;

        scores[2][0] = 2;
        scores[2][1] = 2;
        scores[2][2] = 2;
        scores[2][3] = 2;

        scores[3][0] = 4;
        scores[3][1] = 2;
        scores[3][2] = 5;
        scores[3][3] = 1;

        // Expected output in Q8 fixed-point representation.
        expected[0][0] = 512;
        expected[0][1] = 768;
        expected[0][2] = 384;
        expected[0][3] = 896;

        expected[1][0] = 256;
        expected[1][1] = 256;
        expected[1][2] = 384;
        expected[1][3] = 128;

        expected[2][0] = 256;
        expected[2][1] = 256;
        expected[2][2] = 256;
        expected[2][3] = 256;

        expected[3][0] = 512;
        expected[3][1] = 256;
        expected[3][2] = 640;
        expected[3][3] = 128;

        #1;

        $display("\nScaled output matrix (Q8 integers):");

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin

                $write("%0d ", scaled_scores[i][j]);

                if (scaled_scores[i][j] !== expected[i][j]) begin
                    $error(
                        "Mismatch at [%0d][%0d]: got %0d, expected %0d",
                        i, j,
                        scaled_scores[i][j],
                        expected[i][j]
                    );
                end

            end

            $display("");
        end

        $display("\nScaling test completed.");

        #10;
        $finish;

    end

endmodule

