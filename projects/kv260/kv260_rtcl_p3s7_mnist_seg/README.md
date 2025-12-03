# RTCL-P3S7-MIPI グローバルシャッター高速度カメラ の 1000fps で MNIST のセメンティックセグメンテーションを行う

## 概要

Kria KV260 でRTCL-P3S7-MIPI グローバルシャッター高速度カメラを 1000fps で動かして MNIST(手書き文字)のセマンティックセグメンテーションを行うサンプルです。

モノク版の RTCL-P3S7-MIPI カメラモジュールを前提としています。

アプリは Rust 版のみ提供しています。


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
cd projects/kv260/kv260_rtcl_p3s7_mnist_seg/syn/tcl
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

`projects/kv260/kv260_rtcl_p3s7_mnist_seg/app` ディレクトリに、先ほど PC の Vivado で作成した `kv260_rtcl_p3s7_mnist_seg.bit` をコピーしておいてください。


```bash
cd projects/kv260/kv260_rtcl_p3s7_mnist_seg/app
make run
```

と実行すれば Rust 版のサンプルがコンパイルされ実行されます。

X-Window の設定が正しくできていれば、ウィンドウが開き、カメラ画像が表示されるはずです。

Makefile の中で RUN_OPT 変数を設定することで、実行時の追加のオプションを渡せます。

```bash
make run_rust RUN_OPT="--pgood-off"
```

などとすると、PGOOD 信号を無効にして実行できます。



### PCで PSソフトをクロスコンパイルして実行

cross が使える環境で、下記のようにすれば仮想環境でビルドした後に、リモートで実行できます。

```bash
cd projects/kv260/kv260_rtcl_p3s7_mnist_seg/app/rust
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
make remote_run RUN_OPT="--pgood-off"
```


## 参考情報

- 作者ブログ記事
    - [LUT-NetworkによるFPGAでの手書き数字(MNIST)のセマンティックセグメンテーション再整理](https://blog.rtc-lab.com/entry/2021/07/10/101220)
    - [Zybo Z7 への Raspberry Pi Camera V2 接続(MIPI CSI-2受信)](https://rtc-lab.com/2018/04/29/zybo-rpi-cam-rx/)
    - [Zybo Z7 への Raspberry Pi Camera V2 接続 (1000fps動作)](https://rtc-lab.com/2018/05/06/zybo-rpi-cam-1000fps/)
    - [LUT-Networkの蒸留とMobileNet風構成とセマンティックセグメンテーション](https://rtc-lab.com/2020/03/09/lut-net-semantic-segmentation/)
