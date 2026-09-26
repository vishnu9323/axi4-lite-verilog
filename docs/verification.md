The self-checking testbench includes bounded waits (`TIMEOUT_CYCLES`) so a
protocol deadlock cannot hang simulation. It checks reset/reuse, all registers,
byte strobes, misaligned addresses, out-of-range addresses, response codes,
and data values. A nonzero error counter causes a failing summary.

Run with Vivado using `scripts\vivado_run.tcl`; a simulator such as Icarus
Verilog can also compile `rtl\**\*.v` and `tb\axi4lite_top_tb.v` directly.

In the Vivado GUI, use `run all` or set the simulation run time to at least
`10 us`. The full integration sequence is longer than Vivado's default
`1000 ns` run time.