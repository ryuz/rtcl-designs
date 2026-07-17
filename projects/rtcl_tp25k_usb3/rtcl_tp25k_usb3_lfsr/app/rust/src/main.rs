#![allow(unused)]

use std::error::Error;
use std::fs::File;
use std::io::{Read, Write};
use std::thread;
use std::time::Instant;
use rtcl_d3xx::*;

const BASE_SYSCTL  : usize = 0x0000_0000;
const BASE_LSFR_RX : usize = 0x0002_0000;
const BASE_LSFR_TX : usize = 0x0003_0000;

const REG_SYSCTL_CORE_ID  : usize = BASE_SYSCTL + 4 * 0x00;
const REG_SYSCTL_CONTROL0 : usize = BASE_SYSCTL + 4 * 0x10;    // width
const REG_SYSCTL_CONTROL1 : usize = BASE_SYSCTL + 4 * 0x11;    // height
const REG_SYSCTL_CONTROL2 : usize = BASE_SYSCTL + 4 * 0x12;
const REG_SYSCTL_CONTROL3 : usize = BASE_SYSCTL + 4 * 0x13;    // max
const REG_SYSCTL_CONTROL4 : usize = BASE_SYSCTL + 4 * 0x14;    // limit
const REGR_SYSCTL_CONTROL5: usize = BASE_SYSCTL + 4 * 0x15;    // timeout

const REG_LFSR_RX_CORE_ID      : usize = BASE_LSFR_RX + 4 * 0x00;
const REG_LFSR_RX_CORE_VERSION : usize = BASE_LSFR_RX + 4 * 0x01;
const REG_LFSR_RX_CLEAR        : usize = BASE_LSFR_RX + 4 * 0x10;
const REG_LFSR_RX_LFSR_VALUE   : usize = BASE_LSFR_RX + 4 * 0x11;
const REG_LFSR_RX_RX_COUNT     : usize = BASE_LSFR_RX + 4 * 0x12;
const REG_LFSR_RX_LFSR_ERROR   : usize = BASE_LSFR_RX + 4 * 0x13;

const REG_LFSR_TX_CORE_ID      : usize = BASE_LSFR_TX + 4 * 0x00;
const REG_LFSR_TX_CORE_VERSION : usize = BASE_LSFR_TX + 4 * 0x01;
const REG_LFSR_TX_START        : usize = BASE_LSFR_TX + 4 * 0x10;
const REG_LFSR_TX_LFSR_VALUE   : usize = BASE_LSFR_TX + 4 * 0x11;
const REG_LFSR_TX_TX_LEN       : usize = BASE_LSFR_TX + 4 * 0x12;


fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 test");

    // OpenDevice
    let (axi4l, mut axi4s_rx, axi4s_tx) = RtclFifo32CtlD3xx::new(0)?;

    // direct read/write
    println!("SYSCTL_CORE_ID    : 0x{:08x}", axi4l.read_axi4l((REG_SYSCTL_CORE_ID   ) as u32)?);
    println!("LFSR_RX_CORE_ID   : 0x{:08x}", axi4l.read_axi4l((REG_LFSR_RX_CORE_ID  ) as u32)?);
    println!("LFSR_TX_CORE_ID   : 0x{:08x}", axi4l.read_axi4l((REG_LFSR_TX_CORE_ID  ) as u32)?);

    for i in 0..2 {
        axi4l.write_axi4l(REG_LFSR_TX_TX_LEN as u32, 1024-1, 0xf)?;
        axi4l.write_axi4l(REG_LFSR_TX_START  as u32,     1, 0xf)?;
        std::thread::sleep(std::time::Duration::from_millis(1000));
    }

    println!("End Test");

    Ok(())
}
