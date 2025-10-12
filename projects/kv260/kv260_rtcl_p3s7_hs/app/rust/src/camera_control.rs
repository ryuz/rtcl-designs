#![allow(dead_code)]

use std::error::Error;
use std::result::Result;

use jelly_lib::i2c_access::I2cAccess;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
use rtcl_lib::rtcl_p3s7_i2c::*;

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

type RtclP3s7I2cLinux = RtclP3s7I2c<LinuxI2c>;
type RegAccess = UdmabufAccessor<usize>;

pub struct CameraControl<I2C, U>
where
    I2C: I2cAccess,
    U: Copy + Clone,
{
    cam_i2c: RtclP3s7I2c<I2C>,
    reg_sys: UioAccessor<U>,
    reg_fmtr: UioAccessor<U>,

    opend: bool,
    width: usize,
    height: usize,
    gain: f32,
}

impl<I2C, U> CameraControl<I2C, U>
where
    I2C: I2cAccess,
    <I2C as I2cAccess>::Error: std::error::Error + 'static,
    U: Copy + Clone,
{
    pub fn new(i2c: I2C, reg_sys: UioAccessor<U>, reg_fmtr: UioAccessor<U>) -> Self {
        Self {
            cam_i2c: RtclP3s7I2c::new(i2c),
            reg_sys,
            reg_fmtr,
            opend: false,
            width: 640,
            height: 480,
            gain: 1.0,
        }
    }

    pub fn opend(&self) -> bool {
        self.opend
    }

    pub fn open(&mut self) -> Result<(), Box<dyn Error>>
    where
        <I2C as I2cAccess>::Error: std::error::Error + 'static,
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

        // 動作開始
        self.cam_i2c.set_sequencer_enable(true)?;

        self.opend = true;
        Ok(())
    }

    pub fn close(&mut self) -> Result<(), Box<dyn Error>>
    where
        <I2C as I2cAccess>::Error: std::error::Error + 'static,
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
}
