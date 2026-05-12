import numpy as np

def to_hex(val, bits):
    """將整數轉為指定長度的 Hex 字串 (補碼格式)"""
    return f"{int(val) & ((1 << bits) - 1):0{bits//4}X}"

def generate_combined_hex_file(filename, img1_array, img2_array):
    """將 img1 和 img2 寫入檔案，格式為 img1(8bit)img2(8bit)，例如 6A7B"""
    with open(filename, 'w') as f:
        img1_flat = img1_array.flatten()
        img2_flat = img2_array.flatten()
        for v1, v2 in zip(img1_flat, img2_flat):
            # img1 (8-bit) + img2 (8-bit) = 16-bit (4位 Hex)
            # 格式：HHLV (例如 6A7B)
            f.write(f"{int(v1) & 0xFF:02X}{int(v2) & 0xFF:02X}\n")

def main():
    # ==========================================
    # 1. 測資生成與寫入檔案 (修正為 16-bit 格式)
    # ==========================================
    np.random.seed(3) 
    img1 = np.random.randint(0, 256, (7, 7)).astype(np.float64)
    img2 = np.random.randint(0, 256, (7, 7)).astype(np.float64)

    generate_combined_hex_file("input_combined.txt", img1, img2)
    print("✅ 已成功生成: input_combined.txt (格式: img1_img2, e.g., 6A7B)")

    # ==========================================
    # 2. 計算梯度與乘積和
    # ==========================================
    Ix = img1[1:6, 2:7] - img1[1:6, 0:5]
    Iy = img1[2:7, 1:6] - img1[0:5, 1:6]
    It = img2[1:6, 1:6] - img1[1:6, 1:6]

    sum_Ix2, sum_Iy2 = np.sum(Ix**2), np.sum(Iy**2)
    sum_IxIy, sum_IxIt, sum_IyIt = np.sum(Ix*Iy), np.sum(Ix*It), np.sum(Iy*It)

    # ==========================================
    # 3. 縮放至 16-bit Signed (Auto-scaling)
    # ==========================================
    vals = np.array([sum_Ix2, sum_Iy2, sum_IxIy, sum_IxIt, sum_IyIt])
    max_abs = np.max(np.abs(vals))
    bit_len = int(np.ceil(np.log2(max_abs))) if max_abs > 0 else 0
    # 確保最大值在 15 bits 以內 (留 1 bit 給 sign)
    shift_bits = max(0, bit_len - 15)

    Ix2_s  = int(sum_Ix2)  >> shift_bits
    Iy2_s  = int(sum_Iy2)  >> shift_bits
    IxIy_s = int(sum_IxIy) >> shift_bits
    IxIt_s = int(sum_IxIt) >> shift_bits
    IyIt_s = int(sum_IyIt) >> shift_bits

    # ==========================================
    # 4. 計算 Ux, Uy & detA (依照公式)
    # ==========================================
    # Ux = -(Iy2_s * IxIt_s) + (IxIy_s * IyIt_s)
    # Uy = -(Ix2_s * IyIt_s) + (IxIy_s * IxIt_s)
    Ux = -(Iy2_s * IxIt_s) + (IxIy_s * IyIt_s)
    Uy = -(Ix2_s * IyIt_s) + (IxIy_s * IxIt_s)
    detA = (Ix2_s * Iy2_s) - (IxIy_s ** 2)

    print("\n============== 硬體中間數值比對 (Scaled 16-bit) ==============")
    print(f"Shift Amount : {shift_bits}")
    print(f"Ix2_s  : {to_hex(Ix2_s, 16)} | Iy2_s  : {to_hex(Iy2_s, 16)}")
    print(f"IxIy_s : {to_hex(IxIy_s, 16)} | IxIt_s : {to_hex(IxIt_s, 16)}")
    print(f"IyIt_s : {to_hex(IyIt_s, 16)}")
    print("-" * 60)
    print(f"Ux   : {Ux:10d} (Hex: {to_hex(Ux, 32)})")
    print(f"Uy   : {Uy:10d} (Hex: {to_hex(Uy, 32)})")
    print(f"detA : {detA:10d} (Hex: {to_hex(detA, 32)})")

    # ==========================================
    # 5. 使用 Shift 近似除法 (輸出 1.3.8)
    # ==========================================
    def shift_divide_approx(num, den):
        if den <= 0: return 0
        # 找到 detA 的最高位元 (MSB)
        det_msb = den.bit_length() - 1 
        
        # 硬體簡化除法：(num << 8) >> det_msb 
        # 等同於 num >> (det_msb - 8)
        shift_final = det_msb - 8
        
        if shift_final >= 0:
            res = num >> shift_final
        else:
            res = num << abs(shift_final)
            
        # 飽和處理至 1.3.8 格式 (-2048 ~ 2047)
        if res > 2047: res = 2047
        elif res < -2048: res = -2048
        return int(res), det_msb

    vx_138, msb = shift_divide_approx(Ux, detA)
    vy_138, _   = shift_divide_approx(Uy, detA)

    print("-" * 60)
    print(f"detA MSB : {msb} (Approx Divider: >> {msb-8})")
    print(f"vx_138   : {vx_138:5d} | Hex: {to_hex(vx_138, 12)} | 浮點近似: {vx_138/256:.4f}")
    print(f"vy_138   : {vy_138:5d} | Hex: {to_hex(vy_138, 12)} | 浮點近似: {vy_138/256:.4f}")
    print("==============================================================")

if __name__ == "__main__":
    main()
