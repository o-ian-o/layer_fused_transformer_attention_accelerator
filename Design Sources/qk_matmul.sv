module qk_matmul #(
    parameter int N = 4,
    parameter int D = 64,
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH = 40
) (
    input  logic clk,
    input  logic reset,
    input  logic start,

    input  logic signed [DATA_WIDTH-1:0] q [0:N-1][0:D-1],
    input  logic signed [DATA_WIDTH-1:0] k [0:N-1][0:D-1],

    output logic signed [ACC_WIDTH-1:0] scores [0:N-1][0:N-1],
    output logic busy,
    output logic done
);

    typedef enum logic {
        IDLE,
        COMPUTE
    } state_t;

    state_t state;

    integer i, j, d;

    logic signed [2*DATA_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0] accumulator;

    // Combinational multiplier.
    // Indices are checked to avoid invalid array accesses.
    always_comb begin
        product = '0;

        if (state == COMPUTE &&
            i >= 0 && i < N &&
            j >= 0 && j < N &&
            d >= 0 && d < D) begin

            product = q[i][d] * k[j][d];
        end
    end

    // Sequential control and accumulation.
    always_ff @(posedge clk) begin
        if (reset) begin
            state       <= IDLE;
            i           <= 0;
            j           <= 0;
            d           <= 0;
            accumulator <= '0;
            busy        <= 1'b0;
            done        <= 1'b0;

            for (int r = 0; r < N; r++) begin
                for (int c = 0; c < N; c++) begin
                    scores[r][c] <= '0;
                end
            end
        end
        else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        i           <= 0;
                        j           <= 0;
                        d           <= 0;
                        accumulator <= '0;
                        busy        <= 1'b1;
                        state       <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    busy <= 1'b1;

                    if (d == D-1) begin
                        // Include the final product in the score.
                        scores[i][j] <= accumulator + product;

                        accumulator <= '0;
                        d           <= 0;

                        if (j == N-1) begin
                            j <= 0;

                            if (i == N-1) begin
                                state <= IDLE;
                                busy  <= 1'b0;
                                done  <= 1'b1;
                            end
                            else begin
                                i <= i + 1;
                            end
                        end
                        else begin
                            j <= j + 1;
                        end
                    end
                    else begin
                        accumulator <= accumulator + product;
                        d           <= d + 1;
                    end
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                end

            endcase
        end
    end

endmodule

