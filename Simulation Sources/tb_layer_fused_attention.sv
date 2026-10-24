`timescale 1ns / 1ps

module tb_layer_fused_attention;

    localparam int N = 4;
    localparam int D = 4;

    logic clk;
    logic reset;
    logic start;

    logic signed [15:0] q [0:N-1][0:D-1];
    logic signed [15:0] k [0:N-1][0:D-1];
    logic signed [15:0] v [0:N-1][0:D-1];

    logic signed [15:0]
        output_matrix [0:N-1][0:D-1];

    logic busy;
    logic done;


    // ------------------------------------------
    // DUT
    // ------------------------------------------

    layer_fused_attention #(
        .N(N),
        .D(D)
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


    // ------------------------------------------
    // Clock generation: 10 ns period
    // ------------------------------------------

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // ------------------------------------------
    // Test sequence
    // ------------------------------------------

    initial begin

        $display("\n======================================");
        $display("LAYER-FUSED ATTENTION ACCELERATOR");
        $display("END-TO-END TEST");
        $display("======================================");


        reset = 1'b1;
        start = 1'b0;

        // Initialize Q.

        q[0][0] = 1; q[0][1] = 2;
        q[0][2] = 3; q[0][3] = 4;

        q[1][0] = 2; q[1][1] = 1;
        q[1][2] = 0; q[1][3] = 1;

        q[2][0] = 1; q[2][1] = 1;
        q[2][2] = 1; q[2][3] = 1;

        q[3][0] = 3; q[3][1] = 2;
        q[3][2] = 1; q[3][3] = 0;


        // Initialize K.

        k[0][0] = 1; k[0][1] = 0;
        k[0][2] = 1; k[0][3] = 0;

        k[1][0] = 0; k[1][1] = 1;
        k[1][2] = 0; k[1][3] = 1;

        k[2][0] = 1; k[2][1] = 1;
        k[2][2] = 0; k[2][3] = 0;

        k[3][0] = 0; k[3][1] = 0;
        k[3][2] = 1; k[3][3] = 1;


        // Initialize V.

        v[0][0] = 1; v[0][1] = 2;
        v[0][2] = 3; v[0][3] = 4;

        v[1][0] = 2; v[1][1] = 1;
        v[1][2] = 0; v[1][3] = 1;

        v[2][0] = 1; v[2][1] = 1;
        v[2][2] = 1; v[2][3] = 1;

        v[3][0] = 3; v[3][1] = 2;
        v[3][2] = 1; v[3][3] = 0;


        // Release reset.

        repeat (2) @(negedge clk);
        reset = 1'b0;

        // Start the attention computation.

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;


        // Wait for completion, with a timeout.

        fork

            begin
                wait (done === 1'b1);
            end

            begin
                repeat (200) @(posedge clk);
                $fatal(1, "TIMEOUT: Accelerator did not assert done.");
            end

        join_any

        disable fork;


        // Allow combinational outputs to settle.

        #1;

        $display("\nAccelerator completed.");
        $display("busy = %0b", busy);
        $display("done = %0b", done);

        $display("\nFinal attention output:");

        for (int i = 0; i < N; i++) begin

            for (int j = 0; j < D; j++) begin
                $write("%0d ", output_matrix[i][j]);
            end

            $display("");

        end

        $display("\nEnd-to-end simulation completed.");

        #10;
        $finish;

    end

endmodule