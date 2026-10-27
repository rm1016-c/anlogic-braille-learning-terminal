`timescale 1ns/1ps
module tb_pcm_byte_assembler;
    reg clk=0, rst_n=0, flush=0, byte_valid=0, sample_ready=0;
    reg [7:0] byte_data=0;
    wire byte_pause, sample_valid, partial_sample;
    wire [15:0] sample_data;
    pcm_byte_assembler dut(
        .clk(clk),.rst_n(rst_n),.flush(flush),.byte_data(byte_data),
        .byte_valid(byte_valid),.byte_pause(byte_pause),.sample_data(sample_data),
        .sample_valid(sample_valid),.sample_ready(sample_ready),
        .partial_sample(partial_sample));
    always #5 clk=~clk;

    task send_byte(input [7:0] value);
    begin
        @(posedge clk); byte_data<=value; byte_valid<=1;
        @(posedge clk); byte_valid<=0; #1;
    end endtask

    initial begin
        #30 rst_n=1;
        send_byte(8'h34);
        if(!partial_sample || sample_valid) begin $display("FATAL: low byte state"); $finish; end
        send_byte(8'h12);
        @(posedge clk);
        if(!sample_valid || sample_data!==16'h1234 || !byte_pause) begin
            $display("FATAL: little-endian assembly"); $finish;
        end
        repeat(3) @(posedge clk);
        if(!sample_valid) begin $display("FATAL: sample was not held"); $finish; end
        sample_ready<=1;
        @(posedge clk); sample_ready<=0;
        @(posedge clk);
        if(sample_valid || byte_pause) begin $display("FATAL: handshake did not clear"); $finish; end
        send_byte(8'h78);
        flush<=1; @(posedge clk); flush<=0; @(posedge clk);
        if(partial_sample || sample_valid) begin $display("FATAL: flush failed"); $finish; end
        $display("PASS PCM assembler: endian, backpressure and flush verified");
        $finish;
    end
endmodule
