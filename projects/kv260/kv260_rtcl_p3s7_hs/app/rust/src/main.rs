#![allow(unused)]

use std::error::Error;
use std::io::Write;
//use std::thread;
//use std::time::Duration;

use jelly_lib::{i2c_access::I2cAccess, linux_i2c::LinuxI2c};
use jelly_mem_access::*;
use jelly_pac::video_dma_control::VideoDmaControl;

use opencv::{core::*, highgui::*};

const CAMREG_CORE_ID: u16 = 0x0000;
const CAMREG_CORE_VERSION: u16 = 0x0001;
const CAMREG_RECV_RESET: u16 = 0x0010;
const CAMREG_ALIGN_RESET: u16 = 0x0020;
const CAMREG_ALIGN_PATTERN: u16 = 0x0022;
const CAMREG_ALIGN_STATUS: u16 = 0x0028;
const CAMREG_DPHY_CORE_RESET: u16 = 0x0080;
const CAMREG_DPHY_SYS_RESET: u16 = 0x0081;
const CAMREG_DPHY_INIT_DONE: u16 = 0x0088;

const SYSREG_ID: usize = 0x0000;
const SYSREG_DPHY_SW_RESET: usize = 0x0001;
const SYSREG_CAM_ENABLE: usize = 0x0002;
const SYSREG_CSI_DATA_TYPE: usize = 0x0003;
const SYSREG_DPHY_INIT_DONE: usize = 0x0004;
const SYSREG_FPS_COUNT: usize = 0x0006;
const SYSREG_FRAME_COUNT: usize = 0x0007;
const SYSREG_IMAGE_WIDTH: usize = 0x0008;
const SYSREG_IMAGE_HEIGHT: usize = 0x0009;
const SYSREG_BLACK_WIDTH: usize = 0x000a;
const SYSREG_BLACK_HEIGHT: usize = 0x000b;

const TIMGENREG_CORE_ID: usize = 0x0000;
const TIMGENREG_CORE_VERSION: usize = 0x0001;
const TIMGENREG_CTL_CONTROL: usize = 0x0004;
const TIMGENREG_CTL_STATUS: usize = 0x0005;
const TIMGENREG_CTL_TIMER: usize = 0x0008;
const TIMGENREG_PARAM_PERIOD: usize = 0x0010;
const TIMGENREG_PARAM_TRIG0_START: usize = 0x0020;
const TIMGENREG_PARAM_TRIG0_END: usize = 0x0021;
const TIMGENREG_PARAM_TRIG0_POL: usize = 0x0022;

// Video format regularizer
const REG_VIDEO_FMTREG_CORE_ID: usize = 0x00;
const REG_VIDEO_FMTREG_CORE_VERSION: usize = 0x01;
const REG_VIDEO_FMTREG_CTL_CONTROL: usize = 0x04;
const REG_VIDEO_FMTREG_CTL_STATUS: usize = 0x05;
const REG_VIDEO_FMTREG_CTL_INDEX: usize = 0x07;
const REG_VIDEO_FMTREG_CTL_SKIP: usize = 0x08;
const REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN: usize = 0x0a;
const REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT: usize = 0x0b;
const REG_VIDEO_FMTREG_PARAM_WIDTH: usize = 0x10;
const REG_VIDEO_FMTREG_PARAM_HEIGHT: usize = 0x11;
const REG_VIDEO_FMTREG_PARAM_FILL: usize = 0x12;
const REG_VIDEO_FMTREG_PARAM_TIMEOUT: usize = 0x13;

//const BIT_STREAM: &'static [u8] = include_bytes!("../kv260_rtcl_p3s7_hs.bit");

//use kv260_rtcl_p3s7_hs::rtcl_p3s7_i2c::RtclP3s7I2c;
use kv260_rtcl_p3s7_hs::rtcl_p3s7_i2c::*;

fn usleep(us: u64) {
    std::thread::sleep(std::time::Duration::from_micros(us));
}

fn wait_1us() {
    std::thread::sleep(std::time::Duration::from_micros(1));
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("start kv260_rtcl_p3s7_hs");

    /*
    jelly_fpgautil::set_allow_sudo(true);
    let slot = jelly_fpgautil::load("k26-starter-kits")?;
    println!("load");
    jelly_fpgautil::unload(slot)?;
    println!("unload");

    jelly_fpgautil::unload(slot)?;
    */

    /*
    // TODO: OpenCV test code - currently disabled for cross-compilation
    let img : Mat = Mat::zeros(480, 640, opencv::core::CV_8UC3)?.to_mat()?;
    println!("img = {:?}", img);
    imshow("test", &img)?;
    wait_key(0)?;
    return Ok(());
    */

    let width  = 256 ;
    let height = 256 ;

    // mmap udmabuf
    let udmabuf_device_name = "udmabuf-jelly-vram0";
    println!("\nudmabuf open");
    let udmabuf_acc =
        UdmabufAccessor::<usize>::new(udmabuf_device_name, false).expect("Failed to open udmabuf");
    println!(
        "{} phys addr : 0x{:x}",
        udmabuf_device_name,
        udmabuf_acc.phys_addr()
    );
    println!(
        "{} size      : 0x{:x}",
        udmabuf_device_name,
        udmabuf_acc.size()
    );

    // UIO
    println!("\nuio open");
    let uio_acc = UioAccessor::<usize>::new_with_name("uio_pl_peri").expect("Failed to open uio");
    println!("uio_pl_peri phys addr : 0x{:x}", uio_acc.phys_addr());
    println!("uio_pl_peri size      : 0x{:x}", uio_acc.size());

    let reg_sys = uio_acc.subclone(0x00000000, 0x400);
    let reg_timgen = uio_acc.subclone(0x00010000, 0x400);
    let reg_fmtr = uio_acc.subclone(0x00100000, 0x400);
    let reg_wdma_img = uio_acc.subclone(0x00210000, 0x400);
    let reg_wdma_blk = uio_acc.subclone(0x00220000, 0x400);

    println!("CORE ID");
    println!("reg_sys      : {:08x}", unsafe { reg_sys.read_reg(0) });
    println!("reg_timgen   : {:08x}", unsafe { reg_timgen.read_reg(0) });
    println!("reg_fmtr     : {:08x}", unsafe { reg_fmtr.read_reg(0) });
    println!("reg_wdma_img : {:08x}", unsafe { reg_wdma_img.read_reg(0) });

    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10).unwrap();
    let mut cam = RtclP3s7I2c::new(i2c, usleep);

    //  let mut cam = RtclP3s7I2c::new_with_linux("/dev/i2c-6")?;

    println!("Camera Module ID       : {:08x}", cam.module_id()?);
    println!(
        "Camera Module Version  : {:08x}",
        cam.read_s7_reg(CAMREG_CORE_VERSION)?
    );

    // カメラモジュールリセット
    unsafe {
        reg_sys.write_reg(SYSREG_CAM_ENABLE, 0);
    } // センサー電源OFF
    std::thread::sleep(std::time::Duration::from_millis(10));
    unsafe {
        reg_sys.write_reg(SYSREG_CAM_ENABLE, 1);
    } // センサー電源OFF
    std::thread::sleep(std::time::Duration::from_millis(10));

    // MMCM 設定
    cam.set_dphy_speed(1250000000.0)?; // 1250Mbps

    // 受信側 DPHY リセット
    unsafe {
        reg_sys.write_reg(SYSREG_DPHY_SW_RESET, 1);
    }

    // カメラ基板初期化
    println!("Init Camera");
    cam.set_sensor_power_enable(false)?;
    cam.set_dphy_reset(true);
    std::thread::sleep(std::time::Duration::from_millis(10));

    // 受信側 DPHY 解除 (必ずこちらを先に解除)
    unsafe {
        reg_sys.write_reg(SYSREG_DPHY_SW_RESET, 0);
    }
    // 高速モード設定
    cam.set_camera_mode(CameraMode::HighSpeed);


    // センサー電源ON
    println!("Sensor Power On");
    cam.set_sensor_power_enable(true);
    println!("Sensor ID : {}", cam.sensor_id()?);
    
    // センサー基板 DPHY-TX リセット解除
    cam.set_dphy_reset(false);
    if !cam.dphy_init_done()? {
        println!("!!ERROR!! CAM DPHY TX init_done = 0");
        return Err("CAM DPHY TX init_done = 0".into());
    }

    // ここで RX 側も init_done が来る
    let dphy_rx_init_done = unsafe{reg_sys.read_reg(SYSREG_DPHY_INIT_DONE)};
    if dphy_rx_init_done == 0 {
        println!("!!ERROR!! KV260 DPHY RX init_done = 0");
        return Err("KV260 DPHY RX init_done = 0".into());
    }

    // 受信画像サイズ設定
    unsafe {
        reg_sys.write_reg(SYSREG_IMAGE_WIDTH,  width);
        reg_sys.write_reg(SYSREG_IMAGE_HEIGHT, height);
        reg_sys.write_reg(SYSREG_BLACK_WIDTH,  1280);
        reg_sys.write_reg(SYSREG_BLACK_HEIGHT, 1);
    }

    // センサー起動
    cam.setup();

    cam.set_roi0(width as u16, height as u16, None, None)?;


    ///////////////
    cam.write_s7_reg(CAMREG_DPHY_CORE_RESET, 1); // 受信側 DPHY リセット
    cam.write_s7_reg(CAMREG_DPHY_SYS_RESET, 1); // 受信側 DPHY リセット
    std::thread::sleep(std::time::Duration::from_millis(10));

    // 受信側 DPHY 解除 (必ずこちらを先に解除)
    unsafe {
        reg_sys.write_reg(SYSREG_DPHY_SW_RESET, 0);
    }

    // センサー電源ON
    unsafe {
        reg_sys.write_reg(SYSREG_CAM_ENABLE, 1);
    }
    std::thread::sleep(std::time::Duration::from_millis(10));

    // センサー基板 DPHY-TX リセット解除
    cam.write_s7_reg(CAMREG_DPHY_CORE_RESET, 0)?;
    cam.write_s7_reg(CAMREG_DPHY_SYS_RESET, 0)?;
    std::thread::sleep(std::time::Duration::from_millis(10));
    let dphy_tx_init_done = cam.read_s7_reg(CAMREG_DPHY_INIT_DONE)?;
    if dphy_tx_init_done == 0 {
        eprintln!("!!ERROR!! CAM DPHY TX init_done = 0");
        return Err("CAM DPHY TX init_done = 0".into());
    }

    // ここで RX 側も init_done が来る
    let dphy_rx_init_done = unsafe { reg_sys.read_reg(SYSREG_DPHY_INIT_DONE) };
    if dphy_rx_init_done == 0 {
        eprintln!("!!ERROR!! KV260 DPHY RX init_done = 0");
        return Err("KV260 DPHY RX init_done = 0".into());
    }

    // イメージセンサー起動
    let width = 256;
    let height = 256;

    /// ここから
    // set image size (UIO registers expect usize)
    unsafe {
        reg_sys.write_reg(SYSREG_IMAGE_WIDTH, width as usize)
    };
    unsafe { reg_sys.write_reg(SYSREG_IMAGE_HEIGHT, height as usize) };

    // センサー起動: use the Python300 SPI via the `cam` helper
    cam.write_p3_spi(16, 0x0003)?; // power_down  0:pwd_n, 1:PLL enable, 2: PLL Bypass
    cam.write_p3_spi(32, 0x0007)?; // config0 (10bit mode)
    cam.write_p3_spi(8, 0x0000)?; // pll_soft_reset, pll_lock_soft_reset
    cam.write_p3_spi(9, 0x0000)?; // cgen_soft_reset
    cam.write_p3_spi(34, 0x0001)?; // config0 Logic General Enable Configuration
    cam.write_p3_spi(40, 0x0007)?; // image_core_config0
    cam.write_p3_spi(48, 0x0001)?; // AFE Power down
    cam.write_p3_spi(64, 0x0001)?; // Bias Power Down Configuration
    cam.write_p3_spi(72, 0x2227)?; // Charge Pump
    cam.write_p3_spi(112, 0x0007)?; // Serializers/LVDS/IO
    cam.write_p3_spi(10, 0x0000)?; // soft_reset_analog

    // ROI and address calculations (use signed ints for arithmetic)
    let width_i = width as i32;
    let height_i = height as i32;
    let roi_x = ((672 - width_i) / 2) & !0x0f; // align to 16
    let roi_y = ((512 - height_i) / 2) & !0x01; // align to 2

    let x_start = roi_x / 8;
    let x_end = x_start + width_i / 8 - 1;
    let y_start = roi_y;
    let y_end = y_start + height_i - 1;

    cam.write_p3_spi(256, ((x_end << 8) | (x_start & 0xff)) as u16)?; // x_end<<8 | x_start
    cam.write_p3_spi(257, (y_start & 0xffff) as u16)?; // y_start
    cam.write_p3_spi(258, (y_end & 0xffff) as u16)?; // y_end

    // ストップしてトレーニングへ
    cam.write_p3_spi(192, 0x0)?; // stop / training pattern
    std::thread::sleep(std::time::Duration::from_micros(1000));

    // reset/align on receiver side (Spartan-7 registers)
    cam.write_s7_reg(CAMREG_RECV_RESET, 1)?;
    cam.write_s7_reg(CAMREG_ALIGN_RESET, 1)?;
    std::thread::sleep(std::time::Duration::from_micros(1000));
    cam.write_s7_reg(CAMREG_RECV_RESET, 0)?;
    std::thread::sleep(std::time::Duration::from_micros(1000));
    cam.write_s7_reg(CAMREG_ALIGN_RESET, 0)?;
    std::thread::sleep(std::time::Duration::from_micros(1000));

    let cam_calib_status = cam.read_s7_reg(CAMREG_ALIGN_STATUS)?;
    if cam_calib_status != 0x01 {
        eprintln!(
            "!!ERROR!! CAM calibration is not done.  status = {}",
            cam_calib_status
        );
        return Err("CAM calibration is not done".into());
    }

    // 動作開始
    cam.write_p3_spi(192, 0x1)?;

    let mut vdmaw = VideoDmaControl::new(reg_wdma_img, 2, 2, Some(wait_1us)).unwrap();
    // video input start
    unsafe {
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN, 1);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT, 10000000);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_WIDTH, width);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_HEIGHT, height);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_FILL, 0x000);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_TIMEOUT, 100000);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x03);
    }
    std::thread::sleep(std::time::Duration::from_micros(1000));

    // 1frame キャプチャ
    vdmaw.oneshot(
        udmabuf_acc.phys_addr(),
        width as i32,
        height as i32,
        1,
        0,
        0,
        0,
        0,
        Some(100000),
    )?;
    let mut buf = vec![0u16; (width * height) as usize];
    unsafe {
        udmabuf_acc.copy_to_::<u16>(0, buf.as_mut_ptr(), (width * height) as usize);
    }

    // PGM形式で保存
    let pgm_header = format!("P2\n{} {}\n1023\n", width, height);
    let mut pgm_file = std::fs::File::create("output.pgm").expect("Failed to create output.pgm");
    pgm_file
        .write_all(pgm_header.as_bytes())
        .expect("Failed to write PGM header");
    for pixel in buf {
        pgm_file
            .write_all(format!("{}\n", pixel).as_bytes())
            .expect("Failed to write pixel data");
    }

    // カメラOFF
    unsafe { reg_sys.write_reg(SYSREG_CAM_ENABLE, 0) };
    std::thread::sleep(std::time::Duration::from_millis(10));

    println!("done");
    Ok(())
}

/*
struct RtclP3s7Cmd {
    i2c: LinuxI2c,
}

impl RtclP3s7Cmd {
    pub fn new(devname: &str) -> Result<Self, Box<dyn Error>> {
        Ok(RtclP3s7Cmd {
            i2c: LinuxI2c::new(devname, 0x10)?,
        })
    }

    /// Write a 16-bit register on the Spartan-7
    pub fn write_s7_reg(&mut self, addr: u16, data: u16) -> Result<(), Box<dyn Error>> {
        let addr = (addr << 1) | 1;
        let buf: [u8; 4] = [
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 0) & 0xff) as u8,
            ((data >> 8) & 0xff) as u8,
            ((data >> 0) & 0xff) as u8,
        ];
        self.i2c.write(&buf)?;
        Ok(())
    }

    /// Read a 16-bit register on the Spartan-7
    pub fn read_s7_reg(&mut self, addr: u16) -> Result<u16, Box<dyn Error>> {
        let addr = (addr << 1);
        let wbuf: [u8; 4] = [((addr >> 8) & 0xff) as u8, ((addr >> 0) & 0xff) as u8, 0, 0];
        self.i2c.write(&wbuf)?;
        let mut rbuf: [u8; 2] = [0; 2];
        self.i2c.read(&mut rbuf)?;
        Ok(rbuf[0] as u16 | ((rbuf[1] as u16) << 8))
    }

    /// Write a 16-bit register on the PYTHON300 SPI
    pub fn write_p3_spi(&mut self, addr: u16, data: u16) -> Result<(), Box<dyn Error>> {
        let addr = addr | (1 << 14);
        self.write_s7_reg(addr, data)
    }

    /// Read a 16-bit register on the PYTHON300 SPI
    pub fn read_p3_spi(&mut self, addr: u16, data: u16) -> Result<(u16), Box<dyn Error>> {
        let addr = addr | (1 << 14);
        self.read_s7_reg(addr)
    }
}

*/
