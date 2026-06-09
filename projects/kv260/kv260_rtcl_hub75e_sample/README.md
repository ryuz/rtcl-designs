# KV260 で HUB-75E LED マトリクスを制御するサンプルプロジェクト

## 概要

[こちら](https://rtc-lab.com/products/rtcl-pmod-hub75e/)のボード(RTCL-PMOD-HUB75E)を使って、KV260 で HUB-75E LED マトリクスを制御するサンプルプロジェクトです。

ボードの回路図などの設計は[こちら](https://github.com/ryuz/rtcl-pmod-hub75e-pcb) にあります。

このプロジェクトでは、PL 側で HUB-75E ドライバを実装し、PS 側(Rust)から UIO 経由で VRAM と制御レジスタを操作して表示します。


## このプロジェクトのポイント

### RTCL-PMOD-HUB75E での「信号数2倍化」

HUB-75E は本来、`A/B/C/D/E`, `OE`, `LAT`, `CKE`, `R1/G1/B1`, `R2/G2/B2` に加えてクロックが必要で、PMOD 8本ではそのままは配線できません。

この制約を解くために、`rtl/rtcl_hub75e_pmod.sv` では ODDR(`ODDRE1`)を使って 1 本の物理線に 2 種類の論理信号を時分割で重ねています。

- `pmod[0]`〜`pmod[6]` は、立ち上がり側(`D1`)に `pmod_p[]`、立ち下がり側(`D2`)に `pmod_n[]` を出力
- RTCL-PMOD-HUB75E 側には、立ち上がりでラッチする FF と立ち下がりでラッチする FF の両方があり、それぞれを復元

結果として、7 本で 14 信号分を運べます。

対応は以下の通りです。

| PMOD | 立ち上がり側 (`pmod_p`) | 立ち下がり側 (`pmod_n`) |
|---|---|---|
| `pmod[0]` | `hub75e_oe`  | `hub75e_e`  |
| `pmod[1]` | `hub75e_lat` | `hub75e_r1` |
| `pmod[2]` | `hub75e_cke` | `hub75e_g1` |
| `pmod[3]` | `hub75e_a`   | `hub75e_b1` |
| `pmod[4]` | `hub75e_b`   | `hub75e_r2` |
| `pmod[5]` | `hub75e_c`   | `hub75e_g2` |
| `pmod[6]` | `hub75e_d`   | `hub75e_b2` |


### なぜ 90 度遅れクロック (`clk_90`) が必要か

`pmod[7]` は ODDR で `D1=1`, `D2=0` を出し、疑似的な転送クロックとして使っています。ここでデータ線と同じ位相のクロックをそのまま出すと、

- データ遷移タイミング
- ボード側 FF のサンプリングタイミング

が近づきすぎてセットアップ/ホールド余裕を失いやすくなります。

そのため本設計では、

- データ多重化 ODDR: `clk` (`sys_clk50`)
- クロック ODDR: `clk_90` (`sys_clk50_90`)

を使い分け、受信側 FF のサンプリング点をデータ遷移からずらしてタイミングマージンを確保しています。

`rtl/kv260_rtcl_hub75e_sample.sv` では `design_1` から `sys_clk50` と `sys_clk50_90` を受け、`rtcl_hub75e_pmod` にそれぞれ `clk`, `clk_90` として接続しています。


### データパス概要

- `hub75_driver.sv` / `hub75_driver_core.sv`: HUB-75E の走査、PWM階調、行選択、ラッチ/OE 制御を生成
- AXI4-Lite: 表示制御レジスタ(ON/OFF、反転、輝度パラメータ)を PS から設定
- AXI4 + BRAM アクセサ: PS が書いたフレームデータを VRAM に保持
- `rtcl_hub75e_pmod.sv`: 上記制御信号を PMOD 8本に時分割多重して出力


## 動かし方

### 1. リポジトリ取得

```bash
git clone https://github.com/ryuz/rtcl-designs.git --recurse-submodules
```


### 2. PC側の Vivado で bit ファイル生成

Vivado を利用できる状態にしてから:

```bash
source /tools/Xilinx/Vivado/2024.2/settings64.sh
```

```bash
cd projects/kv260/kv260_rtcl_hub75e_sample/syn/tcl
make
make bit_cp
```

`make bit_cp` で `app` ディレクトリに bit がコピーされます。


### 3. KV260 で実行(セルフコンパイル)

KV260 側でもリポジトリを clone し、以下を実行します。

```bash
cd projects/kv260/kv260_rtcl_hub75e_sample/app
make run_rust
```

このターゲットは、

1. DFX ロード(`xmutil`)
2. Rust アプリ起動

を順に実行します。


### 4. PC でクロスコンパイルしてリモート実行

```bash
cd projects/kv260/kv260_rtcl_hub75e_sample/app/rust
make remote_run
```

必要に応じて以下を設定してください。

```bash
KV260_SERVER_ADDRESS="192.168.16.1:8051"
KV260_SSH_ADDRESS="kria-kv260"
```


## 実行オプション(Rustアプリ)

`app/rust/src/main.rs` では以下のオプションを受け付けます。

- `-f, --file <path>`: 画像ファイルを読み込み 64x64 にリサイズして表示
- `-v`: 上下反転
- `-h`: 左右反転
- `--off`: 表示を OFF

例:

```bash
cd projects/kv260/kv260_rtcl_hub75e_sample/app/rust
make run RUN_OPT="-f Mandrill.bmp"
make run RUN_OPT="-f Mandrill.bmp -h -v"
make run RUN_OPT="--off"
```


## シミュレーション

```bash
cd projects/kv260/kv260_rtcl_hub75e_sample/sim/tb_top/verilator
make
```

または

```bash
cd projects/kv260/kv260_rtcl_hub75e_sample/sim/tb_top/xsim
make
```


## 参考情報

- [RTCL-PMOD-HUB75E プロダクトページ](https://rtc-lab.com/products/rtcl-pmod-hub75e/)
- [RTCL-PMOD-HUB75E PCB 設計リポジトリ](https://github.com/ryuz/rtcl-pmod-hub75e-pcb)





