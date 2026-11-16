use std::error::Error;
use clap::Parser;
use rtcl_d3xx::*;
use std::time::Duration;
use opencv::prelude::*;

use rtcl_lib::rtcl_p3s7_module_driver::*;

const REGADR_SYSCTL_CONTROL0 : usize = 0x10;
const REGADR_SYSCTL_CONTROL1 : usize = 0x11;
//const REGADR_SYSCTL_CONTROL2 : usize = 0x12;
const REGADR_SYSCTL_CONTROL3 : usize = 0x13;

type UsbAccessor = SharedBusAccessor<RtclD3xxAxi4lBus, u32, u32, u8, LittleEndian>;

#[derive(Parser, Debug)]
#[command(about = "RTCL-P3S7-MIPI camera capture via FT601")]
struct Args {
    /// 画像幅 [pixel] (16〜672、16の倍数)
    #[arg(long, default_value_t = 672)]
    width: u16,

    /// 画像高さ [pixel] (2〜512、2の倍数)
    #[arg(long, default_value_t = 512)]
    height: u16,

    /// フレームレート [fps]
    #[arg(long, default_value_t = 1_000_000.0 / (16000.0 + 45.4133), conflicts_with = "fr_length0")]
    fps: f64,

    /// 露光時間 [ms]
    #[arg(long, default_value_t = 15.0, conflicts_with = "exposure0")]
    exposure: f64,

    /// アナログ・デジタル合計ゲイン [dB]
    #[arg(long, default_value_t = 10.0, allow_hyphen_values = true)]
    gain: f32,

    /// フレーム長レジスタ [us] (省略時は16000)
    #[arg(long)]
    fr_length0: Option<u16>,

    /// 露光時間レジスタ [us] (省略時は15000)
    #[arg(long)]
    exposure0: Option<u16>,

    /// カラーセンサーの Bayer 画像を現像して表示
    #[arg(long)]
    color: bool,
}

impl Args {
    fn timing(&self) -> (u16, u16) {
        // The shared P3S7 driver uses a 72 MHz clock and a measured 45.4133 us FOT.
        let frame_length = self.fr_length0
            .unwrap_or(((1_000_000.0 / self.fps - 45.4133).round()) as u16);
        let exposure = self.exposure0.unwrap_or((self.exposure * 1000.0).round() as u16);
        (frame_length, exposure)
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    let (fr_length0, exposure0) = args.timing();
    println!("FT601 Tang Primer25k + RTCL-P3S7-MIPI");

    // OpenDevice
//  let mut usb = RtclFifo32CtlD3xx::new(0)?;
    let usb = D3xxVideoCapture::new_capture(0, 10)?;

    // direct read/write
    println!("id : 0x{:08x}", usb.read_axi4l(0)?);

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

    // カメラOFF
    println!("camera power off");
    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL0, 0);   // 電源
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
        std::thread::sleep(Duration::from_millis(500));
    }

    const P3S7_DEVADR: u8 =     0x10;    // 7bit address
    let i2c = JellyI2c::<UsbAccessor>::new(i2c_acc, None);
    let i2c = JellyI2cDevice::<P3S7_DEVADR, UsbAccessor>::new(i2c);
    let mut cam = RtclP3s7ModuleDriver::new(i2c);

    let module_id = cam.module_id()?;
    println!("module_id : 0x{:04x}", module_id);
    let module_ver = cam.module_version()?;
    println!("module_ver : 0x{:04x}", module_ver);
    
    let width = args.width;
    let height = args.height;

    println!("camera set");
    cam.set_dphy_speed(1250000000.0)?;
//  cam.set_dphy_speed(950000000.0)?;
    cam.set_sensor_pgood_enable(false)?;
    cam.set_sensor_power_enable(false)?;
    cam.set_dphy_reset(true)?;
    std::thread::sleep(std::time::Duration::from_millis(10));

//  cam.set_camera_mode(CameraMode::HighSpeed)?;   // 高速モード設定
    cam.set_camera_mode(CameraMode::Csi2)?;   // CSI2 like なモード
    cam.set_csi2_word_count(width * 10 / 8)?;

    cam.set_pmod_mode(0xff00)?;

    // センサー電源ON
    cam.set_sensor_power_enable(true)?;
    std::thread::sleep(std::time::Duration::from_millis(10));

    // センサー基板 DPHY-TX リセット解除
    cam.set_dphy_reset(false)?;

    // xsm_delay
//  let xsm_delay = cam.calc_xsm_delay(width);
//  cam.set_xsm_delay(255)?; // xsm_delay)?;
    cam.set_xsm_delay(100)?; // xsm_delay)?;
    cam.set_nzrot_xsm_delay_enable(true)?;
    cam.set_zero_rot_enable(true)?;

    // センサー起動
    cam.set_color(args.color)?;
    cam.set_sensor_enable(true)?;

    // ROI 設定
    cam.set_roi0(width as u16, height as u16, None, None)?;
    cam.set_gain_db(args.gain)?;

    cam.set_mult_timer0(72)?;
//  cam.set_fr_length0(33000)?;
//  cam.set_exposure0(30000)?;
    cam.set_fr_length0(fr_length0)?;
    cam.set_exposure0(exposure0)?;

    cam.set_slave_mode(false)?;
    cam.set_triggered_mode(false)?;

    // 動作開始
    cam.set_sequencer_enable(true)?;


    println!("Start");
    
    // frame 取り込み開始
    unsafe {
        frm_acc.write_reg_u32(0x10, 1);
    }

    loop {
        // 1 frame 取り込み
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
        
        if args.color {
            let mut mat_bgr = opencv::core::Mat::default();
            opencv::imgproc::cvt_color(&mat, &mut mat_bgr, opencv::imgproc::COLOR_BayerBG2BGR, 0)?;
            opencv::highgui::imshow("image", &mat_bgr)?;
        } else {
            opencv::highgui::imshow("image", &mat)?;
        }
        let key = opencv::highgui::wait_key(10)?;
        if (key & 0xff) == 27 { // ESC
            break;
        }

        if (key & 0xff) == 'r' as i32 {
            println!("start record");
            let mut frames = Vec::<VideoFrame>::new();
            for _ in 0..1000 {
                let frame = match usb.recv_video_timeout(Duration::from_millis(1000)) {
                    Ok(frame) => frame,
                    Err(_) => {
                        continue;
                    }
                };
                frames.push(frame);
            }
            println!("end record");

            // record/時刻 でディレクトリを作って、連番静止画で保存
            let now = chrono::Local::now();
            let dir_name = format!("record/{}", now.format("%Y%m%d_%H%M%S"));
            std::fs::create_dir_all(&dir_name)?;
            for (i, frame) in frames.iter().enumerate() {
                let mat = frame_to_mat(frame);
                let file_name = format!("{}/frame_{:04}.png", dir_name, i);
                opencv::imgcodecs::imwrite(&file_name, &mat, &opencv::core::Vector::new())?;
            }
        }
    }
    

    println!("End Test");

    // カメラOFF
    println!("camera power off");
    unsafe {
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL0, 0);   // 電源
        std::thread::sleep(Duration::from_millis(100));
        ctl_acc.write_reg_u32(REGADR_SYSCTL_CONTROL1, 0);
        std::thread::sleep(Duration::from_millis(100));
    }

    Ok(())
}

fn frame_to_mat(frame: &VideoFrame) -> opencv::core::Mat {
    let h = frame.height as usize;
    let line_bytes = frame.width;
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
    let flat_image: Vec<u16> = image.iter().flatten().copied().collect();
    let mat_ref = opencv::core::Mat::new_rows_cols_with_data(
        h as i32,
        image_width as i32,
        &flat_image,
    ).unwrap();
    let mut mat = opencv::core::Mat::default();
    mat_ref.copy_to(&mut mat).unwrap();
    mat
}





use std::sync::Arc;
use jelly_mem_access::*;
use jelly_mem_access::bus_accessor::LittleEndian;
use jelly_pac::i2c::*;
use jelly_pac::i2c_device::*;


struct RtclD3xxAxi4lBus {
    d3xx: Arc<D3xxVideoCapture>,
}

impl RtclD3xxAxi4lBus {
    fn new(d3xx: Arc<D3xxVideoCapture>) -> Self {
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

#[cfg(test)]
mod tests {
    use super::*;

    fn config(args: &[&str]) -> Result<(Args, u16, u16), Box<dyn Error>> {
        let args = Args::try_parse_from(std::iter::once("p3s7").chain(args.iter().copied()))?;
        let (frame_length, exposure) = args.timing();
        Ok((args, frame_length, exposure))
    }

    #[test]
    fn defaults_to_monochrome_and_existing_timing() {
        let (args, frame_length, exposure) = config(&[]).unwrap();
        assert!(!args.color);
        assert_eq!((args.width, args.height), (672, 512));
        assert_eq!((frame_length, exposure), (16000, 15000));
        assert_eq!(args.gain, 10.0);
    }

    #[test]
    fn parses_color_size_and_frame_rate() {
        let (args, frame_length, exposure) = config(&[
            "--color", "--width", "640", "--height=480", "--fps", "30",
            "--exposure", "12.5", "--gain", "6",
        ]).unwrap();
        assert!(args.color);
        assert_eq!((args.width, args.height), (640, 480));
        assert_eq!(frame_length, 33288);
        assert_eq!(exposure, 12500);
        assert_eq!(args.gain, 6.0);
    }

    #[test]
    fn preserves_raw_timing_options() {
        let (_, frame_length, exposure) = config(&["--fr-length0", "33000", "--exposure0", "30000"]).unwrap();
        assert_eq!((frame_length, exposure), (33000, 30000));
    }

    #[test]
    fn preserves_exposure_for_faster_frame_rates() {
        let (_, frame_length, exposure) = config(&["--fps=100"]).unwrap();
        assert_eq!(frame_length, 9955);
        assert_eq!(exposure, 15000);
    }

    #[test]
    fn accepts_negative_gain_and_maximum_exposure() {
        let (args, _, exposure) = config(&["--gain", "-6", "--exposure", "65.535"]).unwrap();
        assert_eq!(args.gain, -6.0);
        assert_eq!(exposure, u16::MAX);
    }

    #[test]
    fn rejects_conflicting_timing_options() {
        for args in [
            &["--fps", "30", "--fr-length0", "16000"][..],
            &["--exposure", "15", "--exposure0", "15000"],
        ] {
            assert!(config(args).is_err(), "accepted {args:?}");
        }
    }
}
