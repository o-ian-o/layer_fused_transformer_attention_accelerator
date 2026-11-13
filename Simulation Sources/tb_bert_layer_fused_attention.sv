`timescale 1ns / 1ps

module tb_bert_layer_fused_attention;
    localparam int N = 4, D = 64, DATA_WIDTH = 16, ACC_WIDTH = 40, OUTPUT_WIDTH = 16;
    logic clk=0, reset, start;
    
    // BRAM Interfaces
    logic [$clog2(N*D)-1:0] q_addr, k_addr, v_addr, out_addr;
    logic q_en, k_en, v_en, out_en, out_we;
    logic signed [DATA_WIDTH-1:0] q_dout, k_dout, v_dout;
    logic signed [OUTPUT_WIDTH-1:0] out_din;
    logic busy, done;

    // Simulated BRAM blocks
    logic signed [DATA_WIDTH-1:0] q_mem [0:N*D-1];
    logic signed [DATA_WIDTH-1:0] k_mem [0:N*D-1];
    logic signed [DATA_WIDTH-1:0] v_mem [0:N*D-1];
    logic signed [OUTPUT_WIDTH-1:0] out_mem [0:N*D-1];

    // Temporary 2D Arrays to load the generated include file
    logic signed [DATA_WIDTH-1:0] q [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] k [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] v [0:N-1][0:D-1];

    // Synchronous memory reads/writes
    always_ff @(posedge clk) begin
        if (q_en) q_dout <= q_mem[q_addr];
        if (k_en) k_dout <= k_mem[k_addr];
        if (v_en) v_dout <= v_mem[v_addr];
        if (out_en && out_we) out_mem[out_addr] <= out_din;
    end

    always #5 clk = ~clk;

    layer_fused_attention #(
        .N(N), .D(D), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (
        .clk(clk), .reset(reset), .start(start),
        .q_addr(q_addr), .q_en(q_en), .q_dout(q_dout),
        .k_addr(k_addr), .k_en(k_en), .k_dout(k_dout),
        .v_addr(v_addr), .v_en(v_en), .v_dout(v_dout),
        .out_addr(out_addr), .out_en(out_en), .out_we(out_we), .out_din(out_din),
        .busy(busy), .done(done)
    );

    initial begin
        reset = 1; start = 0;
        
        // Load the flat arrays from the Python-generated vectors
        `include "bert_qkv_test_vectors.svh"

        // Flatten the included 2D data into our simulated BRAM arrays
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < D; j++) begin
                q_mem[i*D + j] = q[i][j];
                k_mem[i*D + j] = k[i][j];
                v_mem[i*D + j] = v[i][j];
            end
        end

        repeat(3) @(negedge clk);
        reset = 0;
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;

        fork
            begin
                wait(done === 1'b1);
                #1;
                $display("BERT 4x64 attention RTL completed.");
                $display("\nFinal attention output (from BRAM):");
                for(int r=0; r<N; r++) begin
                    for(int c=0; c<D; c++) begin
                        $write("%0d ", out_mem[r*D + c]);
                    end
                    $display("");
                end
                $finish;
            end
            begin
                // Sequential model takes ~1200 cycles. We provide plenty of margin.
                repeat(5000) @(posedge clk);
                $fatal(1,"TIMEOUT: Accelerator did not complete.");
            end
        join_any
        disable fork;
    end
endmodule