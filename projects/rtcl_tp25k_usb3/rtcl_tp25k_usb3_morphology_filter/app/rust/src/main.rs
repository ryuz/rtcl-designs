use std::error::Error;
use rtcl_d3xx::*;
use std::time::Duration;

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



// type UsbAccessor = SharedBusAccessor<RtclD3xxAxi4lBus, u32, u32, u8, LittleEndian>;

fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 test");

    let width:  usize = 128;
    let height: usize = 16;


    // OpenDevice
    let (axi4l, axi4s_rx, axi4s_tx) = RtclFifo32CtlD3xx::new(0)?;

    // direct read/write
    println!("SYSCTL_CORE_ID      : 0x{:08x}", axi4l.read_axi4l((BASE_SYSCTL + 4*REGADR_SYSCTL_CORE_ID  ) as u32)?);
    println!("MORPHO_CORE_ID      : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_CORE_ID     ) as u32)?);
    println!("MORPHO_CORE_VERSION : 0x{:08x}", axi4l.read_axi4l((BASE_MORPHO + 4*REG_MORPHO_CORE_VERSION) as u32)?);

    axi4l.write_axi4l((BASE_SYSCTL + 4*REGADR_SYSCTL_CONTROL0) as u32, (width / 32) as u32, 0xf)?;
    axi4l.write_axi4l((BASE_SYSCTL + 4*REGADR_SYSCTL_CONTROL1) as u32, (height    ) as u32, 0xf)?;

    axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_ENABLE  ) as u32, 0b1111, 0xf)?;
    axi4l.write_axi4l((BASE_MORPHO + 4*REG_MORPHO_PARAM_DILATION) as u32, 0b0110, 0xf)?;

    for y in 0..height {
        let tx_buf = vec![0u8; width / 8];
        let tx_stream = Axi4Stream {
            tuser: if y == 0 { 1 } else { 0 },
            tdata: tx_buf,
        };
        axi4s_tx.send_axi4s(&tx_stream)?;
    }

    for y in 0..height {
        let rx_stream = axi4s_rx.recv_axi4s_timeout(Duration::from_millis(1000))?;
        if rx_stream.tdata.len() != width / 8 {
            eprintln!("Received frame with unexpected payload size: {} bytes expected : {}", rx_stream.tdata.len(), width / 8);
            continue;
        }
        println!("Received frame line {}: tuser={} len={}", y, rx_stream.tuser, rx_stream.tdata.len());
    }

    println!("End Test");

    return Ok(());
}
