// Streamed PCM16 player for the ES8388 configuration used by audio_demo.
// ES8388 is BCLK/LRCK master. The source and this player share bclk; the
// source updates on rising edges and the serializer updates on falling edges.
module pcm_stream_i2s_player(
    input  wire        bclk,
    input  wire        lrck,
    input  wire        rst_n,
    input  wire        ready_async,
    input  wire        request_toggle,
    input  wire [7:0]  audio_index_async,
    output reg         ack_toggle,
    output reg         busy,
    output reg         done_toggle,
    output reg         error_toggle,
    output reg         source_start,
    output reg  [7:0]  source_index,
    input  wire        source_done,
    input  wire        source_invalid,
    input  wire [15:0] pcm_data,
    input  wire        pcm_valid,
    output reg         pcm_ready,
    output reg         sdata
);
    reg [1:0] req_sync;
    reg [1:0] ready_sync;
    reg [7:0] index_sync_1;
    reg [7:0] index_sync_2;
    reg lrck_sample;
    reg last_lrck;
    reg source_finished;
    reg [23:0] frame_sample;
    reg [23:0] shift;
    reg [5:0] bits_left;

    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n)
            lrck_sample <= 1'b0;
        else
            lrck_sample <= lrck;
    end

    wire edge_lr = lrck_sample != last_lrck;
    wire [23:0] next_sample = {pcm_data, 8'h00};

    always @(negedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            req_sync        <= 2'b00;
            ready_sync      <= 2'b00;
            index_sync_1    <= 8'd0;
            index_sync_2    <= 8'd0;
            ack_toggle      <= 1'b0;
            busy            <= 1'b0;
            done_toggle     <= 1'b0;
            error_toggle    <= 1'b0;
            source_start    <= 1'b0;
            source_index    <= 8'd0;
            pcm_ready       <= 1'b0;
            last_lrck       <= 1'b0;
            source_finished <= 1'b0;
            frame_sample    <= 24'd0;
            shift           <= 24'd0;
            bits_left       <= 6'd0;
            sdata           <= 1'b0;
        end else begin
            req_sync     <= {req_sync[0], request_toggle};
            ready_sync   <= {ready_sync[0], ready_async};
            index_sync_1 <= audio_index_async;
            index_sync_2 <= index_sync_1;
            last_lrck    <= lrck_sample;
            source_start <= 1'b0;
            pcm_ready    <= 1'b0;

            // A request is acknowledged exactly once. Requests arriving while
            // busy are rejected rather than replayed after the current clip.
            if (req_sync[1] != ack_toggle) begin
                ack_toggle <= req_sync[1];
                if (ready_sync[1] && !busy) begin
                    busy            <= 1'b1;
                    source_finished <= 1'b0;
                    source_index    <= index_sync_2;
                    source_start    <= 1'b1;
                    frame_sample    <= 24'd0;
                end
            end

            if (busy && source_done)
                source_finished <= 1'b1;

            if (busy && source_invalid) begin
                busy         <= 1'b0;
                error_toggle <= ~error_toggle;
            end

            if (edge_lr) begin
                if (!lrck_sample) begin
                    // Left channel: accept the next mono sample. If the flash
                    // has not supplied it yet, transmit one silent frame and
                    // try again at the next left boundary.
                    if (busy && pcm_valid) begin
                        frame_sample <= next_sample;
                        sdata        <= next_sample[23];
                        shift        <= {next_sample[22:0], 1'b0};
                        bits_left    <= 6'd23;
                        pcm_ready    <= 1'b1;
                    end else begin
                        frame_sample <= 24'd0;
                        sdata        <= 1'b0;
                        shift        <= 24'd0;
                        bits_left    <= 6'd0;
                        if (busy && source_finished) begin
                            busy            <= 1'b0;
                            done_toggle     <= ~done_toggle;
                            source_finished <= 1'b0;
                        end
                    end
                end else begin
                    // Right channel repeats the current mono sample.
                    sdata     <= frame_sample[23];
                    shift     <= {frame_sample[22:0], 1'b0};
                    bits_left <= 6'd23;
                end
            end else if (bits_left != 0) begin
                sdata     <= shift[23];
                shift     <= {shift[22:0], 1'b0};
                bits_left <= bits_left - 1'b1;
            end else begin
                sdata <= 1'b0;
            end
        end
    end
endmodule
