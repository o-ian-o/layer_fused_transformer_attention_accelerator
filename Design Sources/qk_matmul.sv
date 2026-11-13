`timescale 1ns / 1ps

module qk_matmul #(
    parameter int N = 4,
    parameter int D = 64,
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH = 40
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    // Q BRAM Interface (Read Only)
    output logic [$clog2(N*D)-1:0] q_addr,
    output logic q_en,
    input  logic signed [DATA_WIDTH-1:0] q_dout,

    // K BRAM Interface (Read Only)
    output logic [$clog2(N*D)-1:0] k_addr,
    output logic k_en,
    input  logic signed [DATA_WIDTH-1:0] k_dout,

    // Scores BRAM Interface (Write Only)
    output logic [$clog2(N*N)-1:0] score_addr,
    output logic score_en,
    output logic score_we,
    output logic signed [ACC_WIDTH-1:0] score_din,

    output logic busy,
    output logic done
);

    typedef enum logic [2:0] {
        IDLE,
        CALC_ADDR,
        WAIT_RAM,
        MAC,
        WRITE_OUT
    } state_t;

    state_t state;
    integer i, j, d;

    // Force Vivado to infer DSP48 slices for the MAC operation
    (* use_dsp = "yes" *) logic signed [ACC_WIDTH-1:0] accumulator;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            i <= 0; j <= 0; d <= 0;
            accumulator <= '0;
            q_addr <= '0; k_addr <= '0;
            q_en <= 1'b0; k_en <= 1'b0;
            score_addr <= '0; score_en <= 1'b0;
            score_we <= 1'b0; score_din <= '0;
            busy <= 1'b0; done <= 1'b0;
        end else begin
            // Default strobes to prevent latching
            q_en <= 1'b0; k_en <= 1'b0;
            score_en <= 1'b0; score_we <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        i <= 0; j <= 0; d <= 0;
                        accumulator <= '0;
                        busy <= 1'b1;
                        state <= CALC_ADDR;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                CALC_ADDR: begin
                    // Request current vector elements from BRAM
                    q_addr <= i * D + d;
                    k_addr <= j * D + d;
                    q_en <= 1'b1;
                    k_en <= 1'b1;
                    state <= WAIT_RAM;
                end

                WAIT_RAM: begin
                    // 1 cycle latency for synchronous BRAM read
                    state <= MAC;
                end

                MAC: begin
                    // Data is valid on q_dout and k_dout. Perform Multiply-Accumulate.
                    accumulator <= accumulator + (q_dout * k_dout);

                    if (d == D - 1) begin
                        state <= WRITE_OUT;
                    end else begin
                        d <= d + 1;
                        state <= CALC_ADDR;
                    end
                end

                WRITE_OUT: begin
                    // Write the completed dot product to the Scores BRAM
                    score_addr <= i * N + j;
                    score_din <= accumulator;
                    score_en <= 1'b1;
                    score_we <= 1'b1;

                    accumulator <= '0;
                    d <= 0;

                    if (j == N - 1) begin
                        j <= 0;
                        if (i == N - 1) begin
                            state <= IDLE;
                            busy <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            i <= i + 1;
                            state <= CALC_ADDR;
                        end
                    end else begin
                        j <= j + 1;
                        state <= CALC_ADDR;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule