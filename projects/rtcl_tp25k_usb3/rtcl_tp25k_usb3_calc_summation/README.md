# Tang Primer 25k + USB3.0 基板(RTCL-TP25K-USB3)用 累算計算サンプル

## 概要

RTCL-TP25K-USB3 にて、USB3.0 経由で PC からデータを送り込んで FPGA で結果を PC に戻す簡単な計算サンプルです。

本サンプルでは、AXI4-Stream で受信した 32bit データ列を FPGA 側で累算し、最後のデータを処理した時点で総和を 1 パケットとして USB3.0 経由で PC に返します。

実装上は、FT601 を 2ch モードで利用し、チャネル 0 で AXI4-Lite 制御、チャネル 1 で AXI4-Stream のデータ転送を行っています。FPGA 側の `calc_summation` モジュールは入力を受信しながら `m_axi4s.tdata <= m_axi4s.tdata + s_axi4s.tdata` として累算し、最後の入力データの時だけ結果を送出します。

## 環境構築

[こちら](../README.md)を参考にしてください。

本プロジェクトでも FT601 については 2チャンネルモードを使う構成になっています。

## 本プロジェクトの使い方

### gitリポジトリ取得

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

で一式取得してください。

### PC側の GOWIN EDA で fs ファイルを作る

#### TCL ビルド (推奨)

`gw_sh` が利用できる環境設定が出来ている前提で、以下を実行します。

```bash
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_calc_summation/syn/cli
make
```

これにより `impl/pnr/rtcl_tp25k_usb3_calc_summation.fs` が生成されます。

このファイルは JTAG 経由で FPGA にダウンロードできます。コマンドラインで行う場合は、JTAG ケーブルの環境によって実行方法が変わるため、Makefile の `run` や `rom_write` の項を参考にオプションを調整してください。

#### GUI 版

`projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_calc_summation/syn/Gowin_V1.9.12.02_SP2` の下にも GUI 用のプロジェクトがあるため、そちらを開いてビルドすることも可能です。

### PC 側のソフト

PC 側では Rust で書かれたサンプルアプリを使って、FPGA の制御レジスタの確認、データ送信、結果受信を行います。

```bash
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_calc_summation/app/rust
cargo run --release
```

実行すると、FPGA の `CORE_ID` と `CORE_VER` を読み取り、入力データとして `[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]` を 32bit little endian で送信し、結果の総和を受信して表示します。

サンプルの実際の流れは以下の通りです。

1. `D3xxFifo32Direct::new(0)?` で FT601 デバイスを開く
2. AXI4-Lite のレジスタ読み出しで `CORE_ID` と `CORE_VER` を確認
3. `u32` 配列を 32bit little endian のバイト列に変換して送信
4. FPGA 側の `calc_summation` モジュールで累算
5. 1つの 32bit 結果を受信して表示

### 期待される動作

入力データが `[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]` の場合、合計は 55 です。

アプリはこの値を受信して

```text
Summation result: 55
```

のように出力することを想定しています。

## FPGA 側の構成

本プロジェクトの FPGA は、主に以下の構成で動作します。

- FT601 に接続された USB3.0 FIFO インターフェース
- チャネル 0: AXI4-Lite 制御チャネル
- チャネル 1: AXI4-Stream データチャネル
- `jelly3_system_control` による制御レジスタ
- `calc_summation` による累算処理
- 送受信のチェック用 `fifo32_cmd_axi4s_checker` と LED/PMOD による状態表示

`calc_summation` モジュールは入出力が以下のような AXI4-Stream インターフェースを持っています。

- `s_axi4s`: 入力データ
- `m_axi4s`: 総和結果出力

入力データの最後に到達した時点で `m_axi4s.tvalid` を立て、1 パケットの結果を返す設計です。

## 参考資料

- [RTCL-TP25K-USB3 関連プロジェクト](../README.md)
- [rtcl_tp25k_usb3_mipi_lane2](../rtcl_tp25k_usb3_mipi_lane2/README.md)
- [jelly](../../../jelly/README.md)

## 補足

このサンプルは「USB3.0 で FPGA に簡単なデータを送り込み、その結果を戻す」最小構成の例として作られています。より複雑な処理や複数データ列の取り扱いに拡張する場合は、AXI4-Stream のデータ長や、パケット境界の取り扱いを考慮して実装を増やす形になります。

