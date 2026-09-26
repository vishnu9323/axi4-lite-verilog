# AXI4-Lite Vivado Project

## Project contents

- `rtl/` contains the synthesizable AXI4-Lite master, slave, and register bank.
- `tb/axi4lite_top_tb.v` is the system-level behavioral testbench.
- `scripts/vivado_run.tcl` creates a Vivado project, compiles the RTL, synthesizes the top level, and runs behavioral simulation.

The default map is 16 aligned 32-bit registers at byte addresses `0x00` through
`0x3c`. Misaligned and out-of-range accesses return `SLVERR` and do not alter
the register bank. The RTL is Verilog-2001 compatible; the supported
parameterization assumes `DATA_WIDTH` is a byte multiple and that the register
address map fits in `ADDR_WIDTH` (the documented default is 32/32).

## Vivado GUI

1. Open Vivado.
2. Create a new RTL project using the FPGA part on your board.
3. Add every Verilog file under `rtl/` as **Design Sources**.
4. Add `tb/axi4lite_top_tb.v` as a **Simulation Source**.
5. Set `axi4lite_top` as the synthesis top.
6. Set `axi4lite_top_tb` as the simulation top.
7. Run **Run Synthesis**, then **Run Simulation > Run Behavioral Simulation**.
8. In the XSim Tcl console, use `run all` (or set the run time to at least
   `10 us`). The integration testbench performs every register transaction
   sequentially and may not finish within Vivado's default `1000 ns` run time.

## Vivado batch flow

The target FPGA part is board-dependent and must be supplied explicitly:

```text
vivado -mode batch -source scripts\vivado_run.tcl -tclargs <FPGA_PART>
```

For example, use the following only when it matches the target board:

```text
vivado -mode batch -source scripts\vivado_run.tcl -tclargs xc7a35tcpg236-1
```

The script expects the testbench at `tb\axi4lite_top_tb.v`; do not add a second copy from outside this project directory.
