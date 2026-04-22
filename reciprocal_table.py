import numpy as np
x = np.linspace(1, 2, 33)

for i in range(32):
    slope = (1/x[i] - 1/x[i+1]) / (1/32)
    a = int(round(slope * (2 ** 12)))
    
    intercept = 1/x[i]
    b = int(round(intercept * (2 ** 16)))

    print(f"5'd{i}: {{a, b}} = {{12'h{a:03x}, 17'h{b:05x}}};") 

