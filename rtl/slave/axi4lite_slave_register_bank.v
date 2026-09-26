
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite Slave - Register Bank
//
// Description:
//   Implements a configurable memory-mapped register bank.
//
// Default configuration:
//   16 registers
//   32-bit register width
//
// Address mapping:
//
//   0x00 -> REG0
//   0x04 -> REG1
//   0x08 -> REG2
//   ...
//   0x3C -> REG15
//
// Write:
//   write_enable = 1
//   write_addr
//   write_data
//   write_strb
//
// Read:
//   read_addr
//   read_data
//
// WSTRB allows individual bytes of a register to be modified.
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_slave_register_bank #(
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
    // Write Interface
    //============================================================
    input wire [ADDR_WIDTH-1:0]    write_addr,
    input wire [DATA_WIDTH-1:0]    write_data,
    input wire [(DATA_WIDTH/8)-1:0] write_strb,
    input wire                     write_enable,
    output wire                    write_addr_valid,

    //============================================================
    // Read Interface
    //============================================================
    input wire [ADDR_WIDTH-1:0]    read_addr,
    output reg [DATA_WIDTH-1:0]    read_data,
    output wire                    read_addr_valid
);

    //============================================================
    // Register Storage
    //============================================================
    reg [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];

    //============================================================
    // Address Index
    //
    // For 32-bit registers:
    //
    //   Address 0x00 >> 2 = 0  -> REG0
    //   Address 0x04 >> 2 = 1  -> REG1
    //   Address 0x08 >> 2 = 2  -> REG2
    //
    // Only the required address bits are used to select a register.
    //============================================================

    localparam integer BYTES_PER_REG = DATA_WIDTH/8;
    localparam [ADDR_WIDTH-1:0] REGISTER_SPACE_BYTES =
                                      NUM_REGS * BYTES_PER_REG;

    integer write_index;
    integer read_index;

    integer i;
    integer byte_index;

    /*
     * The default (and supported) map is a byte-addressed, 32-bit register
     * bank: addresses must be aligned and lie in [0, NUM_REGS*4).
     * Keeping the range check before indexing prevents out-of-bounds array
     * accesses for high addresses and for misaligned aliases.
     */
    assign write_addr_valid = (write_addr < REGISTER_SPACE_BYTES) &&
                              ((write_addr % BYTES_PER_REG) == 0);
    assign read_addr_valid  = (read_addr < REGISTER_SPACE_BYTES) &&
                              ((read_addr % BYTES_PER_REG) == 0);

    //============================================================
    // WRITE LOGIC
    //============================================================
    //
    // The write occurs when write_enable is asserted.
    //
    // WSTRB:
    //   1 -> update corresponding byte
    //   0 -> keep old byte
    //
    // For a 32-bit register:
    //
    //   WSTRB[0] -> bits [7:0]
    //   WSTRB[1] -> bits [15:8]
    //   WSTRB[2] -> bits [23:16]
    //   WSTRB[3] -> bits [31:24]
    //============================================================

    always @(posedge ACLK) begin

        if (!ARESETN) begin

            // Initialize all registers to zero
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end

        end

        else begin

            //====================================================
            // Register Write
            //====================================================
            if (write_enable && write_addr_valid) begin

                // Convert byte address to register index
                write_index = write_addr / BYTES_PER_REG;

                // Check whether address is within register range
                if (write_index < NUM_REGS) begin

                    // Update individual bytes according to WSTRB
                    for (byte_index = 0;
                         byte_index < (DATA_WIDTH/8);
                         byte_index = byte_index + 1) begin

                        if (write_strb[byte_index]) begin

                            registers[write_index]
                                [byte_index*8 +: 8]
                                <= write_data[byte_index*8 +: 8];

                        end
                    end
                end
            end
        end
    end

    //============================================================
    // READ LOGIC
    //============================================================
    //
    // Read is combinational:
    //
    //   read_addr -> register index -> read_data
    //
    // Invalid addresses return zero.
    //============================================================

    always @(*) begin

        // Default value for invalid address
        read_data = {DATA_WIDTH{1'b0}};
        read_index = 0;

        // Check valid register address
        if (read_addr_valid) begin
            read_index = read_addr / BYTES_PER_REG;
            read_data = registers[read_index];
        end
    end

endmodule
