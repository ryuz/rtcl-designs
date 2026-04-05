use std::error::Error;
use clap::Parser;

use opencv::*;
use opencv::core::*;

use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;

use kv260_rtcl_p3s7_centroid::camera_driver::CameraDriver;
use kv260_rtcl_p3s7_centroid::capture_driver::CaptureDriver;
use kv260_rtcl_p3s7_centroid::timing_generator_driver::TimingGeneratorDriver;


// Gaussian filter
 const REG_IMG_GAUSS_CORE_ID        : usize = 0x00;
 const REG_IMG_GAUSS_CORE_VERSION   : usize = 0x01;
 const REG_IMG_GAUSS_CTL_CONTROL    : usize = 0x04;
 const REG_IMG_GAUSS_CTL_STATUS     : usize = 0x05;
 const REG_IMG_GAUSS_CTL_INDEX      : usize = 0x07;
 const REG_IMG_GAUSS_PARAM_ENABLE   : usize = 0x08;
 const REG_IMG_GAUSS_CURRENT_ENABLE : usize = 0x18;

 // Clamp
 const REG_IMG_CLAMP_CORE_ID        : usize = 0x00;
 const REG_IMG_CLAMP_CORE_VERSION   : usize = 0x01;
 const REG_IMG_CLAMP_CTL_CONTROL    : usize = 0x04;
 const REG_IMG_CLAMP_CTL_STATUS     : usize = 0x05;
 const REG_IMG_CLAMP_CTL_INDEX      : usize = 0x07;
 const REG_IMG_CLAMP_PARAM_INV      : usize = 0x10;
 const REG_IMG_CLAMP_PARAM_ZERO     : usize = 0x11;
 const REG_IMG_CLAMP_PARAM_MIN      : usize = 0x20;
 const REG_IMG_CLAMP_PARAM_MAX      : usize = 0x21;

 // Rect
 const REG_IMG_RECT_CORE_ID       : usize = 0x00;
 const REG_IMG_RECT_CORE_VERSION  : usize = 0x01;
 const REG_IMG_RECT_CTL_CONTROL   : usize = 0x04;
 const REG_IMG_RECT_CTL_STATUS    : usize = 0x05;
 const REG_IMG_RECT_CTL_INDEX     : usize = 0x07;
 const REG_IMG_RECT_PARAM_X       : usize = 0x10;
 const REG_IMG_RECT_PARAM_Y       : usize = 0x11;
 const REG_IMG_RECT_PARAM_WIDTH   : usize = 0x12;
 const REG_IMG_RECT_PARAM_HEIGHT  : usize = 0x13;

// moment
const REG_IMG_MOMENT_CORE_ID      : usize = 0x00;
const REG_IMG_MOMENT_CORE_VERSION : usize = 0x01;
const REG_IMG_MOMENT_IRQ_ENABLE   : usize = 0x08;
const REG_IMG_MOMENT_IRQ_STATUS   : usize = 0x09;
const REG_IMG_MOMENT_IRQ_CLR      : usize = 0x0a;
const REG_IMG_MOMENT_IRQ_SET      : usize = 0x0b;
const REG_IMG_MOMENT_OUT_VALID    : usize = 0x20;
const REG_IMG_MOMENT_OUT_READY    : usize = 0x21;
const REG_IMG_MOMENT_OUT_X_LO     : usize = 0x30;
const REG_IMG_MOMENT_OUT_X_HI     : usize = 0x31;
const REG_IMG_MOMENT_OUT_Y_LO     : usize = 0x32;
const REG_IMG_MOMENT_OUT_Y_HI     : usize = 0x33;
const REG_IMG_MOMENT_MOMENT_VALID : usize = 0x40;
const REG_IMG_MOMENT_MOMENT_READY : usize = 0x41;
const REG_IMG_MOMENT_MOMENT_DATA  : usize = 0x50;

// image selector
const REG_IMG_SELECTOR_CORE_ID      : usize = 0x00;
const REG_IMG_SELECTOR_CORE_VERSION : usize = 0x01;
const REG_IMG_SELECTOR_CTL_SELECT   : usize = 0x08;
const REG_IMG_SELECTOR_CONFIG_NUM   : usize = 0x10;

// Logger
const REG_LOGGER_CORE_ID          : usize =  0x00;
const REG_LOGGER_CORE_VERSION     : usize =  0x01;
const REG_LOGGER_CTL_CONTROL      : usize =  0x04;
const REG_LOGGER_CTL_STATUS       : usize =  0x05;
const REG_LOGGER_CTL_COUNT        : usize =  0x07;
const REG_LOGGER_LIMIT_SIZE       : usize =  0x08;
const REG_LOGGER_READ_DATA        : usize =  0x10;
const REG_LOGGER_POL_TIMER0       : usize =  0x18;
const REG_LOGGER_POL_TIMER1       : usize =  0x19;
const REG_LOGGER_POL_DATA0        : usize =  0x20;
const REG_LOGGER_POL_DATA1        : usize =  0x21;

// OCM
const OCM_X: usize = 0x08;
const OCM_Y: usize = 0x01;
const OCM_OFFSET_X: usize = 0x10;
const OCM_OFFSET_Y: usize = 0x11;
const OCM_M00_LIMIT: usize = 0x14;
const OCM_LATENCY: usize = 0x18;
const OCM_PRJ_GIAN_X: usize = 0x20;
const OCM_PRJ_GIAN_Y: usize = 0x21;
const OCM_PRJ_OFFSET_X: usize = 0x24;
const OCM_PRJ_OFFSET_Y: usize = 0x25;
const OCM_PRJ_X_MIN: usize = 0x26;
const OCM_PRJ_X_MAX: usize = 0x27;
const OCM_PRJ_Y_MIN: usize = 0x28;
const OCM_PRJ_Y_MAX: usize = 0x29;
const OCM_PRJ_X: usize = 0x40;
const OCM_PRJ_Y: usize = 0x41;


#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Image width in pixels
    #[arg(short = 'W', long, default_value_t = 320)]
    width: usize,

    /// Image height in pixels
    #[arg(short = 'H', long, default_value_t = 320)]
    height: usize,

    #[arg(short = 'f', long, default_value_t = 1000)]
    fps: i32,

    #[arg(short = 'r', long, default_value_t = 1000)]
    rec_frames: usize,

    /// Enable color mode (default: monochrome)
    #[arg(long="pgood-off", default_value_t = false)]
    pgood_off: bool,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    println!("start kv260_rtcl_p3s7_centroid");
    println!("Configuration:");
    println!("  width:  {}", args.width);
    println!("  height: {}", args.height);

    let width = args.width;
    let height = args.height;
    let fps = args.fps;

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

    let reg_sys      = uio_acc.subclone(0x0000_0000, 0x400);
    let reg_timgen   = uio_acc.subclone(0x0001_0000, 0x400);
    let reg_fmtr     = uio_acc.subclone(0x0010_0000, 0x400);
    let reg_wdma_img = uio_acc.subclone(0x0021_0000, 0x400);
//  let reg_wdma_blk = uio_acc.subclone(0x0022_0000, 0x400);
    let reg_log_c    = uio_acc.subclone(0x0030_0000, 0x400);
    let reg_log_m    = uio_acc.subclone(0x0032_0000, 0x400);
//  let reg_log_lin  = uio_acc.subclone(0x0032_0000, 0x400);
    let reg_gauss    = uio_acc.subclone(0x0040_1000, 0x400);
    let reg_clamp    = uio_acc.subclone(0x0040_2000, 0x400);
    let reg_rect     = uio_acc.subclone(0x0040_3000, 0x400);
    let reg_moment   = uio_acc.subclone(0x0040_4000, 0x400);
    let reg_sel      = uio_acc.subclone(0x0040_f000, 0x400);
    let reg_uart     = uio_acc.subclone(0x0050_0000, 0x400);

    let uio_ocm = UioAccessor::<u64>::new_with_name("uio_ocm").expect("Failed to open uio_ocm");

    println!("CORE ID");
    println!("reg_sys      : {:08x}", unsafe { reg_sys.read_reg(0) });
    println!("reg_timgen   : {:08x}", unsafe { reg_timgen.read_reg(0) });
    println!("reg_fmtr     : {:08x}", unsafe { reg_fmtr.read_reg(0) });
    println!("reg_wdma_img : {:08x}", unsafe { reg_wdma_img.read_reg(0) });
    println!("reg_gauss    : {:08x}", unsafe { reg_gauss.read_reg(0) });
    println!("reg_rect     : {:08x}", unsafe { reg_rect.read_reg(0) });
    println!("reg_moment   : {:08x}", unsafe { reg_moment.read_reg(0) });

    if false {
        for _ in 0..10 {
            // 1ms おきにループして円を描く
            let r = 100;
            for i in 0..360 {
                let x = (r as f64 * (i as f64 * std::f64::consts::PI / 180.0).cos()) as i16;
                let y = (r as f64 * (i as f64 * std::f64::consts::PI / 180.0).sin()) as i16;
                send_projector_xy(&reg_uart, x, y, true);
                std::thread::sleep(std::time::Duration::from_millis(1));
            }
        }
        send_projector_xy(&reg_uart, 0, 0, true);
        return Ok(());
    }

    let mut timgen = TimingGeneratorDriver::new(reg_timgen);

    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;
    let mut cam = CameraDriver::new(i2c, reg_sys.clone(), reg_fmtr);

    if args.pgood_off {
        cam.set_sensor_pgood_enable(false);
    }

    cam.set_image_size(width, height)?;
    cam.set_slave_mode(true)?;
    cam.set_trigger_mode(true)?;
    if let Err(err) = cam.open() {
        if err.to_string().contains("Sensor power good signal indicates failure") {
            println!("\n!! sensor power good error. !! Retry with --pgood-off option.");
            return Ok(());
        } else {
            return Err(err);
        }
    }
    std::thread::sleep(std::time::Duration::from_millis(1000));

    println!("camera module id      : {:04x}", cam.module_id()?);
    println!("camera module version : {:04x}", cam.module_version()?);
    println!("camera sensor id      : {:04x}", cam.sensor_id()?);

    let mut video_capture = CaptureDriver::new(reg_wdma_img, udmabuf_acc.clone())?;

    // ウィンドウ作成
    highgui::named_window("img", highgui::WINDOW_AUTOSIZE)?;
    highgui::resize_window("img", width as i32 + 64, height as i32 + 256)?;

    // トラックバー生成
    create_cv_trackbar("gain",       0,  200,   10)?;
    create_cv_trackbar("fps",       10, 1000,  fps)?;
    create_cv_trackbar("exposure",  10,  900,  900)?;
    create_cv_trackbar("gauss",      0,    4,    0)?;
    create_cv_trackbar("min",        0, 1023,  400)?;
    create_cv_trackbar("max",        0, 1023, 1023)?;
    create_cv_trackbar("x0",         0, (width -1) as i32,       0)?;
    create_cv_trackbar("x1",         0, (width -1) as i32, (width-1) as i32)?;
    create_cv_trackbar("y0",         0, (height-1) as i32,       0)?;
    create_cv_trackbar("y1",         0, (height-1) as i32, (width-1) as i32)?;
    //  create_cv_trackbar("sel",        0,    2,    0)?;

    create_cv_trackbar("m00_lim",    0, 1000, 10 as i32)?;
    create_cv_trackbar("pgx",        -500, 500, -200)?;
    create_cv_trackbar("pgy",        -500, 500, -200)?;
    create_cv_trackbar("pox",        -1000, 1000, 0)?;
    create_cv_trackbar("poy",        -1000, 1000, 200)?;


    let mut hist_x: Vec<f64> = Vec::new();
    let mut hist_y: Vec<f64> = Vec::new();
    let mut log_hist_x: Vec<f64> = Vec::new();
    let mut log_hist_y: Vec<f64> = Vec::new();
    let mut track_x: f64 = 0.0;
    let mut track_y: f64 = 0.0;

    // 初期値設定
    unsafe {
        reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_INV, 1);
        reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_ZERO, 1);
        reg_clamp.write_reg(REG_IMG_CLAMP_CTL_CONTROL, 3);

        uio_ocm.write_reg_f64(OCM_PRJ_X_MIN, -1000.0);
        uio_ocm.write_reg_f64(OCM_PRJ_X_MAX,  1000.0);
        uio_ocm.write_reg_f64(OCM_PRJ_Y_MIN,  -10.0);
        uio_ocm.write_reg_f64(OCM_PRJ_Y_MAX, 1000.0);
    }

    // 画像表示ループ
    while running.load(std::sync::atomic::Ordering::SeqCst) {
        // ESC キーで終了
        let key = highgui::wait_key(10).unwrap();
        if key == 0x1b {
            break;
        }

        // トラックバー値取得
        let gain      = (get_cv_trackbar_pos("gain")? as f32 - 10.0) / 10.0;
        let fps       = get_cv_trackbar_pos("fps")? as f32;
        let exposure  = get_cv_trackbar_pos("exposure")? as u16;
        let gauss     = get_cv_trackbar_pos("gauss")?;
        let clamp_min = get_cv_trackbar_pos("min")?;
        let clamp_max = get_cv_trackbar_pos("max")?;
        let rect_x0   = get_cv_trackbar_pos("x0")?;
        let rect_x1   = get_cv_trackbar_pos("x1")?;
        let rect_y0   = get_cv_trackbar_pos("y0")?;
        let rect_y1   = get_cv_trackbar_pos("y1")?;
        //      let sel       = get_cv_trackbar_pos("sel")?;

        let rect_x = rect_x0.min(rect_x1);
        let rect_y = rect_y0.min(rect_y1);
        let rect_width = (rect_x0.max(rect_x1) - rect_x) + 1;
        let rect_height = (rect_y0.max(rect_y1) - rect_y) + 1;

        unsafe {
            reg_gauss.write_reg(REG_IMG_GAUSS_PARAM_ENABLE, ((1 << gauss) - 1) as usize);
            reg_gauss.write_reg(REG_IMG_GAUSS_CTL_CONTROL, 3);
//          reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_INV, 0);
//          reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_ZERO, 0);
            reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_MIN, clamp_min as usize);
            reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_MAX, clamp_max as usize);
            reg_clamp.write_reg(REG_IMG_CLAMP_CTL_CONTROL, 3);
            reg_rect.write_reg(REG_IMG_RECT_PARAM_X, rect_x as usize);
            reg_rect.write_reg(REG_IMG_RECT_PARAM_Y, rect_y as usize);
            reg_rect.write_reg(REG_IMG_RECT_PARAM_WIDTH, rect_width as usize);
            reg_rect.write_reg(REG_IMG_RECT_PARAM_HEIGHT, rect_height as usize);
            reg_rect.write_reg(REG_IMG_RECT_CTL_CONTROL, 3);
//          reg_sel.write_reg(REG_IMG_SELECTOR_CTL_SELECT, sel as usize);
        }

        let m00_lim = get_cv_trackbar_pos("m00_lim")? as f64 * 100.0;
        let prj_gain_x = get_cv_trackbar_pos("pgx")? as f64 / 100.0;
        let prj_gain_y = get_cv_trackbar_pos("pgy")? as f64 / 100.0;
        let prj_offset_x = get_cv_trackbar_pos("pox")? as f64;
        let prj_offset_y = get_cv_trackbar_pos("poy")? as f64;

        unsafe {
            reg_sel.write_reg(REG_IMG_SELECTOR_CTL_SELECT, 3);

            uio_ocm.write_reg_f64(OCM_OFFSET_X, -0.5 * width as f64);
            uio_ocm.write_reg_f64(OCM_OFFSET_Y, -0.5 * height as f64);
            uio_ocm.write_reg_f64(OCM_M00_LIMIT, m00_lim);
            uio_ocm.write_reg_f64(OCM_PRJ_GIAN_X, prj_gain_x);
            uio_ocm.write_reg_f64(OCM_PRJ_GIAN_Y, prj_gain_y);
            uio_ocm.write_reg_f64(OCM_PRJ_OFFSET_X, prj_offset_x);
            uio_ocm.write_reg_f64(OCM_PRJ_OFFSET_Y, prj_offset_y);
        }

        cam.set_gain(gain)?;

        // us 単位に変換
        let period_us = 1000000.0 / fps;
        let exposure_us = period_us * (exposure as f32 / 1000.0);
        timgen.set_timing(period_us, exposure_us)?;

        // CaptureDriver で 1frame キャプチャ
        video_capture.record(width, height, 1)?;
        let img = video_capture.read_image_mat(0)?;

        // 10bit 画像なので加工して表示
        let mut view = Mat::default();
        img.convert_to(&mut view, CV_16U, 64.0, 0.0)?;
        highgui::imshow("img", &view)?;

        // moment ログ取得
        /*
        unsafe {
            while reg_log_c.read_reg(REG_LOGGER_CTL_STATUS) != 0 {
            let cy = (reg_log_c.read_reg(REG_LOGGER_POL_DATA1) as i64 as f64) / 65536.0;
            let cx = (reg_log_c.read_reg(REG_LOGGER_READ_DATA) as i64 as f64) / 65536.0;
//          println!("x: {:8.3}, y: {:8.3}", x, y);
            
            hist_dx.push(dx);
            hist_dy.push(dy);
            if hist_dx.len() > 1000 {
                hist_dx.remove(0);
                hist_dy.remove(0);
            }

            log_hist_dx.push(dx);
            log_hist_dy.push(dy);
            if log_hist_dx.len() > 10000 {
                log_hist_dx.remove(0);
                log_hist_dy.remove(0);
            }
            
            track_x += dx;
            track_y += dy;
            track_x = track_x.max(0.0).min(width as f64);
            track_y = track_y.max(0.0).min(height as f64);
            }
        }

        let mut graph = Mat::zeros(200, 1000, CV_8UC3)?.to_mat()?;
        for i in 0..hist_dx.len() {
            let y0 = 100 - (hist_dx[i] * 10.0) as i32;
            imgproc::circle(&mut graph, Point::new(i as i32, y0), 1, Scalar::new(0.0, 255.0, 0.0, 0.0), -1, imgproc::LINE_8, 0)?;
            let y1 = 100 - (hist_dy[i] * 10.0) as i32;
            imgproc::circle(&mut graph, Point::new(i as i32, y1), 1, Scalar::new(255.0, 0.0, 0.0, 0.0), -1, imgproc::LINE_8, 0)?;
        }
        highgui::imshow("graph", &graph)?;

        let mut graph2 = Mat::zeros(200, 200, CV_8UC3)?.to_mat()?;
        for i in 0..hist_dx.len() {
            let x = 100 - (hist_dx[i] * 10.0) as i32;
            let y = 100 - (hist_dy[i] * 10.0) as i32;
            imgproc::circle(&mut graph2, Point::new(x, y), 1, Scalar::new(0.0, 255.0, 0.0, 0.0), -1, imgproc::LINE_8, 0)?;
        }
        highgui::imshow("x-y", &graph2)?;
        */


        // キーボード操作
        let ch = key as u8 as char;
        match ch {
            '1' => {
                 unsafe { reg_sel.write_reg(REG_IMG_SELECTOR_CTL_SELECT, 0); }
                 println!("select : {}", unsafe{reg_sel.read_reg(REG_IMG_SELECTOR_CTL_SELECT)});
            },
            '2' => {
                 unsafe { reg_sel.write_reg(REG_IMG_SELECTOR_CTL_SELECT, 1); }
                 println!("select : {}", unsafe{reg_sel.read_reg(REG_IMG_SELECTOR_CTL_SELECT)});
            },
            '3' => {
                 unsafe { reg_sel.write_reg(REG_IMG_SELECTOR_CTL_SELECT, 2); }
                 println!("select : {}", unsafe{reg_sel.read_reg(REG_IMG_SELECTOR_CTL_SELECT)});
            },
            '4' => {
                 unsafe { reg_sel.write_reg(REG_IMG_SELECTOR_CTL_SELECT, 3); }
                 println!("select : {}", unsafe{reg_sel.read_reg(REG_IMG_SELECTOR_CTL_SELECT)});
            },

            'i' => {
                unsafe {
                    let val = reg_clamp.read_reg(REG_IMG_CLAMP_PARAM_INV) ^ 1;
                    reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_INV, val);
                    println!("clamp inv : {}", val);
                }
            }
            'z' => {
                unsafe {
                    let val = reg_clamp.read_reg(REG_IMG_CLAMP_PARAM_ZERO) ^ 1;
                    reg_clamp.write_reg(REG_IMG_CLAMP_PARAM_ZERO, val);
                    println!("clamp zero : {}", val);
                }
            }

            'q' => { break; },
            'p' => {
                println!("camera module id      : {:04x}", cam.module_id()?);
                println!("camera module version : {:04x}", cam.module_version()?);
                println!("camera sensor id      : {:04x}", cam.sensor_id()?);
                println!("sensor_pgood : {}", cam.sensor_pgood()?);
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
                let frames = args.rec_frames;
                video_capture.record(width, height, frames)?;
                for f in 0..frames {
                   let img = video_capture.read_image_mat(f)?;
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


fn send_projector_xy(reg_uart: &UioAccessor<usize>, x: i16, y: i16, laser_on: bool) {
    let xh = ((x as u16) >> 8) as u8;
    let xl = (x as u16 & 0xff) as u8;
    let yh = ((y as u16) >> 8) as u8;
    let yl = (y as u16 & 0xff) as u8;
    let flg = if laser_on { 0x01 } else { 0x00 };
    let chk = xh ^ xl ^ yh ^ yl ^ flg;
    unsafe {
        reg_uart.write_reg(0, 0xa5);
        reg_uart.write_reg(0, xh as usize);
        reg_uart.write_reg(0, xl as usize);
        reg_uart.write_reg(0, yh as usize);
        reg_uart.write_reg(0, yl as usize);
        reg_uart.write_reg(0, flg as usize);
        reg_uart.write_reg(0, chk as usize);
    }
}
