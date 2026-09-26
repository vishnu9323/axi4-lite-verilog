
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite Slave - Write Controller
//
// Handles:
//   AW Channel : Write Address
//   W  Channel : Write Data
//   B  Channel : Write Response
//
// Important AXI4-Lite property:
//   AW and W channels are independent.
//   Therefore, address and data may arrive in different cycles.
//
// Operation:
//   1. Accept AWADDR when AWVALID && AWREADY
//   2. Accept WDATA/WSTRB when WVALID && WREADY
//   3. Wait until both are received
//   4. Generate register write request
//   5. Generate B response
//   6. Wait for BREADY
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_slave_write #(
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
    output reg                     S_AXI_AWREADY,

    //============================================================
    // AXI4-Lite Write Data Channel
    //============================================================
    input wire [DATA_WIDTH-1:0]    S_AXI_WDATA,
    input wire [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire                     S_AXI_WVALID,
    output reg                     S_AXI_WREADY,

    //============================================================
    // AXI4-Lite Write Response Channel
    //============================================================
    output reg [1:0]               S_AXI_BRESP,
    output reg                     S_AXI_BVALID,
    input wire                     S_AXI_BREADY,

    //============================================================
    // Register Bank Interface
    //============================================================
    output reg [ADDR_WIDTH-1:0]    write_addr,
    output reg [DATA_WIDTH-1:0]    write_data,
    output reg [(DATA_WIDTH/8)-1:0] write_strb,
    output reg                     write_enable,
    input wire                     write_addr_valid
);

    //============================================================
    // AXI Response Codes
    //============================================================
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;
    localparam integer BYTES_PER_REG = DATA_WIDTH/8;
    localparam [ADDR_WIDTH-1:0] REGISTER_SPACE_BYTES =
                                      NUM_REGS * BYTES_PER_REG;

    //============================================================
    // Internal Latches
    //============================================================

    reg [ADDR_WIDTH-1:0] aw_addr_latch;
    reg                  aw_valid_latched;

    reg [DATA_WIDTH-1:0] wdata_latch;
    reg [(DATA_WIDTH/8)-1:0] wstrb_latch;
    reg                  w_valid_latched;

    //============================================================
    // Write FSM
    //============================================================

    localparam W_IDLE     = 2'd0;
    localparam W_COMMIT   = 2'd1;
    localparam W_APPLY    = 2'd2;
    localparam W_RESPONSE = 2'd3;

    reg [1:0] write_state;

    // READY is combinational so a transfer is recognized from the current
    // VALID/READY values, without depending on a previous registered READY.
    always @(*) begin
        S_AXI_AWREADY = 1'b0;
        S_AXI_WREADY  = 1'b0;

        if (write_state == W_IDLE && !S_AXI_BVALID) begin
            S_AXI_AWREADY = !aw_valid_latched;
            S_AXI_WREADY  = !w_valid_latched;
        end
    end

    //============================================================
    // Sequential Logic
    //============================================================

    always @(posedge ACLK) begin

        //========================================================
        // Reset
        //========================================================
        if (!ARESETN) begin

            // AXI outputs
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= RESP_OKAY;

            // Internal latches
            aw_addr_latch   <= {ADDR_WIDTH{1'b0}};
            aw_valid_latched <= 1'b0;

            wdata_latch     <= {DATA_WIDTH{1'b0}};
            wstrb_latch     <= {(DATA_WIDTH/8){1'b0}};
            w_valid_latched <= 1'b0;

            // Register interface
            write_addr   <= {ADDR_WIDTH{1'b0}};
            write_data   <= {DATA_WIDTH{1'b0}};
            write_strb   <= {(DATA_WIDTH/8){1'b0}};
            write_enable <= 1'b0;

            write_state <= W_IDLE;
        end

        //========================================================
        // Normal Operation
        //========================================================
        else begin

            // Default: write request is a one-cycle pulse
            write_enable <= 1'b0;

            case (write_state)

                //================================================
                // IDLE
                //================================================
                W_IDLE: begin

                    //------------------------------------------------
                    // Accept Write Address
                    //------------------------------------------------
                    if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                        aw_addr_latch    <= S_AXI_AWADDR;
                        aw_valid_latched <= 1'b1;
                    end

                    //------------------------------------------------
                    // Accept Write Data
                    //------------------------------------------------
                    if (S_AXI_WVALID && S_AXI_WREADY) begin
                        wdata_latch     <= S_AXI_WDATA;
                        wstrb_latch     <= S_AXI_WSTRB;
                        w_valid_latched <= 1'b1;
                    end

                    if ((aw_valid_latched ||
                         (S_AXI_AWVALID && S_AXI_AWREADY)) &&
                        (w_valid_latched ||
                         (S_AXI_WVALID && S_AXI_WREADY))) begin
                        write_state <= W_COMMIT;
                    end
                end

                W_COMMIT: begin
                    // Present the complete transaction to the register bank.
                    // The write-enable pulse is issued on the following edge,
                    // after these nonblocking assignments have taken effect.
                    write_addr   <= aw_addr_latch;
                    write_data   <= wdata_latch;
                    write_strb   <= wstrb_latch;
                    write_state  <= W_APPLY;
                end

                W_APPLY: begin
                    // The register-bank inputs are stable from W_COMMIT.
                    write_enable <= write_addr_valid;
                    S_AXI_BRESP  <=
                        ((aw_addr_latch < REGISTER_SPACE_BYTES) &&
                         ((aw_addr_latch % BYTES_PER_REG) == 0)) ?
                        RESP_OKAY : RESP_SLVERR;
                    S_AXI_BVALID <= 1'b1;
                    write_state  <= W_RESPONSE;
                end


                //================================================
                // RESPONSE
                //================================================
                W_RESPONSE: begin

                    // Address/data channels are no longer
                    // accepting a new transaction.
                    //------------------------------------------------
                    // Wait for Master to Accept B Response
                    //------------------------------------------------
                    if (S_AXI_BVALID && S_AXI_BREADY) begin

                        S_AXI_BVALID <= 1'b0;

                        // Clear transaction latches
                        aw_valid_latched <= 1'b0;
                        w_valid_latched  <= 1'b0;

                        // Return to idle
                        write_state <= W_IDLE;
                    end
                end


                //================================================
                // Default
                //================================================
                default: begin

                    write_state <= W_IDLE;

                    S_AXI_BVALID  <= 1'b0;

                    aw_valid_latched <= 1'b0;
                    w_valid_latched  <= 1'b0;
                end

            endcase
        end
    end

endmodule
