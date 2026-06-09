use std::error::Error;
use clap::Parser;

use opencv::*;
use opencv::core::*;

use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;

use rtcl_p3s7_shared::camera_driver::*;
use rtcl_p3s7_shared::capture_driver::*;
use rtcl_p3s7_shared::timing_generator_driver::TimingGeneratorDriver;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Image width in pixels
    #[arg(short = 'W', long, default_value_t = 416)]
    width: usize,

    /// Image height in pixels
    #[arg(short = 'H', long, default_value_t = 416)]
    height: usize,

    #[arg(short = 'f', long, default_value_t = 1000)]
    fps: i32,

    #[arg(short = 'r', long, default_value_t = 100)]
    rec_frames: usize,

    /// Enable color mode (default: monochrome)
    #[arg(short = 'c', long, default_value_t = false)]
    color: bool,

    /// Master Mode (No External Triggers)
    #[arg(short = 'm', long, default_value_t = false)]
    master : bool,

    /// Trigger Mode (External Triggers)
    #[arg(short = 't', long, default_value_t = false)]
    trigger : bool,

    #[arg(long="pmod-mode", default_value_t = 0x10)]
    pmod_mode: u16,

    /// Enable color mode (default: monochrome)
    #[arg(long="pgood-off", default_value_t = false)]
    pgood_off: bool,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();

    let width = (args.width + 15) & !0xf;  // 16ピクセル境界に合わせる
    let height = (args.height + 1) & !0x01;  // 2ピクセル境界に合わせる
    let color = args.color;
    let fps = args.fps;
    let trigger_mode = args.trigger;

    let spectrals : usize = 8;              // 計測する素スペクトル数
    let slots : usize = spectrals + 1;      // 背景を加えた撮影スロット

    println!("start kv260_rtcl_p3s7_hs");
    println!("Configuration:");
    println!("  width:  {}", width);
    println!("  height: {}", height);
    println!("  color:  {}", color);
    println!("  fps:    {}", fps);
    println!("  trigger mode: {}", trigger_mode);
    println!("  pmod mode : 0x{:04x}", args.pmod_mode);

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

    if args.pgood_off {
        cam.set_sensor_pgood_enable(false);
    }

    cam.set_color(color);
    cam.set_black_lines(15)?;
    cam.set_image_size(width, height)?;
    cam.set_slave_mode(trigger_mode)?;
    cam.set_trigger_mode(trigger_mode)?;
    if let Err(err) = cam.open() {
        if err.to_string().contains("Sensor power good signal indicates failure") {
            println!("\n!! sensor power good error. !! Retry with --pgood-off option.");
            return Ok(());
        } else {
            return Err(err);
        }
    }

    // PMODモード設定
    cam.set_pmod_mode(args.pmod_mode)?;
    cam.set_pmod_slot_len(slots as u16)?;
    for i in 0..spectrals {
        // スロット番号の波長を発光
        cam.set_pmod_slot_pattern(i as u16, (1 << i) as u16)?;
    }
    // 最後のスロットは背景用に全て消灯
    cam.set_pmod_slot_pattern(spectrals as u16, 0)?;

    // ヘッダに設定するのをインデックス値に設定
    cam.set_pmod_header_select(2)?;

    std::thread::sleep(std::time::Duration::from_millis(1000));

    println!("camera module id      : {:04x}", cam.module_id()?);
    println!("camera module version : {:04x}", cam.module_version()?);
    println!("camera sensor id      : {:04x}", cam.sensor_id()?);

    let mut video_capture = CaptureDriver::new(reg_wdma_img, udmabuf_acc.clone())?;

    // ウィンドウ作成
    let view_winname = "multispectral";
    let bg_winname = "background";
    highgui::named_window(view_winname, highgui::WINDOW_AUTOSIZE)?;
    highgui::resize_window(view_winname, (width*4) as i32 + 128, (height*2) as i32 + 256)?;
    highgui::named_window(bg_winname, highgui::WINDOW_AUTOSIZE)?;
    highgui::resize_window(bg_winname, width as i32 + 128, height as i32 + 256)?;

    // トラックバー生成
    create_cv_trackbar("sgain",     &bg_winname,  0,  200,  10)?;    // センサーゲイン
    create_cv_trackbar("dgain",     &bg_winname,  0,  200,  10)?;    // デジタルゲイン
    create_cv_trackbar("fps",       &bg_winname, 10, 1000, fps)?;
    create_cv_trackbar("exposure",  &bg_winname, 10,  990, 990)?;

    for i in 0..spectrals {
        let name = format!("time{}", i);
        create_cv_trackbar(&name, &view_winname, 0, 1000, 1000)?;
    }
    
    
    // 画像表示ループ
    let mut remove_bg = false;
    while running.load(std::sync::atomic::Ordering::SeqCst) {
        // ESC キーで終了
        let key = highgui::wait_key(10).unwrap();
        if key == 0x1b {
            break;
        }

        // トラックバー値取得
        let sgain_db = (get_cv_trackbar_pos("sgain",    &bg_winname)? as f32 - 10.0) / 10.0;
        let dgain_db = (get_cv_trackbar_pos("dgain",    &bg_winname)? as f32 - 10.0) / 10.0;
        let fps      =  get_cv_trackbar_pos("fps",      &bg_winname)? as f32;
        let exposure =  get_cv_trackbar_pos("exposure", &bg_winname)? as u16;

        for i in 0..spectrals {
            let name = format!("time{}", i);
            let time = get_cv_trackbar_pos(&name, &view_winname)? as u16;
            cam.set_pmod_slot_time(i as u16, time)?;
        }

        // us 単位に変換
        let period_us = 1000000.0 / fps;
        let exposure_us = period_us * (exposure as f32 / 1000.0);
        if trigger_mode {
            timgen.set_timing(period_us, exposure_us)?;
        }
        else {
            cam.set_frame_period(period_us)?;
            cam.set_exposure(exposure_us)?;
        }
        
        // CaptureDriver で 1frame キャプチャ
        let mut cap_imgs = vec![Mat::default(); slots as usize];
        video_capture.record(width, height, slots as usize)?;
        for i in 0..slots {
            let src = video_capture.read_image_mat(i as usize)?;
            // 先頭ピクセルの上位6bitにインデックス値が入っているので、画像化前に取り出す
            let idx = (src.at_2d::<u16>(0, 0)? >> 10) as usize;
            let mut img = Mat::default();
            src.convert_to(&mut img, CV_16U, 65535.0/1023.0, 0.0)?;

            // センサーゲインの代わりにデジタルゲインを適用
            let dgain_scale = 10.0_f64.powf(dgain_db as f64 / 20.0);
            let mut img_dgain = Mat::default();
            img.convert_to(&mut img_dgain, -1, dgain_scale, 0.0)?;
            img = img_dgain;

            // imgs の対応する番号に格納
            cap_imgs[idx] = img;
        }
        let bg_img = cap_imgs[slots-1].clone();

        let titles =[
                "625nm (Red)",
                "530nm (Green)",
                "465nm (Blue)",
                "850nm (IR1)",
                "940nm (IR2)",
                "733nm (Red Edge)",
                "590nm (Amber)",
                "395nm (UV)",
                "background",
            ];

        // imgs の0から7までの8枚をタイル状になれべ手 4x2 倍の 表示画像 を作る
        let mut view_img = Mat::zeros(height as i32 * 2, width as i32 * 4, CV_8UC3)?.to_mat()?;
        for i in 0..spectrals {
            if cap_imgs[i].empty() {
                continue;
            }
            
            let mut img = Mat::default();
            if !bg_img.empty() && remove_bg {
                // 背景を引く
                opencv::core::subtract(&cap_imgs[i], &bg_img, &mut img, &Mat::default(), -1)?;
            }
            else {
                img = cap_imgs[i].clone();
            }

            // CV_16U のモノクロ画像を CV_8UC3 に変換
            let mut img_8u = Mat::default();
            img.convert_to(&mut img_8u, CV_8U, 255.0/65535.0, 0.0)?;
            let mut img_rgb = Mat::default();
            opencv::imgproc::cvt_color(&img_8u, &mut img_rgb, opencv::imgproc::COLOR_GRAY2BGR, 0)?;

            // 白い枠を描画
            opencv::imgproc::rectangle(
                &mut img_rgb,
                Rect::new(0, 0, width as i32, height as i32),
                Scalar::new(255.0, 255.0, 255.0, 0.0),
                1,
                opencv::imgproc::LINE_8,
                0,
            )?;

            // タイトルを緑色で描画
            opencv::imgproc::put_text(
                &mut img_rgb,
                titles[i],
                Point::new(4, 16),
                opencv::imgproc::FONT_HERSHEY_SIMPLEX,
                0.5,
                Scalar::new(0.0, 255.0, 0.0, 0.0),
                1,
                opencv::imgproc::LINE_8,
                false,
            )?;

            let x = (i % 4) as i32;
            let y = (i / 4) as i32;
            let roi = Rect::new(x * width as i32, y * height as i32, width as i32, height as i32);
            let mut dst = view_img.roi_mut(roi)?;
            img_rgb.copy_to(&mut dst)?;
        }
        highgui::imshow(&view_winname, &view_img)?;
        highgui::imshow(&bg_winname, &bg_img)?;

        // センサーゲインを適用
        cam.set_gain(sgain_db)?;
        
        // キーボード操作
        let ch = key as u8 as char;
        match ch {
            'q' => { break; },
            'b' => { remove_bg = !remove_bg; },
            'p' => {
                println!("camera module id      : {:04x}", cam.module_id()?);
                println!("camera module version : {:04x}", cam.module_version()?);
                println!("camera sensor id      : {:04x}", cam.sensor_id()?);
                println!("sensor_ready : {}", cam.sensor_ready()?);
                println!("sensor_pgood : {}", cam.sensor_pgood()?);
                println!("fps : {:8.3} ({:8.3} ns)", cam.measure_fps(), cam.measure_frame_period());
            },
            'x' => {
                println!("---- sensor reg ----");
                cam.print_sensor_register();
                println!("------ end  ------");
            },
            'z' => {
                cam.print_timing_status();
            }
            'd' => {
                println!("write : dump.png");
                imgcodecs::imwrite("dump.png", &view_img, &Vector::<i32>::new())?;
                for i in 0..slots {
                    if cap_imgs[i].empty() {
                        continue;
                    }
                    let file_name = format!("dump_{}.png", i);
                    imgcodecs::imwrite(&file_name, &cap_imgs[i], &Vector::<i32>::new())?;
                }
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
                video_capture.record(width, height, (frames+1) * slots)?;
                let mut f = 0;
                // idx 0 のフレームまで読み飛ばす
                let img = video_capture.read_image_mat(f)?;



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


fn create_cv_trackbar(trackbarname: &str, winname: &str, minval: i32, maxval: i32, inival: i32) -> opencv::Result<()> {
    highgui::create_trackbar(trackbarname, winname, None, maxval, None)?;
    highgui::set_trackbar_min(trackbarname, winname, minval)?;
    highgui::set_trackbar_max(trackbarname, winname, maxval)?;
    highgui::set_trackbar_pos(trackbarname, winname, inival)?;
    Ok(())
}

fn get_cv_trackbar_pos(trackbarname: &str, winname: &str) -> opencv::Result<i32> {
    let val = highgui::get_trackbar_pos(trackbarname, &winname)?;
    Ok(val)
}
