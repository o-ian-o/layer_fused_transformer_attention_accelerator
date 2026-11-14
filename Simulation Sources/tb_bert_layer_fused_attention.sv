
`timescale 1ns / 1ps

module tb_bert_layer_fused_attention;

    localparam int N = 4;
    localparam int D = 64;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH = 40;
    localparam int OUTPUT_WIDTH = 16;

    logic clk = 0, reset, start;

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

    // Temporary 2D arrays
    logic signed [DATA_WIDTH-1:0] q [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] k [0:N-1][0:D-1];
    logic signed [DATA_WIDTH-1:0] v [0:N-1][0:D-1];

    integer output_file;

    // =====================================================
    // SYNCHRONOUS BRAM READ/WRITE
    // =====================================================

    always_ff @(posedge clk) begin

        if (q_en)
            q_dout <= q_mem[q_addr];

        if (k_en)
            k_dout <= k_mem[k_addr];

        if (v_en)
            v_dout <= v_mem[v_addr];

        if (out_en && out_we)
            out_mem[out_addr] <= out_din;

    end

    // =====================================================
    // BRAM WRITE MONITOR
    // =====================================================

    always @(posedge clk) begin

        if (out_en && out_we) begin

            $display(
                "BRAM WRITE: addr=%0d, data=%0d, time=%0t",
                out_addr,
                $signed(out_din),
                $time
            );

        end

    end

    // =====================================================
    // INITIALIZE OUTPUT MEMORY
    // =====================================================

    initial begin

        for (int idx = 0; idx < N*D; idx++)
            out_mem[idx] = '0;

    end

    // Clock generation
    always #5 clk = ~clk;

    // =====================================================
    // DUT
    // =====================================================

    layer_fused_attention #(
        .N(N),
        .D(D),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) dut (

        .clk(clk),
        .reset(reset),
        .start(start),

        .q_addr(q_addr),
        .q_en(q_en),
        .q_dout(q_dout),

        .k_addr(k_addr),
        .k_en(k_en),
        .k_dout(k_dout),

        .v_addr(v_addr),
        .v_en(v_en),
        .v_dout(v_dout),

        .out_addr(out_addr),
        .out_en(out_en),
        .out_we(out_we),
        .out_din(out_din),

        .busy(busy),
        .done(done)

    );

    // =====================================================
    // MAIN TEST SEQUENCE
    // =====================================================

    initial begin

        reset = 1;
        start = 0;

        // Load Python-generated Q, K, V vectors
        `include "bert_qkv_test_vectors.svh"

        // Flatten 2D arrays into BRAM memories
        for (int i = 0; i < N; i++) begin

            for (int j = 0; j < D; j++) begin

                q_mem[i*D + j] = q[i][j];
                k_mem[i*D + j] = k[i][j];
                v_mem[i*D + j] = v[i][j];

            end

        end
        
            
        $display("V MEMORY CHECK:");
        $display("V[0]   = %0d", $signed(v_mem[0]));
        $display("V[64]  = %0d", $signed(v_mem[64]));
        $display("V[128] = %0d", $signed(v_mem[128]));
        $display("V[192] = %0d", $signed(v_mem[192]));
        
        // Reset sequence
        repeat (3) @(negedge clk);

        reset = 0;

        // Start accelerator
        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        fork

            // Wait for accelerator completion
            begin

                wait (done === 1'b1);
                repeat (2) @(posedge clk);

                $display("EXPORT CHECK:");
                $display("out_mem[0] = %0d", $signed(out_mem[0]));
                $display("out_mem[1] = %0d", $signed(out_mem[1]));
                $display("out_mem[2] = %0d", $signed(out_mem[2]));
                @(posedge clk);
                #1;

                $display("\nBERT 4x64 attention RTL completed.");

                $display("Internal final output = %h",
                         dut.output_matrix[3][63]);

                $display("Final output bus = %h", out_din);

                $display("Final BRAM location = %h", out_mem[255]);

                // Display final attention output
                $display("\nFinal attention output (from BRAM):");

                for (int r = 0; r < N; r++) begin

                    for (int c = 0; c < D; c++) begin

                        $write("%0d ", $signed(out_mem[r*D + c]));

                    end

                    $display("");

                end

                // Export RTL output to text file
                output_file = $fopen(
                    "C:/FPGA_Projects/layer_fused_attention_accelerator/layer_fused_attention_accelerator/artifacts/bert_run/rtl_output.txt",
                    "w"
                );

                if (output_file == 0)
                    $fatal(1, "Could not create RTL output file");

                for (int idx = 0; idx < N*D; idx++) begin

                    $fwrite(
                        output_file,
                        "%0d\n",
                        $signed(out_mem[idx])
                    );

                end

                $fclose(output_file);
                $display("FILE EXPORT COMPLETED");
$display("Exported first value: %0d", $signed(out_mem[0]));
$display("Exported second value: %0d", $signed(out_mem[1]));
$display("Exported third value: %0d", $signed(out_mem[2]));

                $display("\nRTL output successfully saved.");

                $finish;

            end

            // Timeout protection
            begin

                repeat (10000) @(posedge clk);

                $fatal(1, "TIMEOUT: Accelerator did not complete.");

            end

        join_any

        disable fork;

    end

endmodule
