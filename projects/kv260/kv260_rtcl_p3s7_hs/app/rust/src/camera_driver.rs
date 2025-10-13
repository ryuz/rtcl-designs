#![allow(dead_code)]

use std::error::Error;
use std::result::Result;

use jelly_lib::i2c_hal::I2cHal;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
use rtcl_lib::rtcl_p3s7_module_driver::*;

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

type RtclP3s7ModuleDriverLinux = RtclP3s7ModuleDriver<LinuxI2c>;
type RegAccess = UdmabufAccessor<usize>;

pub struct CameraDriver<I2C, U>
where
    I2C: I2cHal,
    <I2C as I2cHal>::Error: std::error::Error + 'static,
    U: Copy + Clone,
{
    cam_i2c: RtclP3s7ModuleDriver<I2C>,
    reg_sys: UioAccessor<U>,
    reg_fmtr: UioAccessor<U>,

    opend: bool,
    width: usize,
    height: usize,
    slave_mode: bool,
    trigger_mode: bool,
    gain: f32,
    mult_timer: u16,
    fr_length: u16,
    exposure: u16,
}

impl<I2C, U> CameraDriver<I2C, U>
where
    I2C: I2cHal,
    <I2C as I2cHal>::Error: std::error::Error + 'static,
    U: Copy + Clone,
{
    pub fn new(i2c: I2C, reg_sys: UioAccessor<U>, reg_fmtr: UioAccessor<U>) -> Self {
        Self {
            cam_i2c: RtclP3s7ModuleDriver::new(i2c),
            reg_sys,
            reg_fmtr,
            opend: false,
            width: 640,
            height: 480,
            slave_mode: false,
            trigger_mode: false,
            gain: 1.0,
            mult_timer: 72,
            fr_length: 0,
            exposure: 10000,
        }
    }

    pub fn opend(&self) -> bool {
        self.opend
    }

    pub fn open(&mut self) -> Result<(), Box<dyn Error>>
    {
        if self.opend {
            return Ok(());
        }

        // カメラモジュールリセット
        unsafe {
            self.reg_sys.write_reg(SYSREG_CAM_ENABLE, 0); // センサー電源OFF
            std::thread::sleep(std::time::Duration::from_millis(10));
            self.reg_sys.write_reg(SYSREG_CAM_ENABLE, 1); // センサー電源ON
            std::thread::sleep(std::time::Duration::from_millis(10));
        }

        // MMCM 設定
        self.cam_i2c.set_dphy_speed(1250000000.0)?; // 1250Mbps

        // 受信側 DPHY リセット
        unsafe {
            self.reg_sys.write_reg(SYSREG_DPHY_SW_RESET, 1);
        }

        // カメラ基板初期化
        self.cam_i2c.set_sensor_power_enable(false)?;
        self.cam_i2c.set_dphy_reset(true)?;
        std::thread::sleep(std::time::Duration::from_millis(10));

        // 受信側 DPHY 解除 (必ずこちらを先に解除)
        unsafe {
            self.reg_sys.write_reg(SYSREG_DPHY_SW_RESET, 0);
        }
        // 高速モード設定
        self.cam_i2c.set_camera_mode(CameraMode::HighSpeed)?;

        // センサー電源ON
        self.cam_i2c.set_sensor_power_enable(true)?;
        std::thread::sleep(std::time::Duration::from_millis(10));

        // センサー基板 DPHY-TX リセット解除
        self.cam_i2c.set_dphy_reset(false)?;
        if !self.cam_i2c.dphy_init_done()? {
            return Err("CAM DPHY TX init_done = 0".into());
        }

        // ここで RX 側も init_done が来る
        if unsafe { self.reg_sys.read_reg(SYSREG_DPHY_INIT_DONE) } == 0 {
            return Err("KV260 DPHY RX init_done = 0".into());
        }

        // 受信画像サイズ設定
        unsafe {
            self.reg_sys.write_reg(SYSREG_IMAGE_WIDTH, self.width);
            self.reg_sys.write_reg(SYSREG_IMAGE_HEIGHT, self.height);
            self.reg_sys.write_reg(SYSREG_BLACK_WIDTH, 1280);
            self.reg_sys.write_reg(SYSREG_BLACK_HEIGHT, 1);
        }

        // センサー起動
        self.cam_i2c.set_sensor_enable(true)?;

        // ROI 設定
        self.cam_i2c
            .set_roi0(self.width as u16, self.height as u16, None, None)?;
        self.cam_i2c.set_gain_db(self.gain)?;

        self.cam_i2c.set_mult_timer0(self.mult_timer)?;  // 68MHz
        self.cam_i2c.set_fr_length0(self.fr_length)?;
        self.cam_i2c.set_exposure0(self.exposure)?;

        // video input start
        unsafe {
            self.reg_fmtr
                .write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN, 1);
            self.reg_fmtr
                .write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT, 20000000);
            self.reg_fmtr
                .write_reg(REG_VIDEO_FMTREG_PARAM_WIDTH, self.width);
            self.reg_fmtr
                .write_reg(REG_VIDEO_FMTREG_PARAM_HEIGHT, self.height);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_FILL, 0x0);
            self.reg_fmtr
                .write_reg(REG_VIDEO_FMTREG_PARAM_TIMEOUT, 100000);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x03);
        }
        std::thread::sleep(std::time::Duration::from_micros(1000));

        // スレーブモード、トリガーモード設定
        self.cam_i2c.set_slave_mode(self.slave_mode)?;
        self.cam_i2c.set_triggered_mode(self.trigger_mode)?;

        // 動作開始
        self.cam_i2c.set_sequencer_enable(true)?;

        self.opend = true;
        Ok(())
    }

    // カメラ停止
    pub fn close(&mut self) -> Result<(), Box<dyn Error>>
    {
        if !self.opend {
            return Ok(());
        }

        // video input stop
        unsafe {
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x00);
        }
        std::thread::sleep(std::time::Duration::from_millis(10));

        // センサー停止
        self.cam_i2c.set_sequencer_enable(false)?;
        self.cam_i2c.set_sensor_enable(false)?;
        std::thread::sleep(std::time::Duration::from_millis(10));

        // センサー電源OFF
        self.cam_i2c.set_sensor_power_enable(false)?;
        std::thread::sleep(std::time::Duration::from_millis(10));

        self.opend = false;

        Ok(())
    }

    /// スレーブモード設定
    pub fn set_slave_mode(&mut self, enable: bool) -> Result<(), Box<dyn Error>> {
        self.slave_mode = enable;
        if self.opend {
            self.cam_i2c.set_slave_mode(enable)?;
        }
        Ok(())
    }
    
    /// トリガーモード設定
    pub fn set_trigger_mode(&mut self, enable: bool) -> Result<(), Box<dyn Error>> {
        self.trigger_mode = enable;
        if self.opend {
            self.cam_i2c.set_triggered_mode(enable)?;
        }
        Ok(())
    }

    pub fn set_image_size(&mut self, width: usize, height: usize) -> Result<(), Box<dyn Error>> {
        if self.opend() {
            unsafe {
                self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x00);
            }
            self.cam_i2c.set_sequencer_enable(false)?;
            std::thread::sleep(std::time::Duration::from_millis(100));
            self.width = width;
            self.height = height;
            self.cam_i2c
                .set_roi0(self.width as u16, self.height as u16, None, None)?;
            unsafe {
                self.reg_sys.write_reg(SYSREG_IMAGE_WIDTH, self.width);
                self.reg_sys.write_reg(SYSREG_IMAGE_HEIGHT, self.height);
                self.reg_fmtr
                    .write_reg(REG_VIDEO_FMTREG_PARAM_WIDTH, self.width);
                self.reg_fmtr
                    .write_reg(REG_VIDEO_FMTREG_PARAM_HEIGHT, self.height);
                self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x03);
            }
            self.cam_i2c.set_sequencer_enable(true)?;
        } else {
            self.width = width;
            self.height = height;
        }
        Ok(())
    }

    pub fn image_width(&self) -> usize {
        self.width
    }
    pub fn image_height(&self) -> usize {
        self.height
    }

    pub fn set_gain(&mut self, db: f32) -> Result<(), Box<dyn Error>> {
        if self.opend {
            self.cam_i2c.set_gain_db(db)?;
            self.gain = self.cam_i2c.gain_db();
        } else {
            self.gain = db;
        }
        Ok(())
    }

    pub fn gain(&self) -> f32 {
        self.gain
    }

    pub fn set_exposure(&mut self, us : f32) -> Result<(), Box<dyn Error>> {
        let unit =  (self.mult_timer as f32) / 72.0;
        self.exposure = (us / unit) as u16;
        if self.opend {
            self.cam_i2c.set_exposure0(self.exposure)?;
        }
        Ok(())
    }

    pub fn exposure(&self) -> Result<f32, Box<dyn Error>> {
        let unit =  (self.mult_timer as f32) / 72.0;
        Ok(self.exposure as f32 * unit)
    }
    
    pub fn set_fr_length(&mut self, us : f32) -> Result<(), Box<dyn Error>> {
        let unit =  72.0 / (self.mult_timer as f32);
        self.fr_length = (us / unit) as u16;
        if self.opend {
            self.cam_i2c.set_fr_length0(self.exposure)?;
        }
        Ok(())
    }

    /// fps 計測
    pub fn measure_fps(&self) -> f32 {
        let fps_count   = unsafe{self.reg_sys.read_reg(SYSREG_FPS_COUNT)};
        250_000_000.0f32 / fps_count as f32
    }

    pub fn measure_frame_period(&self) -> f32 {
        let fps_count = unsafe{self.reg_sys.read_reg(SYSREG_FPS_COUNT)};
        fps_count as f32 * 4.0
    }


    // debug用
    pub fn print_timing_status(&mut self) {
        for i in 1..5 {
            let mult = 10*i;
            let fr_length = 1000;
            let exposure  = 1000-i;
            self.cam_i2c.set_mult_timer0(mult).unwrap();
            self.cam_i2c.set_fr_length0(fr_length).unwrap();
            self.cam_i2c.set_exposure0(exposure).unwrap();
            std::thread::sleep(std::time::Duration::from_millis(100));
            println!("-----------");
            println!("mult={} fr_length={} exposure={}", mult, fr_length, exposure);
            println!("fps: {}  {}[ns]", self.measure_fps(), self.measure_frame_period());

            let mult_timer_status   =  self.cam_i2c.mult_timer_status().unwrap();
            let reset_length_status =  self.cam_i2c.reset_length_status().unwrap();
            let exposure_status     =  self.cam_i2c.exposure_status().unwrap();
            println!("mult_timer   : {}", self.cam_i2c.mult_timer_status().unwrap());
            println!("reset_length : {}", self.cam_i2c.reset_length_status().unwrap());
            println!("exposure     : {}", self.cam_i2c.exposure_status().unwrap());
            println!("time : {}", (mult_timer_status as f32 * (exposure_status as f32 + reset_length_status as f32)) as f32 * 13.888888);
            let measure_ns = self.measure_frame_period() as f32;
            let calc_ns = (mult_timer_status as f32 * (exposure_status as f32 + reset_length_status as f32)) as f32 * 13.888888;
            println!("diff : {} ns", measure_ns - calc_ns);
        }
    }
}


// オブジェクト解放時にクローズ
impl<I2C, U> Drop for CameraDriver<I2C, U>
where
    I2C: I2cHal,
    <I2C as I2cHal>::Error: std::error::Error + 'static,
    U: Copy + Clone,
{
    fn drop(&mut self) {
        let _ = self.close();
    }
}
