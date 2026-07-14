#!/usr/bin/env python3
"""img_128x128.pgm を並べて 1024x1024 の画像を生成する"""

import cv2
import numpy as np
from pathlib import Path

here = Path(__file__).parent
src_path = here / "img_128x128.pgm"
dst_pgm  = here / "img_1024x1024.pgm"
dst_bin  = here / "img_1024x1024.bin"

tile_w, tile_h = 128, 128
out_w, out_h = 1024, 1024
cols = out_w // tile_w  # 8
rows = out_h // tile_h  # 8

src = cv2.imread(str(src_path), cv2.IMREAD_UNCHANGED)

dst = np.tile(src, (rows, cols))

# P2 (ASCII) PGM として保存
with open(dst_pgm, "w") as f:
    f.write(f"P2\n{out_w} {out_h}\n255\n")
    for row in dst:
        f.write(" ".join(str(v) for v in row) + "\n")
print(f"Saved {dst_pgm} ({out_w}x{out_h})")

# 2値画像として1バイト8画素パックのバイナリ出力 (MSB first, 閾値=128)
binary = (dst >= 128).astype(np.uint8)
packed = np.packbits(binary, axis=1, bitorder='big')  # shape: (1024, 128)
with open(dst_bin, "wb") as f:
    f.write(packed.tobytes())
print(f"Saved {dst_bin} ({out_w}x{out_h}, 1bpp packed)")
