# Tang Primer 25k + USB3.0 基板(RTCL-TP25K-USB3)用 LEDチカチカサンプル

## 概要

RTCL-TP25K-USB3 にて、FPGA の内部クロックを使って LEDチカチカサンプルを行う最小サンプルです。

本サンプルでは、`in_clk50` を基準にしたカウンタと `ft601_clk` を基準にしたカウンタを用意し、それらの上位ビットを LED と PMOD に出力しています。単純な動作確認用のデモとして、USB3.0 の通信機能を使わずに FPGA 単体での点滅確認に特化しています。

## 環境構築

[こちら](../README.md)を参考にしてください。

本サンプルでは FT601 の USB インターフェースそのものは利用せず、FPGA 内部でのクロックと信号出力を確認するための最小構成です。

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
cd projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_blinking_led/syn/cli
make
```

これにより `impl/pnr/rtcl_tp25k_usb3_blinking_led.fs` が生成されます。

このファイルを JTAG 経由で FPGA にダウンロードできます。コマンドラインで行う場合は、JTAG ケーブルの環境によって実行方法が変わるため、Makefile の `load` や `rom_write` の項を参考にオプションを調整してください。

#### GUI 版

`projects/rtcl_tp25k_usb3/rtcl_tp25k_usb3_blinking_led/syn/Gowin_V1.9.12.02_SP2` の下にも GUI 用のプロジェクトがあるため、そちらを開いてビルドすることも可能です。

### FPGA への書き込み

生成した `.fs` ファイルを FPGA に書き込んだ後、LED の点滅を確認します。

実際の FPGA 側コードでは以下のような出力をしています。

- `led[1:0] = clk_counter[24:23]`
- `led[3:2] = usb_counter[24:23]`
- `pmod[3:0] = clk_counter[5:2]`
- `pmod[7:4] = usb_counter[5:2]`

これにより、内部クロックと FT601 クロックの両方に基づいた変化が LED と PMOD 上で確認できます。

## FPGA 側の構成

このサンプルは、非常にシンプルな構成です。

- 50MHz の入力クロック `in_clk50` を受け取る
- 25bit のカウンタを生成して LED に出力
- `ft601_clk` を受け取り、別の 25bit カウンタを生成して LED に出力
- `pmod` にも低ビットのカウンタを出力

つまり、FPGA の動作確認用として「クロックが走っていること」「信号が変化していること」を視覚的に確認できる構成になっています。

## 期待される動作

FPGA を起動すると、LED が徐々に変化して点滅している様子が確認できます。USB3.0 のデータ転送は行わず、シンプルなタイマーテストとして利用します。

## 参考資料

- [RTCL-TP25K-USB3 関連プロジェクト](../README.md)
- [rtcl_tp25k_usb3_calc_summation](../rtcl_tp25k_usb3_calc_summation/README.md)
- [rtcl_tp25k_usb3_calc_morphology](../rtcl_tp25k_usb3_calc_morphology/README.md)
- [rtcl_tp25k_usb3_lfsr](../rtcl_tp25k_usb3_lfsr/README.md)

## 補足

このサンプルは「FPGA が正常に動いているか」を最小限で確認するためのデモであり、USB3.0 通信や画像処理のような複雑な機能は含んでいません。起動チェックや基板の初期確認、デバッグ用の最初のテストとして有用です。
