`timescale 1ns / 1ps
module tb_bert_layer_fused_attention;
    localparam int N=4, D=64, DATA_WIDTH=16, ACC_WIDTH=40;
    logic clk=0, reset, start;
    logic signed [DATA_WIDTH-1:0] q[0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] k[0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] v[0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] output_matrix[0:N-1][0:D-1];
    logic busy, done;

    always #5 clk=~clk;

    layer_fused_attention #(.N(N),.D(D),.DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),.OUTPUT_WIDTH(DATA_WIDTH)) dut (
        .clk(clk),.reset(reset),.start(start),.q(q),.k(k),.v(v),
        .output_matrix(output_matrix),.busy(busy),.done(done));

    initial begin
        reset=1; start=0;
        repeat(3) @(negedge clk);
        reset=0;
        // Generated assignments populate q, k, and v (4x64 signed int16).
        `include "bert_qkv_test_vectors.svh"
        @(negedge clk); start=1;
        @(negedge clk); start=0;
        fork
            begin
                wait(done===1'b1);
                #1;
                $display("BERT 4x64 attention RTL completed.");
                for(int r=0;r<N;r++) begin
                    for(int c=0;c<D;c++) $write("%0d ",output_matrix[r][c]);
                    $display("");
                end
                $finish;
            end
            begin
                // 4*4*64 = 1024 MAC cycles plus controller margin.
                repeat(5000) @(posedge clk);
                $fatal(1,"TIMEOUT: D=64 attention did not complete.");
            end
        join_any
        disable fork;
    end
endmodule
