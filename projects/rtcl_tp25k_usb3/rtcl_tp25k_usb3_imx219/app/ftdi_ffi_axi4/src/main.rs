use std::error::Error;

use rtcl_d3xx::*;

fn main() -> Result<(), Box<dyn Error>> {
    println!("Start Test");

    let mut usb = RtclFifo32D3xx::new(0)?;

    // ID を読んでみる
    let data = usb.read_axi4l(0)?;
    println!("Read data: {:04x}", data);

    // scratch レジスタを書き換えてみる
    usb.write_axi4l(0x13*4, 0x01234567, 0xf)?;
    let data = usb.read_axi4l(0x13*4)?;
    println!("Read data: {:04x}", data);
    usb.write_axi4l(0x13*4, 0x89abcdef, 0xf)?;
    let data = usb.read_axi4l(0x13*4)?;
    println!("Read data: {:04x}", data);


    Ok(())
}

