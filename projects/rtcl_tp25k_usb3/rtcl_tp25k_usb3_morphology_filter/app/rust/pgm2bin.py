#!/usr/bin/env python3
"""P2 PGM → 1bpp packed バイナリファイル変換"""

import sys
import numpy as np
from pathlib import Path

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <input.pgm> [output.bin] [width] [height]")
    print(f"       width and height are auto-detected from PGM if not specified")
    sys.exit(1)

src_path = Path(sys.argv[1])
dst_path = Path(sys.argv[2]) if len(sys.argv) >= 3 else src_path.with_suffix(".bin")

# PGMファイルから画像を読み込む
with open(src_path, "r") as f:
    magic = f.readline().strip()
    if magic != "P2":
        print(f"Error: Not a P2 PGM file (magic: {magic})")
        sys.exit(1)
    
    # コメント行をスキップ
    line = f.readline().strip()
    while line.startswith('#'):
        line = f.readline().strip()
    
    # サイズを取得
    w, h = map(int, line.split())
    max_val = int(f.readline().strip())
    
    # ピクセルデータを読み込む
    pixels = []
    for line in f:
        pixels.extend(map(int, line.split()))

# コマンドラインで指定されたサイズがあればそちらを優先
if len(sys.argv) >= 4:
    w = int(sys.argv[3])
if len(sys.argv) >= 5:
    h = int(sys.argv[4])

# 二値化（閾値は max_val/2）
threshold = max_val / 2
pixels = pixels[:w * h]  # 必要なピクセル数だけ取得
binary = np.array(pixels, dtype=np.uint8)
binary = (binary > threshold).astype(np.uint8)

# 1バイトに8ピクセルを詰め込む（big-endian）
packed = np.packbits(binary, bitorder='big')

# バイナリファイルに保存
dst_path.write_bytes(packed.tobytes())

print(f"Saved {dst_path} ({w}x{h}, {len(packed)} bytes)")
