use std::error::Error;
use std::fs::File;
use std::io::{Read, Write};
use std::thread;
use std::time::Instant;
use rtcl_d3xx::*;

const BASE_SYSCTL : usize = 0x0000_0000;
const BASE_MORPHO : usize = 0x1000_0000;


const REGADR_SYSCTL_CORE_ID  : usize = 0x0;
const REGADR_SYSCTL_CONTROL0 : usize = 0x10;    // width
const REGADR_SYSCTL_CONTROL1 : usize = 0x11;    // height
//const REGADR_SYSCTL_CONTROL2 : usize = 0x12;
//const REGADR_SYSCTL_CONTROL3 : usize = 0x13;    // max
//const REGADR_SYSCTL_CONTROL4 : usize = 0x14;    // limit
//const REGADR_SYSCTL_CONTROL5 : usize = 0x15;    // timeout

const REG_MORPHO_CORE_ID        : usize = 0x00;
const REG_MORPHO_CORE_VERSION   : usize = 0x01;
const REG_MORPHO_CTL_CONTROL    : usize = 0x04;
//const REG_MORPHO_CTL_STATUS     : usize = 0x05;
//const REG_MORPHO_CTL_INDEX      : usize = 0x07;
const REG_MORPHO_PARAM_ENABLE   : usize = 0x08;
const REG_MORPHO_PARAM_DILATION : usize = 0x09;
//const REG_MORPHO_PARAM_FILTER   : usize = 0x10;



fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 test");

//  let width:  usize = 4096;
//  let height: usize = 4096;
    let width:  usize = 2048;
    let height: usize = 2048;
//  let width:  usize = 1024;
//  let height: usize = 1024;
//  let width:  usize = 512;
//  let height: usize = 512;
//  let width:  usize = 256;
//  let height: usize = 256;
//  let width:  usize = 128;
//  let height: usize = 128;

    // OpenDevice
    let (axi4l, mut axi4s_rx, axi4s_tx) = RtclFifo32AxiD3xx::new(0)?;

    // direct read/write
    println!("SYSCTL_CORE_ID        : 0x{:08x}", axi4l.read_axi4l((BASE_SYSCTL + 4*REGADR_SYSCTL_CORE_ID    ) as u32)?);
    println!("MORPHO_CORE_ID        : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_CORE_ID       ) as u32)?);
    println!("MORPHO_CORE_VERSION   : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_CORE_VERSION  ) as u32)?);
    println!("MORPHO_PARAM_ENABLE   : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_ENABLE  ) as u32)?);
    println!("MORPHO_PARAM_DILATION : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_DILATION) as u32)?);

    axi4l.write_axi4l((BASE_SYSCTL + 4*REGADR_SYSCTL_CONTROL0) as u32, (width / 32) as u32, 0xf)?;
    axi4l.write_axi4l((BASE_SYSCTL + 4*REGADR_SYSCTL_CONTROL1) as u32, (height    ) as u32, 0xf)?;

    axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_ENABLE  ) as u32, 0b1111, 0xf)?;
    axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_DILATION) as u32, 0b0110, 0xf)?;
//  axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_ENABLE  ) as u32, 0b0000, 0xf)?;
//  axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_DILATION) as u32, 0b0000, 0xf)?;
    axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_CTL_CONTROL   ) as u32,      3, 0xf)?;

    println!("MORPHO_PARAM_ENABLE   : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_ENABLE  ) as u32)?);
    println!("MORPHO_PARAM_DILATION : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_DILATION) as u32)?);

    // ファイルを先に読み込む（スレッド外で1度だけ実行）
    println!("Loading input image...");
    let line_bytes = width / 8;
    let mut tx_data = vec![0u8; line_bytes * height];
    {
//      let mut file = File::open("input_4096x4096.bin").map_err(|e| e.to_string())?;
        let mut file = File::open("input_2048x2048.bin").map_err(|e| e.to_string())?;
//      let mut file = File::open("input_1024x1024.bin").map_err(|e| e.to_string())?;
//      let mut file = File::open("input_512x512.bin").map_err(|e| e.to_string())?;
//      let mut file = File::open("input_256x256.bin").map_err(|e| e.to_string())?;
//      let mut file = File::open("input_128x128.bin").map_err(|e| e.to_string())?;
        file.read_exact(&mut tx_data).map_err(|e| e.to_string())?;
    }
    println!("Input image loaded: {} bytes", tx_data.len());

    // 時間計測開始
    println!("Start");
    let start_time = Instant::now();

    let tx_handle = thread::spawn(move || -> Result<(), String> {
        axi4s_tx
//          .send_image(line_bytes, height, &tx_data)
            .send_frame(line_bytes, height, &tx_data)
            .map_err(|e| e.to_string())?;
        Ok(())
    });

//  std::thread::sleep(std::time::Duration::from_millis(10));
    let rx_handle = thread::spawn(move || -> Result<Vec<u8>, String> {
        axi4s_rx.set_timeout(5000).map_err(|e| e.to_string())?;
        axi4s_rx
//          .recv_image(line_bytes, height)
            .recv_frame(line_bytes, height)
            .map_err(|e| e.to_string())
    });

    tx_handle
        .join()
        .map_err(|_| "TX thread panicked".to_string())
        .and_then(|r| r)?;
    let result_data = rx_handle
        .join()
        .map_err(|_| "RX thread panicked".to_string())
        .and_then(|r| r)?;

    // 時間計測終了
    let elapsed = start_time.elapsed();
    println!("Processing time: {} microseconds", elapsed.as_micros());


    // 結果をファイルに書き込む（スレッド終了後に1度だけ実行）
    println!("Writing output image...");
    {
        let mut file = File::create("result.bin").map_err(|e| e.to_string())?;
        file.write_all(&result_data).map_err(|e| e.to_string())?;
    }
    println!("Output image written: {} bytes", result_data.len());

    println!("End Test");

    Ok(())
}
