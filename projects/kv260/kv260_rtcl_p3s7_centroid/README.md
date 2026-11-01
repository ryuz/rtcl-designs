# RTCL-P3S7-MIPI グローバルシャッター高速度カメラの 1000fps 輝度重心計測

## 概要

Kria KV260 で RTCL-P3S7-MIPI グローバルシャッター高速度カメラを 1000fps で動かし、輝度重心 (moment) を計測するサンプルです。

モノクロ版の RTCL-P3S7-MIPI カメラモジュールを前提としています。

アプリは Rust 版のみ提供しています。


## 環境準備

KV260 の RPU (Cortex-R5) も利用するため、クロスコンパイラのインストールが必要です。
KV260 側でセルフコンパイルする場合は KV260 側に、PC 側でクロスコンパイルする場合は PC 側にインストールしてください。

```bash
sudo apt update
sudo apt install gcc-arm-none-eabi
sudo apt install libnewlib-arm-none-eabi
```

```bash
rustup target add armv7r-none-eabi
cargo install cargo-binutils
rustup component add llvm-tools
```


## 動かし方

### 1. PC 側で Vivado により bit ファイルを作成

Vivado が使える状態にします。

```bash
source /tools/Xilinx/Vivado/2024.2/settings64.sh
```

または、拙作の Vivado バージョン管理ツール [vitisenv](https://github.com/ryuz/vitisenv) を使って自動化できます。

```bash
cd projects/kv260/kv260_rtcl_p3s7_centroid/syn/tcl
make
make bit_cp
```

`make bit_cp` で `app` ディレクトリへ bit ファイルがコピーされます。


### 2. KV260 側で PS ソフトをセルフコンパイルして実行

ssh 経由で GUI 表示する場合は X Forwarding を有効化し、PC 側に X Server を用意してください。
筆者は Windows 側で [VcXsrv](https://sourceforge.net/projects/vcxsrv/) を使用しています。

KV260 側でリポジトリを取得:

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

PC 側で生成した `kv260_rtcl_p3s7_centroid.bit` を
`projects/kv260/kv260_rtcl_p3s7_centroid/app` に配置してから、以下を実行します。

```bash
cd projects/kv260/kv260_rtcl_p3s7_centroid/app
make run
```

X-Window の設定が正しければ、ウィンドウが開いてカメラ画像が表示されます。

実行オプションは `RUN_OPT` で渡せます。

```bash
make run RUN_OPT="--width 256 --height 256 --fps 500 --pgood-off"
```


### 3. PC 側でクロスコンパイルしてリモート実行

`cross` が使える環境で、以下のようにビルドして KV260 へ転送・実行できます。

```bash
cd projects/kv260/kv260_rtcl_p3s7_centroid/app/rust
make remote_run
```

この際、環境変数 `KV260_SSH_ADDRESS` と `KV260_SERVER_ADDRESS` を設定してください。

```bash
KV260_SERVER_ADDRESS="192.168.16.1:8051"
KV260_SSH_ADDRESS="kria-kv260"
```

`RUN_OPT` の指定例:

```bash
make remote_run RUN_OPT="--width 256 --height 256 --fps 500 --pgood-off"
```


## 備考

- `--pgood-off` を指定するとセンサの PGOOD チェックを無効化できます。
- 引数の詳細は `app/rust/src/main.rs` の `Args` 定義を参照してください。
