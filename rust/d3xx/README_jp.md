# rtcl-d3xx-rs


## 次善順位

### Linux の場合

libftd3xx がインストール済みの前提です。 当方では `libftd3xx-linux-x86_64-1.1.6.tgz` を利用しております。

FTDI社のREADMEに従って

```bash
tar xvfz libftd3xx-linux-x86_64-1.1.6.tgz
cd libftd3xx-linux-x86_64-1.1.6

sudo rm /usr/lib/libftd3xx.so
sudo cp ftd3xx.h /usr/local/include
sudo cp Types.h /usr/local/include
sudo cp libftd3xx.so /usr/lib/
sudo cp libftd3xx.so.1.1.6 /usr/lib/
sudo cp 51-ftd3xx.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo ldconfig
```

のような流れになると思います。



### Windows の場合

当方では `Winusb_D3XX_Release_1.4.0.1.zip` を利用しております。


この crate は `build.rs` で Windows のリンク方法を切り替えるために `static-link` feature を使います。

- `static-link` を付けない場合は `FTD3XX_X64_DYNAMIC_LIB_DIR` を参照します。このディレクトリに `FTD3XXWU.lib` がある必要があります。
- `static-link` を付ける場合は `FTD3XX_X64_STATIC_LIB_DIR` を参照します。このディレクトリに `FTD3XXWU.lib` がある必要があります。

動的リンクの場合は、実行時に `FTD3XXWU.dll` も必要です。`PATH` に通っている場所、または Windows が探索できる場所に配置してください。

## ビルド例

PowerShell の例です。

```powershell
$env:FTD3XX_X64_DYNAMIC_LIB_DIR = "C:\path\to\ftdi\WU_FTD3XXLib\Lib\Dynamic\x64"
cargo build

$env:FTD3XX_X64_STATIC_LIB_DIR = "C:\path\to\ftdi\WU_FTD3XXLib\Lib\Static\x64"
cargo build --features static-link
```

## 補足

- `static-link` は Cargo の feature です。
- `build.rs` は Windows 以外では何も処理しません。
- 環境変数が未設定の場合、ビルドは失敗します。

