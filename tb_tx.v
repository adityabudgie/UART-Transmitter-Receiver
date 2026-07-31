`timescale 1ns/1ps

module tb_tx;

    localparam integer CLK_HZ        = 10_000_000;
    localparam integer BIT_RATE      = 1_000_000;
    localparam integer CLK_PERIOD_NS = 1_000_000_000 / CLK_HZ;
    localparam integer BIT_PERIOD_NS = 1_000_000_000 / BIT_RATE;

    reg        clk;
    reg        resetn;
    reg        uart_tx_en;
    reg  [7:0] uart_tx_data;
    wire       uart_txd;
    wire       uart_tx_busy;

    integer tests;
    integer errors;

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task check_line;
        input expected;
        begin
            tests = tests + 1;
            if (uart_txd !== expected) begin
                errors = errors + 1;
                $display("TX FAIL at %0t: expected %b, got %b", $time, expected, uart_txd);
            end
        end
    endtask

    task send_and_check;
        input [7:0] value;
        integer i;
        begin
            wait (!uart_tx_busy);
            @(negedge clk);
            uart_tx_data = value;
            uart_tx_en   = 1'b1;

            @(posedge clk);
            #1 uart_tx_en = 1'b0;

            #(BIT_PERIOD_NS / 2 - 1);
            check_line(1'b0);

            for (i = 0; i < 8; i = i + 1) begin
                #BIT_PERIOD_NS;
                check_line(value[i]);
            end

            #BIT_PERIOD_NS;
            check_line(1'b1);
            wait (!uart_tx_busy);
            $display("TX PASS: 0x%02h", value);
        end
    endtask

    initial begin
        clk          = 1'b0;
        resetn       = 1'b0;
        uart_tx_en   = 1'b0;
        uart_tx_data = 8'h00;
        tests        = 0;
        errors       = 0;

        $dumpfile("waves-tx.vcd");
        $dumpvars(0, tb_tx);

        repeat (3) @(posedge clk);
        @(negedge clk);
        resetn = 1'b1;

        send_and_check(8'h55);
        send_and_check(8'hA3);
        send_and_check(8'h00);
        send_and_check(8'hFF);

        if (errors == 0) begin
            $display("TX TEST PASSED (%0d checks)", tests);
        end else begin
            $display("TX TEST FAILED (%0d errors)", errors);
            $fatal(1, "Transmitter test failed");
        end

        $finish;
    end

    uart_tx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ  (CLK_HZ)
    ) dut (
        .clk         (clk),
        .resetn      (resetn),
        .uart_txd    (uart_txd),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_en  (uart_tx_en),
        .uart_tx_data(uart_tx_data)
    );

endmodule
