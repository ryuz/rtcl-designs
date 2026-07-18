#!/usr/bin/env python3
"""img_128x128.pgm を並べて 1024x1024 の画像を生成する"""

import cv2
import numpy as np

expand = 2
tile_w, tile_h = 128, 128
#out_w, out_h = 512, 512
out_w, out_h = 2048, 2048
scaled_tile_w = tile_w * expand
scaled_tile_h = tile_h * expand
cols = out_w // scaled_tile_w
rows = out_h // scaled_tile_h

src_pgm = f"img_{tile_w}x{tile_h}.pgm"
dst_pgm = f"img_{out_w}x{out_h}.pgm"
dst_bin = f"input_{out_w}x{out_h}.bin"

src = cv2.imread(str(src_pgm), cv2.IMREAD_UNCHANGED)
if src is None:
    raise FileNotFoundError(f"Failed to read source image: {src_pgm}")

# src を縦横 expand 倍にバイリニア拡大してから二値化
src_scaled = cv2.resize(src, (scaled_tile_w, scaled_tile_h), interpolation=cv2.INTER_LINEAR)
src_binary = ((src_scaled >= 128).astype(np.uint8) * 255)

# 二値化後のタイルを並べる
dst = np.tile(src_binary, (rows, cols))

# P2 (ASCII) PGM として保存
with open(dst_pgm, "w") as f:
    f.write(f"P2\n{out_w} {out_h}\n255\n")
    for row in dst:
        f.write(" ".join(str(v) for v in row) + "\n")
print(f"Saved {dst_pgm} ({out_w}x{out_h})")

# 2値画像として1バイト8画素パックのバイナリ出力 (MSB first, 閾値=128)
binary = (dst >= 128).astype(np.uint8)
packed = np.packbits(binary, axis=1, bitorder='little')
with open(dst_bin, "wb") as f:
    f.write(packed.tobytes())
print(f"Saved {dst_bin} ({out_w}x{out_h}, 1bpp packed)")
