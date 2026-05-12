import numpy as np

def generate_combined_hex_file(filename, img1_array, img2_array):
    """將 img1 和 img2 寫入同一個 txt 檔案，格式為 img1_img2 (32-bit)"""
    with open(filename, 'w') as f:
        # flatten() 會把 7x7 拉平成 49 個元素的 1D 陣列
        img1_flat = img1_array.flatten()
        img2_flat = img2_array.flatten()
        
        for v1, v2 in zip(img1_flat, img2_flat):
            # 組合為 32-bit: img1 在高 16-bit，img2 在低 16-bit
            # 加上底線 (_) 方便肉眼閱讀，Verilog $readmemh 完全支援
            f.write(f"{int(v1) & 0xFF:02X}{int(v2) & 0xFF:02X}\n")

def main():
    # ==========================================
    # 1. 生成 7x7 的隨機輸入矩陣 (img1, img2)
    # ==========================================
    np.random.seed(0) # 鎖定亂數種子，確保每次產生一樣的測資
    
    img1 = np.random.randint(0, 256, (7, 7)).astype(np.float64)
    img2 = np.random.randint(0, 256, (7, 7)).astype(np.float64)

    # 輸出成單一 txt 檔案
    generate_combined_hex_file("input_combined.txt", img1, img2)
    print("✅ 已成功生成: input_combined.txt (格式: img1_img2)\n")

    # ==========================================
    # 2. 計算中央 5x5 的梯度矩陣 Ix, Iy, It
    # ==========================================
    Ix = img1[1:6, 2:7] - img1[1:6, 0:5]
    Iy = img1[2:7, 1:6] - img1[0:5, 1:6]
    It = img2[1:6, 1:6] - img1[1:6, 1:6]

    # ==========================================
    # 3. 計算 5x5 區域內的乘積總和 (Sums)
    # ==========================================
    sum_Ix2  = np.sum(Ix ** 2)
    sum_Iy2  = np.sum(Iy ** 2)
    sum_IxIy = np.sum(Ix * Iy)
    sum_IxIt = np.sum(Ix * It)
    sum_IyIt = np.sum(Iy * It)

    # 印出硬體比對用的關鍵數值
    print("============== LK 演算法中間數值 ==============")
    print(f"sum_Ix^2 : {sum_Ix2:10.0f}")
    print(f"sum_Iy^2 : {sum_Iy2:10.0f}")
    print(f"sum_IxIy : {sum_IxIy:10.0f}")
    print(f"sum_IxIt : {sum_IxIt:10.0f}")
    print(f"sum_IyIt : {sum_IyIt:10.0f}")
    print("===============================================\n")


    # ==========================================
    # 4. 求解光流向量 (未除以 detA 版本)
    # ==========================================
    
    # 定義克拉瑪公式所需的分子矩陣內容
    # b1 = -sum_IxIt, b2 = -sum_IyIt
    b1 = -sum_IxIt
    b2 = -sum_IyIt
    
    # det(A) = (sum_Ix2 * sum_Iy2) - (sum_IxIy * sum_IxIy)
    detA = (sum_Ix2 * sum_Iy2) - (sum_IxIy ** 2)
    
    # 未除以 detA 的 vx (即 detAx)
    # detAx = b1 * sum_Iy2 - sum_IxIy * b2
    vx_num = (b1 * sum_Iy2) - (sum_IxIy * b2)
    
    # 未除以 detA 的 vy (即 detAy)
    # detAy = sum_Ix2 * b2 - b1 * sum_IxIy
    vy_num = (sum_Ix2 * b2) - (b1 * sum_IxIy)

    print("============== 最終光流計算結果 ==============")
    print(f"det(A) : {detA}")
    print(f"vx_num : {vx_num:17.0f} (未除以 detA)")
    print(f"vy_num : {vy_num:17.0f} (未除以 detA)")
    print("-" * 47)
    print(type(sum_Ix2))
    # 驗證原始結果
    if abs(detA) > 1e-9:
        print(f"驗證 vx (vx_num/detA) : {vx_num/detA:.6f}")
        print(f"驗證 vy (vy_num/detA) : {vy_num/detA:.6f}")
    else:
        print("detA 太小，無法計算除法")
    print("===============================================")


    # ==========================================
    # 4. 求解光流向量 vx, vy
    # ==========================================
    A = np.array([
        [sum_Ix2, sum_IxIy],
        [sum_IxIy, sum_Iy2]
    ])
    b = np.array([
        [-sum_IxIt],
        [-sum_IyIt]
    ])

    try:
        v = np.linalg.pinv(A) @ b
        vx, vy = v[0, 0], v[1, 0]
    except np.linalg.LinAlgError:
        vx, vy = 0.0, 0.0

    print("============== 最終光流計算結果 ==============")
    print(f"vx = {vx:.6f}")
    print(f"vy = {vy:.6f}")
    print("===============================================")

if __name__ == "__main__":
    main()
