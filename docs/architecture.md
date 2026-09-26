# AXI4-Lite architecture

`axi4lite_top` connects one transaction-generating master directly to one
AXI4-Lite slave. The master has independent write and read controllers. The
slave has independent AW/W/B and AR/R controllers and a synchronous register
bank.

```text
user interface
      |
axi4lite_top
  +---+---+
  |       |
 master  slave
  |       |
  |   +---+---+
  |   |       |
  | write   read
  | ctrl    ctrl
  |   \       /
  |   register bank
  +-- AXI4-Lite channels --+
```

The write controller latches AW and W independently, performs the register
write after both handshakes, and holds BVALID until BREADY. The read controller
latches AR, captures the combinational register-bank result into RDATA, and
holds RVALID until RREADY.

The implemented address map is byte-addressed, aligned, and valid only for
`0 <= address < NUM_REGS * (DATA_WIDTH/8)`. Invalid accesses do not modify the
register bank and return `SLVERR`. The project is intended for the default
32-bit data, 32-bit address, 16-register configuration; parameter changes
must preserve byte-multiple data width and a representable register space.