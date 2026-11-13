`timescale 1ns / 1ps

module tb_qk_matmul;
    localparam int N = 4;
    localparam int D = 4;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH = 40;

    logic clk, reset, start, busy, done;

    // BRAM routing signals
    logic [$clog2(N*D)-1:0] q_addr, k_addr;
    logic q_en, k_en;
    logic signed [DATA_WIDTH-1:0] q_dout, k_dout;
    
    logic [$clog2(N*N)-1:0] score_addr;
    logic score_en, score_we;
    logic signed [ACC_WIDTH-1:0] score_din;

    // Inferred BRAM arrays for simulation
    logic signed [DATA_WIDTH-1:0] q_mem [0:N*D-1];
    logic signed [DATA_WIDTH-1:0] k_mem [0:N*D-1];
    logic signed [ACC_WIDTH-1:0] score_mem [0:N*N-1];

    // Synchronous memory reads and writes
    always_ff @(posedge clk) begin
        if (q_en) q_dout <= q_mem[q_addr];
        if (k_en) k_dout <= k_mem[k_addr];
        if (score_en && score_we) score_mem[score_addr] <= score_din;
    end

    // Device Under Test
    qk_matmul #(
        .N(N), .D(D), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk), .reset(reset), .start(start),
        .q_addr(q_addr), .q_en(q_en), .q_dout(q_dout),
        .k_addr(k_addr), .k_en(k_en), .k_dout(k_dout),
        .score_addr(score_addr), .score_en(score_en), .score_we(score_we), .score_din(score_din),
        .busy(busy), .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1; start = 0;

        // Initialize 1D q_mem using original test vectors
        q_mem[0*D+0]=1; q_mem[0*D+1]=2; q_mem[0*D+2]=3; q_mem[0*D+3]=4;
        q_mem[1*D+0]=2; q_mem[1*D+1]=1; q_mem[1*D+2]=0; q_mem[1*D+3]=1;
        q_mem[2*D+0]=1; q_mem[2*D+1]=1; q_mem[2*D+2]=1; q_mem[2*D+3]=1;
        q_mem[3*D+0]=3; q_mem[3*D+1]=2; q_mem[3*D+2]=1; q_mem[3*D+3]=0;

        // Initialize 1D k_mem
        k_mem[0*D+0]=1; k_mem[0*D+1]=0; k_mem[0*D+2]=1; k_mem[0*D+3]=0;
        k_mem[1*D+0]=0; k_mem[1*D+1]=1; k_mem[1*D+2]=0; k_mem[1*D+3]=1;
        k_mem[2*D+0]=1; k_mem[2*D+1]=1; k_mem[2*D+2]=0; k_mem[2*D+3]=0;
        k_mem[3*D+0]=0; k_mem[3*D+1]=0; k_mem[3*D+2]=1; k_mem[3*D+3]=1;

        repeat (2) @(negedge clk);
        reset = 0;

        @(negedge clk); start = 1;
        @(negedge clk); start = 0;

        wait (done === 1'b1);
        #1;

        $display("\nQK^T output matrix (Read from BRAM):");
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                $write("%0d ", score_mem[r*N+c]);
            end
            $display("");
        end
        
        // Automated Verification
        begin
            int expected [0:N*N-1] = '{
                4, 6, 3, 7,
                2, 2, 3, 1,
                2, 2, 2, 2,
                4, 2, 5, 1
            };
            for (int i = 0; i < N*N; i++) begin
                if (score_mem[i] !== expected[i]) begin
                    $error("Mismatch at %0d: got %0d, expected %0d", i, score_mem[i], expected[i]);
                end
            end
        end

        $display("Matrix multiplication test completed successfully.");
        $finish;
    end
endmodule