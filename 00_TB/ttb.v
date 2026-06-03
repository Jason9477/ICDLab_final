`define CYCLE  10
`define HCYCLE (`CYCLE/2.0)

// ===== 只需指定影像尺寸,其餘自動推導 =====
`define IMG_W   202
`define IMG_H   202
`define WINDOW  7
`define STRIDE  5

// 自動推導 grid:每方向 window 數 = (size-WINDOW)/STRIDE + 1
`define N_COLS  ((`IMG_W - `WINDOW)/`STRIDE + 1)        // 40
`define N_ROWS  ((`IMG_H - `WINDOW)/`STRIDE + 1)        // 40

// 去重餵入:每 column 第一個 window 餵滿 WINDOW 排,後續每個只餵 STRIDE 排
//   per-column pixels = WINDOW*WINDOW + STRIDE*WINDOW*(N_ROWS-1)
`define PER_COL (`WINDOW*`WINDOW + `STRIDE*`WINDOW*(`N_ROWS-1))   // 49 + 35*39 = 1414
`define N       (`N_COLS * `PER_COL)                              // 40*1414 = 56560

// 答案數:每個 window 一組 (vx,vy),共 N_COLS*N_ROWS 個 window
`define N_WIN   (`N_COLS * `N_ROWS)                               // 1600
`define N_ANS   (`N_WIN * 2)                                      // 3200

module tb;

reg clk;
reg rst_n;
reg [7:0] a, b;
reg       first_row;

wire        valid;
wire [11:0] Vout;

reg [7:0]         a_mem      [0:(`N-1)];
reg [7:0]         b_mem      [0:(`N-1)];
reg signed [11:0] answer_mem [0:(`N_ANS-1)];

integer c;          // column index
integer k;          // pixel index within current column
integer idx;        // global index into a_mem / b_mem
integer ans_idx;
integer error_cnt;

LK uut(
    .clk      (clk),
    .rst_n    (rst_n),
    .a        (a),
    .b        (b),
    .first_row(first_row),
    .valid    (valid),
    .Vout     (Vout)
);
//////////////////////////////////////////////////
// SDF annotation
//////////////////////////////////////////////////

`ifdef SDF
initial $sdf_annotate(`SDFFILE, uut);
`endif

//////////////////////////////////////////////////
// dump
//////////////////////////////////////////////////
initial begin
    $dumpfile("LK.vcd");
    $dumpvars();
end

//////////////////////////////////////////////////
// clock
//////////////////////////////////////////////////
initial begin
    clk = 0;
    a   = 0;
    b   = 0;
end
always #`HCYCLE clk = ~clk;

//////////////////////////////////////////////////
// compare variables
//////////////////////////////////////////////////
reg signed [11:0] prev_Vout;
reg               prev_valid;

real vout1_decimal;
real vout2_decimal;
real ans1_decimal;
real ans2_decimal;

//////////////////////////////////////////////////
// compare output with answer
//////////////////////////////////////////////////
always @(posedge clk) begin
    if (valid) begin
        if (prev_valid) begin
            // Q3.8 -> decimal (先算,再印/比較)
            vout1_decimal = $signed(prev_Vout)/256.0;
            vout2_decimal = $signed(Vout)/256.0;
            ans1_decimal  = answer_mem[ans_idx]/256.0;
            ans2_decimal  = answer_mem[ans_idx+1]/256.0;

            $display("\n===== Compare #%0d  =====", ans_idx/2);
            $display("Expected=%b (%f)", answer_mem[ans_idx],   ans1_decimal);
            $display("Got     =%b (%f)", prev_Vout,             vout1_decimal);
            $display("Expected=%b (%f)", answer_mem[ans_idx+1], ans2_decimal);
            $display("Got     =%b (%f)", Vout,                  vout2_decimal);

            if ($signed(prev_Vout) !== answer_mem[ans_idx]) begin
                error_cnt = error_cnt + 1;
                $display("\nERROR idx=%0d", ans_idx);
                $display("Expected=%b (%f)", answer_mem[ans_idx], ans1_decimal);
                $display("Got     =%b (%f)", prev_Vout,           vout1_decimal);
            end
            if ($signed(Vout) !== answer_mem[ans_idx+1]) begin
                error_cnt = error_cnt + 1;
                $display("\nERROR idx=%0d", ans_idx+1);
                $display("Expected=%b (%f)", answer_mem[ans_idx+1], ans2_decimal);
                $display("Got     =%b (%f)", Vout,                  vout2_decimal);
            end

            ans_idx = ans_idx + 2;
        end
        prev_Vout  <= Vout;
        prev_valid <= 1;
    end
    else begin
        prev_valid <= 0;
    end
end

//////////////////////////////////////////////////
// stimulus
//////////////////////////////////////////////////
initial begin
    $readmemh("aa_walking.txt",   a_mem);
    $readmemh("bb_walking.txt",   b_mem);
    $readmemh("ans_walking.txt", answer_mem);

    rst_n     = 0;
    ans_idx   = 0;
    error_cnt = 0;
    first_row = 0;
    a         = 0;
    b         = 0;
    idx       = 0;

    #(`CYCLE*1);
    rst_n = 1;

    // 逐 column 餵入;每個 column 第一拍拉一拍 first_row
    for (c = 0; c < `N_COLS; c = c + 1) begin
        for (k = 0; k < `PER_COL; k = k + 1) begin
            @(negedge clk);
            first_row = (k == 0) ? 1'b1 : 1'b0;   // 每個 column 開頭拉一拍
            a = a_mem[idx];
            b = b_mem[idx];
            idx = idx + 1;
        end
    end

    @(negedge clk);
    first_row = 0;

    #(11*`CYCLE);

    //////////////////////////////////////////
    // summary
    //////////////////////////////////////////
    $display("");
    $display("===============");
    $display("Total Error=%0d", error_cnt);
    if (error_cnt == 0)
        $display("ALL PASS");
    else
        $display("FAIL");
    $display("===============");
    $finish;
end

endmodule