
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite Master - Read Controller
//
// Description:
//   Handles the AXI4-Lite read transaction:
//       1. Send read address (AR channel)
//       2. Wait for ARREADY handshake
//       3. Wait for read data/response (R channel)
//       4. Capture RDATA and RRESP
//
// FSM:
//       R_IDLE
//          |
//          | start_read
//          v
//       R_ADDRESS
//          |
//          | ARVALID && ARREADY
//          v
//       R_DATA
//          |
//          | RVALID && RREADY
//          v
//       R_IDLE
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_master_read #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    //============================================================
    // Clock and Reset
    //============================================================
    input  wire                     ACLK,
    input  wire                     ARESETN,

    //============================================================
    // User/Application Interface
    //============================================================
    input  wire                     start_read,
    input  wire [ADDR_WIDTH-1:0]    read_addr,

    output reg  [DATA_WIDTH-1:0]    read_data,
    output reg                      read_done,
    output reg  [1:0]               read_resp,

    //============================================================
    // AXI4-Lite Read Address Channel
    //============================================================
    output reg  [ADDR_WIDTH-1:0]    M_AXI_ARADDR,
    output reg  [2:0]               M_AXI_ARPROT,
    output reg                      M_AXI_ARVALID,
    input  wire                     M_AXI_ARREADY,

    //============================================================
    // AXI4-Lite Read Data Channel
    //============================================================
    input  wire [DATA_WIDTH-1:0]    M_AXI_RDATA,
    input  wire [1:0]               M_AXI_RRESP,
    input  wire                     M_AXI_RVALID,
    output reg                      M_AXI_RREADY
);

    //============================================================
    // FSM State Encoding
    //============================================================
    localparam R_IDLE    = 2'd0;
    localparam R_ADDRESS = 2'd1;
    localparam R_DATA    = 2'd2;

    reg [1:0] read_state;
    reg       request_seen;

    //============================================================
    // Sequential Logic
    //============================================================
    always @(posedge ACLK) begin

        //========================================================
        // Active-Low Reset
        //========================================================
        if (!ARESETN) begin

            read_state    <= R_IDLE;

            read_data     <= {DATA_WIDTH{1'b0}};
            read_done     <= 1'b0;
            read_resp     <= 2'b00;

            M_AXI_ARADDR  <= {ADDR_WIDTH{1'b0}};
            M_AXI_ARPROT  <= 3'b000;
            M_AXI_ARVALID <= 1'b0;

            M_AXI_RREADY  <= 1'b0;
            request_seen  <= 1'b0;
        end

        //========================================================
        // Normal Operation
        //========================================================
        else begin

            // Default: read_done is a one-clock pulse
            read_done <= 1'b0;

            if (!start_read)
                request_seen <= 1'b0;

            case (read_state)

                //================================================
                // IDLE
                //================================================
                R_IDLE: begin

                    M_AXI_ARVALID <= 1'b0;
                    M_AXI_RREADY  <= 1'b0;

                    // Start a new read transaction
                    if (start_read && !request_seen) begin

                        // Capture read address
                        M_AXI_ARADDR <= read_addr;

                        // Normal/non-secure data access
                        M_AXI_ARPROT <= 3'b000;

                        // Assert address valid
                        M_AXI_ARVALID <= 1'b1;
                        request_seen  <= 1'b1;

                        // Move to address phase
                        read_state <= R_ADDRESS;
                    end
                end


                //================================================
                // ADDRESS PHASE
                //================================================
                R_ADDRESS: begin

                    // Wait for AXI AR handshake
                    if (M_AXI_ARVALID && M_AXI_ARREADY) begin

                        // Address has been accepted
                        M_AXI_ARVALID <= 1'b0;

                        // Ready to receive read data
                        M_AXI_RREADY <= 1'b1;

                        // Move to data phase
                        read_state <= R_DATA;
                    end
                end


                //================================================
                // DATA PHASE
                //================================================
                R_DATA: begin

                    // Wait for AXI R handshake
                    if (M_AXI_RVALID && M_AXI_RREADY) begin

                        // Capture returned data
                        read_data <= M_AXI_RDATA;

                        // Capture AXI response
                        read_resp <= M_AXI_RRESP;

                        // Transaction completed
                        read_done <= 1'b1;

                        // Stop accepting read data
                        M_AXI_RREADY <= 1'b0;

                        // Return to idle
                        read_state <= R_IDLE;
                    end
                end


                //================================================
                // Default
                //================================================
                default: begin

                    read_state    <= R_IDLE;

                    M_AXI_ARVALID <= 1'b0;
                    M_AXI_RREADY  <= 1'b0;

                end

            endcase
        end
    end

endmodule
