import numpy as np
import matplotlib.pyplot as plt
import cv2


# =========================
# 讀影像（IMPORTANT：不要用 int8）
# =========================
file1 = "s0_pad.png"
file2 = "s1_pad.png"


i1 = cv2.imread(file1, cv2.IMREAD_GRAYSCALE).astype(np.int16)
i2 = cv2.imread(file2, cv2.IMREAD_GRAYSCALE).astype(np.int16)
# 向左移 4 pixel（右邊補左邊的內容）
# i2 = np.roll(i1, shift=2, axis=1)
# i1 = (cv2.imread(file1, cv2.IMREAD_GRAYSCALE)).astype(np.int16)
# i2 = (cv2.imread(file2, cv2.IMREAD_GRAYSCALE)).astype(np.int16)
print(i1)
im1 = i1 
im2 = i2

H, W = im1.shape

# =========================
# window = 3
# stride = 3
# =========================
window_size = 5
w = window_size // 2
stride = 5


Ix = np.zeros_like(im1, dtype=np.float32)

Iy = np.zeros_like(im1, dtype=np.float32)

It = np.zeros_like(im1, dtype=np.float32)

for i in range(1,H-1):

    for j in range(1,W-1):

        ip = i 

        jp = j 

        Ix[i, j] = (im1[ip, jp+1] - im1[ip, jp-1])

        Iy[i, j] = (im1[ip+1, jp] - im1[ip-1, jp])

        It[i, j] = im2[ip, jp] - im1[ip, jp]

# =========================
# optical flow
# =========================
Vx = np.zeros((H, W), dtype=np.float32)
Vy = np.zeros((H, W), dtype=np.float32)

pp = 0
for i in range(w, H-w, stride):
    for j in range(w, W-w, stride):

        wx = Ix[i-w:i+w+1, j-w:j+w+1].flatten().astype(np.float32)
        wy = Iy[i-w:i+w+1, j-w:j+w+1].flatten().astype(np.float32)
        wt = It[i-w:i+w+1, j-w:j+w+1].flatten().astype(np.float32)

        sum_Ix2  = np.sum(wx * wx).astype(np.int64) >> 0
        sum_Iy2  = np.sum(wy * wy).astype(np.int64) >> 0
        sum_IxIy = np.sum(wx * wy).astype(np.int64) >> 0
        sum_IxIt = np.sum(wx * wt).astype(np.int64) >> 0
        sum_IyIt = np.sum(wy * wt).astype(np.int64) >> 0

        # print("Ix^2 =", sum_Ix2)
        # print("Iy^2 =", sum_Iy2)
        # print("IxIy =", sum_IxIy)
        # print("IxIt =", sum_IxIt)
        # print("IyIt =", sum_IyIt)

        pp += 1

        ATA = np.array([[sum_Ix2,  sum_IxIy],
            [sum_IxIy, sum_Iy2]])

        ATb = np.array([[-sum_IxIt],
            [-sum_IyIt]])

        # 拆開元素
        a = ATA[0, 0]
        b_ = ATA[0, 1]
        c = ATA[1, 0]
        d = ATA[1, 1]

        det = a * d - b_ * c

        if abs(det) > 1:   # 避免除0
            inv00 =  d / det
            inv01 = -b_ / det
            inv10 = -c / det
            inv11 =  a / det

            Vx_val = inv00 * ATb[0, 0] + inv01 * ATb[1, 0]
            Vy_val = inv10 * ATb[0, 0] + inv11 * ATb[1, 0]

            Vx[i, j] = Vx_val * 5
            Vy[i, j] = Vy_val * 5
        else:
            Vx[i, j] = 0
            Vy[i, j] = 0
        # if(Vx_val>3 or Vy_val>3):
        
        


        

print("patch count:", pp)

# =========================
# visualization
# =========================
fig, axes = plt.subplots(1, 3, figsize=(18, 6))

axes[0].imshow(im1, cmap='gray')
axes[0].set_title("im1")
axes[0].axis('off')

axes[1].imshow(im2, cmap='gray')
axes[1].set_title("im2")
axes[1].axis('off')

axes[2].imshow(im1, cmap='gray', alpha=0.5)

ys = np.arange(w, H-w, stride)
xs = np.arange(w, W-w, stride)
X_grid, Y_grid = np.meshgrid(xs, ys)

Vx_sparse = Vx[w:H-w:stride, w:W-w:stride]
Vy_sparse = Vy[w:H-w:stride, w:W-w:stride]

axes[2].quiver(X_grid, Y_grid, Vx_sparse, Vy_sparse,
               color='red', angles='xy', scale_units='xy', scale=1)


axes[2].axis('off')

plt.tight_layout()
plt.show()