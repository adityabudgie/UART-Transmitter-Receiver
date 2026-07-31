// Simple UART demo: show each received byte on the LEDs and echo it back.

`timescale 1ns/1ps

module impl_top #(
    parameter integer CLK_HZ       = 50_000_000,
    parameter integer BIT_RATE     = 9600,
    parameter integer PAYLOAD_BITS = 8
) (
    input  wire       clk,
    input  wire       sw_0,
    input  wire       sw_1,
    input  wire       uart_rxd,
    output wire       uart_txd,
    output wire [7:0] led
);

    wire [PAYLOAD_BITS-1:0] uart_rx_data;
    wire                    uart_rx_valid;
    wire                    uart_rx_break;
    wire                    uart_tx_busy;
    wire                    uart_tx_en;

    reg [PAYLOAD_BITS-1:0] pending_data;
    reg                    pending_valid;
    reg [7:0]              led_reg;

    assign led        = led_reg;
    assign uart_tx_en = pending_valid && !uart_tx_busy;

    // One pending register is enough for this small echo demonstration.
    always @(posedge clk or negedge sw_0) begin
        if (!sw_0) begin
            led_reg       <= 8'h00;
            pending_data  <= {PAYLOAD_BITS{1'b0}};
            pending_valid <= 1'b0;
        end else begin
            if (uart_rx_valid) begin
                led_reg       <= uart_rx_data;
                pending_data  <= uart_rx_data;
                pending_valid <= 1'b1;
            end else if (uart_tx_en) begin
                pending_valid <= 1'b0;
            end
        end
    end

    uart_rx #(
        .BIT_RATE    (BIT_RATE),
        .CLK_HZ      (CLK_HZ),
        .PAYLOAD_BITS(PAYLOAD_BITS)
    ) i_uart_rx (
        .clk          (clk),
        .resetn       (sw_0),
        .uart_rxd     (uart_rxd),
        .uart_rx_en   (1'b1),
        .uart_rx_break(uart_rx_break),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data (uart_rx_data)
    );

    uart_tx #(
        .BIT_RATE    (BIT_RATE),
        .CLK_HZ      (CLK_HZ),
        .PAYLOAD_BITS(PAYLOAD_BITS)
    ) i_uart_tx (
        .clk         (clk),
        .resetn      (sw_0),
        .uart_txd    (uart_txd),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_en  (uart_tx_en),
        .uart_tx_data(pending_data)
    );

endmodule
