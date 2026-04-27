//=============0427====================  
刪掉不用的東西，用imput_combined.txt當input tb
//=============0425====================  
完成 week 9 報告中的計算順序架構:
shift registers (img1 Ix It)
summation (Ix^2 Iy^2 IxIy IxIt IyIt)
//=============0420====================  
完成算sum(IxIt),sum(IyIt),sum(IxIy)
//=============0416====================  
寫了輸入 計算Ix Iy It 並sum(IX^2), sum(Iy^2)  





pattern.py可以生input pattern line19:random_seed(42)暫固定
sphere資料夾內有實際測資
為方便tb寫在同一檔案  
gtkwave無法看packed signal(array) 故以wire展開部分
input form:  
(Hex)img1img2  
Pixel1  
Pixel2  
.  
.  
.  
Pixel49

img:x bits
Ix:x+1 bits
Ix2: (x+1)*2 bits
sumIx^2: 2x+7
sum*sum :4x+14 
ad-bc : 4x+15

$$
\begin{bmatrix}
V_x \
V_y
\end{bmatrix}
=
\begin{bmatrix}
\sum_i I_x(q_i)^2 & \sum_i I_x(q_i) I_y(q_i) \
\sum_i I_y(q_i) I_x(q_i) & \sum_i I_y(q_i)^2
\end{bmatrix}^{-1}
\begin{bmatrix}
- \sum_i I_x(q_i) I_t(q_i) \
- \sum_i I_y(q_i) I_t(q_i)
\end{bmatrix}
$$