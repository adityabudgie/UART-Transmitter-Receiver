`timescale 1ns/1ps

module tb;

    localparam integer CLK_HZ        = 10_000_000;
    localparam integer BIT_RATE      = 1_000_000;
    localparam integer CLK_PERIOD_NS = 1_000_000_000 / CLK_HZ;
    localparam integer BIT_PERIOD_NS = 1_000_000_000 / BIT_RATE;

    reg        clk;
    reg        resetn;
    reg        uart_rxd;
    wire       uart_txd;
    wire [7:0] led;

    integer tests;
    integer errors;

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task drive_byte;
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
            #BIT_PERIOD_NS;
        end
    endtask

    task receive_echo;
        input [7:0] expected;
        reg   [7:0] received;
        integer i;
        begin
            @(negedge uart_txd);
            #(BIT_PERIOD_NS / 2);

            if (uart_txd !== 1'b0) begin
                errors = errors + 1;
                $display("TOP FAIL: invalid echo start bit");
            end

            for (i = 0; i < 8; i = i + 1) begin
                #BIT_PERIOD_NS;
                received[i] = uart_txd;
            end

            #BIT_PERIOD_NS;
            if (uart_txd !== 1'b1) begin
                errors = errors + 1;
                $display("TOP FAIL: invalid echo stop bit");
            end

            tests = tests + 1;
            if (received !== expected) begin
                errors = errors + 1;
                $display("TOP FAIL: expected 0x%02h, got 0x%02h", expected, received);
            end else begin
                $display("TOP PASS: 0x%02h received and echoed", expected);
            end
        end
    endtask

    task run_case;
        input [7:0] value;
        begin
            fork
                drive_byte(value);
                receive_echo(value);
            join

            if (led !== value) begin
                errors = errors + 1;
                $display("TOP FAIL: LED expected 0x%02h, got 0x%02h", value, led);
            end

            #(BIT_PERIOD_NS / 2);
        end
    endtask

    initial begin
        clk      = 1'b0;
        resetn   = 1'b0;
        uart_rxd = 1'b1;
        tests    = 0;
        errors   = 0;

        $dumpfile("waves-top.vcd");
        $dumpvars(0, tb);

        repeat (3) @(posedge clk);
        @(negedge clk);
        resetn = 1'b1;

        run_case(8'h41);
        run_case(8'h5A);
        run_case(8'hC3);

        if (errors == 0) begin
            $display("TOP TEST PASSED (%0d bytes)", tests);
        end else begin
            $display("TOP TEST FAILED (%0d errors)", errors);
            $fatal(1, "Top-level test failed");
        end

        $finish;
    end

    impl_top #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ  (CLK_HZ)
    ) dut (
        .clk     (clk),
        .sw_0    (resetn),
        .sw_1    (1'b0),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .led     (led)
    );

endmodule
