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
    (* use_dsp = "yes" *) logic signed [ACC_WIDTH-1:0] accumulator;

    typedef enum logic [1:0] {IDLE, COMPUTE} state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            i <= 0; j <= 0; k <= 0;
            accumulator <= '0;
            busy <= 1'b0; done <= 1'b0;
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
                        i <= 0; j <= 0; k <= 0;
                        accumulator <= '0;
                        busy <= 1'b1;
                        state <= COMPUTE;
                    end else begin
                        busy <= 1'b0;
                    end
                end
                COMPUTE: begin
                    if (k == N-1) begin
                        // Final MAC and shift for this output element
                        output_matrix[i][j] <= (accumulator + ($signed({1'b0, weights[i][k]}) * $signed(v[k][j]))) >>> 15;
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
                        accumulator <= accumulator + ($signed({1'b0, weights[i][k]}) * $signed(v[k][j]));
                        k <= k + 1;
                    end
                end
            endcase
        end
    end
endmodule