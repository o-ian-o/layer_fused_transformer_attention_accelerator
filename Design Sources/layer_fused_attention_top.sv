`timescale 1ns / 1ps

module layer_fused_attention_top #(
    parameter int N = 4,
    parameter int D = 64,
    parameter int DATA_WIDTH = 16,
    parameter int OUTPUT_WIDTH = 16,
    parameter int ADDR_WIDTH = $clog2(N*D)
)(
    input  logic clk,
    input  logic reset_n,
    input  logic start_btn,
    output logic uart_txd
);

    // ------------------------------------------------
    // RESET
    // ------------------------------------------------

    logic reset;
    assign reset = ~reset_n;

    // ------------------------------------------------
    // START BUTTON EDGE DETECTION
    // ------------------------------------------------

    logic start_d;
    logic start_pulse;

    always_ff @(posedge clk) begin
        if (reset)
            start_d <= 0;
        else
            start_d <= start_btn;
    end

    assign start_pulse = start_btn & ~start_d;

    // ------------------------------------------------
    // INTERNAL MEMORY
    // ------------------------------------------------

    logic signed [15:0] q_mem [0:N*D-1];
    logic signed [15:0] k_mem [0:N*D-1];
    logic signed [15:0] v_mem [0:N*D-1];
    logic signed [15:0] out_mem [0:N*D-1];

    logic [ADDR_WIDTH-1:0] q_addr, k_addr;
    logic [ADDR_WIDTH-1:0] v_addr, out_addr;

    logic q_en, k_en, v_en;
    logic out_en, out_we;

    logic signed [15:0] q_dout, k_dout, v_dout;
    logic signed [15:0] out_din;

    logic core_busy, core_done;
    logic core_start;

    // ------------------------------------------------
    // MEMORY INITIALIZATION
    // ------------------------------------------------

    initial begin
        $readmemh("q_mem.hex", q_mem);
        $readmemh("k_mem.hex", k_mem);
        $readmemh("v_mem.hex", v_mem);
    end

    // ------------------------------------------------
    // SYNCHRONOUS MEMORY INTERFACE
    // ------------------------------------------------

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

    // ------------------------------------------------
    // ATTENTION ACCELERATOR
    // ------------------------------------------------

    layer_fused_attention #(
        .N(N),
        .D(D),
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) u_attention (

        .clk(clk),
        .reset(reset),
        .start(core_start),

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

        .busy(core_busy),
        .done(core_done)
    );

    // ------------------------------------------------
    // UART TRANSMITTER
    // ------------------------------------------------

    logic [7:0] uart_data;
    logic uart_start;
    logic uart_busy;
    logic uart_done;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk(clk),
        .reset(reset),
        .tx_start(uart_start),
        .tx_data(uart_data),
        .tx(uart_txd),
        .tx_busy(uart_busy),
        .tx_done(uart_done)
    );

    // ------------------------------------------------
    // HEX CONVERSION
    // ------------------------------------------------

    function automatic [7:0] hex_ascii(input logic [3:0] value);
        begin
            if (value < 10)
                hex_ascii = 8'h30 + value;
            else
                hex_ascii = 8'h41 + value - 10;
        end
    endfunction

    // ------------------------------------------------
    // UART OUTPUT CONTROLLER
    // ------------------------------------------------

    typedef enum logic [2:0] {
        IDLE,
        FETCH_WORD,
        SEND_HEX,
        WAIT_TX,
        SEND_NEWLINE,
        WAIT_NEWLINE,
        FINISH
    } uart_state_t;

    uart_state_t uart_state;

    logic [8:0] output_index;
    logic [1:0] nibble_index;

    logic [15:0] tx_word;
    logic streaming;

    assign core_start = start_pulse && !streaming;

    always_ff @(posedge clk) begin

        if (reset) begin
            uart_state  <= IDLE;
            uart_data   <= 0;
            uart_start  <= 0;
            output_index <= 0;
            nibble_index <= 0;
            tx_word     <= 0;
            streaming   <= 0;
        end

        else begin

            uart_start <= 0;

            case (uart_state)

                IDLE: begin
                    if (core_done) begin
                        output_index <= 0;
                        streaming <= 1;
                        uart_state <= FETCH_WORD;
                    end
                end

                FETCH_WORD: begin
                    tx_word <= out_mem[output_index];
                    nibble_index <= 0;
                    uart_state <= SEND_HEX;
                end

                SEND_HEX: begin
                    if (!uart_busy) begin

                        uart_data <= hex_ascii(
                            (tx_word >> (12 - nibble_index * 4)) & 16'h000F
                        );

                        uart_start <= 1;
                        uart_state <= WAIT_TX;

                    end
                end

                WAIT_TX: begin
                    if (uart_done) begin

                        if (nibble_index == 3)
                            uart_state <= SEND_NEWLINE;
                        else begin
                            nibble_index <= nibble_index + 1;
                            uart_state <= SEND_HEX;
                        end

                    end
                end

                SEND_NEWLINE: begin
                    if (!uart_busy) begin
                        uart_data <= 8'h0A;
                        uart_start <= 1;
                        uart_state <= WAIT_NEWLINE;
                    end
                end

                WAIT_NEWLINE: begin
                    if (uart_done) begin

                        if (output_index == N*D-1)
                            uart_state <= FINISH;
                        else begin
                            output_index <= output_index + 1;
                            uart_state <= FETCH_WORD;
                        end

                    end
                end

                FINISH: begin
                    streaming <= 0;
                    uart_state <= IDLE;
                end

                default: uart_state <= IDLE;

            endcase

        end
    end

endmodule


// ====================================================
// UART TRANSMITTER MODULE
// ====================================================

module uart_tx #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int BAUD_RATE = 115200
)(
    input logic clk,
    input logic reset,

    input logic tx_start,
    input logic [7:0] tx_data,

    output logic tx,
    output logic tx_busy,
    output logic tx_done
);

    localparam int BAUD_COUNT = CLK_FREQ / BAUD_RATE;

    logic [15:0] baud_counter;
    logic [3:0] bit_index;
    logic [9:0] shift_reg;

    typedef enum logic [1:0] {
        UART_IDLE,
        UART_START,
        UART_DATA,
        UART_STOP
    } uart_state_t;

    uart_state_t state;

    always_ff @(posedge clk) begin

        if (reset) begin
            state <= UART_IDLE;
            tx <= 1;
            tx_busy <= 0;
            tx_done <= 0;
            baud_counter <= 0;
            bit_index <= 0;
            shift_reg <= 10'h3FF;
        end

        else begin

            tx_done <= 0;

            case (state)

                UART_IDLE: begin
                    tx <= 1;
                    tx_busy <= 0;
                    baud_counter <= 0;

                    if (tx_start) begin
                        shift_reg <= {1'b1, tx_data, 1'b0};
                        tx_busy <= 1;
                        state <= UART_START;
                    end
                end

                UART_START: begin
                    tx <= 0;

                    if (baud_counter == BAUD_COUNT-1) begin
                        baud_counter <= 0;
                        bit_index <= 0;
                        state <= UART_DATA;
                    end
                    else
                        baud_counter <= baud_counter + 1;
                end

                UART_DATA: begin
                    tx <= shift_reg[bit_index+1];

                    if (baud_counter == BAUD_COUNT-1) begin
                        baud_counter <= 0;

                        if (bit_index == 7)
                            state <= UART_STOP;
                        else
                            bit_index <= bit_index + 1;
                    end
                    else
                        baud_counter <= baud_counter + 1;
                end

                UART_STOP: begin
                    tx <= 1;

                    if (baud_counter == BAUD_COUNT-1) begin
                        baud_counter <= 0;
                        tx_busy <= 0;
                        tx_done <= 1;
                        state <= UART_IDLE;
                    end
                    else
                        baud_counter <= baud_counter + 1;
                end

                default: state <= UART_IDLE;

            endcase

        end
    end

endmodule