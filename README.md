# UART Transmitter and Receiver in Verilog

A basic UART transmitter and receiver written in Verilog HDL. The project demonstrates asynchronous serial communication using baud-rate timing, finite state machines, parallel-to-serial conversion in the transmitter, and serial-to-parallel conversion in the receiver.

The design is intentionally small and interview-friendly. It implements the core UART ideas without adding a FIFO, parity generator, flow control, or a complex oversampling circuit.

## Default UART format

The default configuration is **9600 baud, 8 data bits, no parity, and 1 stop bit (8-N-1)**.

```text
Idle   Start      Data bits (least-significant bit first)       Stop   Idle
  1      0       D0  D1  D2  D3  D4  D5  D6  D7                  1      1
```

The transmitter and receiver do not share a clock signal. They only agree on the baud rate and frame format, which is why UART is called asynchronous communication.

## Files

| File | Purpose |
| --- | --- |
| `uart_tx.v` | UART transmitter with baud counter and four-state FSM |
| `uart_rx.v` | UART receiver with input synchronizer, center sampling, and four-state FSM |
| `impl_top.v` | Small demo that displays a received byte on LEDs and echoes it back |
| `tb_tx.v` | Self-checking transmitter testbench |
| `tb_rx.v` | Self-checking receiver testbench |
| `tb.v` | Self-checking top-level receive-and-echo testbench |

## How the transmitter works

1. The line stays high in `IDLE`.
2. When `uart_tx_en` is high for one clock while the transmitter is idle, `uart_tx_data` is stored internally.
3. The `START` state sends a low start bit for one bit period.
4. The `DATA` state sends the stored byte from bit 0 to bit 7.
5. The `STOP` state sends a high stop bit and then returns to `IDLE`.

`uart_tx_busy` remains high while a frame is being sent. A new byte should be requested only when this signal is low.

```text
IDLE -> START -> DATA -> STOP -> IDLE
```

## How the receiver works

1. A two-flip-flop synchronizer brings `uart_rxd` into the system clock domain.
2. A low level is treated as a possible start bit.
3. The receiver waits half a bit period and checks that the line is still low. This rejects short false-start pulses.
4. It samples one data bit every full bit period and stores the bits from D0 to D7.
5. A high stop bit completes the frame. `uart_rx_data` is updated and `uart_rx_valid` pulses for one clock.

The receiver uses one sample near the center of each bit. This is suitable for a basic design when both ends use close baud rates. Production UARTs commonly use 8x or 16x oversampling for better noise tolerance.

## Baud-rate calculation

The number of system-clock cycles per serial bit is:

```text
CLKS_PER_BIT = CLK_HZ / BIT_RATE
```

The counter runs from `0` to `CLKS_PER_BIT - 1`, so every transmitted bit has exactly that many clock cycles.

### Example 1: default timing

For a 50 MHz clock and 9600 baud:

```text
Clock period       = 1 / 50,000,000
                   = 20 ns

CLKS_PER_BIT       = 50,000,000 / 9,600
                   = 5,208 clock cycles (integer value used by the RTL)

Generated bit time = 5,208 x 20 ns
                   = 104.16 us

Generated baud     = 50,000,000 / 5,208
                   = 9,600.61 baud

Baud error         = (9,600.61 - 9,600) / 9,600 x 100
                   = about +0.0064%
```

The small rounding error occurs because a hardware counter uses a whole number of clock cycles.

### Example 2: time to transmit one byte

An 8-N-1 frame contains 10 bits:

```text
1 start + 8 data + 1 stop = 10 bits

Frame time at 9600 baud = 10 / 9,600
                        = 1.0417 ms

Maximum byte rate       = 9,600 / 10
                        = 960 bytes per second
```

This is the raw frame rate and does not include gaps that software may place between bytes.

### Example 3: transmitting the letter `A`

ASCII `A` is hexadecimal `0x41`, or binary `0100_0001`. UART sends the least-significant bit first:

```text
Parallel byte:  D7 D6 D5 D4 D3 D2 D1 D0 = 0 1 0 0 0 0 0 1
Serial order:   D0 D1 D2 D3 D4 D5 D6 D7 = 1 0 0 0 0 0 1 0

Complete frame: start | 1 0 0 0 0 0 1 0 | stop
                    0 |                   | 1
```

The transmitter performs the parallel-to-serial conversion. The receiver samples the same sequence and rebuilds `0x41`.

## Parameters and signals

The RTL has four parameters:

| Parameter | Default | Meaning |
| --- | ---: | --- |
| `CLK_HZ` | 50,000,000 | System clock frequency |
| `BIT_RATE` | 9,600 | UART baud rate |
| `PAYLOAD_BITS` | 8 | Number of data bits |
| `STOP_BITS` | 1 | Number of stop bits |

Main transmitter signals:

| Signal | Direction | Meaning |
| --- | --- | --- |
| `uart_tx_data` | Input | Parallel data to send |
| `uart_tx_en` | Input | One-clock send request |
| `uart_tx_busy` | Output | High while a frame is active |
| `uart_txd` | Output | Serial transmit line |

Main receiver signals:

| Signal | Direction | Meaning |
| --- | --- | --- |
| `uart_rxd` | Input | Serial receive line |
| `uart_rx_en` | Input | Receiver enable |
| `uart_rx_data` | Output | Reconstructed parallel data |
| `uart_rx_valid` | Output | One-clock pulse when data is ready |
| `uart_rx_break` | Output | Pulse for an all-low frame with a low stop bit |

`resetn` is an asynchronous active-low reset. UART lines return to the idle-high state after reset.

## Running the simulations

The examples below use [Icarus Verilog](https://steveicarus.github.io/iverilog/) and are run from the repository folder.

### Transmitter

```sh
iverilog -g2012 -Wall -s tb_tx -o sim_tx uart_tx.v tb_tx.v
vvp sim_tx
```

### Receiver

```sh
iverilog -g2012 -Wall -s tb_rx -o sim_rx uart_rx.v tb_rx.v
vvp sim_rx
```

### Top-level echo demo

```sh
iverilog -g2012 -Wall -s tb -o sim_top uart_tx.v uart_rx.v impl_top.v tb.v
vvp sim_top
```

Each testbench prints pass/fail results and creates a VCD waveform file that can be opened in GTKWave. The testbenches use faster clock and baud settings to reduce simulation time; the same RTL defaults to 50 MHz and 9600 baud.

## What to explain in an interview

A short explanation can be:

> I implemented a basic 8-N-1 UART in Verilog. The transmitter latches a parallel byte and uses an FSM plus a baud counter to send a start bit, eight data bits LSB-first, and a stop bit. The receiver synchronizes the asynchronous input, confirms the start bit near its center, samples each data bit once per baud period, and raises a valid pulse after a correct stop bit. I verified the transmitter, receiver, and echo top level with self-checking testbenches.

Important follow-up points:

- UART is asynchronous because no clock is sent with the data.
- Both devices must use close baud rates.
- The start bit changes the line from idle high to low.
- LSB-first shifting performs the serial conversion.
- Sampling near the bit center gives timing margin on both sides.
- A two-flip-flop synchronizer reduces metastability risk, but it does not replace oversampling.

## Current scope and limitations

This project is deliberately a basic educational design:

- 8-N-1 is the intended and tested configuration.
- Baud timing uses an integer clock divider.
- The receiver samples once per bit.
- The design has no parity, FIFO, or hardware flow control.
- The demo top contains only one pending echo register, not a general-purpose transmit queue.
- Board-specific pin constraints are not included.

## Future scope

Possible improvements, if the project is extended later, are:

1. Add 8x or 16x receiver oversampling and majority voting.
2. Add parity generation/checking and a framing-error output.
3. Add small transmit and receive FIFOs for back-to-back data.
4. Use a fractional baud generator for clock/baud combinations with larger divider error.
5. Add configurable data length and hardware flow control such as RTS/CTS.
6. Add FPGA board constraints and test communication with a USB-to-UART adapter.

These are future ideas and are **not claimed as features of the current code**.
