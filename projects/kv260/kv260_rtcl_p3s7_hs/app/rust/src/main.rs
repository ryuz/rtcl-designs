#![allow(unused)]

use std::error::Error;
use std::io::Write;
//use std::thread;
//use std::time::Duration;

use jelly_lib::{i2c_access::I2cAccess, linux_i2c::LinuxI2c};
use jelly_mem_access::*;
use jelly_pac::video_dma_control::VideoDmaControl;

use rtcl_lib::rtcl_p3s7_i2c::*;

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
//use kv260_rtcl_p3s7_hs::rtcl_p3s7_i2c::*;

use kv260_rtcl_p3s7_hs::camera_control::CameraControl;

fn usleep(us: u64) {
    std::thread::sleep(std::time::Duration::from_micros(us));
}

fn wait_1us() {
    std::thread::sleep(std::time::Duration::from_micros(1));
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("start kv260_rtcl_p3s7_hs");

    // Ctrl+C の設定
    let running = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(true));
    let r = running.clone();
    ctrlc::set_handler(move || {
        r.store(false, std::sync::atomic::Ordering::SeqCst);
    })?;

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

    let width = 256;
    let height = 256;
        let width = 640;
        let height = 480;
//    let width = 64;
//    let height = 64;

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

    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;

    let mut cam = CameraControl::new(i2c, reg_sys, reg_fmtr);
    cam.open()?;
    std::thread::sleep(std::time::Duration::from_millis(1000));
    cam.set_image_size(width, height);

    /*
    let mut cam = RtclP3s7I2c::new(i2c);

    println!("Camera Module ID       : {:08x}", cam.module_id()?);
    println!(
        "Camera Module Version  : {:08x}",
        cam.read_s7_reg(CAMREG_CORE_VERSION)?
    );

    // カメラモジュールリセット
    unsafe {
        reg_sys.write_reg(SYSREG_CAM_ENABLE, 0); // センサー電源OFF
        std::thread::sleep(std::time::Duration::from_millis(10));
        reg_sys.write_reg(SYSREG_CAM_ENABLE, 1); // センサー電源OFF
        std::thread::sleep(std::time::Duration::from_millis(10));
    }

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
    println!("Sensor ID : 0x{:04x}", cam.sensor_id()?);

    // センサー基板 DPHY-TX リセット解除
    cam.set_dphy_reset(false);
    if !cam.dphy_init_done()? {
        println!("!!ERROR!! CAM DPHY TX init_done = 0");
        return Err("CAM DPHY TX init_done = 0".into());
    }

    // ここで RX 側も init_done が来る
    let dphy_rx_init_done = unsafe { reg_sys.read_reg(SYSREG_DPHY_INIT_DONE) };
    if dphy_rx_init_done == 0 {
        println!("!!ERROR!! KV260 DPHY RX init_done = 0");
        return Err("KV260 DPHY RX init_done = 0".into());
    }

    // 受信画像サイズ設定
    unsafe {
        reg_sys.write_reg(SYSREG_IMAGE_WIDTH, width);
        reg_sys.write_reg(SYSREG_IMAGE_HEIGHT, height);
        reg_sys.write_reg(SYSREG_BLACK_WIDTH, 1280);
        reg_sys.write_reg(SYSREG_BLACK_HEIGHT, 1);
    }

    // センサー起動
    cam.set_sensor_enable(true)?;

    // ROI 設定
    cam.set_roi0(width as u16, height as u16, None, None)?;

    // 動作開始
    cam.set_sequencer_enable(true)?;

    // video input start
    unsafe {
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN, 1);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT, 20000000);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_WIDTH, width);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_HEIGHT, height);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_FILL, 0xffff);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_TIMEOUT, 100000);
        reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x03);
    }
    std::thread::sleep(std::time::Duration::from_micros(1000));
    */

    //  cam.write_p3_spi(144, 0x3)?;  // test pattern

    let mut vdmaw =
        jelly_lib::video_dma_driver::VideoDmaDriver::new(reg_wdma_img, 2, 2, None).unwrap();

    while running.load(std::sync::atomic::Ordering::SeqCst) {
        let key = wait_key(10).unwrap();
        if key == 0x1b {
            break;
        }

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
            for i in 0..buf.len() {
                buf[i] = (buf[i] as u32 * 64) as u16; // 10bit -> 16bit
            }
            let img = Mat::new_rows_cols_with_data(height as i32, width as i32, &buf)?;
            // 10bit の img を 64倍して 16bit に拡張
            //          let mut img = img * 64;
            imshow("img", &img)?;
        }

        if key == 'p' as i32 {
            println!("fps : {:8.3} ({:8.3} ns)", cam.measure_fps(), cam.measure_frame_period());
//            let fps_count   = unsafe{reg_sys.read_reg(SYSREG_FPS_COUNT)};
//            let frame_count = unsafe{reg_sys.read_reg(SYSREG_FRAME_COUNT)};

        }

//        cam.print_timing_status();
//        break;

    }

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

    cam.close();

    /*
    cam.set_sensor_enable(false)?;

    // カメラOFF
    unsafe { reg_sys.write_reg(SYSREG_CAM_ENABLE, 0) };
    std::thread::sleep(std::time::Duration::from_millis(10));
    */

    println!("done");

    return Ok(());
}
