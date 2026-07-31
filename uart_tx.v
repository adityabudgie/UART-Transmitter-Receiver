// Basic UART transmitter
// Frame format: 1 start bit, PAYLOAD_BITS data bits (LSB first), STOP_BITS stop bits

`timescale 1ns/1ps

module uart_tx #(
    parameter integer BIT_RATE     = 9600,
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer PAYLOAD_BITS = 8,
    parameter integer STOP_BITS    = 1
) (
    input  wire                    clk,
    input  wire                    resetn,
    output wire                    uart_txd,
    output wire                    uart_tx_busy,
    input  wire                    uart_tx_en,
    input  wire [PAYLOAD_BITS-1:0] uart_tx_data
);

    localparam integer CLKS_PER_BIT = CLK_HZ / BIT_RATE;
    localparam integer COUNT_WIDTH  = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);
    localparam integer DATA_WIDTH   = (PAYLOAD_BITS <= 1) ? 1 : $clog2(PAYLOAD_BITS);
    localparam integer STOP_WIDTH   = (STOP_BITS <= 1) ? 1 : $clog2(STOP_BITS);

    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    reg [1:0]                    state;
    reg [COUNT_WIDTH-1:0]        clock_count;
    reg [DATA_WIDTH-1:0]         bit_index;
    reg [STOP_WIDTH-1:0]         stop_index;
    reg [PAYLOAD_BITS-1:0]       data_to_send;
    reg                          txd_reg;

    assign uart_txd     = txd_reg;
    assign uart_tx_busy = (state != IDLE);

    // uart_tx_en is sampled only while the transmitter is idle.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state        <= IDLE;
            clock_count  <= {COUNT_WIDTH{1'b0}};
            bit_index    <= {DATA_WIDTH{1'b0}};
            stop_index   <= {STOP_WIDTH{1'b0}};
            data_to_send <= {PAYLOAD_BITS{1'b0}};
            txd_reg      <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    txd_reg     <= 1'b1;
                    clock_count <= {COUNT_WIDTH{1'b0}};
                    bit_index   <= {DATA_WIDTH{1'b0}};
                    stop_index  <= {STOP_WIDTH{1'b0}};

                    if (uart_tx_en) begin
                        data_to_send <= uart_tx_data;
                        txd_reg      <= 1'b0;
                        state        <= START;
                    end
                end

                START: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= {COUNT_WIDTH{1'b0}};
                        bit_index   <= {DATA_WIDTH{1'b0}};
                        txd_reg     <= data_to_send[0];
                        state       <= DATA;
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= {COUNT_WIDTH{1'b0}};

                        if (bit_index == PAYLOAD_BITS - 1) begin
                            stop_index <= {STOP_WIDTH{1'b0}};
                            txd_reg    <= 1'b1;
                            state      <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            txd_reg   <= data_to_send[bit_index + 1'b1];
                        end
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STOP: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= {COUNT_WIDTH{1'b0}};

                        if (stop_index == STOP_BITS - 1) begin
                            txd_reg <= 1'b1;
                            state   <= IDLE;
                        end else begin
                            stop_index <= stop_index + 1'b1;
                        end
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                default: begin
                    state   <= IDLE;
                    txd_reg <= 1'b1;
                end
            endcase
        end
    end

endmodule
