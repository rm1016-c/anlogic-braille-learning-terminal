// Mode-1 physical layout, viewed exactly as in the user's photo:
//   left six physical columns are R8,R7,R6,R5,R4,R3;
//   top-to-bottom physical rows are C1..C8.
// The 47 pinyin items are placed left-to-right then top-to-bottom.  The final
// cell (R3,C8 / S24) is reserved.
module mode1_key_lut(
    input  wire [5:0] key_id,
    output reg        valid,
    output reg  [7:0] audio_index
);
    reg [2:0] row_index;
    reg [2:0] column_index;
    reg [5:0] local_index;

    always @* begin
        row_index    = key_id[5:3];
        column_index = key_id[2:0];
        local_index  = 6'd0;
        valid        = 1'b0;
        audio_index  = 8'd0;

        if (row_index >= 3'd2) begin
            // photo_column = 7-row_index, pinyin_index = C*6+photo_column
            local_index = (column_index * 6) + (7 - row_index);
            if (local_index < 47) begin
                valid       = 1'b1;
                audio_index = 8'd7 + local_index;
            end
        end
    end
endmodule
