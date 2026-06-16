use std::io::{Read, Result, Write};
use std::thread;
use std::time::Duration;

use d3xx::{list_devices, Device, Pipe};

struct Axi4LiteD3xx {
    device: Device,
}

impl Axi4LiteD3xx {
    fn new(device: Device) -> Self {
        Self { device }
    }

    /*
    fn init(&self) -> Result<()> {
        let packet = [0; 4];
        for _ in 0..128 {
            self.device.pipe(Pipe::Out0).write_all(&packet)?;
        }
        Ok(())
    }*/

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
        thread::sleep(Duration::from_millis(20));

        let mut resp = [0u8; 4];
        self.device.pipe(Pipe::In0).read_exact(&mut resp)?;
        Ok(u32::from_le_bytes(resp))
    }

    fn read_axi4l(&self, addr: u32) -> Result<u32> {
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
        Ok(u32::from_le_bytes([resp[4], resp[5], resp[6], resp[7]]))
    }
}

fn main() {
    println!("FT601 AXI4-Lite access test");

    let all_devices = list_devices().expect("failed to list devices");
    assert!(!all_devices.is_empty(), "No FT601 device found");
    println!("Found {} devices", all_devices.len());

    let device = all_devices[0].open().expect("failed to open device");
    let axi = Axi4LiteD3xx::new(device);

    let id = axi.read_axi4l(0x00 * 4).expect("read_axi4l(id) failed");
    println!("id : {id:04x}");

    let scratch = axi
        .read_axi4l(0x13 * 4)
        .expect("read_axi4l(scratch before) failed");
    println!("scratch : {scratch:04x}");

    axi.write_axi4l(0x13 * 4, 0xabcd55aa, 0xF)
        .expect("write_axi4l(scratch) failed");

    let scratch = axi
        .read_axi4l(0x13 * 4)
        .expect("read_axi4l(scratch after) failed");
    println!("scratch : {scratch:04x}");

    axi.write_axi4l(0x13 * 4, 0x87654321, 0xe)
        .expect("write_axi4l(scratch) failed");

    let scratch = axi
        .read_axi4l(0x13 * 4)
        .expect("read_axi4l(scratch after) failed");
    println!("scratch : {scratch:04x}");
}

