`timescale 1ns/1ps
module tb_pcm_stream_i2s_player;
    reg bclk = 1'b0;
    reg lrck = 1'b1;
    reg rst_n = 1'b0;
    reg ready = 1'b0;
    reg request = 1'b0;
    wire ack, busy, done_toggle, error_toggle;
    wire source_start;
    wire [7:0] source_index;
    reg source_done = 1'b0;
    reg source_invalid = 1'b0;
    reg [15:0] pcm_data = 16'h1234;
    reg pcm_valid = 1'b0;
    wire pcm_ready;
    wire sdata;
    integer bclk_edges = 0;
    integer accepted = 0;
    reg [1:0] source_state = 0;

    always #5 bclk = ~bclk;
    always @(negedge bclk) begin
        bclk_edges = bclk_edges + 1;
        if ((bclk_edges % 32) == 0)
            lrck <= ~lrck;
    end

    pcm_stream_i2s_player dut(
        .bclk(bclk), .lrck(lrck), .rst_n(rst_n), .ready_async(ready),
        .request_toggle(request), .audio_index_async(8'd0),
        .ack_toggle(ack), .busy(busy), .done_toggle(done_toggle),
        .error_toggle(error_toggle), .source_start(source_start),
        .source_index(source_index), .source_done(source_done),
        .source_invalid(source_invalid), .pcm_data(pcm_data),
        .pcm_valid(pcm_valid), .pcm_ready(pcm_ready), .sdata(sdata)
    );

    // Minimal source model, updated on rising BCLK like flash_audio_source.
    always @(posedge bclk) begin
        source_done <= 1'b0;
        if (source_start) begin
            source_state <= 1;
            pcm_data <= 16'h1234;
            pcm_valid <= 1'b1;
        end else if (pcm_valid && pcm_ready) begin
            accepted <= accepted + 1;
            if (source_state == 1) begin
                source_state <= 2;
                pcm_data <= 16'hFEDC;
                pcm_valid <= 1'b1;
            end else begin
                source_state <= 3;
                pcm_valid <= 1'b0;
                source_done <= 1'b1;
            end
        end
    end

    initial begin
        #40 rst_n = 1'b1;
        #40 ready = 1'b1;
        #80 request = 1'b1;
        wait(done_toggle == 1'b1);
        #30;
        if (accepted != 2 || busy || error_toggle || source_index != 0) begin
            $display("FATAL: accepted=%0d busy=%b error=%b index=%0d", accepted, busy, error_toggle, source_index);
            $finish(1);
        end
        $display("PASS PCM stream player: accepted=%0d", accepted);
        $finish;
    end

    initial begin
        #100000;
        $display("FATAL: timeout");
        $finish(1);
    end
endmodule
