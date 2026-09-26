
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite Slave - Read Controller
//
// Handles:
//   AR Channel : Read Address
//   R  Channel : Read Data + Response
//
// Operation:
//   1. Accept read address when ARVALID && ARREADY
//   2. Capture the requested address
//   3. Obtain data from the register bank
//   4. Assert RVALID with RDATA
//   5. Wait for RREADY
//   6. Complete the read transaction
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_slave_read #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    //============================================================
    // Clock and Reset
    //============================================================
    input wire                     ACLK,
    input wire                     ARESETN,

    //============================================================
    // AXI4-Lite Read Address Channel
    //============================================================
    input wire [ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input wire [2:0]               S_AXI_ARPROT,
    input wire                     S_AXI_ARVALID,
    output reg                     S_AXI_ARREADY,

    //============================================================
    // AXI4-Lite Read Data Channel
    //============================================================
    output reg [DATA_WIDTH-1:0]    S_AXI_RDATA,
    output reg [1:0]               S_AXI_RRESP,
    output reg                     S_AXI_RVALID,
    input wire                     S_AXI_RREADY,

    //============================================================
    // Register Bank Interface
    //============================================================
    output reg [ADDR_WIDTH-1:0]    read_addr,
    input wire [DATA_WIDTH-1:0]    read_data,
    input wire                     read_addr_valid
);

    //============================================================
    // AXI Response Codes
    //============================================================
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    //============================================================
    // Read FSM States
    //============================================================
    localparam R_IDLE     = 2'd0;
    localparam R_RESPONSE = 2'd1;

    reg [1:0] read_state;

    //============================================================
    // Internal Read Address Latch
    //============================================================
    reg [ADDR_WIDTH-1:0] ar_addr_latch;
    reg                  ar_valid_latched;

    // The slave accepts one address at a time. READY is combinational so the
    // current ARVALID can handshake without relying on an old READY value.
    always @(*) begin
        S_AXI_ARREADY = (read_state == R_IDLE) &&
                        !ar_valid_latched &&
                        !S_AXI_RVALID;
    end

    //============================================================
    // Sequential Logic
    //============================================================
    always @(posedge ACLK) begin

        //========================================================
        // Reset
        //========================================================
        if (!ARESETN) begin

            read_state <= R_IDLE;

            // AXI outputs
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= {DATA_WIDTH{1'b0}};
            S_AXI_RRESP   <= RESP_OKAY;

            // Address latch
            ar_addr_latch   <= {ADDR_WIDTH{1'b0}};
            ar_valid_latched <= 1'b0;

            // Register interface
            read_addr <= {ADDR_WIDTH{1'b0}};
        end

        //========================================================
        // Normal Operation
        //========================================================
        else begin

            case (read_state)

                //================================================
                // IDLE
                //================================================
                R_IDLE: begin

                    //------------------------------------------------
                    // Ready to accept a new read address
                    //------------------------------------------------
                    if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                        ar_addr_latch    <= S_AXI_ARADDR;
                        ar_valid_latched <= 1'b1;
                        read_addr        <= S_AXI_ARADDR;
                        read_state       <= R_RESPONSE;
                    end
                end


                //================================================
                // RESPONSE
                //================================================
                R_RESPONSE: begin

                    // The address was captured on the previous edge. The
                    // register bank has now decoded that captured address.
                    if (!S_AXI_RVALID) begin
                        S_AXI_RDATA  <= read_data;
                        S_AXI_RRESP  <= read_addr_valid ? RESP_OKAY : RESP_SLVERR;
                        S_AXI_RVALID <= 1'b1;
                    end

                    //------------------------------------------------
                    // RVALID && RREADY = Read Data Handshake
                    //------------------------------------------------
                    if (S_AXI_RVALID && S_AXI_RREADY) begin

                        // Response accepted by master
                        S_AXI_RVALID <= 1'b0;

                        // Clear address latch
                        ar_valid_latched <= 1'b0;

                        // Return to idle
                        read_state <= R_IDLE;
                    end
                end


                //================================================
                // Default
                //================================================
                default: begin

                    read_state <= R_IDLE;

                    S_AXI_RVALID  <= 1'b0;

                    ar_valid_latched <= 1'b0;
                end

            endcase
        end
    end

endmodule
