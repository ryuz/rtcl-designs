# RTCL-TP25K-USB3(Tang Primer 25k 用 USB3 ベースボード)関連プロジェクト

## はじめに

このディレクトリの下には RTCL-TP25K-USB3(Tang Primer 25k 用 USB3 ベースボード)関連のプロジェクトが含まれています。

ボード設計は[こちら](https://github.com/ryuz/rtcl-tp25k-usb3-pcb)にあります。


## 環境準備

### FPGA 開発環境

まず FPGA では GOWIN FPGA の開発環境が必要です。

[GOWIN](https://www.gowinsemi.com/)の公式サイトから ユーザー登録し、GOWIN EDA をダウンロードしてインストールするとともに ライセンスリクエスト を行い、ライセンスファイルを取得して動作するようにしておく必要があります。

gw_sh や programmer_cli をコマンドラインで利用したりもしておりますので、環境変数など適切に設定してください。

特に本プロジェクトでは WSL2 から Windows 版のツールを呼び出すことも考慮しています。
その場合 Linux 環境で開発しつつ、Windows 側のライセンスや USBデバイスを利用することが可能となります。

例えば当方では下記のような実行権限を付与したファイルを `~/.local/bin/` 以下においてパスを通しておき、GW_SH_WINDOWS という環境変数が設定されているときは WSL2 から Windows 版のツールを呼び出すようにしています。

```bash:~/.local/bin/gw_sh
#!/usr/bin/bash

if [[ -n "$GW_SH_WINDOWS" ]]; then
    # Windows版起動
    /mnt/c/Gowin/Gowin_V1.9.12.02_SP2_x64/IDE/bin/gw_sh.exe $@
else
    # Linux版起動
    GOWIN_DIR="$HOME/.opt/Gowin/Gowin_V1.9.12.02_SP2"

    export PATH="$GOWIN_DIR/IDE/bin:$PATH"
    export LD_LIBRARY_PATH="$GOWIN_DIR/IDE/lib:$LD_LIBRARY_PATH"
    $GOWIN_DIR/IDE/bin/gw_sh $@
fi
```

同様に programmer_cli についても下記のようなファイルを `~/.local/bin/` 以下においております。

```bash:~/.local/bin/programmer_cli
#!/usr/bin/bash

if [[ -n "$PROGRAMMER_CLI_WINDOWS" ]]; then
    cd /mnt/c/Gowin/Gowin_V1.9.11.01_x64/Programmer/bin/
    ./programmer_cli.exe $@
else
    GOWIN_DIR="$HOME/.opt/Gowin/Gowin_V1.9.12.02_SP2"
    export PATH="$GOWIN_DIR/IDE/bin:$PATH"
    export LD_LIBRARY_PATH="$GOWIN_DIR/IDE/lib:$LD_LIBRARY_PATH"
    $GOWIN_DIR/IDE/bin/programmer_cli $@
fi
```

上記あくまで例ですが、参考になれば幸いです。


### JATG ダウンロードケーブル

FPGA への書き込みに一度 コアモジュールのみ Tang Primer 25k 標準の Dock Base Board に取り付け直してROMに書き込む方法もありますが、JTAG ダウンロードケーブルがあると便利です。

当方では

- [秋月FT232HLボード+変換基板](https://github.com/ryuz/rtcl-ae-ft232hl-jtag-pcb) + programmer_cli
- [Digilent JTAG-HS2](https://digilent.com/reference/programmers/jtag-hs2) + openFPGAloadr

で確認しておりますが、特に [openFPGAloadr](https://github.com/trabucayre/openFPGALoader) であれば、多くの JTAG ダウンロードケーブルが利用可能なようです。

ただし GOWIN の GAO などが使いたい場合は、GOWIN純正の JTAGケーブルか、 FT232HL 系のチップののったケーブルが必要なようです。


### USB3 デバイスドライバ

FT601 の 利用にFTDI社の D3XX ドライバやライブラリが必要です。[FTDI社の公式サイト](https://ftdichip.com/drivers/d3xx-drivers/) から各環境に合わせたドライバをダウンロードしてインストールしておいてください。

特に Windows 版に含まれていた `FT600ChipConfigurationProg_WU.exe` は、チップの設定を簡単に行えるので重宝しています。


### Rust 環境

本プロジェクトでは PC 側のソフトにしばし Rust を利用します。

[Rust の公式サイト](https://rust-lang.org/) などから Rust をインストールしておいてください。

また、Windows においては Rust から D3XX を使うのに、いくつかの環境変数を必要としています。

[こちら](../../rust/d3xx/README.md) を参考にして設定してください。


### OpenCV 環境

本プロジェクトの PC 側のソフトの中には OpenCV を使うものがあります。

OpenCV のインストールと Rust から [opencvクレート](https://crates.io/crates/opencv) を使えるようにしておく必要がありますので、各環境に合わせてインストールしてください。

