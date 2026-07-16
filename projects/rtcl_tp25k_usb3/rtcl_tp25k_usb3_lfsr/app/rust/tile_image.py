#!/usr/bin/env python3
"""img_128x128.pgm を並べて 1024x1024 の画像を生成する"""

import cv2
import numpy as np


tile_w, tile_h = 128, 128
out_w, out_h = 512, 512
cols = out_w // tile_w  # 8
rows = out_h // tile_h  # 8

src_pgm = f"img_{tile_w}x{tile_h}.pgm"
dst_pgm = f"img_{out_w}x{out_h}.pgm"
dst_bin = f"input_{out_w}x{out_h}.bin"

src = cv2.imread(str(src_pgm), cv2.IMREAD_UNCHANGED)

dst = np.tile(src, (rows, cols))

# P2 (ASCII) PGM として保存
with open(dst_pgm, "w") as f:
    f.write(f"P2\n{out_w} {out_h}\n255\n")
    for row in dst:
        f.write(" ".join(str(v) for v in row) + "\n")
print(f"Saved {dst_pgm} ({out_w}x{out_h})")

# 2値画像として1バイト8画素パックのバイナリ出力 (MSB first, 閾値=128)
binary = (dst >= 128).astype(np.uint8)
packed = np.packbits(binary, axis=1, bitorder='little')  # shape: (1024, 128)
with open(dst_bin, "wb") as f:
    f.write(packed.tobytes())
print(f"Saved {dst_bin} ({out_w}x{out_h}, 1bpp packed)")
