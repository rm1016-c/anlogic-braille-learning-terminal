module braille_modes_top(
    input  wire       sys_clk,
    input  wire       reset_n,
    input  wire       uart_rx,
    output wire       uart_tx,
    input  wire [7:0] matrix_row_n,
    inout  wire [7:0] matrix_column,
    input  wire       aud_bclk,
    input  wire       aud_lrc,
    output wire       aud_mclk,
    output wire       aud_dacdat,
    inout  wire       aud_scl,
    inout  wire       aud_sda,
    output wire       flash_cs_n,
    output wire       flash_sclk,
    output wire       flash_mosi,
    input  wire       flash_miso,
    output wire       led_ready,
    output wire       led_busy,
    output wire       led_mode2,
    output wire       led_error
);
    reg [15:0] por = 16'd0;
    always @(posedge sys_clk) begin
        if (!reset_n)
            por <= 16'd0;
        else if (!(&por))
            por <= por + 1'b1;
    end

    wire locked;
    audio_pll pll(
        .clk50(sys_clk), .reset(!(&por)), .mclk(aud_mclk), .locked(locked)
    );

    wire arst_n = reset_n && (&por) && locked;
    reg [1:0] sys_reset;
    reg [1:0] aud_reset;
    always @(posedge sys_clk or negedge arst_n)
        if (!arst_n) sys_reset <= 2'b00;
        else sys_reset <= {sys_reset[0], 1'b1};
    always @(negedge aud_bclk or negedge arst_n)
        if (!arst_n) aud_reset <= 2'b00;
        else aud_reset <= {aud_reset[0], 1'b1};

    wire codec_ready;
    wire codec_error;
    wire [5:0] cfg_index;
    es8388_init codec_cfg(
        .clk(sys_clk), .rst_n(sys_reset[1]), .scl(aud_scl), .sda(aud_sda),
        .ready(codec_ready), .error(codec_error), .reg_index(cfg_index)
    );

    wire key_valid;
    wire [5:0] key_id;
    wire multi_key;
    matrix8x8_scanner scanner(
        .clk(sys_clk), .rst_n(sys_reset[1]), .row_n(matrix_row_n),
        .column(matrix_column), .key_valid(key_valid), .key_id(key_id),
        .multi_key(multi_key)
    );

    wire player_ack;
    wire player_busy;
    wire player_done;
    wire player_error;
    reg [1:0] ack_sync;
    reg [1:0] busy_sync;
    reg [1:0] done_sync;
    reg [1:0] error_sync;
    reg last_done;
    reg last_error;
    reg flash_error_latched;
    reg request_toggle;
    reg [7:0] selected_index;

    wire request_pending = request_toggle != ack_sync[1];
    wire audio_busy = request_pending || busy_sync[1];
    wire audio_done_pulse = done_sync[1] != last_done;

    wire control_request;
    wire [7:0] control_index;
    wire running;
    wire mode2_active;
    wire [5:0] question_id;
    wire [5:0] answer_current;
    wire answer_stage_b;
    wire session_done;
    wire [2:0] current_stage;
    wire [2:0] unlocked_stage;
    wire [1:0] practice_type;
    wire old_request;
    wire [7:0] old_index;
    wire controller_key_valid;
    wire [5:0] controller_key_id;
    wire target_valid;
    wire uart_byte_valid;
    wire [7:0] uart_byte_data;
    wire uart_byte_error,braille_valid,writing_wait;
    wire [4:0] braille_count;
    wire [95:0] braille_cells;
    wire image_active,image_valid,image_error;
    wire [4:0] image_count;
    wire [95:0] image_cells;
    braille_image_rx image_rx(.clk(sys_clk),.rst_n(sys_reset[1]),.enable(writing_wait),
        .byte_valid(uart_byte_valid),.byte_data(uart_byte_data),.byte_error(uart_byte_error),
        .active(image_active),.result_valid(image_valid),.frame_error(image_error),
        .cell_count(image_count),.cells(image_cells));
    wire hello_start,hello_busy,hello_done;
    braille_text_rx text_rx(
        .clk(sys_clk),.rst_n(sys_reset[1]),.enable(writing_wait&&!image_active),
        .byte_valid(uart_byte_valid),.byte_data(uart_byte_data),.byte_error(uart_byte_error),
        .result_valid(braille_valid),.cell_count(braille_count),.cells(braille_cells));
    uart_hello_tx hello_tx(.clk(sys_clk),.rst_n(sys_reset[1]),.start(hello_start),
        .tx(uart_tx),.busy(hello_busy),.done(hello_done));
    wire uart_edge_seen;
    uart_activity_diag rx_diag(
        .clk(sys_clk), .rst_n(sys_reset[1]), .rx(uart_rx),
        .edge_seen(uart_edge_seen)
    );
    reg [25:0] uart_byte_led_timer;
    reg uart_frame_seen;
    // Diagnostic indicators work in every mode. Valid byte LED lasts 1s;
    // valid frame LED remains asserted until reset, including repeated IDs.
    always @(posedge sys_clk or negedge arst_n) begin
        if (!arst_n) begin
            uart_byte_led_timer <= 0;
            uart_frame_seen <= 0;
        end else begin
            if (uart_byte_valid) uart_byte_led_timer <= 26'd50_000_000;
            else if (uart_byte_led_timer != 0)
                uart_byte_led_timer <= uart_byte_led_timer - 1'b1;
            if (target_valid) uart_frame_seen <= 1'b1;
        end
    end
    wire [2:0] target_id;
    wire mode3_active;
    wire controller_hold;
    wire external_exit;
    recognition_uart uart(
        .clk(sys_clk), .rst_n(sys_reset[1]), .rx(uart_rx),
        .target_valid(target_valid), .target_id(target_id), .byte_valid(uart_byte_valid),
        .byte_data(uart_byte_data),.byte_error(uart_byte_error)
    );
    mode3_uart_bridge bridge(
        .clk(sys_clk), .rst_n(sys_reset[1]), .running(running),
        .mode2_active(mode2_active), .key_valid(key_valid), .key_id(key_id),
        .audio_busy(audio_busy), .audio_done(audio_done_pulse),
        .old_request(old_request), .old_index(old_index),
        .target_valid(target_valid), .target_id(target_id),
        .result_valid(image_valid||braille_valid),
        .result_count(image_valid?image_count:braille_count),
        .result_cells(image_valid?image_cells:braille_cells),
        .tx_busy(hello_busy),.tx_done(hello_done),.hello_start(hello_start),.writing_wait(writing_wait),
        .controller_key_valid(controller_key_valid), .controller_key_id(controller_key_id),
        .request(control_request), .audio_index(control_index), .mode3_active(mode3_active),
        .controller_hold(controller_hold), .external_exit(external_exit)
    );

    // Final flow starts with stage 1 only.  A retest score of at least 8/10
    // unlocks the next stage inside the controller.
    mode12_controller #(.DIAGNOSTIC_MODE(0), .MODE3_AUDIO_TEST(0), .ENABLE_HOLD(1), .INITIAL_UNLOCKED_STAGE(0)) controller(
        .clk(sys_clk), .rst_n(sys_reset[1]), .codec_ready(codec_ready),
        .hold(controller_hold),
        .external_exit(external_exit),
        .key_valid(controller_key_valid), .key_id(controller_key_id), .audio_busy(audio_busy||mode3_active),
        .audio_done(audio_done_pulse&&!mode3_active), .audio_request(old_request),
        .audio_index(old_index), .running(running),
        .mode2_active(mode2_active), .question_id(question_id),
        .answer_current(answer_current), .answer_stage_b(answer_stage_b),
        .session_done(session_done), .current_stage(current_stage),
        .unlocked_stage(unlocked_stage), .practice_type(practice_type)
    );

    always @(posedge sys_clk or negedge arst_n) begin
        if (!arst_n) begin
            ack_sync           <= 2'b00;
            busy_sync          <= 2'b00;
            done_sync          <= 2'b00;
            error_sync         <= 2'b00;
            last_done          <= 1'b0;
            last_error         <= 1'b0;
            flash_error_latched <= 1'b0;
            request_toggle     <= 1'b0;
            selected_index     <= 8'd0;
        end else begin
            ack_sync   <= {ack_sync[0], player_ack};
            busy_sync  <= {busy_sync[0], player_busy};
            done_sync  <= {done_sync[0], player_done};
            error_sync <= {error_sync[0], player_error};
            last_done  <= done_sync[1];
            last_error <= error_sync[1];

            if (control_request) begin
                selected_index <= control_index;
                request_toggle <= ~request_toggle;
            end
            if (error_sync[1] != last_error)
                flash_error_latched <= 1'b1;
        end
    end

    wire source_start;
    wire [7:0] source_index;
    wire source_busy;
    wire source_done;
    wire source_invalid;
    wire [15:0] pcm_data;
    wire pcm_valid;
    wire pcm_ready;

    flash_audio_source #(.SPI_CLK_DIV(6)) flash_source(
        .clk(aud_bclk), .rst_n(aud_reset[1]),
        .play_start(source_start), .audio_index(source_index),
        .busy(source_busy), .done(source_done),
        .invalid_index(source_invalid), .pcm_data(pcm_data),
        .pcm_valid(pcm_valid), .pcm_ready(pcm_ready),
        .flash_cs_n(flash_cs_n), .flash_sclk(flash_sclk),
        .flash_mosi(flash_mosi), .flash_miso(flash_miso)
    );

    pcm_stream_i2s_player player(
        .bclk(aud_bclk), .lrck(aud_lrc), .rst_n(aud_reset[1]),
        .ready_async(codec_ready), .request_toggle(request_toggle),
        .audio_index_async(selected_index), .ack_toggle(player_ack),
        .busy(player_busy), .done_toggle(player_done),
        .error_toggle(player_error), .source_start(source_start),
        .source_index(source_index), .source_done(source_done),
        .source_invalid(source_invalid), .pcm_data(pcm_data),
        .pcm_valid(pcm_valid), .pcm_ready(pcm_ready), .sdata(aud_dacdat)
    );

    // Diagnostic version: LED0 is raw RX activity, not codec readiness.
    assign led_ready = uart_edge_seen;
    assign led_busy  = uart_byte_led_timer != 0;
    assign led_mode2 = uart_frame_seen;
    assign led_error = codec_error || flash_error_latched || multi_key;
endmodule
