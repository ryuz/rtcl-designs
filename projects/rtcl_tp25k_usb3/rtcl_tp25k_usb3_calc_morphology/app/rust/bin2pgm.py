#!/usr/bin/env python3
"""1bpp packed バイナリファイル → P2 PGM 変換"""

import sys
import numpy as np
from pathlib import Path

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <input.bin> [output.pgm] [width] [height]")
    print(f"       width and height default to 1024x1024")
    sys.exit(1)

src_path = Path(sys.argv[1])
dst_path = Path(sys.argv[2]) if len(sys.argv) >= 3 else src_path.with_suffix(".pgm")

# デフォルト値: 1024x1024
out_w = int(sys.argv[3]) if len(sys.argv) >= 4 else 1024
out_h = int(sys.argv[4]) if len(sys.argv) >= 5 else 1024

data = np.frombuffer(src_path.read_bytes(), dtype=np.uint8)
bits = np.unpackbits(data, bitorder='little')  # 1 → 255, 0 → 0
img = (bits[:out_h * out_w] * 255).reshape(out_h, out_w).astype(np.uint8)

with open(dst_path, "w") as f:
    f.write(f"P2\n{out_w} {out_h}\n255\n")
    for row in img:
        f.write(" ".join(str(v) for v in row) + "\n")

print(f"Saved {dst_path} ({out_w}x{out_h})")
