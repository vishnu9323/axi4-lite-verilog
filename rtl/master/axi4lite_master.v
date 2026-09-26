
`timescale 1ns / 1ps

//==============================================================================
// AXI4-Lite Master
//
// Purpose:
//   Top-level AXI4-Lite Master wrapper.
//
// Architecture:
//
//                  USER INTERFACE
//                        |
//              +---------+---------+
//              |                   |
//              v                   v
//        WRITE CONTROLLER    READ CONTROLLER
//              |                   |
//              v                   v
//          AW / W / B          AR / R
//              |                   |
//              +---------+---------+
//                        |
//                    AXI4-Lite BUS
//
// The actual transaction control is implemented in:
//
//   axi4lite_master_write.v
//   axi4lite_master_read.v
//
//==============================================================================

module axi4lite_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    //--------------------------------------------------------------------------
    // Clock and Reset
    //--------------------------------------------------------------------------
    input wire ACLK,
    input wire ARESETN,

    //--------------------------------------------------------------------------
    // User Write Interface
    //--------------------------------------------------------------------------
    input wire                    start_write,
    input wire [ADDR_WIDTH-1:0]   addr,
    input wire [DATA_WIDTH-1:0]   write_data,
    input wire [DATA_WIDTH/8-1:0] write_strb,

    output wire                   write_done,
    output wire [1:0]             write_resp,

    //--------------------------------------------------------------------------
    // User Read Interface
    //--------------------------------------------------------------------------
    input wire                    start_read,
    input wire [ADDR_WIDTH-1:0]   read_addr,

    output wire [DATA_WIDTH-1:0]  read_data,
    output wire                   read_done,
    output wire [1:0]             read_resp,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Address Channel
    //--------------------------------------------------------------------------
    output wire [ADDR_WIDTH-1:0]  M_AXI_AWADDR,
    output wire [2:0]             M_AXI_AWPROT,
    output wire                   M_AXI_AWVALID,
    input  wire                   M_AXI_AWREADY,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Data Channel
    //--------------------------------------------------------------------------
    output wire [DATA_WIDTH-1:0]  M_AXI_WDATA,
    output wire [DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                   M_AXI_WVALID,
    input  wire                   M_AXI_WREADY,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Response Channel
    //--------------------------------------------------------------------------
    input wire [1:0]              M_AXI_BRESP,
    input wire                    M_AXI_BVALID,
    output wire                   M_AXI_BREADY,

    //--------------------------------------------------------------------------
    // AXI4-Lite Read Address Channel
    //--------------------------------------------------------------------------
    output wire [ADDR_WIDTH-1:0]  M_AXI_ARADDR,
    output wire [2:0]             M_AXI_ARPROT,
    output wire                   M_AXI_ARVALID,
    input wire                    M_AXI_ARREADY,

    //--------------------------------------------------------------------------
    // AXI4-Lite Read Data Channel
    //--------------------------------------------------------------------------
    input wire [DATA_WIDTH-1:0]   M_AXI_RDATA,
    input wire [1:0]              M_AXI_RRESP,
    input wire                    M_AXI_RVALID,
    output wire                   M_AXI_RREADY
);

    //==========================================================================
    // WRITE CONTROLLER
    //
    // Handles:
    //   AW - Write Address
    //   W  - Write Data
    //   B  - Write Response
    //==========================================================================

    axi4lite_master_write #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_master_write (

        .ACLK        (ACLK),
        .ARESETN     (ARESETN),

        // User interface
        .start_write (start_write),
        .addr        (addr),
        .write_data  (write_data),
        .write_strb  (write_strb),

        .write_done  (write_done),
        .write_resp  (write_resp),

        // AXI Write Address Channel
        .M_AXI_AWADDR  (M_AXI_AWADDR),
        .M_AXI_AWPROT   (M_AXI_AWPROT),
        .M_AXI_AWVALID  (M_AXI_AWVALID),
        .M_AXI_AWREADY  (M_AXI_AWREADY),

        // AXI Write Data Channel
        .M_AXI_WDATA   (M_AXI_WDATA),
        .M_AXI_WSTRB   (M_AXI_WSTRB),
        .M_AXI_WVALID  (M_AXI_WVALID),
        .M_AXI_WREADY  (M_AXI_WREADY),

        // AXI Write Response Channel
        .M_AXI_BRESP   (M_AXI_BRESP),
        .M_AXI_BVALID  (M_AXI_BVALID),
        .M_AXI_BREADY  (M_AXI_BREADY)
    );


    //==========================================================================
    // READ CONTROLLER
    //
    // Handles:
    //   AR - Read Address
    //   R  - Read Data
    //==========================================================================

    axi4lite_master_read #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_master_read (

        .ACLK       (ACLK),
        .ARESETN    (ARESETN),

        // User interface
        .start_read  (start_read),
        .read_addr   (read_addr),

        .read_data   (read_data),
        .read_done   (read_done),
        .read_resp   (read_resp),

        // AXI Read Address Channel
        .M_AXI_ARADDR  (M_AXI_ARADDR),
        .M_AXI_ARPROT   (M_AXI_ARPROT),
        .M_AXI_ARVALID  (M_AXI_ARVALID),
        .M_AXI_ARREADY  (M_AXI_ARREADY),

        // AXI Read Data Channel
        .M_AXI_RDATA   (M_AXI_RDATA),
        .M_AXI_RRESP   (M_AXI_RRESP),
        .M_AXI_RVALID  (M_AXI_RVALID),
        .M_AXI_RREADY  (M_AXI_RREADY)
    );

endmodule

