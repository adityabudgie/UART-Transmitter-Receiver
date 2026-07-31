// Basic UART receiver
// Frame format: 1 start bit, PAYLOAD_BITS data bits (LSB first), STOP_BITS stop bits

`timescale 1ns/1ps

module uart_rx #(
    parameter integer BIT_RATE     = 9600,
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer PAYLOAD_BITS = 8,
    parameter integer STOP_BITS    = 1
) (
    input  wire                    clk,
    input  wire                    resetn,
    input  wire                    uart_rxd,
    input  wire                    uart_rx_en,
    output reg                     uart_rx_break,
    output reg                     uart_rx_valid,
    output reg  [PAYLOAD_BITS-1:0] uart_rx_data
);

    localparam integer CLKS_PER_BIT    = CLK_HZ / BIT_RATE;
    localparam integer COUNT_WIDTH     = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);
    localparam integer DATA_WIDTH      = (PAYLOAD_BITS <= 1) ? 1 : $clog2(PAYLOAD_BITS);
    localparam integer STOP_WIDTH      = (STOP_BITS <= 1) ? 1 : $clog2(STOP_BITS);
    localparam integer HALF_BIT_COUNT  = (CLKS_PER_BIT < 2) ? 0 : (CLKS_PER_BIT / 2) - 1;

    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    reg [1:0]                    state;
    reg [COUNT_WIDTH-1:0]        clock_count;
    reg [DATA_WIDTH-1:0]         bit_index;
    reg [STOP_WIDTH-1:0]         stop_index;
    reg [PAYLOAD_BITS-1:0]       received_data;

    // Two flip-flops reduce the chance of metastability when the asynchronous
    // serial input enters the clocked receiver logic.
    reg rxd_meta;
    reg rxd_sync;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rxd_meta <= 1'b1;
            rxd_sync <= 1'b1;
        end else begin
            rxd_meta <= uart_rxd;
            rxd_sync <= rxd_meta;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state         <= IDLE;
            clock_count   <= {COUNT_WIDTH{1'b0}};
            bit_index     <= {DATA_WIDTH{1'b0}};
            stop_index    <= {STOP_WIDTH{1'b0}};
            received_data <= {PAYLOAD_BITS{1'b0}};
            uart_rx_data  <= {PAYLOAD_BITS{1'b0}};
            uart_rx_valid <= 1'b0;
            uart_rx_break <= 1'b0;
        end else begin
            // Both status outputs are one-clock pulses.
            uart_rx_valid <= 1'b0;
            uart_rx_break <= 1'b0;

            if (!uart_rx_en) begin
                state       <= IDLE;
                clock_count <= {COUNT_WIDTH{1'b0}};
                bit_index   <= {DATA_WIDTH{1'b0}};
                stop_index  <= {STOP_WIDTH{1'b0}};
            end else begin
                case (state)
                    IDLE: begin
                        clock_count <= {COUNT_WIDTH{1'b0}};
                        bit_index   <= {DATA_WIDTH{1'b0}};
                        stop_index  <= {STOP_WIDTH{1'b0}};

                        if (!rxd_sync) begin
                            received_data <= {PAYLOAD_BITS{1'b0}};
                            state         <= START;
                        end
                    end

                    START: begin
                        // Check the middle of the start bit. If the line has
                        // returned high, the low pulse was not a valid start.
                        if (clock_count == HALF_BIT_COUNT) begin
                            clock_count <= {COUNT_WIDTH{1'b0}};

                            if (!rxd_sync) begin
                                bit_index <= {DATA_WIDTH{1'b0}};
                                state     <= DATA;
                            end else begin
                                state <= IDLE;
                            end
                        end else begin
                            clock_count <= clock_count + 1'b1;
                        end
                    end

                    DATA: begin
                        if (clock_count == CLKS_PER_BIT - 1) begin
                            clock_count             <= {COUNT_WIDTH{1'b0}};
                            received_data[bit_index] <= rxd_sync;

                            if (bit_index == PAYLOAD_BITS - 1) begin
                                stop_index <= {STOP_WIDTH{1'b0}};
                                state      <= STOP;
                            end else begin
                                bit_index <= bit_index + 1'b1;
                            end
                        end else begin
                            clock_count <= clock_count + 1'b1;
                        end
                    end

                    STOP: begin
                        if (clock_count == CLKS_PER_BIT - 1) begin
                            clock_count <= {COUNT_WIDTH{1'b0}};

                            if (!rxd_sync) begin
                                // A continuous low frame (zero data and a low
                                // stop bit) is treated as a UART break.
                                if (received_data == {PAYLOAD_BITS{1'b0}})
                                    uart_rx_break <= 1'b1;
                                state <= IDLE;
                            end else if (stop_index == STOP_BITS - 1) begin
                                uart_rx_data  <= received_data;
                                uart_rx_valid <= 1'b1;
                                state         <= IDLE;
                            end else begin
                                stop_index <= stop_index + 1'b1;
                            end
                        end else begin
                            clock_count <= clock_count + 1'b1;
                        end
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule
