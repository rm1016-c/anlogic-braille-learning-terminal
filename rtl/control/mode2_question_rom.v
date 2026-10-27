// Six-stage mode-2 question library. Stages 1..5 contain 42 unique words;
// stage 6 reuses the entries as a comprehensive exercise.
// bit0..bit5 correspond to Braille dots 1..6.
module mode2_question_rom(
    input wire [5:0] question_id,
    output reg [5:0] answer_a, output reg [5:0] answer_b,
    output reg [7:0] question_audio, output reg has_initial, output reg valid
);
    localparam [5:0] B=6'b000011,P=6'b001111,M=6'b001101,F=6'b001011;
    localparam [5:0] D=6'b011001,T=6'b011110,N=6'b011101,L=6'b000111;
    localparam [5:0] GJ=6'b011011,KQ=6'b000101,HX=6'b010011;
    localparam [5:0] ZH=6'b001100,CH=6'b011111,SH=6'b110001,R=6'b011010;
    localparam [5:0] Z=6'b110101,C=6'b001001,S=6'b001110;
    localparam [5:0] VA=6'b010100,VOE=6'b100010,VI=6'b001010,VU=6'b100101;
    localparam [5:0] VV=6'b101100,VER=6'b010111,VAI=6'b101010,VAO=6'b010110;
    localparam [5:0] VEI=6'b101110,VOU=6'b110111,VIE=6'b010001,VIOU=6'b110011;
    localparam [5:0] VUE=6'b111110,VAN=6'b100111,VANG=6'b100110,VEN=6'b110100;
    localparam [5:0] VIN=6'b101111,VUN=6'b010010,VVN=6'b111000,VENG=6'b111100;
    localparam [5:0] VING=6'b100001,VONG=6'b110010;
    always @* begin
        answer_a=0; answer_b=0; question_audio=0; has_initial=1; valid=1;
        case(question_id)
            0:begin answer_a=B;answer_b=VA;end 1:begin answer_a=M;answer_b=VA;end
            2:begin answer_a=D;answer_b=VA;end 3:begin answer_a=T;answer_b=VA;end
            4:begin answer_a=N;answer_b=VI;end 5:begin answer_a=L;answer_b=VU;end
            6:begin answer_a=GJ;answer_b=VOE;end 7:begin answer_a=KQ;answer_b=VOE;end
            8:begin answer_a=HX;answer_b=VOE;end 9:begin answer_a=GJ;answer_b=VI;end
            10:begin answer_a=KQ;answer_b=VI;end 11:begin answer_a=HX;answer_b=VI;end
            12:begin answer_a=P;answer_b=VA;end 13:begin answer_a=F;answer_b=VA;end
            14:begin answer_a=P;answer_b=VOE;end
            15:begin answer_a=Z;answer_b=VA;end 16:begin answer_a=C;answer_b=VA;end
            17:begin answer_a=S;answer_b=VA;end 18:begin answer_a=ZH;answer_b=VA;end
            19:begin answer_a=CH;answer_b=VA;end 20:begin answer_a=SH;answer_b=VA;end
            21:begin answer_a=R;answer_b=VOE;end
            22:begin answer_a=B;answer_b=VAI;end 23:begin answer_a=B;answer_b=VEI;end
            24:begin answer_a=GJ;answer_b=6'b111010;end 25:begin answer_a=GJ;answer_b=VAO;end
            26:begin answer_a=SH;answer_b=VOU;end 27:begin answer_a=N;answer_b=VIOU;end
            28:begin answer_a=D;answer_b=VIE;end
            29:begin answer_a=B;answer_b=VAN;end 30:begin answer_a=M;answer_b=VEN;end
            31:begin answer_a=L;answer_b=VIN;end 32:begin answer_a=L;answer_b=VUN;end
            33:begin answer_a=B;answer_b=VANG;end 34:begin answer_a=D;answer_b=VENG;end
            35:begin answer_a=HX;answer_b=VING;end 36:begin answer_a=ZH;answer_b=VONG;end
            37:begin answer_a=N;answer_b=VV;end 38:begin answer_a=L;answer_b=VV;end
            39:begin answer_a=L;answer_b=VUE;end 40:begin answer_a=GJ;answer_b=VVN;end
            41:begin answer_b=VER;has_initial=0;end
            default:begin valid=0;has_initial=0;end
        endcase
        if(valid) question_audio=8'd111+question_id;
    end
endmodule
