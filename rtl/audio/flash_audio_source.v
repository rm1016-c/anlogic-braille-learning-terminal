// Resolve one global audio_index and stream its PCM16 samples from W25Q64.
// All ports except SPI pins are synchronous to clk.
module flash_audio_source #(
    parameter integer SPI_CLK_DIV = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        play_start,
    input  wire [7:0]  audio_index,
    output reg         busy,
    output reg         done,
    output reg         invalid_index,
    output wire [15:0] pcm_data,
    output wire        pcm_valid,
    input  wire        pcm_ready,
    output wire        flash_cs_n,
    output wire        flash_sclk,
    output wire        flash_mosi,
    input  wire        flash_miso
);
    wire [23:0] descriptor_address;
    wire [23:0] descriptor_samples;
    wire descriptor_valid;
    audio_descriptor_rom descriptors(
        .audio_index(audio_index),
        .start_address(descriptor_address),
        .sample_count(descriptor_samples),
        .valid(descriptor_valid)
    );

    reg reader_start;
    reg assembler_flush;
    reg [23:0] latched_address;
    reg [24:0] latched_byte_count;
    reg reader_finished;
    wire reader_busy, reader_done, byte_valid, byte_pause, partial_sample;
    wire [7:0] byte_data;

    w25q64_stream_reader #(.CLK_DIV(SPI_CLK_DIV)) reader(
        .clk(clk), .rst_n(rst_n), .start(reader_start),
        .start_address(latched_address), .byte_count(latched_byte_count),
        .pause(byte_pause), .busy(reader_busy), .done(reader_done),
        .byte_data(byte_data), .byte_valid(byte_valid),
        .flash_cs_n(flash_cs_n), .flash_sclk(flash_sclk),
        .flash_mosi(flash_mosi), .flash_miso(flash_miso)
    );

    pcm_byte_assembler assembler(
        .clk(clk), .rst_n(rst_n), .flush(assembler_flush),
        .byte_data(byte_data), .byte_valid(byte_valid), .byte_pause(byte_pause),
        .sample_data(pcm_data), .sample_valid(pcm_valid),
        .sample_ready(pcm_ready), .partial_sample(partial_sample)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy               <= 1'b0;
            done               <= 1'b0;
            invalid_index      <= 1'b0;
            reader_start       <= 1'b0;
            assembler_flush    <= 1'b0;
            latched_address    <= 24'd0;
            latched_byte_count <= 25'd0;
            reader_finished    <= 1'b0;
        end else begin
            done            <= 1'b0;
            invalid_index   <= 1'b0;
            reader_start    <= 1'b0;
            assembler_flush <= 1'b0;

            if (!busy && play_start) begin
                if (!descriptor_valid || descriptor_samples == 0) begin
                    invalid_index <= 1'b1;
                end else begin
                    latched_address    <= descriptor_address;
                    latched_byte_count <= {descriptor_samples, 1'b0};
                    assembler_flush    <= 1'b1;
                    reader_start       <= 1'b1;
                    reader_finished    <= 1'b0;
                    busy               <= 1'b1;
                end
            end

            if (busy && reader_done)
                reader_finished <= 1'b1;

            if (busy && reader_finished && !pcm_valid && !partial_sample) begin
                busy            <= 1'b0;
                done            <= 1'b1;
                reader_finished <= 1'b0;
            end
        end
    end
endmodule
