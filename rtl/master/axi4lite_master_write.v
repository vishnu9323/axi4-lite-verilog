
`timescale 1ns / 1ps

//==============================================================================
// AXI4-Lite Master Write Controller
//
// Handles the three AXI4-Lite write channels:
//
//   AW : Write Address
//   W  : Write Data
//   B  : Write Response
//
// Write Transaction:
//
//   IDLE
//     |
//     | start_write
//     v
//   SEND_WRITE
//     |
//     | AWVALID && AWREADY
//     | WVALID  && WREADY
//     v
//   WAIT_RESPONSE
//     |
//     | BVALID && BREADY
//     v
//   DONE
//     |
//     v
//   IDLE
//
// Important AXI Rule:
//
//   A transfer occurs only when:
//       VALID && READY
//
// The AW and W channels are independent in AXI4-Lite, therefore the
// controller keeps separate flags for address and data acceptance.
//==============================================================================

module axi4lite_master_write #(
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
    input wire                     start_write,
    input wire [ADDR_WIDTH-1:0]    addr,
    input wire [DATA_WIDTH-1:0]    write_data,
    input wire [DATA_WIDTH/8-1:0]  write_strb,

    output reg                     write_done,
    output reg [1:0]               write_resp,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Address Channel - AW
    //--------------------------------------------------------------------------
    output reg [ADDR_WIDTH-1:0]    M_AXI_AWADDR,
    output reg [2:0]               M_AXI_AWPROT,
    output reg                     M_AXI_AWVALID,
    input wire                      M_AXI_AWREADY,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Data Channel - W
    //--------------------------------------------------------------------------
    output reg [DATA_WIDTH-1:0]    M_AXI_WDATA,
    output reg [DATA_WIDTH/8-1:0]  M_AXI_WSTRB,
    output reg                     M_AXI_WVALID,
    input wire                      M_AXI_WREADY,

    //--------------------------------------------------------------------------
    // AXI4-Lite Write Response Channel - B
    //--------------------------------------------------------------------------
    input wire [1:0]               M_AXI_BRESP,
    input wire                     M_AXI_BVALID,
    output reg                     M_AXI_BREADY
);

    //==========================================================================
    // AXI Response Codes
    //==========================================================================

    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    //==========================================================================
    // Write FSM States
    //==========================================================================

    localparam W_IDLE     = 2'd0;
    localparam W_TRANSFER = 2'd1;
    localparam W_RESPONSE = 2'd2;

    reg [1:0] write_state;

    //==========================================================================
    // Handshake Tracking
    //
    // AW and W are independent AXI channels.
    //
    // aw_accepted = AW handshake completed
    // w_accepted  = W handshake completed
    //==========================================================================

    reg aw_accepted;
    reg w_accepted;
    reg request_seen;

    //==========================================================================
    // Sequential Write Controller
    //==========================================================================

    always @(posedge ACLK) begin

        //======================================================================
        // RESET
        //======================================================================

        if (!ARESETN) begin

            write_state <= W_IDLE;

            M_AXI_AWADDR  <= {ADDR_WIDTH{1'b0}};
            M_AXI_AWPROT  <= 3'b000;
            M_AXI_AWVALID <= 1'b0;

            M_AXI_WDATA   <= {DATA_WIDTH{1'b0}};
            M_AXI_WSTRB   <= {(DATA_WIDTH/8){1'b0}};
            M_AXI_WVALID  <= 1'b0;

            M_AXI_BREADY  <= 1'b0;

            write_done    <= 1'b0;
            write_resp    <= RESP_OKAY;

            aw_accepted   <= 1'b0;
            w_accepted    <= 1'b0;
            request_seen  <= 1'b0;

        end

        //======================================================================
        // NORMAL OPERATION
        //======================================================================

        else begin

            // write_done is a one-clock pulse
            write_done <= 1'b0;

            if (!start_write)
                request_seen <= 1'b0;

            case (write_state)

                //================================================================
                // IDLE
                //
                // Wait for the user to request a write.
                //================================================================

                W_IDLE: begin

                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b0;
                    M_AXI_BREADY  <= 1'b0;

                    aw_accepted <= 1'b0;
                    w_accepted  <= 1'b0;

                    if (start_write && !request_seen) begin

                        // Capture write address
                        M_AXI_AWADDR  <= addr;
                        M_AXI_AWPROT  <= 3'b000;
                        M_AXI_AWVALID <= 1'b1;

                        // Capture write data
                        M_AXI_WDATA   <= write_data;
                        M_AXI_WSTRB   <= write_strb;
                        M_AXI_WVALID  <= 1'b1;
                        request_seen  <= 1'b1;

                        // Move to transfer state
                        write_state <= W_TRANSFER;

                    end
                end


                //================================================================
                // WRITE TRANSFER
                //
                // AW and W can complete independently.
                //================================================================

                W_TRANSFER: begin

                    //------------------------------------------------------------
                    // AW Channel Handshake
                    //
                    // Transfer occurs when:
                    //
                    //     AWVALID && AWREADY
                    //------------------------------------------------------------

                    if (M_AXI_AWVALID && M_AXI_AWREADY) begin

                        M_AXI_AWVALID <= 1'b0;
                        aw_accepted   <= 1'b1;

                    end


                    //------------------------------------------------------------
                    // W Channel Handshake
                    //
                    // Transfer occurs when:
                    //
                    //     WVALID && WREADY
                    //------------------------------------------------------------

                    if (M_AXI_WVALID && M_AXI_WREADY) begin

                        M_AXI_WVALID <= 1'b0;
                        w_accepted   <= 1'b1;

                    end


                    //------------------------------------------------------------
                    // Both AW and W have been accepted
                    //
                    // Now wait for the slave's B response.
                    //------------------------------------------------------------

                    if ((aw_accepted || 
                         (M_AXI_AWVALID && M_AXI_AWREADY)) &&
                        (w_accepted  ||
                         (M_AXI_WVALID && M_AXI_WREADY))) begin

                        M_AXI_BREADY <= 1'b1;

                        write_state <= W_RESPONSE;

                    end

                end


                //================================================================
                // WAIT FOR WRITE RESPONSE
                //================================================================

                W_RESPONSE: begin

                    //------------------------------------------------------------
                    // B Channel Handshake
                    //
                    // Transfer occurs when:
                    //
                    //     BVALID && BREADY
                    //------------------------------------------------------------

                    if (M_AXI_BVALID && M_AXI_BREADY) begin

                        // Capture response from slave
                        write_resp <= M_AXI_BRESP;

                        // Stop accepting response
                        M_AXI_BREADY <= 1'b0;

                        // Generate one-cycle completion pulse
                        write_done <= 1'b1;

                        // Clear handshake flags
                        aw_accepted <= 1'b0;
                        w_accepted  <= 1'b0;

                        // Transaction complete
                        write_state <= W_IDLE;

                    end

                end


                //================================================================
                // DEFAULT
                //================================================================

                default: begin

                    write_state <= W_IDLE;

                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b0;
                    M_AXI_BREADY  <= 1'b0;

                    aw_accepted <= 1'b0;
                    w_accepted  <= 1'b0;

                end

            endcase

        end

    end

endmodule
