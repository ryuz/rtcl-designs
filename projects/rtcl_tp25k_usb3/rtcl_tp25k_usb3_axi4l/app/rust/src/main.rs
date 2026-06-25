use std::error::Error;
//use std::time::Instant;
use rtcl_d3xx::*;

fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 loopback test");

    // Open the first device found.
    let mut usb = RtclFifo32CtlD3xx::new(0)?;

    println!("id : 0x{:08x}", usb.read_axi4l(0)?);

    Ok(())
}
