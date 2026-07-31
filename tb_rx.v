`timescale 1ns/1ps

module tb_rx;

    localparam integer CLK_HZ        = 10_000_000;
    localparam integer BIT_RATE      = 1_000_000;
    localparam integer CLK_PERIOD_NS = 1_000_000_000 / CLK_HZ;
    localparam integer BIT_PERIOD_NS = 1_000_000_000 / BIT_RATE;

    reg        clk;
    reg        resetn;
    reg        uart_rxd;
    reg        uart_rx_en;
    wire       uart_rx_break;
    wire       uart_rx_valid;
    wire [7:0] uart_rx_data;

    integer tests;
    integer errors;

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task send_and_check;
        input [7:0] value;
        integer i;
        begin
            @(negedge clk);
            uart_rxd = 1'b0;
            #BIT_PERIOD_NS;

            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = value[i];
                #BIT_PERIOD_NS;
            end

            uart_rxd = 1'b1;
            @(posedge uart_rx_valid);
            #1;

            tests = tests + 1;
            if (uart_rx_data !== value) begin
                errors = errors + 1;
                $display("RX FAIL: expected 0x%02h, got 0x%02h", value, uart_rx_data);
            end else begin
                $display("RX PASS: 0x%02h", value);
            end

            #(BIT_PERIOD_NS / 2);
        end
    endtask

    initial begin
        clk        = 1'b0;
        resetn     = 1'b0;
        uart_rxd   = 1'b1;
        uart_rx_en = 1'b1;
        tests      = 0;
        errors     = 0;

        $dumpfile("waves-rx.vcd");
        $dumpvars(0, tb_rx);

        repeat (3) @(posedge clk);
        @(negedge clk);
        resetn = 1'b1;

        // A short low pulse must not be accepted as a start bit.
        @(negedge clk);
        uart_rxd = 1'b0;
        #(BIT_PERIOD_NS / 4);
        uart_rxd = 1'b1;
        #(2 * BIT_PERIOD_NS);
        if (uart_rx_valid) begin
            errors = errors + 1;
            $display("RX FAIL: false start produced valid data");
        end

        send_and_check(8'h55);
        send_and_check(8'hA3);
        send_and_check(8'h00);
        send_and_check(8'hFF);

        if (errors == 0) begin
            $display("RX TEST PASSED (%0d bytes)", tests);
        end else begin
            $display("RX TEST FAILED (%0d errors)", errors);
            $fatal(1, "Receiver test failed");
        end

        $finish;
    end

    uart_rx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ  (CLK_HZ)
    ) dut (
        .clk          (clk),
        .resetn       (resetn),
        .uart_rxd     (uart_rxd),
        .uart_rx_en   (uart_rx_en),
        .uart_rx_break(uart_rx_break),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data (uart_rx_data)
    );

endmodule
