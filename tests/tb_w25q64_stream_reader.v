`timescale 1ns/1ps
module tb_w25q64_stream_reader;
    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;
    reg [23:0] start_address = 0;
    reg [24:0] byte_count = 0;
    reg pause = 0;
    wire busy, done, byte_valid;
    wire [7:0] byte_data;
    wire cs_n, sclk, mosi;
    reg miso = 0;

    w25q64_stream_reader #(.CLK_DIV(2)) dut(
        .clk(clk), .rst_n(rst_n), .start(start),
        .start_address(start_address), .byte_count(byte_count), .pause(pause),
        .busy(busy), .done(done), .byte_data(byte_data), .byte_valid(byte_valid),
        .flash_cs_n(cs_n), .flash_sclk(sclk), .flash_mosi(mosi), .flash_miso(miso)
    );

    always #5 clk = ~clk;

    reg [7:0] memory [0:4095];
    integer i;
    integer input_bits = 0;
    reg [31:0] input_shift = 0;
    reg [31:0] captured_word = 0;
    reg reading = 0;
    reg [23:0] model_address = 0;
    integer model_bit = 7;
    integer received = 0;

    initial for (i=0; i<4096; i=i+1) memory[i] = i[7:0] ^ 8'h5a;

    always @(negedge cs_n) begin
        input_bits = 0;
        input_shift = 0;
        reading = 0;
        miso = 0;
    end

    always @(posedge sclk) begin
        if (!reading) begin
            input_shift = {input_shift[30:0], mosi};
            input_bits = input_bits + 1;
            if (input_bits == 32) begin
                captured_word = input_shift;
                if (captured_word[31:24] !== 8'h03) begin
                    $display("FATAL: command mismatch captured=%08x", captured_word);
                    $finish;
                end
                model_address = captured_word[23:0];
                model_bit = 7;
                reading = 1;
            end
        end
    end

    always @(negedge sclk) begin
        if (reading) begin
            miso = memory[model_address][model_bit];
            if (model_bit == 0) begin
                model_bit = 7;
                model_address = model_address + 1'b1;
            end else begin
                model_bit = model_bit - 1;
            end
        end
    end

    always @(posedge clk) begin
        if (byte_valid) begin
            if (byte_data !== ((8'h80 + received) ^ 8'h5a)) begin
                $display("FATAL: byte %0d got %02x expected %02x", received,
                         byte_data, ((8'h80 + received) ^ 8'h5a));
                $finish;
            end
            received = received + 1;
            if (received == 5) pause <= 1'b1;
        end
    end

    initial begin
        #40 rst_n = 1;
        @(posedge clk);
        start_address <= 24'h000080;
        byte_count <= 25'd20;
        start <= 1;
        @(posedge clk);
        start <= 0;
        wait(received == 5);
        repeat(20) @(posedge clk);
        if (received != 5) begin
            $display("FATAL: pause did not stop at byte boundary");
            $finish;
        end
        pause <= 0;
        wait(done);
        if (received != 20 || busy) begin
            $display("FATAL: completion mismatch received=%0d busy=%0b", received, busy);
            $finish;
        end
        if (!cs_n || sclk) begin
            $display("FATAL: SPI pins not idle after completion");
            $finish;
        end
        $display("PASS w25q64 reader: 20 bytes and pause control verified");
        $finish;
    end

    initial begin
        #200000;
        $display("FATAL: timeout");
        $finish;
    end
endmodule
