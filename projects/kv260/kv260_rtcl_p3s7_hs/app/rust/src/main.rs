
//#![allow(unused)]

use std::error::Error;
use std::io::Write;

use opencv::*;
use opencv::core::*;
//use opencv::imgcodecs::imwrite;
//use opencv::{core::*, highgui::*, imgproc::*};
//use opencv::{core::*, highgui::*};

use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
//use jelly_pac::video_dma_control::VideoDmaControl;

//use rtcl_lib::rtcl_p3s7_module_driver::*;
use kv260_rtcl_p3s7_hs::camera_driver::CameraDriver;
use kv260_rtcl_p3s7_hs::capture_driver::CaptureDriver;
use kv260_rtcl_p3s7_hs::timing_generator_driver::TimingGeneratorDriver;


//const BIT_STREAM: &'static [u8] = include_bytes!("../../kv260_rtcl_p3s7_hs.bit");
//const DTBO: &'static [u8] = include_bytes!("../../kv260_rtcl_p3s7_hs.dtbo");


fn main() -> Result<(), Box<dyn Error>> {
    println!("start kv260_rtcl_p3s7_hs");

    // Ctrl+C の設定
    let running = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(true));
    let r = running.clone();
    ctrlc::set_handler(move || {
        r.store(false, std::sync::atomic::Ordering::SeqCst);
    })?;

    /*
//  jelly_fpgautil::set_allow_sudo(true);
    jelly_fpgautil::register_accel_with_vec("kv260_rtcl_p3s7_hs", "kv260_rtcl_p3s7_hs.bit", BIT_STREAM, "kv260_rtcl_p3s7_hs.dtbo", &DTBO, None, true)?;
    println!("load");
    let slot = jelly_fpgautil::load("kv260_rtcl_p3s7_hs")?;
    */


//    let width = 256;
//    let height = 256;
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
//  let reg_wdma_blk = uio_acc.subclone(0x00220000, 0x400);

    println!("CORE ID");
    println!("reg_sys      : {:08x}", unsafe { reg_sys.read_reg(0) });
    println!("reg_timgen   : {:08x}", unsafe { reg_timgen.read_reg(0) });
    println!("reg_fmtr     : {:08x}", unsafe { reg_fmtr.read_reg(0) });
    println!("reg_wdma_img : {:08x}", unsafe { reg_wdma_img.read_reg(0) });

    let mut timgen = TimingGeneratorDriver::new(reg_timgen);

    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;
    let mut cam = CameraDriver::new(i2c, reg_sys, reg_fmtr);
    cam.set_image_size(width, height)?;
    cam.set_slave_mode(true)?;
    cam.set_trigger_mode(true)?;
    cam.open()?;
    std::thread::sleep(std::time::Duration::from_millis(1000));

    let mut video_capture = CaptureDriver::new(reg_wdma_img, udmabuf_acc.clone())?;


    //  cam.write_p3_spi(144, 0x3)?;  // test pattern

//    let mut vdmaw =
//        jelly_lib::video_dma_pac::VideoDmaPac::new(reg_wdma_img, 2, 2, None).unwrap();


    // ウィンドウ作成
    highgui::named_window("img", highgui::WINDOW_AUTOSIZE)?;

    // トラックバー生成
    create_cv_trackbar("gain",       0,  200,  10)?;
    create_cv_trackbar("fps",       10, 1000,  60)?;
    create_cv_trackbar("exposure",  10,  900, 900)?;

    // 画像表示ループ
    while running.load(std::sync::atomic::Ordering::SeqCst) {
        // ESC キーで終了
        let key = highgui::wait_key(10).unwrap();
        if key == 0x1b {
            break;
        }

        // トラックバー値取得
        let gain = (get_cv_trackbar_pos("gain")? as f32 - 10.0) / 10.0;
        let fps = get_cv_trackbar_pos("fps")? as f32;
        let exposure = get_cv_trackbar_pos("exposure")? as u16;

        cam.set_gain(gain)?;

        // us 単位に変換
        let period_us = 1000000.0 / fps;
        let exposure_us = period_us * (exposure as f32 / 1000.0);
        timgen.set_timing(period_us, exposure_us)?;

        // CaptureDriver で 1frame キャプチャ
        video_capture.record(width, height, 1)?;
        let img = video_capture.read_image(0)?;

        // 10bit 画像なので加工して表示
        let mut view = Mat::default();
        img.convert_to(&mut view, CV_16U, 64.0, 0.0)?;
        highgui::imshow("img", &view)?;

        // キーボード操作
        let ch = key as u8 as char;
        match ch {
            'q' => { break; },
            'p' => {
                println!("fps : {:8.3} ({:8.3} ns)", cam.measure_fps(), cam.measure_frame_period());
            },
            'd' => {
                println!("write : dump.png");
                imgcodecs::imwrite("dump.png", &view, &Vector::<i32>::new())?;
            },
            'r' => {  // 動画記録
                // 日時のディレクトリを生成
                let now = chrono::Local::now();
                let _ = std::fs::create_dir("record");
                let dir_name = format!("record/{}", now.format("%Y%m%d-%H%M%S"));
                std::fs::create_dir(&dir_name).expect("Failed to create directory");
                println!("record to {}", dir_name);
                
                // 100フレーム録画
                let frames = 100;
                video_capture.record(width, height, frames)?;
                for f in 0..frames {
                   let img = video_capture.read_image(f)?;
                    let mut view = Mat::default();
                    img.convert_to(&mut view, CV_16U, 64.0, 0.0)?;
                    let file_name = format!("{}/img{:04}.png", dir_name, f);
                    imgcodecs::imwrite(&file_name, &view, &Vector::<i32>::new())?;
                }
                println!("record done");
            },
            _ => {
            }
        }
    }

    /*
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
    */
    
    cam.close()?;

    /*
    cam.set_sensor_enable(false)?;

    // カメラOFF
    unsafe { reg_sys.write_reg(SYSREG_CAM_ENABLE, 0) };
    std::thread::sleep(std::time::Duration::from_millis(10));
    */

    println!("done");

//    println!("unload");
//    jelly_fpgautil::unload(slot)?;

    return Ok(());
}


fn create_cv_trackbar(trackbarname: &str, minval: i32, maxval: i32, inival: i32) -> opencv::Result<()> {
    let winname = "img";
    highgui::create_trackbar(trackbarname, &winname, None, maxval, None)?;
    highgui::set_trackbar_min(trackbarname, &winname, minval)?;
    highgui::set_trackbar_max(trackbarname, &winname, maxval)?;
    highgui::set_trackbar_pos(trackbarname, &winname, inival)?;
    Ok(())
}

fn get_cv_trackbar_pos(trackbarname: &str) -> opencv::Result<i32> {
    let winname = "img";
    let val = highgui::get_trackbar_pos(trackbarname, &winname)?;
    Ok(val)
}
