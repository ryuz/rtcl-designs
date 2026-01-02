# RTCL-P3S7-MIPI グローバルシャッター高速度カメラ の 1000fps でのオプティカルフロー計測

## 概要

Kria KV260 でRTCL-P3S7-MIPI グローバルシャッター高速度カメラを 1000fps で動かして Lucas-Kanade法にてオプティカルフロー計測を行うサンプルです。

モノク版の RTCL-P3S7-MIPI カメラモジュールを前提としています。

アプリは Rust 版のみ提供しています。


## 環境準備

KV260 の RPU(Cortex-R5) も利用する為、クロスコンパイラのインストールが必要です。
これはコンパイルする環境で必要ですので、KV260側でセルフコンパイルする場合は、KV260 側で、PC側でクロスコンパイルする場合は PC 側でインストールしてください。


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

### PC側の Vivado で bit ファイルを作る

Vivado が使えるように

```bash
source /tools/Xilinx/Vivado/2024.2/settings64.sh
```

しておいてください。
もしくは 拙作の Vivado バージョン管理ツール [vitisenv](https://github.com/ryuz/vitisenv) を用いるとこの作業を自動化できます。


vivado のツール群が使える状態で

```bash
cd projects/kv260/kv260_rtcl_p3s7_optical_flow/syn/tcl
make
```

とすると bit ファイルが生成されます。続けて

```bash
make bit_cp
```

とすると app ディレクトリに bit ファイルがコピーされます。


### KV260 でPSソフトをセルフコンパイルして実行

ssh で接続して利用する場合は X Forwarding を有効にして、PC側の X-Server も準備しておいてください。
筆者は [VcXsrv](https://sourceforge.net/projects/vcxsrv/) を Windows 側にインストールして利用しております。

KV260 側でも PC 同様に本リポジトリを clone します。

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```

`projects/kv260/kv260_rtcl_p3s7_optical_flow/app` ディレクトリに、先ほど PC の Vivado で作成した `kv260_rtcl_p3s7_optical_flow.bit` をコピーしておいてください。


```bash
cd projects/kv260/kv260_rtcl_p3s7_mnikv260_rtcl_p3s7_optical_flowst_seg/app
make run
```

と実行すれば Rust 版のサンプルがコンパイルされ実行されます。

X-Window の設定が正しくできていれば、ウィンドウが開き、カメラ画像が表示されるはずです。

Makefile の中で RUN_OPT 変数を設定することで、実行時の追加のオプションを渡せます。

```bash
make run_rust RUN_OPT="--width 256 --height 256 --fps 500"
```

などとすると、PGOOD 信号を無効にして実行できます。



### PCで PSソフトをクロスコンパイルして実行

cross が使える環境で、下記のようにすれば仮想環境でビルドした後に、リモートで実行できます。

```bash
cd projects/kv260/kv260_rtcl_p3s7_optical_flow/app/rust
make remote_run
```

この際、環境変数 `KV260_SSH_ADDRESS` と `KV260_SERVER_ADDRESS` にそれぞれ KV260 の SSH アドレスと jelly-fpga-server サーバーのアドレスを設定しておいてください。

例えば

```bash
KV260_SERVER_ADDRESS="192.168.16.1:8051"
KV260_SSH_ADDRESS="kria-kv260"
```

といった形式になります。

また、Makefile の中で RUN_OPT 変数を設定することで、実行時の追加のオプションを渡せます。

```bash
make remote_run RUN_OPT="--width 256 --height 256 --fps 500"
```


## 参考情報

- [Lucas–Kanade method](https://en.wikipedia.org/wiki/Lucas%E2%80%93Kanade_method)
- [FPGAによる超低遅延オプティカルフロー](https://rtc-lab.com/development/ultra-low-delay-optical-flow/)
