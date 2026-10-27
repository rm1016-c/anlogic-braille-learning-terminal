`timescale 1ns/1ps
module tb_mode1_key_lut;
    reg [5:0] key_id;
    wire valid;
    wire [7:0] audio_index;
    integer c;
    integer p;
    integer expected_local;

    mode1_key_lut dut(.key_id(key_id), .valid(valid), .audio_index(audio_index));

    initial begin
        for (c = 0; c < 8; c = c + 1) begin
            for (p = 0; p < 6; p = p + 1) begin
                key_id = ((7-p) * 8) + c;
                expected_local = c * 6 + p;
                #1;
                if (expected_local < 47) begin
                    if (!valid || audio_index !== 7 + expected_local)
                        $fatal(1, "mode1 map mismatch key=%0d expected audio=%0d got=%0d valid=%0d",
                               key_id, 7+expected_local, audio_index, valid);
                end else if (valid) begin
                    $fatal(1, "reserved key S24 must be invalid");
                end
            end
        end
        key_id = 6'd0; #1;
        if (valid) $fatal(1, "mode2 key leaked into mode1 LUT");
        $display("PASS mode1 LUT: 47 pinyin keys and reserved cell verified");
        $finish;
    end
endmodule
