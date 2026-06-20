use std::io::{Read, Result, Write};
use std::thread;
use std::time::Duration;

use jelly_mem_access::*;
use jelly_mem_access::bus_accessor::LittleEndian;
use jelly_pac::i2c::*;
use jelly_pac::i2c_device::*;
use jelly_lib::imx219_sensor_driver::Imx219SensorDriver;

use d3xx::{list_devices, Device, Pipe};

struct Axi4LiteD3xx {
    device: Device,
}

impl Axi4LiteD3xx {
    fn new(device: Device) -> Self {
        Self { device }
    }

    fn init(&self) -> Result<()> {
        let packet = [0; 4];
        for _ in 0..128 {
            self.device.pipe(Pipe::Out0).write_all(&packet)?;
        }
        Ok(())
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

    fn read_data(&self, addr: u32) -> Result<Vec<u8>> {
        let mut resp = [0u8; 64];
        self.device.pipe(Pipe::In0).read_exact(&mut resp)?;
        Ok(resp.to_vec())
    }
}

impl Bus<u32, u32, u8> for Axi4LiteD3xx {
    type Error = std::io::Error;

    fn write(&mut self, addr: u32, data: u32, strb: u8) -> Result<()> {
//      println!("write: addr=0x{:08x}, data=0x{:08x}, strb=0x{:02x}", addr, data, strb);
        self.write_axi4l(addr, data, strb)?;
        Ok(())
    }

    fn read(&mut self, addr: u32) -> Result<u32> {
        let v = self.read_axi4l(addr)?;
//      println!("read: addr=0x{:08x}, data=0x{:08x}", addr, v);
        Ok(v)
    }
}

type UsbAccessor = SharedBusAccessor<Axi4LiteD3xx, u32, u32, u8, LittleEndian>;

const REGADR_SYSCTL_CONTROL0 : usize = 0x10;
const REGADR_SYSCTL_CONTROL1 : usize = 0x11;
const REGADR_SYSCTL_CONTROL2 : usize = 0x12;
const REGADR_SYSCTL_CONTROL3 : usize = 0x13;


fn main() {
    println!("FT601 AXI4-Lite access test");

    let all_devices = list_devices().expect("failed to list devices");
    assert!(!all_devices.is_empty(), "No FT601 device found");
    println!("Found {} devices", all_devices.len());

    let device = all_devices[0].open().expect("failed to open device");
    let axi = Axi4LiteD3xx::new(device);

//    axi.init().expect("failed to init device");

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


//  let accessor: SharedBusAccessor<Axi4LiteD3xx, u32, u32, u8, LittleEndian> = SharedBusAccessor::new(axi);
    let accessor = UsbAccessor::new(axi);
    unsafe {
        accessor.try_write_reg_u32(0x13, 0xdeadbeef).expect("try_write_mem_u32 failed");
        let val = accessor.try_read_reg_u32(0x13).expect("try_read_reg_u32 failed");
        println!("scratch : {val:04x}");
        accessor.try_write_reg_u32(0x13, 0x11223344).expect("try_write_mem_u32 failed");
        let val = accessor.try_read_reg_u32(0x13).expect("try_read_reg_u32 failed");
        println!("scratch : {val:04x}");
    }

    let ctl_acc = accessor.subclone(0x0000_0000, 0x1000);
    let i2c_acc = accessor.subclone(0x0001_0000, 0x1000);

    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL0, 1);
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL1, 1);
    }

    const IMX219_DEVADR: u8 =     0x10;    // 7bit address
    let i2c = JellyI2c::<UsbAccessor>::new(i2c_acc, None);
    let mut model_id: [u8; 2] = [0u8; 2];
    i2c.write(IMX219_DEVADR, &[0x00, 0x00]);
    i2c.read(IMX219_DEVADR, &mut model_id);
    println!("model_id: 0x{:02x}{:02x}", model_id[0], model_id[1]);
    let i2c = JellyI2cDevice::<IMX219_DEVADR, UsbAccessor>::new(i2c);

    let mut imx219 = Imx219SensorDriver::new(i2c);
    println!("sensor model ID:{:04x}", imx219.get_model_id().unwrap());

    // camera 設定
    let pixel_clock: f64 = 91000000.0;
    let binning =  true;
    let width: i32 = 1280;
    let height: i32 = 720;
//    let frame_rate: i32 = 30;
//    let exposure: i32 = 33;
//    let a_gain: i32 = args.a_gain;
//    let d_gain: i32 = args.d_gain;
    let aoi_x: i32 = -1;
    let aoi_y: i32 = -1;
    let flip_h: bool = false;
    let flip_v: bool = false;
    imx219.set_pixel_clock(pixel_clock).unwrap();
    imx219.set_aoi(width, height, aoi_x, aoi_y, binning, binning).unwrap();
    imx219.start().unwrap();



    // キー入力待ち
    print!("進むには Enter キーを押してください...");
    std::io::stdout().flush().unwrap();
    let mut input = String::new();
    std::io::stdin().read_line(&mut input).unwrap();

}

