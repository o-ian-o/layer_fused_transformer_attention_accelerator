`timescale 1ns / 1ps

module tb_bert_layer_fused_attention;

    localparam int N = 4;
    localparam int D = 64;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH = 40;

    logic clk = 0;
    logic reset, start;

    logic signed [DATA_WIDTH-1:0] q [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] k [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] v [0:N-1][0:D-1];

    logic signed [DATA_WIDTH-1:0]
        output_matrix [0:N-1][0:D-1];

    logic busy, done;

    always #5 clk = ~clk;

    // DUT
    layer_fused_attention #(
        .N(N),
        .D(D),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .OUTPUT_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .q(q),
        .k(k),
        .v(v),
        .output_matrix(output_matrix),
        .busy(busy),
        .done(done)
    );

    initial begin

        // --------------------------------
        // Initial reset
        // --------------------------------

        reset = 1;
        start = 0;

        repeat(3) @(negedge clk);

        reset = 0;

        // --------------------------------
        // Load BERT Q, K, V test vectors
        // --------------------------------

        `include "bert_qkv_test_vectors.svh"

        // --------------------------------
        // Start BERT attention transaction
        // --------------------------------

        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        // --------------------------------
        // Wait for completion
        // --------------------------------

        fork

            begin
                wait(done === 1'b1);
                #1;

                $display("--------------------------------");
                $display("BERT 4x64 attention RTL completed.");
                $display("--------------------------------");

                for(int r = 0; r < N; r++) begin
                    for(int c = 0; c < D; c++)
                        $write("%0d ", output_matrix[r][c]);

                    $display("");
                end

                // --------------------------------
                // Reset verification
                // --------------------------------

                $display("Starting reset verification...");

                @(negedge clk);
                start = 1;

                @(negedge clk);
                start = 0;

                repeat(3) @(negedge clk);

                if (busy !== 1'b1)
                    $fatal(1, "FAIL: Accelerator did not enter BUSY state");

                $display("PASS: Accelerator entered BUSY state");

                // Assert reset while accelerator is busy
                reset = 1;

                @(negedge clk);

                if (busy !== 1'b0 || done !== 1'b0)
                    $fatal(1, "FAIL: Reset did not clear busy/done");

                $display("PASS: Reset cleared busy and done");

                reset = 0;

                $display("--------------------------------");
                $display("RESET VERIFICATION PASSED");
                $display("--------------------------------");

                $finish;
            end

            begin
                repeat(5000) @(posedge clk);
                $fatal(1, "TIMEOUT: D=64 attention did not complete.");
            end

        join_any

        disable fork;

    end

endmodule