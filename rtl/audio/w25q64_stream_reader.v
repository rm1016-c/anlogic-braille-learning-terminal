// W25Q64 continuous read controller, SPI mode 0, command 0x03.
// SPI_SCLK = clk / (2*CLK_DIV). CLK_DIV must keep SCLK within the board limit.
// byte_valid is a one-clk pulse. pause is sampled only between complete bytes.
module w25q64_stream_reader #(
    parameter integer CLK_DIV = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [23:0] start_address,
    input  wire [24:0] byte_count,
    input  wire        pause,
    output reg         busy,
    output reg         done,
    output reg  [7:0]  byte_data,
    output reg         byte_valid,
    output reg         flash_cs_n,
    output reg         flash_sclk,
    output reg         flash_mosi,
    input  wire        flash_miso
);
    localparam ST_IDLE = 1'b0;
    localparam ST_XFER = 1'b1;

    reg state;
    reg [31:0] tx_shift;
    reg [5:0] command_bits;
    reg command_done;
    reg [2:0] receive_bits;
    reg [7:0] rx_shift;
    reg [24:0] bytes_remaining;
    reg last_byte_received;
    reg [15:0] divider;

    wire divider_tick = divider == CLK_DIV - 1;
    wire low_phase_stall = command_done && !flash_sclk &&
                           (pause || last_byte_received);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= ST_IDLE;
            tx_shift           <= 32'd0;
            command_bits       <= 6'd0;
            command_done       <= 1'b0;
            receive_bits       <= 3'd0;
            rx_shift           <= 8'd0;
            bytes_remaining    <= 25'd0;
            last_byte_received <= 1'b0;
            divider            <= 16'd0;
            busy               <= 1'b0;
            done               <= 1'b0;
            byte_data          <= 8'd0;
            byte_valid         <= 1'b0;
            flash_cs_n         <= 1'b1;
            flash_sclk         <= 1'b0;
            flash_mosi         <= 1'b0;
        end else begin
            done       <= 1'b0;
            byte_valid <= 1'b0;

            if (state == ST_IDLE) begin
                divider    <= 16'd0;
                flash_sclk <= 1'b0;
                flash_cs_n <= 1'b1;
                busy       <= 1'b0;
                if (start) begin
                    if (byte_count == 0) begin
                        done <= 1'b1;
                    end else begin
                        state              <= ST_XFER;
                        busy               <= 1'b1;
                        flash_cs_n         <= 1'b0;
                        tx_shift           <= {8'h03, start_address};
                        flash_mosi         <= 1'b0; // 0x03 bit 7
                        command_bits       <= 6'd0;
                        command_done       <= 1'b0;
                        receive_bits       <= 3'd0;
                        bytes_remaining    <= byte_count;
                        last_byte_received <= 1'b0;
                    end
                end
            end else begin
                if (low_phase_stall) begin
                    divider <= 16'd0;
                    if (last_byte_received) begin
                        flash_cs_n         <= 1'b1;
                        busy               <= 1'b0;
                        done               <= 1'b1;
                        state              <= ST_IDLE;
                        last_byte_received <= 1'b0;
                    end
                end else if (divider_tick) begin
                    divider <= 16'd0;
                    if (!flash_sclk) begin
                        // Rising edge: flash samples MOSI; controller samples MISO.
                        flash_sclk <= 1'b1;
                        if (command_done) begin
                            rx_shift <= {rx_shift[6:0], flash_miso};
                            if (receive_bits == 3'd7) begin
                                byte_data       <= {rx_shift[6:0], flash_miso};
                                byte_valid      <= 1'b1;
                                receive_bits    <= 3'd0;
                                bytes_remaining <= bytes_remaining - 1'b1;
                                if (bytes_remaining == 1)
                                    last_byte_received <= 1'b1;
                            end else begin
                                receive_bits <= receive_bits + 1'b1;
                            end
                        end
                    end else begin
                        // Falling edge: change MOSI only after the flash sampled it.
                        flash_sclk <= 1'b0;
                        if (!command_done) begin
                            if (command_bits == 6'd31) begin
                                command_done <= 1'b1;
                                flash_mosi   <= 1'b0;
                            end else begin
                                command_bits <= command_bits + 1'b1;
                                tx_shift     <= {tx_shift[30:0], 1'b0};
                                flash_mosi   <= tx_shift[30];
                            end
                        end
                    end
                end else begin
                    divider <= divider + 1'b1;
                end
            end
        end
    end
endmodule
