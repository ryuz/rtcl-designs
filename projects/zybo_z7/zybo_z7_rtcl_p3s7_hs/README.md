# ZYBO Z7 用 RTCL-P3S7-MIPI グローバルシャッター高速度カメラ動作サンプル

## 概要

ZYBO Z7-20 で [グローバルシャッターMIPI高速度カメラ](https://rtc-lab.com/products/rtcl-cam-p3s7-mipi/)(設計は[こちら](https://github.com/ryuz/rtcl-p3s7-mipi-pcb))を動かすサンプルです。

このプロジェクトは、オンセミ社の[PYTHON300センサー](https://www.onsemi.jp/products/sensors/image-sensors/python300) + AMD社 [Spartan-7 FPGA](https://www.amd.com/ja/products/adaptive-socs-and-fpgas/fpga/spartan-7.html) を搭載したカメラモジュールを ZYBO Z7 に接続し、D-PHY 上で独自プロトコルを用いた高速画像伝送を行います。

本プロジェクトでは MIPI の DPHY の物理層を利用しつつ、CSI2 規格ではない独自プロトコルで伝送することで、画像1フレームを1パケットとして転送し、伝送帯域を有効活用して高速度撮影を実現しています。

本ドキュメントでは、カメラモジュール側の Spartan-7 には [こちら](https://github.com/ryuz/rtcl-designs/tree/main/projects/rtcl_p3s7_mipi/rtcl_p3s7_mipi)のデザインが書き込まれている前提で、ZYBO Z7 側で FPGAデザインについて説明します。


## 環境構築

本プロジェクトでは、ZYBO Z7 の FPGA部分である PL(Proglamable Logic)部 用の SystemVerilog の設計の他に、それらを制御する PS(Processing System)部 用のソフトウェアや PC 側から制御する提供しております。

シンプルな動作サンプルとして C++版のサンプルも用意しておりますが、メインでは Rust 版を推奨しており、Rust のサーバーを起動することで gRPC 経由で PCからカメラ制御も可能です。

### ZYBO Z7 環境

ikwzm氏公開の [Debian12](https://github.com/ikwzm/FPGA-SoC-Debian12) 環境にて試しております。

```
Description : Debian-12
kernel      : 6.1.108-armv7-fpga
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
rustup target add arm-unknown-linux-gnueabihf
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
cargo-binstall --target arm-unknown-linux-gnueabihf --git https://github.com/ryuz/jelly-fpga-loader.git jelly-fpga-loader
```

### PC環境

Windows WLS2 環境を含めた Ubuntu 22.04/24.04 環境で動作確認しております。

Vivado は 2024.2 を用いております。

ZYBO Z7 上でセルフコンパイルも可能ですが、クロスコンパイルを行う場合は Docker をインストールすると便利です。

VS-Code などの Dev Container や Rust の [cross](https://github.com/cross-rs/cross) を用いたクロスコンパイルも可能です。

ZYBO Z7 と同様に PC 側でも Rust のインストールも下記のように行ってください。

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup default stable
rustup update
rustup target add arm-unknown-linux-gnueabihf
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
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/syn/tcl
make
```

とすると bit ファイルが生成されます。続けて

```bash
make bit_cp
```

とすると app ディレクトリに bit ファイルがコピーされます。


#### GUI 版

`projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/syn/vivado2024.2/zybo_z7_rtcl_p3s7_hs.xpr`

に Vivado GUI 用のプロジェクトがあるので、Vivado の GUI から開いてご利用ください。

最初に BlockDesign を tcl から再構成する必要があります。

Vivado メニューの「Tools」→「Run Tcl Script」で、プロジェクトと同じディレクトリにある `update_design.tcl` を実行すると再構築を行うようにしています。

うまくいかない場合は、既に登録されている design_1 を手動で削除してから、`design_1.tcl` を実行しても同じことができるはずです。

design_1 が生成されたら「Flow」→「Run Implementation」で合成を行います。正常に合成できれば

`zybo_z7_rtcl_p3s7_hs.runs/impl_1/zybo_z7_rtcl_p3s7_hs.bit`

が出来上がります。


### ZYBO Z7 でPSソフトをセルフコンパイルして実行

ssh で接続して利用する場合は X Forwarding を有効にして、PC側の X-Server も準備しておいてください。
筆者は [VcXsrv](https://sourceforge.net/projects/vcxsrv/) を Windows 側にインストールして利用しております。

ZYBO Z7 側でも PC 同様に本リポジトリを clone します。

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

`projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/app` ディレクトリに、先ほど PC の Vivado で作成した `zybo_z7_rtcl_p3s7_hs.bit` をコピーしておいてください。

#### C++版の実行

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/app
make run_cpp
```

と実行すれば C++ 版のサンプルがコンパイルされ実行されます。

X-Window の設定が正しくできていれば、ウィンドウが開き、カメラ画像が表示されるはずです。


#### Rust版の実行

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/app
make run_rust
```

と実行すれば Rust 版のサンプルがコンパイルされ実行されます。

X-Window の設定が正しくできていれば、ウィンドウが開き、カメラ画像が表示されるはずです。



### PCで PSソフトをクロスコンパイルして実行

#### C++版の実行

DevContainer が使えるなら `devcontainer/devcontainer.sample.json` を参考に DevContainer を作成し、VS-Code で開いてください。

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/app/cpp
make remote_run
```

とすればクロスコンパイルした後に、リモートで実行できます。


#### Rust版の実行

cross が使える環境で、下記のようにすれば仮想環境でビルドした後に、リモートで実行できます。

```bash
cd projects/zybo_z7/zybo_z7_rtcl_p3s7_hs/app/rust
make remote_run
```

この際、環境変数 `ZYBO_Z7_SSH_ADDRESS` と `ZYBO_Z7_SERVER_ADDRESS` にそれぞれ ZYBO_Z7 の ssh アドレスと gRPC サーバーのアドレスを設定しておいてください。

`ZYBO_Z7_SERVER_ADDRESS` には jelly-fpga-server が接続できるアドレス、`ZYBO_Z7_SSH_ADDRESS` には ssh 接続できるアドレスを設定してください。

```bash
ZYBO_Z7_SERVER_ADDRESS="192.168.16.1:8051"
ZYBO_Z7_SSH_ADDRESS="zybo-z7"
```


## 参考情報

- [プロダクトページ](https://rtc-lab.com/products/rtcl-cam-p3s7-mipi/)
- [PYTHON300 データシート](https://www.onsemi.jp/products/sensors/image-sensors/python300)
- [カメラモジュール設計リポジトリ](https://github.com/ryuz/rtcl-p3s7-mipi)
- [ZYBO Z7](https://digilent.com/reference/programmable-logic/zybo-z7/start)

