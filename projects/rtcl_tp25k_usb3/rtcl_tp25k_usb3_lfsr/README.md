# Tang Primer 25k + USB3.0 基板(RTCL-TP25K-USB3)用 LFSR ループバックテストサンプル

## 概要

RTCL-TP25K-USB3 にて、USB3.0 経由で FPGA と PC の間で LFSR(Linear Feedback Shift Register) 乱数列を送受信し、データの破損や伝送異常がないかを確認するサンプルです。

本サンプルでは、`fifo32_lfsr_transmitter` と `fifo32_lfsr_receiver` を利用して、PC から FPGA へ LFSR 列を送信し、FPGA から PC へ戻すループバック検証を行います。受信データの検査は `check_lfsr_words()` により行われ、ミスマッチがあればエラー数と最初の異常位置を出力します。

## 環境構築

[こちら](../README.md)を参考にしてください。

本プロジェクトでも FT601 は 2チャンネルモードを使い、チャネル 0 で AXI4-Lite 制御、チャネル 1 で AXI4-Stream のデータ転送を行っています。

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
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_lfsr/syn/cli
make
```

これにより `impl/pnr/rtcl_tp25k_usb3_lfsr.fs` が生成されます。

このファイルを JTAG 経由で FPGA にダウンロードできます。コマンドラインで行う場合は、JTAG ケーブルの環境によって実行方法が変わるため、Makefile の `load` や `rom_write` の項を参考にオプションを調整してください。

#### GUI 版

`projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_lfsr/syn/Gowin_V1.9.12.02_SP2` の下にも GUI 用のプロジェクトがあるため、そちらを開いてビルドすることも可能です。

### PC 側のソフト

Rust で作られたサンプルアプリを使って LFSR の送受信テストを実施します。

```bash
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_lfsr/app/rust
cargo run --release
```

このアプリでは、以下の順で動作します。

1. FT601 デバイスを開く
2. `CORE_ID` を読み出して FPGA の稼働確認
3. LFSR 乱数列を生成して FPGA へ送信
4. FPGA が生成した LFSR 列を PC で受信
5. 受信データの内容を検査して、ミスマッチがないか確認
6. 送受信の throughput を表示

データサイズは `16*1024*1024` バイトで、初期値は `0x12345678` に設定されています。

## FPGA 側の構成

本プロジェクトの FPGA では、主に以下の構成で動作します。

- FT601 に接続された USB3.0 FIFO インターフェース
- チャネル 0: AXI4-Lite 制御チャネル
- チャネル 1: AXI4-Stream データチャネル
- `jelly3_system_control` による制御レジスタ
- `fifo32_lfsr_receiver` による受信検査
- `fifo32_lfsr_transmitter` による送信生成
- `fifo32_cmd_axi4s_checker` によるパケット異常検知

FPGA 側では、LFSR の生成多項式として `0x80200003` を使い、乱数列を連続して送受信します。受信側では比較用のシード値と出力値を照合し、誤りがあれば `lfsr_rx_error` と `pkt_error` で状態を知らせます。

## 期待される動作

正常な環境では、受信したデータ列が LFSR の期待値と一致しているため、以下のようなログが出力されます。

```text
SYSCTL_CORE_ID    : 0x....
LFSR_RX_CORE_ID   : 0x....
LFSR_TX_CORE_ID   : 0x....
Recv done: bytes=..., words=..., elapsed=...
FPGA => PC throughput: ...
LFSR check OK: no mismatch
FPGA RX count: ..., RX error: 0
PC => FPGA throughput: ...
End Test
```

異常がある場合は、`LFSR check NG` のようなメッセージで、どこで誤差が発生したかを示します。

## 参考資料

- [RTCL-TP25K-USB3 関連プロジェクト](../README.md)
- [rtcl_tp25k_usb3_calc_summation](../rtcl_tp25k_usb3_calc_summation/README.md)
- [rtcl_tp25k_usb3_calc_morphology](../rtcl_tp25k_usb3_calc_morphology/README.md)
- [jelly](../../../jelly/README.md)

## 補足

このサンプルは「USB3.0 で大量データを高速に転送し、FPGA 側で生成した LFSR 乱数列が壊れていないか」確認するためのテスト用途のデモです。

通信路の確認、送受信周波数の計測、データ整合性のチェックを行う際のベースとして利用できます。実際の応用では、他のデータパターンやより長い転送サイズにも簡単に拡張できます。
