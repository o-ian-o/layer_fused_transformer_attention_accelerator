module layer_fused_attention #(
    parameter int N = 4,
    parameter int D = 4,
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH = 40,
    parameter int OUTPUT_WIDTH = 16
) (
    input  logic clk,
    input  logic reset,
    input  logic start,

    input  logic signed [DATA_WIDTH-1:0]
        q [0:N-1][0:D-1],

    input  logic signed [DATA_WIDTH-1:0]
        k [0:N-1][0:D-1],

    input  logic signed [DATA_WIDTH-1:0]
        v [0:N-1][0:D-1],

    output logic signed [OUTPUT_WIDTH-1:0]
        output_matrix [0:N-1][0:D-1],

    output logic busy,
    output logic done
);

    // ------------------------------------------
    // Internal signals
    // ------------------------------------------

    logic qk_start;
    logic qk_busy;
    logic qk_done;

    logic signed [ACC_WIDTH-1:0]
        qk_scores [0:N-1][0:N-1];

    logic signed [ACC_WIDTH-1:0]
        scaled_scores [0:N-1][0:N-1];

    logic [15:0]
        attention_weights [0:N-1][0:N-1];


    // ------------------------------------------
    // Controller states
    // ------------------------------------------

    typedef enum logic {
        IDLE,
        WAIT_QK
    } state_t;

    state_t state;


    // ------------------------------------------
    // Stage 1: QK^T matrix multiplication
    // ------------------------------------------

    qk_matmul #(
        .N(N),
        .D(D),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_qk_matmul (
        .clk(clk),
        .reset(reset),
        .start(qk_start),
        .q(q),
        .k(k),
        .scores(qk_scores),
        .busy(qk_busy),
        .done(qk_done)
    );


    // ------------------------------------------
    // Stage 2: Scale attention scores
    // ------------------------------------------

    scale_unit #(
        .N(N),
        .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(8),
        .OUT_WIDTH(ACC_WIDTH),
        .SCALE_DENOM(2)
    ) u_scale_unit (
        .scores(qk_scores),
        .scaled_scores(scaled_scores)
    );


    // ------------------------------------------
    // Stage 3: Softmax
    // ------------------------------------------

    softmax #(
        .N(N),
        .SCORE_WIDTH(ACC_WIDTH),
        .WEIGHT_WIDTH(16),
        .SUM_WIDTH(20)
    ) u_softmax (
        .scaled_scores(scaled_scores),
        .weights(attention_weights)
    );


    // ------------------------------------------
    // Stage 4: Attention weights multiplied by V
    // ------------------------------------------

    attention_weighted_sum #(
        .N(N),
        .D(D),
        .WEIGHT_WIDTH(16),
        .VALUE_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) u_weighted_sum (
        .weights(attention_weights),
        .v(v),
        .output_matrix(output_matrix)
    );


    // ------------------------------------------
    // Top-level controller
    // ------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin
            state    <= IDLE;
            qk_start <= 1'b0;
            busy     <= 1'b0;
            done     <= 1'b0;
        end

        else begin

            // Default values: pulses last one cycle.
            qk_start <= 1'b0;
            done     <= 1'b0;

            case (state)

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        qk_start <= 1'b1;
                        busy     <= 1'b1;
                        state    <= WAIT_QK;

                    end

                end


                WAIT_QK: begin

                    busy <= 1'b1;

                    if (qk_done) begin

                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= IDLE;

                    end

                end


                default: begin

                    state    <= IDLE;
                    qk_start <= 1'b0;
                    busy     <= 1'b0;
                    done     <= 1'b0;

                end

            endcase

        end

    end

endmodule