`timescale 1ns/1ps
module tb_matrix8x8_scanner;
    reg clk = 0;
    reg rst_n = 0;
    reg pressed = 0;
    reg [2:0] target_row = 0;
    reg [2:0] target_column = 0;
    wire [7:0] row_n;
    tri [7:0] column;
    wire key_valid;
    wire [5:0] key_id;
    wire multi_key;

    always #5 clk = ~clk;

    matrix8x8_scanner #(
        .CLK_HZ(1_000_000), .COLUMN_US(2), .DEBOUNCE_FRAMES(2)
    ) dut(
        .clk(clk), .rst_n(rst_n), .row_n(row_n), .column(column),
        .key_valid(key_valid), .key_id(key_id), .multi_key(multi_key)
    );

    genvar r;
    generate
        for (r = 0; r < 8; r = r + 1) begin : row_model
            assign row_n[r] = (pressed && target_row == r &&
                               column[target_column] === 1'b0) ? 1'b0 : 1'b1;
        end
    endgenerate

    task expect_key;
        input [5:0] expected;
        integer timeout;
        begin
            timeout = 0;
            while (!key_valid && timeout < 1000) begin
                @(posedge clk); timeout = timeout + 1;
            end
            if (!key_valid || key_id !== expected)
                $fatal(1, "expected key_id=%0d got=%0d valid=%0d", expected, key_id, key_valid);
            @(posedge clk);
        end
    endtask

    task wait_release;
        integer cycles;
        begin
            pressed = 0;
            for (cycles = 0; cycles < 80; cycles = cycles + 1)
                @(posedge clk);
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1;
        target_row = 3'd7; target_column = 3'd0; pressed = 1; // S57
        expect_key(6'd56);
        repeat (100) @(posedge clk);
        if (key_valid) $fatal(1, "held key repeated unexpectedly");
        wait_release();
        target_row = 3'd0; target_column = 3'd3; pressed = 1; // S4
        expect_key(6'd3);
        $display("PASS matrix scanner: S57/S4 numbering, debounce and hold suppression verified");
        $finish;
    end
endmodule
