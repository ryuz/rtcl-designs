use std::error::Error;
use rtcl_d3xx::*;
use std::time::Duration;


const REGADR_SYSCTL_CONTROL0 : usize = 0x10;
const REGADR_SYSCTL_CONTROL1 : usize = 0x11;
//const REGADR_SYSCTL_CONTROL2 : usize = 0x12;
const REGADR_SYSCTL_CONTROL3 : usize = 0x13;

type UsbAccessor = SharedBusAccessor<RtclD3xxAxi4lBus, u32, u32, u8, LittleEndian>;

fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 test");

    // OpenDevice
    let mut usb = RtclFifo32CtlD3xx::new(0)?;

    // direct read/write
    println!("id : 0x{:08x}", usb.read_axi4l(0)?);

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

    Ok(())
}






use std::sync::{Arc, Mutex};
use jelly_mem_access::*;
use jelly_mem_access::bus_accessor::LittleEndian;
use jelly_pac::i2c::*;
use jelly_pac::i2c_device::*;
use jelly_lib::imx219_sensor_driver::Imx219SensorDriver;


struct RtclD3xxAxi4lBus {
    d3xx: Arc<Mutex<RtclFifo32CtlD3xx>>,
}

impl RtclD3xxAxi4lBus {
    fn new(d3xx: Arc<Mutex<RtclFifo32CtlD3xx>>) -> Self {
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
