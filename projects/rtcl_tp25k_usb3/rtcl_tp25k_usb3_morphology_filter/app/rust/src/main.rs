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
    let height: usize = 256*16;


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

    /*
    usb.write_axi4l(0x13*4, 0x01234567, 0xf)?;
    let data = usb.read_axi4l(0x13*4)?;
    println!("Read data: {:04x}", data);
    usb.write_axi4l(0x13*4, 0x89abcdef, 0xf)?;
    let data = usb.read_axi4l(0x13*4)?;
    println!("Read data: {:04x}", data);

    let usb = Arc::new(usb);
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

    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL3, 512);     // max
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL4, 1024*8);  // limit
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL5, 10000);   // 100us
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

    //  let width: i32 = 256;
//  let height: i32 = 256;
//    let frame_rate: i32 = 30;
//    let exposure: i32 = 33;
//    let a_gain: i32 = args.a_gain;
//    let d_gain: i32 = args.d_gain;
    let aoi_x: i32 = -1;
    let aoi_y: i32 = -1;
//    let flip_h: bool = false;
//    let flip_v: bool = false;
    imx219.set_pixel_clock(pixel_clock).unwrap();
    imx219.set_aoi(width as i32, height as i32, aoi_x, aoi_y, binning, binning).unwrap();
    imx219.set_frame_rate(30.0).unwrap();
    imx219.set_exposure_time(20.0).unwrap();

    imx219.set_gain(3.0).unwrap();
    imx219.set_digital_gain(1.0).unwrap();
    println!("set camera end");

    println!("start camera");
    imx219.start().unwrap();
    std::thread::sleep(Duration::from_millis(100)); 

    /*
    // 1 frame 取り込み指示
    loop {
        unsafe {
            frm_acc.write_reg_u32(0x10, 1);
        }

//      print!("\nwait key : start capture...");
        std::io::stdout().flush().unwrap();
        let mut input = String::new();
        std::io::stdin().read_line(&mut input).unwrap();   
//      println!("");
    }
    return Ok(());
    */

    // frame 取り込み開始
    unsafe {
        frm_acc.write_reg_u32(0x10, 1);
    }

    loop {

        std::thread::sleep(Duration::from_millis(10));

        let frame = match usb.recv_video_timeout(Duration::from_millis(1000)) {
            Ok(frame) => frame,
            Err(_) => {
                continue;
            }
        };

        if frame.width == 0 || frame.height == 0 {
            continue;
        }
        if frame.width % 5 != 0 {
            eprintln!("Received frame with unexpected line size: {} bytes", frame.width);
            continue;
        }

        let h = frame.height as usize;
        let line_bytes = frame.width;
        if frame.data.len() != line_bytes * h {
            eprintln!(
                "Received frame with unexpected payload size: {} bytes expected : {}",
                frame.data.len(),
                line_bytes * h
            );
            continue;
        }

        let image_width = (line_bytes / 5) * 4;
        let mut image = vec![vec![0u16; image_width]; h];
        for y in 0..h {
            let line = &frame.data[(y * line_bytes)..((y + 1) * line_bytes)];
            for x in 0..(image_width / 4) {
                image[y][x * 4 + 0] = (((line[x * 5 + 0] as u16) << 2) | ((line[x * 5 + 4] as u16) >> 0) & 0x03) * 64;
                image[y][x * 4 + 1] = (((line[x * 5 + 1] as u16) << 2) | ((line[x * 5 + 4] as u16) >> 2) & 0x03) * 64;
                image[y][x * 4 + 2] = (((line[x * 5 + 2] as u16) << 2) | ((line[x * 5 + 4] as u16) >> 4) & 0x03) * 64;
                image[y][x * 4 + 3] = (((line[x * 5 + 3] as u16) << 2) | ((line[x * 5 + 4] as u16) >> 6) & 0x03) * 64;
            }
        }

        // OpenCV で画像を表示
        let flat_image: Vec<u16> = image.iter().flatten().copied().collect();
        let mat = opencv::core::Mat::new_rows_cols_with_data(
            h as i32,
            image_width as i32,
            &flat_image,
        )?;

        // BAYER を BGR に変換
        let mut mat_bgr = opencv::core::Mat::default();
        opencv::imgproc::cvt_color(&mat, &mut mat_bgr, opencv::imgproc::COLOR_BayerBG2BGR, 0)?;

        opencv::highgui::imshow("image", &mat_bgr)?;
        let key = opencv::highgui::wait_key(10)?;
        if (key & 0xff) == 27 { // ESC
            break;
        }
    }

    // frame 取り込み停止
    unsafe {
        frm_acc.write_reg_u32(0x10, 0);
    }

    println!("start stop");
    imx219.stop().unwrap();
    std::thread::sleep(Duration::from_millis(100)); 

    // カメラOFF
    println!("camera power off");
    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL0, 0);
        std::thread::sleep(Duration::from_millis(100));
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL1, 0);
        std::thread::sleep(Duration::from_millis(100));
    }

    println!("End Test");

    Ok(())
    */
}



/*


use std::sync::Arc;
use jelly_mem_access::*;
use jelly_mem_access::bus_accessor::LittleEndian;
use jelly_pac::i2c::*;
use jelly_pac::i2c_device::*;
use jelly_lib::imx219_sensor_driver::Imx219SensorDriver;


struct RtclD3xxAxi4lBus {
    d3xx: Arc<RtclVideoCaptureD3xx>,
}

impl RtclD3xxAxi4lBus {
    fn new(d3xx: Arc<RtclVideoCaptureD3xx>) -> Self {
        Self { d3xx }
    }

    fn write_axi4l(&self, addr: u32, data: u32, strb: u8) -> Result<(), Box<dyn Error>> {
        self.d3xx.write_axi4l(addr, data, strb)
    }

    fn read_axi4l(&self, addr: u32) -> Result<u32, Box<dyn Error>> {
        self.d3xx.read_axi4l(addr)
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
*/