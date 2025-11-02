# Kria KV260 用 RTCL-P3S7-MIPI グローバルシャッター高速度カメラ動作サンプル

## 概要

Kria KV260 で [グローバルシャッターMIPI高速度カメラ](https://rtc-lab.com/products/rtcl-cam-p3s7-mipi/)(設計は[こちら](https://github.com/ryuz/rtcl-p3s7-mipi-pcb))を動かすサンプルです。

このプロジェクトは、オンセミ社の[PYTHON300センサー](https://www.onsemi.jp/products/sensors/image-sensors/python300) + AMD社 [Spartan-7 FPGA](https://www.amd.com/ja/products/adaptive-socs-and-fpgas/fpga/spartan-7.html) を搭載したカメラモジュールを KV260 に接続し、D-PHY 上で独自プロトコルを用いた高速画像伝送を行います。

本プロジェクトでは MIPI の DPHY の物理層を利用しつつ、CSI2 規格ではない独自プロトコルで伝送することで、画像1フレームを1パケットとして転送し、伝送帯域を有効活用して高速度撮影を実現しています。

本ドキュメントでは、カメラモジュール側の Spartan-7 には [こちら](https://github.com/ryuz/rtcl-designs/tree/main/projects/rtcl_p3s7_mipi/rtcl_p3s7_mipi)のデザインが書き込まれている前提で、KV260 側で FPGAデザインについて説明します。


## 環境構築

本プロジェクトでは、KV260 の FPGA部分である PL(Proglamable Logic)部 用の SystemVerilog の設計の他に、それらを制御する PS(Processing System)部 用のソフトウェアや PC 側から制御する提供しております。

シンプルな動作サンプルとして C++版のサンプルも用意しておりますが、メインでは Rust 版を推奨しており、Rust のサーバーを起動することで gRPC 経由で PCからカメラ制御も可能です。

### KV260環境

KV260 の環境構築基本的には[こちらの記事](https://zenn.dev/ryuz88/articles/kv260_setup_memo_ubuntu24)を参考にしてください。

以下、抜粋した説明のみ記載します。

[認定Ubuntu](https://japan.xilinx.com/products/design-tools/embedded-software/ubuntu.html) 環境にて試しております。

```
Description : Ubuntu 24.04 LTS
kernel      : 6.8.0-1017-xilinx
```

セルフコンパイルを行う為に下記のパッケージなどをインストールしておいてください。

```bash
sudo apt update
sudo apt install -y build-essential
sudo apt install -y libssl-dev
sudo apt install -y protobuf-compiler
sudo apt install -y libopencv-dev
sudo apt install -y llvm-dev clang libclang-dev
sudo apt install -y xauth x11-apps
```

また Rust のインストールも下記のように行ってください。

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup default stable
rustup update
```

コンパイル時間短縮の為バイナリインストールツールの cargo-binstall も導入しておくと便利です。

```bash
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
```

拙作の FPGA 制御サービス [jelly-fpga-server](https://github.com/ryuz/jelly-fpga-server) と FPGA ローダー [jelly-fpga-loader](https://github.com/ryuz/jelly-fpga-loader) も以下のコマンドでそれぞれインストールできます。

```bash
curl -LsSf https://raw.githubusercontent.com/ryuz/jelly-fpga-server/master/binst.sh | sudo bash
```

```bash
cargo-binstall --git https://github.com/ryuz/jelly-fpga-loader.git jelly-fpga-loader
```

### PC環境

Windows WLS2 環境を含めた Ubuntu 22.04/24.04 環境で動作確認しております。

Vivado は 2024.2 を用いております。

KV260 上でセルフコンパイルも可能ですが、クロスコンパイルを行う場合は Docker をインストールすると便利です。

VS-Code などの Dev Container や Rust の [cross](https://github.com/cross-rs/cross) を用いたクロスコンパイルも可能です。

KV260 と同様に PC 側でも Rust のインストールも下記のように行ってください。

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup default stable
rustup update
```

cargo-binstall も同様に導入できます。

```bash
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
```

クロスコンパイルツールの cross も

```bash
cargo install cross --git https://github.com/cross-rs/cross
```

とすればインストールできます。

jelly-fpga-loader も以下のコマンドでインストールできます。

```bash
cargo-binstall --git https://github.com/ryuz/jelly-fpga-loader.git jelly-fpga-loader
```


## 本プロジェクトの使い方

### gitリポジトリ取得

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

で一式取得してください。


### PC側の Vivado で bit ファイルを作る

#### TCL ビルド (推奨)

Vivado が使えるように

```bash
source /tools/Xilinx/Vivado/2024.2/settings64.sh
```

しておいてください。
もしくは 拙作の Vivado バージョン管理ツール [vitisenv](https://github.com/ryuz/vitisenv) を用いるとこの作業を自動化できます。


vivado のツール群が使える状態で

```bash
cd projects/kv260/kv260_rtcl_p3s7_hs/syn/tcl
make
```

とすると bit ファイルが生成されます。続けて

```bash
make bit_cp
```

とすると app ディレクトリに bit ファイルがコピーされます。


#### GUI 版

`projects/kv260/kv260_rtcl_p3s7_hs/syn/vivado2024.2/kv260_rtcl_p3s7_hs.xpr`

に Vivado GUI 用のプロジェクトがあるので、Vivado の GUI から開いてご利用ください。

最初に BlockDesign を tcl から再構成する必要があります。

Vivado メニューの「Tools」→「Run Tcl Script」で、プロジェクトと同じディレクトリにある `update_design.tcl` を実行すると再構築を行うようにしています。

うまくいかない場合は、既に登録されている design_1 を手動で削除してから、`design_1.tcl` を実行しても同じことができるはずです。

design_1 が生成されたら「Flow」→「Run Implementation」で合成を行います。正常に合成できれば

`kv260_rtcl_p3s7_hs.runs/impl_1/kv260_rtcl_p3s7_hs.bit`

が出来上がります。


### KV260 でPSソフトをセルフコンパイルして実行

ssh で接続して利用する場合は X Forwarding を有効にして、PC側の X-Server も準備しておいてください。
筆者は [VcXsrv](https://sourceforge.net/projects/vcxsrv/) を Windows 側にインストールして利用しております。

KV260 側でも PC 同様に本リポジトリを clone します。

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

`projects/kv260/kv260_rtcl_p3s7_hs/app` ディレクトリに、先ほど PC の Vivado で作成した `kv260_rtcl_p3s7_hs.bit` をコピーしておいてください。

#### C++版の実行

```bash
cd projects/kv260/kv260_rtcl_p3s7_hs/app
make run_cpp
```

と実行すれば C++ 版のサンプルがコンパイルされ実行されます。

X-Window の設定が正しくできていれば、ウィンドウが開き、カメラ画像が表示されるはずです。

#### Rust版の実行

```bash
cd projects/kv260/kv260_rtcl_p3s7_hs/app
make run_rust
```

と実行すれば Rust 版のサンプルがコンパイルされ実行されます。

X-Window の設定が正しくできていれば、ウィンドウが開き、カメラ画像が表示されるはずです。


#### gRPC サーバーの起動

```bash
cd projects/kv260/kv260_rtcl_p3s7_hs/app
make run_server
```

と実行すれば Rust 版の gRPC サーバーが起動して、リモートからカメラ制御が可能になります。

PC 側で


### その他の実行方法

#### Rust版の実行

```bash
make run_rust
```

#### gRPCサーバーの起動

```bash
make server
```

## シミュレーション

`projects/kv260/kv260_rtcl_p3s7_hs/sim` 以下にシミュレーション環境を作っています。

該当ディレクトリに移動して make と実行することで、シミュレーションが動きます。

.vcd ファイルとして波形が生成されるので、gtkwave などの波形ビューワーで確認ください。

## カメラモジュールの仕様

本プロジェクトで使用するカメラモジュールの仕様：

| 項目 | 仕様 |
|------|------|
| イメージセンサー | オンセミコンダクター PYTHON300<br>モノクロ：NOIP1SN0300A-QTI<br>カラー：NOIP1SN0300A-QTI |
| FPGA | AMD Spartan-7 (XC7S6-2FTGB196C) |
| 解像度 | 640×480 (VGA) |
| 最大フレームレート | 815 fps (Zero ROT mode) |
| 画素サイズ | 4.8μm × 4.8μm |
| シャッター方式 | グローバルシャッター |
| MIPIコネクタ | Raspberry PI 互換 15pin コネクタ<br>差動信号2レーン (各最大1250Mbps)<br>I2C信号線、GPIO線 x 2bit、3.3V給電 |
| 汎用I/O | PMOD仕様コネクタ x 1 |
| JTAGコネクタ | Xilinx標準仕様(2×7 2mmピッチ) x 1 |

## システム特徴

- **独自プロトコル**: MIPI-CSI規格を使わず、D-PHY上で独自プロトコルで高速伝送
- **高速度撮影**: 画像1フレームを1パケットとして転送することで伝送帯域を有効活用
- **グローバルシャッター**: 動きの速い被写体でも歪みなく撮影可能
- **低遅延**: FPGAベースの処理による低遅延画像処理
- **同期撮影**: 外部照明やトリガー信号との同期撮影が可能

## 各種設定

FPGAの内部動作や、イメージセンサーのSPIでアクセスするレジスタはI2Cから制御できるようにしております。

### FPGA設定

I2C経由で 16bitアドレス 16bit データの読み書きが可能で、以下のレジスタが操作できます。

|   Addr | 名称                 | Access | リセット値    | Bits/説明                                      |
|--------|----------------------|--------|--------------|-----------------------------------------------|
| 0x0000 | CORE_ID              | RO     | 0x527A       | [15:0]=0x527A, 識別子                         |
| 0x0001 | CORE_VERSION         | RO     | 0x0100       | [15:0]=0x0100, バージョン                     |
| 0x0010 | RECV_RESET           | R/W    | 0x0001       | [0]=1: 受信系リセット                         |
| 0x0020 | ALIGN_RESET          | R/W    | 0x0001       | [0]=1: アライメント部リセット                 |
| 0x0022 | ALIGN_PATTERN        | R/W    | 0x03A6       | [9:0]: パターン値                              |
| 0x0028 | ALIGN_STATUS         | RO     | -            | [1]=エラー, [0]=完了                           |
| 0x0080 | DPHY_CORE_RESET      | R/W    | 0x0001       | [0]=1: D-PHY コアリセット                     |
| 0x0081 | DPHY_SYS_RESET       | R/W    | 0x0001       | [0]=1: D-PHY SYSリセット                      |
| 0x0088 | DPHY_INIT_DONE       | RO     | -            | [0]=1: D-PHY 初期化完了                       |


## 応用例

### マルチスペクトル撮影

グローバルシャッターカメラでは照明とシャッターを同期させた高速度撮影が容易です。複数色のLEDを用意して発光パターンを変えながら撮影することで、マルチスペクトル計測が可能です。

### ビジュアルフィードバック

1ms級の低遅延での非接触画像認識により、以下のような応用が可能です：
- 非接触での振動計測による故障検知／予知
- 振動環境下での画像認識  
- 振動フィードバックによる制振制御
- ランダムに動くものの把持
- 遅延なく人間の動きに追従するアシストロボ

### 同期撮影

FPGAから生成したパルスで同期撮影が可能です。超高速での照明変化と同期してシャッターを切ることで、通常のカメラでは不可能な特殊撮影が実現できます。

## 参考情報

- [作者ブログ記事](https://rtc-lab.com/products/rtcl-cam-p3s7-mipi/)
- [PYTHON300 データシート](https://www.onsemi.jp/products/sensors/image-sensors/python300)
- [カメラモジュール設計リポジトリ](https://github.com/ryuz/rtcl-p3s7-mipi)
- [Kria KV260 ビジョン AI スターター キット](https://www.amd.com/ja/products/system-on-modules/kria/k26/kv260-vision-starter-kit.html)

