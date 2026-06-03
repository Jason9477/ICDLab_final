
module LK #(parameter width = 8)(
    input            clk,
    input            rst_n,
    input      [7:0] a,
    input      [7:0] b,
    input        top_row,
    output reg       valid,
    output reg [11:0] Vout
);

    // ---------------- input shift register (7x7 window storage) ----------------
    reg [width-1:0]  img1[0:13];
    reg [3:0]        row_reg;
    reg [3:0]        col_reg;
    //
    reg start_valid;
    reg first_row_reg;

    // 5-deep shift registers for Ix / It
    reg signed [width:0] Ix[0:4];
    reg signed [width:0] It[0:4];

    // ---------------- accumulators ----------------
    reg signed [2*width+6:0] Ix2;
    reg signed [2*width+6:0] Iy2;
    reg signed [2*width+6:0] IxIy;
    reg signed [2*width+6:0] IxIt;
    reg signed [2*width+6:0] IyIt;
    reg signed [2*width+3:0] Ix2_new;
    reg signed [2*width+3:0] IxIt_new;
    reg signed [2*width+6:0] Ix2_reg;
    reg signed [2*width+6:0] Iy2_reg;
    reg signed [2*width+6:0] IxIy_reg;
    reg signed [2*width+6:0] IxIt_reg;
    reg signed [2*width+6:0] IyIt_reg;

    // ---------------- per-pixel gradients ----------------
    reg signed [width:0] Ix_now;
    reg signed [width:0] Iy_now;
    reg signed [width:0] It_now;

    wire [width*2+1:0] Ix_now2 = Ix_now * Ix_now;   // 18 = 9+9
    wire [width*2+1:0] Iy_now2 = Iy_now * Iy_now;

    reg [width-1:0] a_reg, b_reg;

    // ---------------- enable / shift control ----------------
    wire Ix_shift = (col_reg != 0) && (row_reg != 0) ;// && (row_reg != 6) ;                          // 何時 shift Ix
    wire Ix_en    = Ix_shift && (col_reg != 1) && (row_reg != 6);              // 何時計算 Ix^2 / IxIt
    wire Iy_en    = (col_reg != 6) && (col_reg != 0) &&
                    (row_reg != 0  && row_reg != 1);                           // 何時計算 Iy^2 / IxIy / IyIt
    wire It_shift = (col_reg != 6) && (col_reg != 0) && (row_reg != 0);        // 何時 shift It

    always @(*) begin
        Ix_now = a_reg - img1[12];
        Iy_now = a_reg - img1[0];
        It_now = b_reg - a_reg;
    end

    wire signed [2*width+1:0] IxIt_now = Ix_now * It[4];
    wire signed [2*width+1:0] IyIt_now = Iy_now * It[0];
    wire signed [2*width+1:0] IxIy_now = Iy_now * Ix[0];
    always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        Iy2  <= 0;
        Ix2  <= 0;
        IxIt <= 0;
        IyIt <= 0;
        IxIy <= 0;
    end else begin
        if (Iy_en) begin
            Iy2  <= Iy2  + Iy_now2;
            IxIy <= IxIy + IxIy_now;
            IyIt <= IyIt + IyIt_now;
        end
        if (Ix_en ) begin
            Ix2  <= Ix2  + Ix_now2;
            IxIt <= IxIt + IxIt_now;
        end
         // window 邊界清零累加器，否則正常累加
            if(first_row_reg) begin
                if (col_reg == 0 && row_reg == 2) begin
                    Iy2  <= 0;
                    IyIt <= 0;
                    IxIy <= 0;
                end else if (col_reg == 0 && row_reg == 1) begin
                    Ix2 <= 0;
                    IxIt <= 0;
                   
                end
            end else begin
                    if (col_reg == 0 && row_reg == 2) begin
                    Ix2 <= Ix2_new;
                    IxIt <= IxIt_new;
                    Iy2  <= 0;
                    IyIt <= 0;
                    IxIy <= 0;
                    end 

            end
            if(col_reg == 6 && row_reg == 6) begin 
                Ix2_reg <= Ix2;
                Iy2_reg <= Iy2;
                IxIy_reg <= IxIy;
                IxIt_reg <= IxIt;
                IyIt_reg <= IyIt;
            end
    end
    end
    always @(posedge clk) begin
            if(row_reg ==5 ) begin
                Ix2_new <=0;
                IxIt_new <=0;
            end
            else if(row_reg == 6 && col_reg !=0 && col_reg!=1) begin
                Ix2_new  <= Ix2_new  + Ix_now2;
                IxIt_new <= IxIt_new + IxIt_now;
            
            end
    end
    // ================= auto-scale: find leading-one position of accumulators =================
    reg  [2:0]                       mul_counter;
    reg  signed [2*width+6:0]        mul_src;
    wire        [2*width+6:0]        mul_src_abs = mul_src[2*width+6] ? -mul_src : mul_src;
    wire        [$clog2(2*width+7)-1:0] mul_pos;
    wire        [$clog2(2*width+7)-1:0] mul_pos_new;
    reg         [$clog2(2*width+7)-1:0] mul_pos_buffer;
    wire                             mul_valid;

    LOD #(.W(2*width+7)) L_mul (.in(mul_src_abs), .pos(mul_pos), .valid(mul_valid));

    assign mul_pos_new = (mul_pos > mul_pos_buffer && mul_valid) ? mul_pos : mul_pos_buffer;

    // 在 window 邊界把各累加值依序送進 LOD，求最大 leading-one 位置
    reg mul_pos_valid;
    always @(*) begin
        mul_src       = 0;
        mul_pos_valid = 0;
        if (row_reg == 6) begin
            case (col_reg)
                4: begin mul_src = Ix2;  mul_pos_valid = 1; end
                5: begin mul_src = IxIt; mul_pos_valid = 1; end
                6: begin mul_src = Iy2;  mul_pos_valid = 1; end
            endcase
        end
        else if (row_reg == 0 || row_reg == 2) begin
            case (col_reg)
                0: begin mul_src = IxIy; mul_pos_valid = 1; end
                1: begin mul_src = IyIt_reg; mul_pos_valid = 1; end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mul_pos_buffer <= 0;
        end
        else begin
            if (mul_pos_valid)
                mul_pos_buffer <= mul_pos_new;
            else if (row_reg == 3)
                mul_pos_buffer <= 0;
        end
    end

    // ---------------- scale accumulators down so the multiply fits ----------------
    wire       sum_shift    = (mul_pos_new > 14);
    wire [3:0] shift_amount = sum_shift ? (mul_pos_new - 14) : 0;
    reg  [3:0] shift_amount_reg;   // (0,2) to (1,0) 可用

    wire signed [2*width-1:0] Ix2_shift  = (Ix2_reg  >>> shift_amount_reg);
    wire signed [2*width-1:0] Iy2_shift  = (Iy2_reg  >>> shift_amount_reg);
    wire signed [2*width-1:0] IxIy_shift = (IxIy_reg >>> shift_amount_reg);
    wire signed [2*width-1:0] IxIt_shift = (IxIt_reg >>> shift_amount_reg);
    wire signed [2*width-1:0] IyIt_shift = (IyIt_reg >>> shift_amount_reg);

    // ================= 2x2 system solve: numerators (Ux,Uy) and determinant (det) =================
    wire signed [4*width-1:0] Iy2_IxIt, Ix2_IyIt, Ix2_Iy2, IxIy_IyIt, IxIy_IxIt, IxIy2;

    mult_pipe M1 (.clk(clk), .rst_n(rst_n), .A(Iy2_shift),  .B(IxIt_shift), .result(Iy2_IxIt));
    mult_pipe M2 (.clk(clk), .rst_n(rst_n), .A(Ix2_shift),  .B(IyIt_shift), .result(Ix2_IyIt));
    mult_pipe M3 (.clk(clk), .rst_n(rst_n), .A(Ix2_shift),  .B(Iy2_shift),  .result(Ix2_Iy2));
    mult_pipe M4 (.clk(clk), .rst_n(rst_n), .A(IxIy_shift), .B(IyIt_shift), .result(IxIy_IyIt));
    mult_pipe M5 (.clk(clk), .rst_n(rst_n), .A(IxIy_shift), .B(IxIt_shift), .result(IxIy_IxIt));
    mult_pipe M6 (.clk(clk), .rst_n(rst_n), .A(IxIy_shift), .B(IxIy_shift), .result(IxIy2));

    wire signed [4*width:0] Ux  = -Iy2_IxIt + IxIy_IyIt;
    wire signed [4*width:0] Uy  = -Ix2_IyIt + IxIy_IxIt;
    wire signed [4*width:0] det =  Ix2_Iy2  - IxIy2;

    reg signed [4*width:0] Ux_reg, Uy_reg;   // (0,4) 可用
    reg                    det_signed;

    // ---------------- division by det via leading-one (barrel shift) ----------------
    wire        [4*width:0]            det_abs = det[4*width] ? (-det) : det;
    wire        [$clog2(4*width+1)-1:0] div_pos;
    reg         [$clog2(4*width+1)-1:0] div_pos_reg;
    wire                               div_valid;

    LOD #(.W(4*width+1)) L1 (.in(det_abs), .pos(div_pos), .valid(div_valid));

    wire signed [4*width+11:0] Ux_pad    = {{3{Ux_reg[4*width]}}, Ux_reg, 8'b0};
    wire signed [4*width+11:0] Uy_pad    = {{3{Uy_reg[4*width]}}, Uy_reg, 8'b0};
    wire signed [4*width+11:0] shifted_x = Ux_pad >>> div_pos_reg;
    wire signed [4*width+11:0] shifted_y = Uy_pad >>> div_pos_reg;

    wire signed [11:0] result_x = det_signed ? -$signed(shifted_x[11:0]) : $signed(shifted_x[11:0]);
    wire signed [11:0] result_y = det_signed ? -$signed(shifted_y[11:0]) : $signed(shifted_y[11:0]);

    reg signed [11:0] vx_reg, vy_reg;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_pos_reg <= 0;
        end
        else begin
            if (col_reg ==5)
                div_pos_reg <= div_pos;
        end
    end


    // ---------------- Harris corner gate ----------------
    wire corner;
    Harris #(.width(width)) H1 (.Ix2(Ix2_shift), .Iy2(Iy2_shift), .det(det),
                                .corner(corner), .clk(clk), .rst_n(rst_n));   // (0,4) 可用

    // 速度過大則視為無效
    wire too_long = ($signed(result_x) > $signed(12'b010100000000) ||
                     $signed(result_x) < $signed(12'b101100000000) ||
                     $signed(result_y) > $signed(12'b010100000000) ||
                     $signed(result_y) < $signed(12'b101100000000));

    always @(*) begin
        if (~div_valid || too_long || ~corner) vx_reg = 8'b0;
        else                                    vx_reg = result_x;

        if (~div_valid || too_long || ~corner) vy_reg = 8'b0;
        else                                    vy_reg = result_y;
    end

    // ================= shift registers (data feeding) =================
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (j = 0; j < 14; j = j + 1) img1[j] <= 0;
            for (j = 0; j < 5;  j = j + 1) begin
                Ix[j] <= 0;
                It[j] <= 0;
                // Ix_new[j]<= 0;
                // It_new[j]<= 0;
            end
        end
        else begin
            // img1: 14-deep line, feeds vertical neighbour for Ix/Iy gradient
            for (j = 0; j <= 12; j = j + 1) img1[j] <= img1[j + 1];
            img1[13] <= a_reg;

            if (Ix_shift) begin
                for (j = 0; j <= 3; j = j + 1) Ix[j] <= Ix[j + 1];
                Ix[4] <= Ix_now;
            end

            if (It_shift) begin
                for (j = 0; j <= 3; j = j + 1) It[j] <= It[j + 1];
                It[4] <= It_now;
            end
        end
    end

    // ================= summation + output pipeline =================

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            Vout <= 0;
            valid <= 0;
            start_valid      <= 0;
            a_reg            <= 0;
            b_reg            <= 0;
            shift_amount_reg <= 0;
            Ux_reg           <= 0;
            Uy_reg           <= 0;
            det_signed       <= 0;
            first_row_reg    <= 0;
        end
        else begin
            a_reg            <= a;
            b_reg            <= b;
            shift_amount_reg <= shift_amount;
            det_signed       <= det[4*width];

            if (row_reg == 6 && col_reg == 6) first_row_reg <= top_row;
            // 在 window 邊界輸出 vx / vy
            if(first_row_reg) begin
                if (col_reg == 6 && row_reg == 0) begin
                    Vout <= vx_reg;
                    if (start_valid) valid <= 1;
                    else             start_valid <= 1;
                end
                else if (col_reg == 0 && row_reg == 1) begin
                    Vout <= vy_reg;
                end

                if (col_reg == 1 && row_reg == 1) begin
                    valid <= 0;
                end
                if(col_reg == 3 &&  row_reg == 0) begin
                    Ux_reg <= Ux;
                    Uy_reg <= Uy;
                end
            end else begin
                if (col_reg == 6 && row_reg == 2) begin
                Vout <= vx_reg;
                valid <= 1;
                end
                else if (col_reg == 0 && row_reg == 3) begin
                    Vout <= vy_reg;
                end

                if (col_reg == 1 && row_reg == 3) begin
                    valid <= 0;
                end
                if (col_reg == 3 && row_reg == 2 ) begin
                    Ux_reg <= Ux;
                    Uy_reg <= Uy;
                end
            end

           

    end
    end

    // ================= input matrix index (row/col counter, 0..6) =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_reg <= 6;
            col_reg <= 6;
        end
        else begin
            if (col_reg == 6) begin    // 0 到 6 代表 7 個數
                if (row_reg == 6) begin
                    col_reg <= 0;
                    if(top_row) begin
                        row_reg <= 0;
                    end
                     else begin
                        row_reg <= 2;
                    end

                end
                else begin
                    col_reg <= 0;
                    row_reg <= row_reg + 1;
                end
            end
            else begin
                col_reg <= col_reg + 1;
            end
        end
    end

endmodule


// Leading One Detector
module LOD #(
    parameter W = 45
)(
    input [W - 1 : 0] in,
    output [$clog2(W) - 1 : 0] pos,
    output valid
);
    localparam W_pow2 = 1 << $clog2(W);
    wire [W_pow2-1 : 0] in_pad;
    generate
        if(W_pow2 == W) begin: no_padding_zeros
            assign in_pad = in;
        end
        else begin: padding_zeros
            assign in_pad = {{(W_pow2 - W){1'b0}}, in};
        end

        if(W_pow2 == 2) begin: base_case
            assign valid = in_pad[1] | in_pad[0];
            assign pos = in_pad[1];
        end
        else begin: recursive_case
            wire left_valid, right_valid;
            wire [$clog2(W_pow2/2) - 1 : 0] left_pos, right_pos;

            LOD #(.W(W_pow2/2)) LOD_left(.in(in_pad[W_pow2 - 1 : W_pow2/2]), .pos(left_pos), .valid(left_valid));
            LOD #(.W(W_pow2/2)) LOD_right(.in(in_pad[W_pow2/2 - 1 : 0]), .pos(right_pos), .valid(right_valid));

            assign valid = left_valid | right_valid;
            assign pos = (left_valid)? {1'b1, left_pos} : {1'b0, right_pos};
        end
    endgenerate
endmodule
module Harris#(parameter width = 8)(
    input  [2*width-1:0] Ix2,
    input  [2*width-1:0] Iy2,
    input  [4*width:0]   det,
    input                clk,
    input                rst_n,
    output               corner
);

wire [2*width:0] trace;
assign trace = Ix2 + Iy2;

wire [7:0] trace_hi = trace[2*width:width+1];
wire [8:0] trace_lo = trace[width:0];

reg [17:0] s1_P0;
reg [16:0] s1_P1;
reg [15:0] s1_P2;
reg [4*width:0] s1_det;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        s1_P0  <= 0;
        s1_P1  <= 0;
        s1_P2  <= 0;
        s1_det <= 0;
    end else begin
        s1_P0  <= trace_lo * trace_lo;
        s1_P1  <= trace_hi * trace_lo;
        s1_P2  <= trace_hi * trace_hi;
        s1_det <= det;
    end
end

wire [4*width+1:0] trace_sq,trace_sq1,trace_sq2;
assign trace_sq1 = {{(2*width-16){1'b0}}, s1_P0}+ ({{(2*width-15){1'b0}}, s1_P1} << (width+1));
assign trace_sq2 = ({{(2*width-15){1'b0}}, s1_P1} << (width+1)) + ({{(2*width-14){1'b0}}, s1_P2} << (2*width+2));
assign trace_sq = trace_sq1 + trace_sq2;

reg [4*width+1:0] trace_sq_reg;
reg [4*width:0]   det_reg;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        trace_sq_reg <= 0;
        det_reg      <= 0;
    end else begin
        trace_sq_reg <= trace_sq;
        det_reg      <= s1_det;
    end
end

wire signed [4*width+1:0] R;
assign R = $signed(det_reg) - $signed(trace_sq_reg >>> 4);

localparam signed [31:0] THRESHOLD = 32'd10000000;
assign corner = (R > THRESHOLD);

endmodule
module mult_pipe (
    input         clk,
    input         rst_n,
    input  [15:0] A,
    input  [15:0] B,
    output [31:0] result
);

wire signed [8:0]  A_hi = $signed(A[15:8]);
wire        [7:0]  A_lo = A[7:0];
wire signed [8:0]  B_hi = $signed(B[15:8]);
wire        [7:0]  B_lo = B[7:0];

reg signed [16:0] s1_P0;
reg signed [16:0] s1_P1;
reg signed [16:0] s1_P2;
reg signed [16:0] s1_P3;
reg               s1_valid;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_P0    <= 0;
        s1_P1    <= 0;
        s1_P2    <= 0;
        s1_P3    <= 0;
        s1_valid <= 1'b0;
    end else begin
        s1_P0    <= $signed({1'b0, A_lo}) * $signed({1'b0, B_lo}); // u8*u8 = u16
        s1_P1    <= A_hi * $signed({1'b0, B_lo});                   // s8*u8 = s17
        s1_P2    <= $signed({1'b0, A_lo}) * B_hi;                   // u8*s8 = s17
        s1_P3    <= A_hi * B_hi;                                     // s8*s8 = s16
        s1_valid <= 1'b1;
    end
end

reg signed [31:0] s2_result;
reg               s2_valid;
wire signed [31:0]s2_1 = $signed({{15{s1_P0[16]}}, s1_P0})
            + ($signed({{15{s1_P1[16]}}, s1_P1}) <<< 8)
            ,s2_2 =($signed({{15{s1_P2[16]}}, s1_P2}) <<< 8)
            + ($signed({{15{s1_P3[16]}}, s1_P3}) <<< 16);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s2_result <= 32'd0;
        s2_valid  <= 1'b0;
    end else begin
        s2_result <= s2_1 + s2_2;
        s2_valid  <= s1_valid;
    end
end

assign result    = s2_result;

endmodule




















