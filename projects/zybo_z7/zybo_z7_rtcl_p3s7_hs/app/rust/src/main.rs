use std::error::Error;

use clap::Parser;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;

use zybo_z7_rtcl_p3s7_hs::camera_driver::CameraDriver;
use zybo_z7_rtcl_p3s7_hs::capture_driver::CaptureDriver;
use zybo_z7_rtcl_p3s7_hs::timing_generator_driver::TimingGeneratorDriver;

use opencv::*;
use opencv::core::*;

/// ZYBO Z7 RTCL P3S7 High Speed Camera Application
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Image width in pixels
    #[arg(short = 'W', long, default_value_t = 640)]
    width: usize,

    /// Image height in pixels
    #[arg(short = 'H', long, default_value_t = 480)]
    height: usize,

    /// Enable color mode (default: monochrome)
    #[arg(short = 'c', long)]
    color: bool,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    
    println!("start zybo_z7_rtcl_p3s7_hs");
    println!("Configuration:");
    println!("  width:  {}", args.width);
    println!("  height: {}", args.height);
    println!("  color:  {}", args.color);

    let width = args.width;
    let height = args.height;
    let color = args.color;

    // Ctrl+C の設定
    let running = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(true));
    let r = running.clone();
    ctrlc::set_handler(move || {
        r.store(false, std::sync::atomic::Ordering::SeqCst);
    })?;

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

    let reg_sys      = uio_acc.subclone(0x00000000, 0x400);
    let reg_timgen   = uio_acc.subclone(0x00010000, 0x400);
    let reg_fmtr     = uio_acc.subclone(0x00100000, 0x400);
    let reg_wdma_img = uio_acc.subclone(0x00210000, 0x400);
    let reg_wdma_blk = uio_acc.subclone(0x00220000, 0x400);

    println!("CORE ID");
    println!("reg_sys      : {:08x}", unsafe { reg_sys.read_reg(0) });
    println!("reg_timgen   : {:08x}", unsafe { reg_timgen.read_reg(0) });
    println!("reg_fmtr     : {:08x}", unsafe { reg_fmtr.read_reg(0) });
    println!("reg_wdma_img : {:08x}", unsafe { reg_wdma_img.read_reg(0) });
    println!("reg_wdma_blk : {:08x}", unsafe { reg_wdma_blk.read_reg(0) });

    let mut timgen = TimingGeneratorDriver::new(reg_timgen);

    let i2c = LinuxI2c::new("/dev/i2c-0", 0x10)?;
    let mut cam = CameraDriver::new(i2c, reg_sys, reg_fmtr);
    cam.set_image_size(width, height)?;
//  cam.set_slave_mode(true)?;
//  cam.set_trigger_mode(true)?;
    cam.open()?;
    cam.set_color(color)?;
    std::thread::sleep(std::time::Duration::from_millis(1000));

    println!("camera module id      : {:04x}", cam.module_id()?);
    println!("camera module version : {:04x}", cam.module_version()?);
    println!("camera sensor id      : {:04x}", cam.sensor_id()?);


    let mut video_capture = CaptureDriver::new(reg_wdma_img, udmabuf_acc.clone())?;

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

        if color {
            let mut view_rgb = Mat::default();
            imgproc::cvt_color(&view, &mut view_rgb, imgproc::COLOR_BayerBG2BGR, 0)?;
            highgui::imshow("img", &view_rgb)?;
        } else {
            highgui::imshow("img", &view)?;
        }

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

    cam.close()?;
    println!("done");

    Ok(())
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
