
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite Slave - Top-Level Wrapper
//
// Description:
//   Integrates the AXI4-Lite slave write controller,
//   AXI4-Lite slave read controller, and register bank.
//
// Architecture:
//
//                  AXI4-Lite Bus
//                        |
//          +-------------+-------------+
//          |                           |
//     Write Channels              Read Channels
//      AW / W / B                   AR / R
//          |                           |
//          v                           v
//   +---------------+         +---------------+
//   | Slave Write   |         |  Slave Read   |
//   | Controller    |         |  Controller   |
//   +-------+-------+         +-------+-------+
//           |                         |
//           +------------+------------+
//                        |
//                        v
//                 +-------------+
//                 | Register    |
//                 | Bank        |
//                 | 16 x 32-bit |
//                 +-------------+
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16
)(
    //============================================================
    // Clock and Reset
    //============================================================
    input wire                     ACLK,
    input wire                     ARESETN,

    //============================================================
    // AXI4-Lite Write Address Channel
    //============================================================
    input wire [ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    input wire [2:0]               S_AXI_AWPROT,
    input wire                     S_AXI_AWVALID,
    output wire                    S_AXI_AWREADY,

    //============================================================
    // AXI4-Lite Write Data Channel
    //============================================================
    input wire [DATA_WIDTH-1:0]    S_AXI_WDATA,
    input wire [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire                     S_AXI_WVALID,
    output wire                    S_AXI_WREADY,

    //============================================================
    // AXI4-Lite Write Response Channel
    //============================================================
    output wire [1:0]              S_AXI_BRESP,
    output wire                    S_AXI_BVALID,
    input wire                     S_AXI_BREADY,

    //============================================================
    // AXI4-Lite Read Address Channel
    //============================================================
    input wire [ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input wire [2:0]               S_AXI_ARPROT,
    input wire                     S_AXI_ARVALID,
    output wire                    S_AXI_ARREADY,

    //============================================================
    // AXI4-Lite Read Data Channel
    //============================================================
    output wire [DATA_WIDTH-1:0]   S_AXI_RDATA,
    output wire [1:0]              S_AXI_RRESP,
    output wire                    S_AXI_RVALID,
    input wire                     S_AXI_RREADY
);

    //============================================================
    // Internal Register Bank Interface
    //============================================================

    wire [DATA_WIDTH-1:0] register_read_data;
    wire [ADDR_WIDTH-1:0] register_read_addr;

    wire [ADDR_WIDTH-1:0] register_write_addr;
    wire [DATA_WIDTH-1:0] register_write_data;
    wire [(DATA_WIDTH/8)-1:0] register_write_strb;
    wire register_write_enable;
    wire register_write_addr_valid;
    wire register_read_addr_valid;

    //============================================================
    // Slave Write Controller
    //============================================================
    //
    // Handles:
    //   AW channel
    //   W channel
    //   B channel
    //
    // Generates a register write request when a complete
    // AXI4-Lite write transaction has been received.
    //============================================================

    axi4lite_slave_write #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_slave_write (

        .ACLK            (ACLK),
        .ARESETN         (ARESETN),

        // AW channel
        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWPROT   (S_AXI_AWPROT),
        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),

        // W channel
        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),
        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),

        // B channel
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),

        // Register interface
        .write_addr     (register_write_addr),
        .write_data     (register_write_data),
        .write_strb     (register_write_strb),
        .write_enable   (register_write_enable),
        .write_addr_valid (register_write_addr_valid)
    );

    //============================================================
    // Slave Read Controller
    //============================================================
    //
    // Handles:
    //   AR channel
    //   R channel
    //
    // Provides the selected register value to the AXI master.
    //============================================================

    axi4lite_slave_read #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_slave_read (

        .ACLK            (ACLK),
        .ARESETN         (ARESETN),

        // AR channel
        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARPROT   (S_AXI_ARPROT),
        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),

        // R channel
        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),
        .S_AXI_RVALID   (S_AXI_RVALID),
        .S_AXI_RREADY   (S_AXI_RREADY),

        // Register interface
        .read_data      (register_read_data),
        .read_addr      (register_read_addr),
        .read_addr_valid (register_read_addr_valid)
    );

    //============================================================
    // Register Bank
    //============================================================
    //
    // NUM_REGS registers are implemented.
    //
    // Default configuration:
    //     NUM_REGS  = 16
    //     DATA_WIDTH = 32
    //
    // Therefore:
    //
    //     REG0  -> address 0x00
    //     REG1  -> address 0x04
    //     REG2  -> address 0x08
    //       ...
    //     REG15 -> address 0x3C
    //
    // Byte strobes allow individual bytes of a register to
    // be updated.
    //============================================================

    axi4lite_slave_register_bank #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_register_bank (

        .ACLK          (ACLK),
        .ARESETN       (ARESETN),

        .write_addr    (register_write_addr),
        .write_data    (register_write_data),
        .write_strb    (register_write_strb),
        .write_enable  (register_write_enable),
        .write_addr_valid (register_write_addr_valid),

        .read_addr     (register_read_addr),
        .read_data     (register_read_data),
        .read_addr_valid (register_read_addr_valid)
    );

endmodule
