use std::io::{Read, Result, Write};

use d3xx::{list_devices, Device, Pipe};

struct Axi4LiteD3xx {
    device: Device,
}

impl Axi4LiteD3xx {
    fn new(device: Device) -> Self {
        Self { device }
    }

    fn write_axi4l(&self, addr: u32, data: u32, strb: u8) -> Result<u32> {
        let packet = [
            0x02,
            strb << 4,
            0x08,
            0x00,
            (addr & 0xff) as u8,
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 16) & 0xff) as u8,
            ((addr >> 24) & 0xff) as u8,
            (data & 0xff) as u8,
            ((data >> 8) & 0xff) as u8,
            ((data >> 16) & 0xff) as u8,
            ((data >> 24) & 0xff) as u8,
        ];

        self.device.pipe(Pipe::Out0).write_all(&packet)?;

        let mut resp = [0u8; 4];
        self.device.pipe(Pipe::In0).read_exact(&mut resp)?;
        Ok(u32::from_le_bytes(resp))
    }

    fn read_axi4l(&self, addr: u32) -> Result<[u8; 8]> {
        let packet = [
            0x03,
            0x00,
            0x04,
            0x00,
            (addr & 0xff) as u8,
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 16) & 0xff) as u8,
            ((addr >> 24) & 0xff) as u8,
        ];

        self.device.pipe(Pipe::Out0).write_all(&packet)?;

        let mut resp = [0u8; 8];
        self.device.pipe(Pipe::In0).read_exact(&mut resp)?;
        Ok(resp)
    }
}

fn main() {
    println!("FT601 AXI4-Lite access test");

    let all_devices = list_devices().expect("failed to list devices");
    assert!(!all_devices.is_empty(), "No FT601 device found");
    println!("Found {} devices", all_devices.len());

    let device = all_devices[0].open().expect("failed to open device");
    let axi = Axi4LiteD3xx::new(device);

    let read_data = axi.read_axi4l(0x00).expect("read_axi4l failed");
    println!("read_axi4l(0x0000_0000):");
    for b in read_data {
        println!("{b:02x}");
    }

    let wr_resp = axi
        .write_axi4l(0x04, 0x1234_5678, 0xF)
        .expect("write_axi4l failed");
    println!("write response: 0x{wr_resp:08x}");
}
