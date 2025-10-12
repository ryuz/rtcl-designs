#![allow(dead_code)]

use std::error::Error;
use std::result::Result;

use rtcl_lib::rtcl_p3s7_i2c::*;
use jelly_lib::linux_i2c::LinuxI2c;
//use jelly_lib::{i2c_access::I2cAccess, linux_i2c::LinuxI2c};
use jelly_mem_access::*;
use jelly_pac::video_dma_control::VideoDmaControl;


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


type RtclP3s7I2cLinux = RtclP3s7I2c<LinuxI2c>;

pub struct RtclP3s7Control
{
    cam_i2c: RtclP3s7I2cLinux,
    udmabuf0 : UdmabufAccessor::<usize>,
    udmabuf1 : UdmabufAccessor::<usize>,
    reg_sys : UioAccessor::<usize>,
    reg_timgen : UioAccessor::<usize>,
    reg_fmtr : UioAccessor::<usize>,
    wdma_img: VideoDmaControl<UioAccessor<usize>>,
    wdma_blk: VideoDmaControl<UioAccessor<usize>>,

    opend: bool,
    width: usize,
    height: usize,
}

fn wait_1us() {
    std::thread::sleep(std::time::Duration::from_micros(1));
}


impl RtclP3s7Control {
    pub fn new() -> Result<Self, Box<dyn Error>> {
        let cam_i2c  = RtclP3s7I2cLinux::new_with_linux("/dev/i2c-6")?;
        let udmabuf0 = UdmabufAccessor::<usize>::new("udmabuf-jelly-vram0", false)?;
        let udmabuf1 = UdmabufAccessor::<usize>::new("udmabuf-jelly-vram1", false)?;
        let uio_acc = UioAccessor::<usize>::new_with_name("uio_pl_peri")?;
        let reg_sys = uio_acc.subclone(0x00000000, 0x400);
        let reg_timgen = uio_acc.subclone(0x00010000, 0x400);
        let reg_fmtr = uio_acc.subclone(0x00100000, 0x400);
        let reg_wdma_img = uio_acc.subclone(0x00210000, 0x400);
        let reg_wdma_blk = uio_acc.subclone(0x00220000, 0x400);
        let wdma_img = VideoDmaControl::new(reg_wdma_img, 2, 2, Some(wait_1us)).unwrap();
        let wdma_blk = VideoDmaControl::new(reg_wdma_blk, 2, 2, Some(wait_1us)).unwrap();
        Ok(Self {
            cam_i2c ,
            udmabuf0,
            udmabuf1,
            reg_sys    ,
            reg_timgen ,
            reg_fmtr   ,
            wdma_img   ,
            wdma_blk   ,
            opend: false,
            width: 640,
            height: 480,
        })
    }

    pub fn opend(&self) -> bool {
        self.opend
    }

    pub fn open(&mut self) -> Result<(), Box<dyn Error>> {
        if self.opend {
            return Ok(());
        }

        // カメラモジュールリセット
        unsafe {
            self.reg_sys.write_reg(SYSREG_CAM_ENABLE, 0); // センサー電源OFF
            std::thread::sleep(std::time::Duration::from_millis(10));
            self.reg_sys.write_reg(SYSREG_CAM_ENABLE, 1); // センサー電源OFF
            std::thread::sleep(std::time::Duration::from_millis(10));
        }

        // MMCM 設定
        self.cam_i2c.set_dphy_speed(1250000000.0)?; // 1250Mbps

        // 受信側 DPHY リセット
        unsafe {
            self.reg_sys.write_reg(SYSREG_DPHY_SW_RESET, 1);
        }

        // カメラ基板初期化
        println!("Init Camera");
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

        // センサー基板 DPHY-TX リセット解除
        self.cam_i2c.set_dphy_reset(false)?;
        if !self.cam_i2c.dphy_init_done()? {
            return Err("CAM DPHY TX init_done = 0".into());
        }

        // ここで RX 側も init_done が来る
        if unsafe { self.reg_sys.read_reg(SYSREG_DPHY_INIT_DONE)} == 0 {
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
        self.cam_i2c.set_roi0(self.width as u16, self.height as u16, None, None)?;

        // 動作開始
        self.cam_i2c.set_sequencer_enable(true)?;

        // video input start
        unsafe {
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN, 1);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT, 20000000);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_WIDTH, self.width);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_HEIGHT, self.height);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_FILL, 0xffff);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_PARAM_TIMEOUT, 100000);
            self.reg_fmtr.write_reg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x03);
        }
        std::thread::sleep(std::time::Duration::from_micros(1000));

        self.opend = true;

        Ok(())
    }

    fn close(&mut self) -> Result<(), Box<dyn Error>> {
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



}
