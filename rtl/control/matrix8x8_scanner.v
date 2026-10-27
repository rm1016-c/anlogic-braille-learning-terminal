// Scan the external 8x8 matrix keyboard.
//
// The keyboard PCB has 10 kOhm pull-ups on R1..R8.  One C line is pulled
// low at a time; all other C lines are high impedance.  A pressed key is
// therefore observed as a low level on one row input.
//
// key_id follows the schematic numbering: key_id = S_number - 1
//                                     = row_index * 8 + column_index
// where row_index is R1..R8 and column_index is C1..C8.
module matrix8x8_scanner #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer COLUMN_US       = 250,
    parameter integer DEBOUNCE_FRAMES = 8
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] row_n,
    inout  wire [7:0] column,
    output reg        key_valid,
    output reg  [5:0] key_id,
    output reg        multi_key
);
    localparam integer COLUMN_TICKS = (CLK_HZ / 1_000_000) * COLUMN_US;
    localparam integer COUNT_W = (COLUMN_TICKS <= 2) ? 1 : $clog2(COLUMN_TICKS);
    localparam integer DB_W = (DEBOUNCE_FRAMES <= 1) ? 1 : $clog2(DEBOUNCE_FRAMES + 1);

    reg [COUNT_W-1:0] tick_count;
    reg [2:0] scan_column;
    reg       frame_found;
    reg       frame_multiple;
    reg [5:0] frame_key;
    reg [6:0] observed_last;
    reg [6:0] stable_code;
    reg [DB_W-1:0] debounce_count;

    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : column_driver
            assign column[g] = (scan_column == g[2:0]) ? 1'b0 : 1'bz;
        end
    endgenerate

    wire [7:0] pressed_rows = ~row_n;
    wire       sample_any = |pressed_rows;
    wire       sample_one = sample_any && ((pressed_rows & (pressed_rows - 1'b1)) == 8'd0);

    reg [2:0] sampled_row;
    integer i;
    always @* begin
        sampled_row = 3'd0;
        for (i = 0; i < 8; i = i + 1)
            if (pressed_rows[i])
                sampled_row = i[2:0];
    end

    wire sample_conflict = sample_any && (!sample_one || frame_found);
    wire frame_multiple_next = frame_multiple || sample_conflict;
    wire frame_found_next = frame_found || (sample_one && !frame_found);
    wire [5:0] frame_key_next = (sample_one && !frame_found)
                              ? {sampled_row, scan_column} : frame_key;
    wire [6:0] completed_code = (frame_found_next && !frame_multiple_next)
                              ? {1'b1, frame_key_next} : 7'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_count       <= {COUNT_W{1'b0}};
            scan_column      <= 3'd0;
            frame_found      <= 1'b0;
            frame_multiple   <= 1'b0;
            frame_key        <= 6'd0;
            observed_last    <= 7'd0;
            stable_code      <= 7'd0;
            debounce_count   <= {DB_W{1'b0}};
            key_valid        <= 1'b0;
            key_id           <= 6'd0;
            multi_key        <= 1'b0;
        end else begin
            key_valid <= 1'b0;

            if (tick_count == COLUMN_TICKS - 1) begin
                tick_count <= {COUNT_W{1'b0}};

                if (scan_column == 3'd7) begin
                    scan_column    <= 3'd0;
                    frame_found    <= 1'b0;
                    frame_multiple <= 1'b0;
                    frame_key      <= 6'd0;
                    multi_key      <= frame_multiple_next;

                    if (completed_code == observed_last) begin
                        if (debounce_count < DEBOUNCE_FRAMES)
                            debounce_count <= debounce_count + 1'b1;

                        if ((debounce_count == DEBOUNCE_FRAMES - 1) &&
                            (completed_code != stable_code)) begin
                            stable_code <= completed_code;
                            if (completed_code[6]) begin
                                key_id    <= completed_code[5:0];
                                key_valid <= 1'b1;
                            end
                        end
                    end else begin
                        observed_last  <= completed_code;
                        debounce_count <= {{(DB_W-1){1'b0}}, 1'b1};
                    end
                end else begin
                    scan_column <= scan_column + 1'b1;
                    frame_found <= frame_found_next;
                    frame_multiple <= frame_multiple_next;
                    frame_key <= frame_key_next;
                end
            end else begin
                tick_count <= tick_count + 1'b1;
            end
        end
    end
endmodule
