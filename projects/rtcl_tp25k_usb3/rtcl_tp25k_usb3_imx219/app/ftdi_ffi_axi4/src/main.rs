use std::error::Error;
use std::io::Write;
use std::thread;
use std::time::Duration;

use rtcl_d3xx::*;

const REGADR_SYSCTL_CONTROL0 : usize = 0x10;
const REGADR_SYSCTL_CONTROL1 : usize = 0x11;
const REGADR_SYSCTL_CONTROL2 : usize = 0x12;
const REGADR_SYSCTL_CONTROL3 : usize = 0x13;

type UsbAccessor = SharedBusAccessor<RtclD3xxAxi4lBus, u32, u32, u8, LittleEndian>;

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


    let usb = Arc::new(Mutex::new(usb));
    let axi4l_bus = RtclD3xxAxi4lBus::new(usb.clone());
    let usb_accessor = SharedBusAccessor::<RtclD3xxAxi4lBus, u32, u32, u8, LittleEndian>::new(axi4l_bus);
    let ctl_acc = usb_accessor.subclone(0x0000_0000, 0x1000);
    let i2c_acc = usb_accessor.subclone(0x0001_0000, 0x1000);

    unsafe {
        let id = ctl_acc
            .try_read_reg_u32(0)
            .expect("read_axi4l(scratch before) failed");
        println!("id : {id:04x}");

        let scratch = ctl_acc
            .try_read_reg_u32(REGADR_SYSCTL_CONTROL3)
            .expect("read_axi4l(scratch before) failed");
        println!("scratch : {scratch:04x}");

        ctl_acc
            .try_write_reg_u32(REGADR_SYSCTL_CONTROL3, 0x1234)
            .expect("read_axi4l(scratch before) failed");
        println!("scratch : {scratch:04x}");

        let scratch = ctl_acc
            .try_read_reg_u32(REGADR_SYSCTL_CONTROL3)
            .expect("read_axi4l(scratch before) failed");
        println!("scratch : {scratch:04x}");

    }

    // カメラOFF
    println!("camera power off");
    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL0, 0);
        std::thread::sleep(Duration::from_millis(100));
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL1, 0);
        std::thread::sleep(Duration::from_millis(100));
    }

    // カメラ電源ON
    println!("camera power on");
    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL0, 1);
        std::thread::sleep(Duration::from_millis(100));
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL1, 1);
        std::thread::sleep(Duration::from_millis(100));
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

    println!("Reset camera");
    imx219.reset().unwrap();
    std::thread::sleep(Duration::from_millis(100));

    println!("set camera");
    // camera 設定
    let pixel_clock: f64 = 91000000.0;
    let binning =  false;
    let width: i32 = 256;
    let height: i32 = 256;
//  let width: i32 = 256;
//  let height: i32 = 256;
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
    imx219.set_frame_rate(30.0).unwrap();
    imx219.set_exposure_time(33.0).unwrap();

    imx219.set_gain(3.0).unwrap();
    imx219.set_digital_gain(1.0).unwrap();
    println!("set camera end");

    print!("wait key : start camera...");
    std::io::stdout().flush().unwrap();
    let mut input = String::new();
    std::io::stdin().read_line(&mut input).unwrap();   

    imx219.start().unwrap();
    
    let mut img_list = Vec::<Vec<u8>>::new();
    if let Ok(mut d3xx_guard) = usb.lock() {
        for _ in 0..256+1 {
            let pkt = d3xx_guard.recv_axi4s().unwrap();
            img_list.push(pkt);
//          println!("Received AXI4S packet: {:?}", pkt);
        }
    }
    
    for (i, img) in img_list.iter().enumerate() {
        // ファイルに保存
        let filename = format!("rec/image_{:03}.bin", i);
        std::fs::write(&filename, img).expect("Failed to write image file");
    }


    print!("wait key : Quit");
    std::io::stdout().flush().unwrap();
    let mut input = String::new();
    std::io::stdin().read_line(&mut input).unwrap();   

    println!("End Test");

    Ok(())
}




use std::sync::{Arc, Condvar, Mutex};
use jelly_mem_access::*;
use jelly_mem_access::bus_accessor::LittleEndian;
use jelly_pac::i2c::*;
use jelly_pac::i2c_device::*;
use jelly_lib::imx219_sensor_driver::Imx219SensorDriver;


struct RtclD3xxAxi4lBus {
    d3xx: Arc<Mutex<RtclFifo32D3xx>>,
}

impl RtclD3xxAxi4lBus {
    fn new(d3xx: Arc<Mutex<RtclFifo32D3xx>>) -> Self {
        Self { d3xx }
    }

    fn write_axi4l(&self, addr: u32, data: u32, strb: u8) -> Result<(), Box<dyn Error>> {
        if let Ok(mut d3xx_guard) = self.d3xx.lock() {
            d3xx_guard.write_axi4l(addr, data, strb)?;
            Ok(())
        }
        else {
            Err(Box::new(std::io::Error::new(std::io::ErrorKind::Other, "Failed to lock RtclD3xx")))
        }
    }

    fn read_axi4l(&self, addr: u32) -> Result<u32, Box<dyn Error>> {
        if let Ok(mut d3xx_guard) = self.d3xx.lock() {
            d3xx_guard.read_axi4l(addr)
        } else {
            Err(Box::new(std::io::Error::new(std::io::ErrorKind::Other, "Failed to lock RtclD3xx")))
        }
    }
}

impl Bus<u32, u32, u8> for RtclD3xxAxi4lBus {
    type Error = Box<dyn Error>;

    fn write(&mut self, addr: u32, data: u32, strb: u8) -> Result<(), Box<dyn Error>> {
        self.write_axi4l(addr, data, strb)?;
        Ok(())
    }

    fn read(&mut self, addr: u32) -> Result<u32, Box<dyn Error>> {
        let v = self.read_axi4l(addr)?;
        Ok(v)
    }
}

