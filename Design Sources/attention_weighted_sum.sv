`timescale 1ns / 1ps

module attention_weighted_sum #(
    parameter int N = 4,
    parameter int D = 64,
    parameter int WEIGHT_WIDTH = 16,
    parameter int VALUE_WIDTH = 16,
    parameter int ACC_WIDTH = 40,
    parameter int OUTPUT_WIDTH = 16
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    input  logic [WEIGHT_WIDTH-1:0] weights [0:N-1][0:N-1],
    input  logic signed [VALUE_WIDTH-1:0] v [0:N-1][0:D-1],

    output logic signed [OUTPUT_WIDTH-1:0] output_matrix [0:N-1][0:D-1],

    output logic busy,
    output logic done
);

    integer i, j, k;

    (* use_dsp = "yes" *)
    logic signed [ACC_WIDTH-1:0] accumulator;

    logic signed [WEIGHT_WIDTH:0] weight_ext;
    logic signed [VALUE_WIDTH-1:0] value_ext;
    logic signed [WEIGHT_WIDTH+VALUE_WIDTH:0] product;

    logic signed [ACC_WIDTH-1:0] product_ext;

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE
    } state_t;

    state_t state;

    // Explicitly extend unsigned weights and signed values.
    always_comb begin
        weight_ext = $signed({1'b0, weights[i][k]});
        value_ext  = v[k][j];

        product = weight_ext * value_ext;

        product_ext = {
            {(ACC_WIDTH-(WEIGHT_WIDTH+VALUE_WIDTH+1)){product[WEIGHT_WIDTH+VALUE_WIDTH]}},
            product
        };
    end

    always_ff @(posedge clk) begin

        if (reset) begin
            state <= IDLE;

            i <= 0;
            j <= 0;
            k <= 0;

            accumulator <= '0;

            busy <= 1'b0;
            done <= 1'b0;

            for (int r = 0; r < N; r++) begin
                for (int c = 0; c < D; c++) begin
                    output_matrix[r][c] <= '0;
                end
            end

        end else begin

            done <= 1'b0;

            case (state)

                IDLE: begin
                    if (start) begin
                        i <= 0;
                        j <= 0;
                        k <= 0;

                        accumulator <= '0;

                        busy <= 1'b1;
                        state <= COMPUTE;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                COMPUTE: begin
                    if (i == 0 && j == 0) begin
                         $display(
                             "AWS DEBUG: k=%0d, weight=%0d, value=%0d, product=%0d, accumulator=%0d",
                              k,
                              weights[i][k],
                              v[k][j],
                              product,
                              accumulator
                           );
                    end
                    if (k == N-1) begin

                        // Final MAC and fixed-point conversion.
                        output_matrix[i][j] <=
                            (accumulator + product_ext) >>> 15;

                        accumulator <= '0;
                        k <= 0;

                        if (j == D-1) begin
                            j <= 0;

                            if (i == N-1) begin
                                state <= IDLE;
                                busy <= 1'b0;
                                done <= 1'b1;
                            end else begin
                                i <= i + 1;
                            end

                        end else begin
                            j <= j + 1;
                        end

                    end else begin

                        accumulator <= accumulator + product_ext;
                        k <= k + 1;

                    end

                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end

            endcase
        end
    end

endmodule