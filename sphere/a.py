import cv2
import numpy as np

# 1. 讀取原始 200x200 灰階圖
# 假設圖片名稱為 'input.jpg'
img = cv2.imread('s0.png', cv2.IMREAD_GRAYSCALE)

# --- 第一步：Left Shift 2 Pixels (維持 200x200) ---
# 建立一個 200x200 的全黑背景
shifted_img = np.zeros((200, 200), dtype=np.uint8)
# 將原圖從第 2 欄開始的內容往左搬，貼到新圖的第 0 欄
# 此操作後，shifted_img 的最右邊 2 欄會是 0 (黑色)
shifted_img[0:198, :] = img[2:200, :]

# --- 第二步：四周補 0 擴展至 202x202 ---
# 建立一個 202x202 的全黑畫布
final_img = np.zeros((202, 202), dtype=np.uint8)
# 將位移後的圖片放入畫布中心 (座標從 1 開始到 201)
# 這樣上下左右都會各留 1 像素的黑邊
final_img[1:201, 1:201] = shifted_img

# 儲存結果
cv2.imwrite('s0_s_pad.png', final_img)

print("圖像處理完成，已儲存為 output_202x202.png")
