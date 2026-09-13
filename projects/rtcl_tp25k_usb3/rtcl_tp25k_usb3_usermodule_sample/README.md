# Tang Primer 25k + USB3.0 基板(RTCL-TP25K-USB3)用 ユーザーモジュールサンプル

## 概要

AXI4-Lite によるレジスタ読み書きや、AXI4-Stream によるデータ送受信を行うユーザーモジュールを、RTCL-TP25K-USB3 にて USB3.0 経由で PC から制御するサンプルです。

Verilog などの RTL開発に初めて触れる人が、まず usermodule.sv としてユーザーモジュールを書いてみることで PC から簡単にアクセスできる環境で FPGA の勉強を始められることを目的としています。


## 環境構築

[こちら](../README.md)を参考にしてください。

本プロジェクトでも FT601 については 2チャンネルモードを使う構成になっています。

## 本プロジェクトの使い方

### gitリポジトリ取得

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

で一式取得してください。

### FPGA コンフィグレーションファイルの生成

#### TCL ビルド (推奨)

`gw_sh` が利用できる環境設定が出来ている前提で、以下を実行します。

```bash
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_usermodule_sample/syn/cli
make
```

これにより `impl/pnr/rtcl_tp25k_usb3_usermodule_sample.fs` が生成されます。

JTAG 経由で FPGA に書き込む場合は、同じディレクトリで次を実行します。

```bash
make load
```

このターゲットは `openFPGALoader -c digilent_hs2` を使用します。使用する JTAG ケーブルが異なる場合は、`syn/cli/Makefile` の `load` または `load_wsl` を環境に合わせて変更してください。

#### GUI 版

`syn/Gowin_V1.9.12.02_SP2/rtcl_tp25k_usb3_calc_summation.gprj` を GOWIN EDA で開いてビルドすることもできます。

### PC 側のソフト

PC 側では Rust で書かれたサンプルアプリを使って、FPGA の制御レジスタの確認、LED/PMOD の制御、AXI4-Stream データの送受信を行います。FPGA に書き込んだ後、以下を実行してください。

```bash
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_usermodule_sample/app/rust
cargo run --release
```

また、アプリのディレクトリから FPGA の書き込みと実行を続けて行うこともできます。

```bash
make load run
```

実行すると、FPGA の ID、バージョン、スイッチ状態を読み出した後、ユーザーレジスタの読み書き、LED/PMOD の点滅を行います。続いて `[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]` を 32bit little endian で送信し、各データに 1 を加えた結果を受信して表示します。

サンプルの実際の流れは以下の通りです。

1. `D3xxFifo32Direct::new(0)?` で FT601 デバイスを開く
2. AXI4-Lite で ID、バージョン、スイッチ状態を読み出す
3. `USER0` と `USER1` を書き込み、バイトイネーブル付きの書き込みを確認
4. LED と PMOD を点滅させる
5. `u32` 配列を 32bit little endian のバイト列に変換して送信
6. FPGA 側の `usermodule` で各データに 1 を加算
7. 変換後の 32bit 配列を受信して表示

### 期待される動作

入力データが `[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]` の場合、受信データは `[2, 3, 4, 5, 6, 7, 8, 9, 10, 11]` です。

アプリはこの値を受信して

```text
Summation result: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
```

と出力することを想定しています。表示文字列は Rust アプリに残っている既存の文言であり、処理内容は累算ではありません。

## FPGA 側の構成

本プロジェクトの FPGA は、主に以下の構成で動作します。

- FT601 に接続された USB3.0 FIFO インターフェース
- チャネル 0: AXI4-Lite 制御チャネル
- チャネル 1: AXI4-Stream データチャネル
- `fifo32_cmd_axi4l` による AXI4-Lite コマンド処理
- `fifo32_cmd_axi4s_rx` / `fifo32_cmd_axi4s_tx` による AXI4-Stream パケット処理
- `usermodule` によるユーザー処理と LED/PMOD 制御

`usermodule` は以下のインターフェースを持っています。

- `s_axi4l`: 制御レジスタアクセス
- `s_axi4s`: 入力データ
- `m_axi4s`: 出力データ
- `push_sw` / `dip_sw`: ボード上のスイッチ入力
- `led` / `pmod`: ボード上の出力

AXI4-Lite のレジスタアドレスは以下の通りです。

| アドレス | 名前 | 内容 |
| --- | --- | --- |
| `0x0000_0000` | `ID` | `0x1234_abcd` を返す |
| `0x0000_0004` | `VERSION` | `0x0001_0000` を返す |
| `0x0000_0008` | `USER0` | 読み書き可能なユーザーレジスタ |
| `0x0000_000c` | `USER1` | 読み書き可能なユーザーレジスタ |
| `0x0000_0010` | `PUSH_SW` | プッシュスイッチ入力 |
| `0x0000_0014` | `DIP_SW` | DIP スイッチ入力 |
| `0x0000_0018` | `LED` | LED 出力 |
| `0x0000_001c` | `PMOD` | PMOD 出力 |

## 参考資料

- [RTCL-TP25K-USB3 関連プロジェクト](../README.md)
- [rtcl_tp25k_usb3_mipi_lane2](../rtcl_tp25k_usb3_mipi_lane2/README.md)
- [jelly](../../../jelly/README.md)

## 補足

このサンプルは、USB3.0 とユーザーモジュールの接続方法を確認するためのものです。ユーザー処理を変更する場合は `rtl/usermodule.sv` を編集し、AXI4-Lite のレジスタマップや AXI4-Stream のパケット境界を合わせて変更してください。

