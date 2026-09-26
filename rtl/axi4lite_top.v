
`timescale 1ns / 1ps

//==============================================================================
// AXI4-Lite Top-Level Module
//
// Purpose:
//   Integrates the AXI4-Lite Master and AXI4-Lite Slave.
//
// Architecture:
//
//              +----------------------+
//              |   AXI4-Lite TOP      |
//              |                      |
//   User ----->|   AXI4-Lite Master   |
//              |          |           |
//              |          | AXI Bus   |
//              |          v           |
//              |   AXI4-Lite Slave    |
//              |          |           |
//              |     Register Bank    |
//              +----------------------+
//
// AXI4-Lite Channels:
//   Write : AW (Address), W (Data), B (Response)
//   Read  : AR (Address), R (Data)
//
//==============================================================================

module axi4lite_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16
)(
    //--------------------------------------------------------------------------
    // Global Clock and Reset
    //--------------------------------------------------------------------------
    input wire ACLK,
    input wire ARESETN,

    //--------------------------------------------------------------------------
    // User Interface - Write
    //--------------------------------------------------------------------------
    input wire                  start_write,
    input wire [ADDR_WIDTH-1:0] write_addr,
    input wire [DATA_WIDTH-1:0] write_data,
    input wire [DATA_WIDTH/8-1:0] write_strb,

    output wire                  write_done,
    output wire [1:0]            write_resp,

    //--------------------------------------------------------------------------
    // User Interface - Read
    //--------------------------------------------------------------------------
    input wire                  start_read,
    input wire [ADDR_WIDTH-1:0] read_addr,

    output wire [DATA_WIDTH-1:0] read_data,
    output wire                  read_done,
    output wire [1:0]            read_resp
);

    //==========================================================================
    // AXI4-Lite Write Address Channel
    //==========================================================================

    wire [ADDR_WIDTH-1:0] axi_awaddr;
    wire [2:0]            axi_awprot;
    wire                  axi_awvalid;
    wire                  axi_awready;

    //==========================================================================
    // AXI4-Lite Write Data Channel
    //==========================================================================

    wire [DATA_WIDTH-1:0] axi_wdata;
    wire [DATA_WIDTH/8-1:0] axi_wstrb;
    wire                  axi_wvalid;
    wire                  axi_wready;

    //==========================================================================
    // AXI4-Lite Write Response Channel
    //==========================================================================

    wire [1:0]            axi_bresp;
    wire                  axi_bvalid;
    wire                  axi_bready;

    //==========================================================================
    // AXI4-Lite Read Address Channel
    //==========================================================================

    wire [ADDR_WIDTH-1:0] axi_araddr;
    wire [2:0]            axi_arprot;
    wire                  axi_arvalid;
    wire                  axi_arready;

    //==========================================================================
    // AXI4-Lite Read Data Channel
    //==========================================================================

    wire [DATA_WIDTH-1:0] axi_rdata;
    wire [1:0]            axi_rresp;
    wire                  axi_rvalid;
    wire                  axi_rready;


    //==========================================================================
    // AXI4-Lite MASTER
    //
    // The Master initiates AXI4-Lite read/write transactions.
    // Detailed protocol logic is implemented in:
    //
    //   rtl/master/axi4lite_master.v
    //
    //==========================================================================

    axi4lite_master #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_master (
        .ACLK       (ACLK),
        .ARESETN    (ARESETN),

        // User write interface
        .start_write(start_write),
        .addr       (write_addr),
        .write_data (write_data),
        .write_strb (write_strb),

        .write_done (write_done),
        .write_resp (write_resp),

        // User read interface
        .start_read (start_read),
        .read_addr  (read_addr),

        .read_data  (read_data),
        .read_done  (read_done),
        .read_resp  (read_resp),

        // AXI Write Address Channel
        .M_AXI_AWADDR (axi_awaddr),
        .M_AXI_AWPROT  (axi_awprot),
        .M_AXI_AWVALID (axi_awvalid),
        .M_AXI_AWREADY (axi_awready),

        // AXI Write Data Channel
        .M_AXI_WDATA  (axi_wdata),
        .M_AXI_WSTRB  (axi_wstrb),
        .M_AXI_WVALID (axi_wvalid),
        .M_AXI_WREADY (axi_wready),

        // AXI Write Response Channel
        .M_AXI_BRESP  (axi_bresp),
        .M_AXI_BVALID (axi_bvalid),
        .M_AXI_BREADY (axi_bready),

        // AXI Read Address Channel
        .M_AXI_ARADDR (axi_araddr),
        .M_AXI_ARPROT  (axi_arprot),
        .M_AXI_ARVALID(axi_arvalid),
        .M_AXI_ARREADY(axi_arready),

        // AXI Read Data Channel
        .M_AXI_RDATA  (axi_rdata),
        .M_AXI_RRESP  (axi_rresp),
        .M_AXI_RVALID (axi_rvalid),
        .M_AXI_RREADY (axi_rready)
    );


    //==========================================================================
    // AXI4-Lite SLAVE
    //
    // The Slave receives AXI4-Lite transactions and provides access to its
    // internal register bank.
    //
    // Detailed Slave logic is implemented in:
    //
    //   rtl/slave/axi4lite_slave.v
    //
    //==========================================================================

    axi4lite_slave #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_slave (
        .ACLK       (ACLK),
        .ARESETN    (ARESETN),

        // AXI Write Address Channel
        .S_AXI_AWADDR (axi_awaddr),
        .S_AXI_AWPROT  (axi_awprot),
        .S_AXI_AWVALID (axi_awvalid),
        .S_AXI_AWREADY (axi_awready),

        // AXI Write Data Channel
        .S_AXI_WDATA  (axi_wdata),
        .S_AXI_WSTRB  (axi_wstrb),
        .S_AXI_WVALID (axi_wvalid),
        .S_AXI_WREADY (axi_wready),

        // AXI Write Response Channel
        .S_AXI_BRESP  (axi_bresp),
        .S_AXI_BVALID (axi_bvalid),
        .S_AXI_BREADY (axi_bready),

        // AXI Read Address Channel
        .S_AXI_ARADDR (axi_araddr),
        .S_AXI_ARPROT  (axi_arprot),
        .S_AXI_ARVALID(axi_arvalid),
        .S_AXI_ARREADY(axi_arready),

        // AXI Read Data Channel
        .S_AXI_RDATA  (axi_rdata),
        .S_AXI_RRESP  (axi_rresp),
        .S_AXI_RVALID (axi_rvalid),
        .S_AXI_RREADY (axi_rready)
    );

endmodule

