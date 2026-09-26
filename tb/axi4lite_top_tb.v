`timescale 1ns / 1ps

module axi4lite_top_tb;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter NUM_REGS   = 16;
    localparam integer CLK_PERIOD = 10;
    localparam integer TIMEOUT_CYCLES = 100;

    reg ACLK, ARESETN;
    reg start_write, start_read;
    reg [ADDR_WIDTH-1:0] write_addr, read_addr;
    reg [DATA_WIDTH-1:0] write_data;
    reg [(DATA_WIDTH/8)-1:0] write_strb;
    wire write_done, read_done;
    wire [1:0] write_resp, read_resp;
    wire [DATA_WIDTH-1:0] read_data;
    integer errors;

    axi4lite_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
                   .NUM_REGS(NUM_REGS)) DUT (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .start_write(start_write), .write_addr(write_addr),
        .write_data(write_data), .write_strb(write_strb),
        .write_done(write_done), .write_resp(write_resp),
        .start_read(start_read), .read_addr(read_addr),
        .read_data(read_data), .read_done(read_done), .read_resp(read_resp));

    initial begin ACLK = 1'b0; forever #(CLK_PERIOD/2) ACLK = ~ACLK; end
    initial begin
        $dumpfile("axi4lite_top_tb.vcd");
        $dumpvars(0, axi4lite_top_tb);
    end

    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [(DATA_WIDTH/8)-1:0] strb;
        input [1:0] expected_resp;
        integer n;
        begin
            @(negedge ACLK);
            write_addr = addr; write_data = data; write_strb = strb;
            start_write = 1'b1;
            @(negedge ACLK); start_write = 1'b0;
            n = 0;
            while (!write_done && n < TIMEOUT_CYCLES) begin
                @(posedge ACLK);
                #1;
                n = n + 1;
            end
            if (n >= TIMEOUT_CYCLES) begin
                $display("ERROR: write timeout at %h", addr); errors = errors + 1;
            end else if (write_resp !== expected_resp) begin
                $display("ERROR: BRESP %b, expected %b at %h",
                         write_resp, expected_resp, addr);
                errors = errors + 1;
            end
            @(posedge ACLK);
            #1;
        end
    endtask

    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected_data;
        input [1:0] expected_resp;
        integer n;
        begin
            @(negedge ACLK); read_addr = addr; start_read = 1'b1;
            @(negedge ACLK); start_read = 1'b0;
            n = 0;
            while (!read_done && n < TIMEOUT_CYCLES) begin
                @(posedge ACLK);
                #1;
                n = n + 1;
            end
            if (n >= TIMEOUT_CYCLES) begin
                $display("ERROR: read timeout at %h", addr); errors = errors + 1;
            end else begin
                if (read_resp !== expected_resp ||
                    (expected_resp == 2'b00 && read_data !== expected_data)) begin
                    $display("ERROR: read %h data=%h/%h resp=%b/%b",
                             addr, read_data, expected_data,
                             read_resp, expected_resp);
                    errors = errors + 1;
                end
            end
            @(posedge ACLK);
            #1;
        end
    endtask

    integer i;
    initial begin
        start_write = 0; start_read = 0; write_addr = 0; read_addr = 0;
        write_data = 0; write_strb = 0; ARESETN = 0; errors = 0;
        repeat (4) @(posedge ACLK);
        ARESETN = 1;

        axi_write(32'h0, 32'h12345678, 4'b1111, 2'b00);
        axi_read (32'h0, 32'h12345678, 2'b00);

        for (i = 0; i < NUM_REGS; i = i + 1) begin
            axi_write(i*4, 32'h10000000+i, 4'b1111, 2'b00);
            axi_read (i*4, 32'h10000000+i, 2'b00);
        end

        axi_write(32'h0c, 32'haabbccdd, 4'b1111, 2'b00);
        axi_write(32'h0c, 32'h00000011, 4'b0001, 2'b00);
        axi_read (32'h0c, 32'haabbcc11, 2'b00);

        axi_write(32'h10, 32'h00000000, 4'b1111, 2'b00);
        axi_write(32'h10, 32'h000000aa, 4'b0001, 2'b00);
        axi_write(32'h10, 32'h0000bb00, 4'b0010, 2'b00);
        axi_write(32'h10, 32'h00cc0000, 4'b0100, 2'b00);
        axi_write(32'h10, 32'hdd000000, 4'b1000, 2'b00);
        axi_read (32'h10, 32'hddccbbaa, 2'b00);

        /* Both misalignment and out-of-range accesses must not alias. */
        axi_read (32'h02, 32'h00000000, 2'b10);
        axi_write(32'h02, 32'hffffffff, 4'b1111, 2'b10);
        axi_read (NUM_REGS*4, 32'h00000000, 2'b10);
        axi_write(NUM_REGS*4, 32'hffffffff, 4'b1111, 2'b10);

        ARESETN = 0; repeat (3) @(posedge ACLK); ARESETN = 1;
        axi_read(32'h0, 32'h00000000, 2'b00);

        if (errors == 0) begin
            $display("AXI4-LITE TEST PASS");
        end
        else begin
            $display("AXI4-LITE TEST FAIL: %0d errors", errors);
            $fatal(1, "AXI4-LITE testbench failed");
        end
        #20;
        $finish;
    end
endmodule
