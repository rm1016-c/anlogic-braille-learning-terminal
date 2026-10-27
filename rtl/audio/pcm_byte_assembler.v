// Convert little-endian PCM bytes into signed 16-bit samples.
// byte_pause prevents the SPI reader from delivering another byte while a
// complete sample is waiting for the downstream consumer.
module pcm_byte_assembler(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,
    input  wire [7:0]  byte_data,
    input  wire        byte_valid,
    output wire        byte_pause,
    output reg  [15:0] sample_data,
    output reg         sample_valid,
    input  wire        sample_ready,
    output reg         partial_sample
);
    reg [7:0] low_byte;
    assign byte_pause = sample_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            low_byte      <= 8'd0;
            sample_data   <= 16'd0;
            sample_valid  <= 1'b0;
            partial_sample <= 1'b0;
        end else if (flush) begin
            low_byte      <= 8'd0;
            sample_data   <= 16'd0;
            sample_valid  <= 1'b0;
            partial_sample <= 1'b0;
        end else begin
            if (sample_valid && sample_ready)
                sample_valid <= 1'b0;

            if (byte_valid) begin
                if (!partial_sample) begin
                    low_byte       <= byte_data;
                    partial_sample <= 1'b1;
                end else begin
                    sample_data    <= {byte_data, low_byte};
                    sample_valid   <= 1'b1;
                    partial_sample <= 1'b0;
                end
            end
        end
    end
endmodule
