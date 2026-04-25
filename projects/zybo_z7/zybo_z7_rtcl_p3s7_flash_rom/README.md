# ZYBO Z7 用 RTCL-P3S7-MIPI グローバルシャッター高速度カメラ Flash-ROM 更新アプリ

## 概要

ZYBO Z7-20 で [グローバルシャッターMIPI高速度カメラ](https://rtc-lab.com/products/rtcl-cam-p3s7-mipi/)(設計は[こちら](https://github.com/ryuz/rtcl-p3s7-mipi-pcb)) の Flash-ROM を JTAGダウンロードケーブルなしで更新するアプリです。

以降は zybo_z7_rtcl_p3s7_hs などの基本サンプルが動作する状態にセットアップされている前提として説明します。


--- ここまで書き替えた ---

## 本プロジェクトの使い方

### gitリポジトリ取得

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

で一式取得してください。


### 最短手順 (PCからリモート更新)

すでに ZYBO Z7 側で `jelly-fpga-server` が起動しており、SSH 接続できる場合は以下が最短です。

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_flash_rom/app/rust
ZYBO_Z7_SERVER_ADDRESS="192.168.16.1:8051" \
ZYBO_Z7_SSH_ADDRESS="zybo-z7" \
make remote_update
```

`remote_update` は次を自動で行います。

- Rust アプリのクロスビルド
- FPGA オーバレイのロード
- 更新対象 bitstream (`rtcl_p3s7_mipi.bin`) の生成と転送
- ZYBO Z7 上で Flash-ROM への書き込み実行 (`-w -v`)


### 手動手順

#### 1. PC側で FPGA bit ファイルを作る

Vivado が使えるように

```bash
source /tools/Xilinx/Vivado/2024.2/settings64.sh
```

しておいてください。
もしくは拙作の Vivado バージョン管理ツール [vitisenv](https://github.com/ryuz/vitisenv) を用いるとこの作業を自動化できます。

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_flash_rom/syn/tcl
make
make bit_cp
```

`make bit_cp` で生成された bit ファイルが `app` ディレクトリにコピーされます。


#### 2. オーバレイをロードして更新アプリを実行

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_flash_rom/app/rust
make remote_run
```

上記でオーバレイをロードしつつ実行できます。
更新処理まで一気に行う場合は `remote_update` を使ってください。


### 主要ターゲット

`projects/zybo_z7/zybo_z7_rtcl_p3s7_flash_rom/app/rust/Makefile` の主なターゲットです。

- `make build` : ローカルビルド
- `make cross_build` : ARM向けクロスビルド
- `make remote_run` : 転送して ZYBO Z7 で実行
- `make remote_update` : bitstream 転送を含む更新フローを実行


### 実行オプション (Rustアプリ)

更新アプリは次のようなオプションを持っています。

- `-i` : Flash-ROM 情報表示
- `-r -o <file>` : 指定範囲を読み出して保存
- `-w <file>` : 書き込み
- `-v <file>` : 検証
- `-e` : 消去
- `-a <addr>` : アドレス指定 (デフォルト `0x100000`)
- `-s <size>` : サイズ指定 (デフォルト `0x0f0000`)

例:

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_flash_rom/app/rust
make remote_run RUN_OPT="-i"
```

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_flash_rom/app/rust
make remote_run RUN_OPT="-r -a 0x100000 -s 0x0f0000 -o /tmp/read_back.bin"
```


### 注意事項

- `0x100000` 未満や `0x1ff000` を超える領域を書き換えると、ゴールデンイメージ領域を上書きする可能性があります。
- 本番更新の前に、`-r` でバックアップを取得することを強く推奨します。
- 書き換え完了直後は、現在起動中の古いイメージで動作を継続しています。新しいイメージで起動するには、一度電源を落として再投入してください。

