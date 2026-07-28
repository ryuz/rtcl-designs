#![allow(unused)]

use std::error::Error;
use std::fs::File;
use std::io::{Read, Write};
use std::thread;
use std::time::{Duration, Instant};
use rtcl_d3xx::*;

const BASE_SYSCTL  : u32 = 0x0000_0000;
const BASE_LSFR_RX : u32 = 0x0002_0000;
const BASE_LSFR_TX : u32 = 0x0003_0000;

const REG_SYSCTL_CORE_ID  : u32 = BASE_SYSCTL + 4 * 0x00;
const REG_SYSCTL_CONTROL0 : u32 = BASE_SYSCTL + 4 * 0x10;    // width
const REG_SYSCTL_CONTROL1 : u32 = BASE_SYSCTL + 4 * 0x11;    // height
const REG_SYSCTL_CONTROL2 : u32 = BASE_SYSCTL + 4 * 0x12;
const REG_SYSCTL_CONTROL3 : u32 = BASE_SYSCTL + 4 * 0x13;    // max
const REG_SYSCTL_CONTROL4 : u32 = BASE_SYSCTL + 4 * 0x14;    // limit
const REGR_SYSCTL_CONTROL5: u32 = BASE_SYSCTL + 4 * 0x15;    // timeout

const REG_LFSR_RX_CORE_ID      : u32 = BASE_LSFR_RX + 4 * 0x00;
const REG_LFSR_RX_CORE_VERSION : u32 = BASE_LSFR_RX + 4 * 0x01;
const REG_LFSR_RX_CLEAR        : u32 = BASE_LSFR_RX + 4 * 0x10;
const REG_LFSR_RX_LFSR_VALUE   : u32 = BASE_LSFR_RX + 4 * 0x11;
const REG_LFSR_RX_RX_COUNT     : u32 = BASE_LSFR_RX + 4 * 0x12;
const REG_LFSR_RX_LFSR_ERROR   : u32 = BASE_LSFR_RX + 4 * 0x13;

const REG_LFSR_TX_CORE_ID      : u32 = BASE_LSFR_TX + 4 * 0x00;
const REG_LFSR_TX_CORE_VERSION : u32 = BASE_LSFR_TX + 4 * 0x01;
const REG_LFSR_TX_START        : u32 = BASE_LSFR_TX + 4 * 0x10;
const REG_LFSR_TX_LFSR_VALUE   : u32 = BASE_LSFR_TX + 4 * 0x11;
const REG_LFSR_TX_TX_LEN       : u32 = BASE_LSFR_TX + 4 * 0x12;


fn calc_lfsr(lfsr: u32) -> u32 {
    let bit = ((lfsr >> 0) ^ (lfsr >> 1) ^ (lfsr >> 21) ^ (lfsr >> 31)) & 1;
    (lfsr >> 1) | (bit << 31)
}


#[derive(Debug, Clone, Copy)]
struct LfsrCheckResult {
    error_count: usize,
    first_error: Option<(usize, u32, u32)>,
}


fn check_lfsr_words(words: &[u32], seed: u32) -> LfsrCheckResult {
    let mut expected = seed;
    let mut error_count: usize = 0;
    let mut first_error: Option<(usize, u32, u32)> = None;

    for (i, &actual) in words.iter().enumerate() {
        if actual != expected {
            error_count += 1;
            if first_error.is_none() {
                first_error = Some((i, expected, actual));
            }
            if error_count <= 8 {
                println!(
                    "LFSR mismatch[{}]: expected=0x{:08x}, actual=0x{:08x}",
                    i, expected, actual
                );
            }
        }
        expected = calc_lfsr(expected);
    }

    LfsrCheckResult {
        error_count,
        first_error,
    }
}


fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 test");

    // OpenDevice
//  let (axi4l, mut axi4s_rx, axi4s_tx) = D3xxFifo32Direct::new(0)?;
    let (axi4l, mut axi4s_rx, axi4s_tx) = D3xxFifo32::new(0)?;

    // direct read/write
    println!("SYSCTL_CORE_ID    : 0x{:08x}", axi4l.read_axi4l((REG_SYSCTL_CORE_ID   ) as u32)?);
    println!("LFSR_RX_CORE_ID   : 0x{:08x}", axi4l.read_axi4l((REG_LFSR_RX_CORE_ID  ) as u32)?);
    println!("LFSR_TX_CORE_ID   : 0x{:08x}", axi4l.read_axi4l((REG_LFSR_TX_CORE_ID  ) as u32)?);

    // Recwive Test
    let data_size : u32 = 1*1024*1024;
    let tx_seed: u32 = 0x12345678;
    axi4l.write_axi4l(REG_LFSR_TX_LFSR_VALUE,      tx_seed, 0xf)?;
    axi4l.write_axi4l(REG_LFSR_TX_TX_LEN    ,    data_size, 0xf)?;

    let rx_start = Instant::now();  // 時間計測開始
    axi4l.write_axi4l(REG_LFSR_TX_START     ,            1, 0xf)?;
    let rx_data = axi4s_rx.recv_axi4s_timeout(Duration::from_millis(10000))?;
//  let rx_data = axi4s_rx.recv_axi4s(data_size as usize)?;
    let rx_elapsed = rx_start.elapsed();

    // AXI4S payload bytes -> u32 words (little-endian)
    let words_count = rx_data.tdata.len() / 4;
    let rx_words: Vec<u32> = rx_data
        .tdata
        .chunks_exact(4)
        .map(|chunk| u32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]))
        .collect();

    let remain = rx_data.tdata.len() % 4;
    if remain != 0 {
        println!(
            "WARNING: received payload is not 4-byte aligned: {} bytes (remain={})",
            rx_data.tdata.len(),
            remain
        );
    }

    // Check LFSR sequence corruption
    let check = check_lfsr_words(&rx_words, tx_seed);

    println!(
        "RX done: bytes={}, words={}, elapsed={:.3}s",
        rx_data.tdata.len(),
        words_count,
        rx_elapsed.as_secs_f64()
    );

    let rx_seconds = rx_elapsed.as_secs_f64();
    if rx_seconds > 0.0 {
        let rx_byte_per_sec = rx_data.tdata.len() as f64 / rx_seconds;
        let rx_mbyte_per_sec = rx_byte_per_sec / 1_000_000.0;
        let rx_mbits_per_sec = (rx_byte_per_sec * 8.0) / 1_000_000.0;
        println!(
            "RX throughput: {:.3} MByte/s, {:.3} Mbits/s",
            rx_mbyte_per_sec, rx_mbits_per_sec
        );
    }

    if check.error_count == 0 {
        println!("LFSR check OK: no mismatch");
    } else if let Some((idx, exp, act)) = check.first_error {
        println!(
            "LFSR check NG: mismatches={}, first at [{}] expected=0x{:08x}, actual=0x{:08x}",
            check.error_count, idx, exp, act
        );
    } else {
        println!("LFSR check NG: mismatches={}", check.error_count);
    }

    std::thread::sleep(std::time::Duration::from_millis(5000));

    println!("End Test");

    Ok(())
}


/*
fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 test");

    // OpenDevice
    let (axi4l, mut axi4s_rx, axi4s_tx) = RtclFifo32AxiD3xx::new(0)?;

    // direct read/write
    println!("SYSCTL_CORE_ID    : 0x{:08x}", axi4l.read_axi4l((REG_SYSCTL_CORE_ID   ) as u32)?);
    println!("LFSR_RX_CORE_ID   : 0x{:08x}", axi4l.read_axi4l((REG_LFSR_RX_CORE_ID  ) as u32)?);
    println!("LFSR_TX_CORE_ID   : 0x{:08x}", axi4l.read_axi4l((REG_LFSR_TX_CORE_ID  ) as u32)?);

    for i in 0..1 {
        axi4l.write_axi4l(REG_LFSR_TX_TX_LEN as u32,    16*1024*1024, 0xf)?;
        axi4l.write_axi4l(REG_LFSR_TX_START  as u32,    1, 0xf)?;
        std::thread::sleep(std::time::Duration::from_millis(1000));
        let data = axi4s_rx.recv_data(4)?;
        println!("Received data: {:?}", data);
    }

    println!("End Test");

    Ok(())
}
*/