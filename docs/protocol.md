## Controller behavior

AW and W are accepted independently and are held until both have arrived.
The slave emits exactly one B response and holds it stable until BREADY.
Likewise, an accepted AR address is held while RVALID is asserted until RREADY.
The master keeps VALID asserted until the corresponding handshake, and user
completion signals are one-cycle pulses.

AWREADY, WREADY, and ARREADY are combinational acceptance signals. The slave
captures the read address first, then decodes that captured address before
loading RDATA/RRESP. Write payloads are captured independently, presented to
the register bank after both handshakes, and only then is the B response
generated.

Only aligned addresses in the implemented register window are legal. Invalid
reads return zero with `RRESP=SLVERR`; invalid writes return `BRESP=SLVERR`
and are ignored.