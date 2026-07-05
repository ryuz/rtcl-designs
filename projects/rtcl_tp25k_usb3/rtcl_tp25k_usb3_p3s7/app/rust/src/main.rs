use std::error::Error;
use rtcl_d3xx::*;
use std::io::Write;
use std::time::Duration;

use rtcl_lib::rtcl_p3s7_module_driver::*;

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
    let frm_acc = usb_accessor.subclone(0x0004_0000, 0x1000);

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

    const P3S7_DEVADR: u8 =     0x10;    // 7bit address
    let i2c = JellyI2c::<UsbAccessor>::new(i2c_acc, None);
    let i2c = JellyI2cDevice::<P3S7_DEVADR, UsbAccessor>::new(i2c);
    let mut cam = RtclP3s7ModuleDriver::new(i2c);

    let module_id = cam.module_id()?;
    println!("module_id : 0x{:04x}", module_id);
    let module_ver = cam.module_version()?;
    println!("module_ver : 0x{:04x}", module_ver);

    // キー入力待ち
    /*
    print!("Press Enter to start...");
    std::io::stdout().flush()?;
    let mut input = String::new();
    std::io::stdin().read_line(&mut input)?;
    */

    println!("camera set");
//  cam.set_dphy_speed(1250000000.0)?;
    cam.set_dphy_speed(950000000.0)?;
    cam.set_sensor_pgood_enable(false)?;
    cam.set_sensor_power_enable(false)?;
    cam.set_dphy_reset(true)?;
    std::thread::sleep(std::time::Duration::from_millis(10));

//  cam.set_camera_mode(CameraMode::HighSpeed)?;   // 高速モード設定
    cam.set_camera_mode(CameraMode::Csi2)?;   // CSI2 like なモード

    cam.set_pmod_mode(0xff00)?;

    // センサー電源ON
    cam.set_sensor_power_enable(true)?;
    std::thread::sleep(std::time::Duration::from_millis(10));

    // センサー基板 DPHY-TX リセット解除
    cam.set_dphy_reset(false)?;

    let width = 128;
    let height = 128;

    // xsm_delay
//  let xsm_delay = cam.calc_xsm_delay(width);
    cam.set_xsm_delay(255)?; // xsm_delay)?;
    cam.set_nzrot_xsm_delay_enable(true)?;
    cam.set_zero_rot_enable(true)?;

    // センサー起動
    cam.set_color(false)?;
    cam.set_sensor_enable(true)?;

    // ROI 設定
    cam.set_roi0(width as u16, height as u16, None, None)?;
    cam.set_gain_db(1.0)?;

    cam.set_mult_timer0(72)?;
    cam.set_fr_length0(33000)?;
    cam.set_exposure0(30000)?;

    cam.set_slave_mode(false)?;
    cam.set_triggered_mode(false)?;

    // 動作開始
    cam.set_sequencer_enable(true)?;

    // キー入力待ち
    print!("Press Enter to start...");
    std::io::stdout().flush()?;
    let mut input = String::new();
    std::io::stdin().read_line(&mut input)?;
    return Ok(());

    println!("Start");

    loop {
  
        // 1 frame 取り込み指示
        unsafe {
            frm_acc.write_reg_u32(0x10, 1);
        }

//          println!("frame size = {}", size);

        std::thread::sleep(Duration::from_millis(10));

        let mut lines = Vec::<Vec<u8>>::new();
        let size = ((4 + (width * 10 / 8)) * height) as usize;
        let mut frame = Vec::<u8>::with_capacity(size);
        for _ in 0..height {
            let packet_result = match usb.lock().unwrap().try_recv_axi4s() {
                Ok(packet) => Ok(packet),
                Err(_) => {
                    // 10us スリープ
                    std::thread::sleep(Duration::from_micros(10));
                    usb.lock().unwrap().try_recv_axi4s()
                }
            };

            let axi4s = match packet_result {
                Ok(packet) => packet,
                Err(_) => {
                    eprintln!("Failed to receive AXI4S packet, retrying...");
                    break;  // 内側のfor loopを抜ける
                }
            };

            lines.push(axi4s.tdata.clone());
            frame.extend_from_slice(axi4s.tdata.as_slice());
    //      println!("frame size = {}", frame.len());
        }

        // 受信に失敗したらリトライ
        if lines.len() != height {
            continue;
        }
        let h = lines.len();

        let mut image = vec![vec![0u16; width as usize]; h as usize];
        for y in 0..h {
            for x in 0..width/4 {
                image[y][x*4+0] = (((lines[y][x*5+0] as u16) << 2) | ((lines[y][x*5+4] as u16) >> 0) & 0x03) * 64;
                image[y][x*4+1] = (((lines[y][x*5+1] as u16) << 2) | ((lines[y][x*5+4] as u16) >> 2) & 0x03) * 64;
                image[y][x*4+2] = (((lines[y][x*5+2] as u16) << 2) | ((lines[y][x*5+4] as u16) >> 4) & 0x03) * 64;
                image[y][x*4+3] = (((lines[y][x*5+3] as u16) << 2) | ((lines[y][x*5+4] as u16) >> 6) & 0x03) * 64;
            }
        }

        // OpenCV で画像を表示
        let flat_image: Vec<u16> = image.iter().flatten().copied().collect();
        let mat = opencv::core::Mat::new_rows_cols_with_data(
            h as i32,
            width as i32,
            &flat_image,
        )?;
        
        // BYAER を BGR に変換
//      let mut mat_bgr = opencv::core::Mat::default();
//      opencv::imgproc::cvt_color(&mat, &mut mat_bgr, opencv::imgproc::COLOR_BayerBG2BGR, 0)?;

        opencv::highgui::imshow("image", &mat)?;
        let key = opencv::highgui::wait_key(100)?;
        if (key & 0xff) == 27 { // ESC
            break;
        }
    }
    

    println!("End Test");


    Ok(())
}






use std::sync::{Arc, Mutex};
use jelly_mem_access::*;
use jelly_mem_access::bus_accessor::LittleEndian;
use jelly_pac::i2c::*;
use jelly_pac::i2c_device::*;


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
