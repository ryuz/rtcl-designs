# rtcl-d3xx (Python)

[rust/d3xx](../../rust/d3xx) の rtcl-d3xx クレートを PyO3 でラップした Python バインディングです。

## ビルド / インストール

実行時に `libftd3xx.so` が必要です（システムにインストール済みであること）。

```bash
pip install maturin
cd python/rtcl-d3xx
maturin build --release --skip-auditwheel   # patchelf があれば --skip-auditwheel 不要
pip install target/wheels/rtcl_d3xx-*.whl
# 開発時は: maturin develop --release
```

## 使い方

```python
import rtcl_d3xx

# AXI4-Lite レジスタアクセス + AXI4-Stream 転送
dev = rtcl_d3xx.Fifo32(dev_index=0)
core_id = dev.read_axi4l(0x0000_0000)
dev.write_axi4l(0x0000_0040, 128, strb=0xf)

dev.send_axi4s(b"\x00" * 4096, tuser=0x01)   # 長さは4バイト境界
pkt = dev.recv_axi4s(timeout=1.0)             # Axi4Stream (pkt.tuser, pkt.data)
pkt = dev.try_recv_axi4s()                    # 無ければ None

dev.send_frame(width, height, image_bytes)    # 1ライン=1パケットで送信

# フレーム組み立てスレッド付きビデオキャプチャ
cap = rtcl_d3xx.VideoCapture(dev_index=0, max_buffered_frames=4)
frame = cap.recv_video(timeout=5.0)           # VideoFrame
print(frame.frame_id, frame.width, frame.height, len(frame.data))
print(cap.stats())
```

`Fifo32` と `VideoCapture` は同一デバイスを排他的に開くため同時には使えません。
