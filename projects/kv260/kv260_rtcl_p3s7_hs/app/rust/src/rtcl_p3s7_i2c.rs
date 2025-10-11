#![allow(dead_code)]

use jelly_lib::i2c_access::I2cAccess;

#[cfg(feature = "std")]
use jelly_lib::linux_i2c::LinuxI2c;

const REG_P3S7_MODULE_ID: u16 = 0x0000;
const REG_P3S7_MODULE_VERSION: u16 = 0x0001;
const REG_P3S7_SENSOR_ENABLE: u16 = 0x0004;
const REG_P3S7_SENSOR_READY: u16 = 0x0008;
const REG_P3S7_RECEIVER_RESET: u16 = 0x0010;
const REG_P3S7_RECEIVER_CLK_DLY: u16 = 0x0012;
const REG_P3S7_ALIGN_RESET: u16 = 0x0020;
const REG_P3S7_ALIGN_PATTERN: u16 = 0x0022;
const REG_P3S7_ALIGN_STATUS: u16 = 0x0028;
const REG_P3S7_CLIP_ENABLE: u16 = 0x0040;
const REG_P3S7_CSI_MODE: u16 = 0x0050;
const REG_P3S7_CSI_DT: u16 = 0x0052;
const REG_P3S7_CSI_WC: u16 = 0x0053;
const REG_P3S7_DPHY_CORE_RESET: u16 = 0x0080;
const REG_P3S7_DPHY_SYS_RESET: u16 = 0x0081;
const REG_P3S7_DPHY_INIT_DONE: u16 = 0x0088;
const REG_P3S7_MMCM_CONTROL: u16 = 0x00a0;
const REG_P3S7_PLL_CONTROL: u16 = 0x00a1;
const REG_P3S7_MMCM_DRP: u16 = 0x1000;

#[derive(Debug, PartialEq, Eq, Copy, Clone)]
pub enum RtclP3s7I2cError<E> {
    I2c(E),
    ReceiverCalibrationFailed,
    MyError,
}

impl<E> From<E> for RtclP3s7I2cError<E> {
    fn from(error: E) -> Self {
        RtclP3s7I2cError::I2c(error)
    }
}

impl<E: core::fmt::Display> core::fmt::Display for RtclP3s7I2cError<E> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            RtclP3s7I2cError::I2c(e) => write!(f, "I2C operation failed: {}", e),
            RtclP3s7I2cError::ReceiverCalibrationFailed => write!(f, "Receiver calibration failed"),
            RtclP3s7I2cError::MyError => write!(f, "MyError occurred"),
        }
    }
}

#[cfg(feature = "std")]
impl<E: std::error::Error + 'static> std::error::Error for RtclP3s7I2cError<E> {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            RtclP3s7I2cError::I2c(e) => Some(e),
            _ => None,
        }
    }
}

pub enum CameraMode {
    HighSpeed = 0,
    Csi2 = 1,
}

pub struct RtclP3s7I2c<I2C: I2cAccess, F>
where
    F: Fn(u64),
{
    i2c: I2C,
    usleep: F,

    general_configuration : u16,
}

impl<I2C: I2cAccess, F> RtclP3s7I2c<I2C, F>
where
    F: Fn(u64),
{
    pub fn new(i2c: I2C, usleep: F) -> Self {
        Self { i2c, usleep, general_configuration: 0x0000 }
    }

    #[cfg(feature = "std")]
    pub fn new_with_linux(
        devname: &str,
    ) -> Result<RtclP3s7I2c<LinuxI2c, fn(u64)>, Box<dyn std::error::Error>> {
        let i2c = LinuxI2c::new(devname, 0x10)?;
        let sleep_fn: fn(u64) = |t| std::thread::sleep(std::time::Duration::from_micros(t));
        Ok(RtclP3s7I2c::new(i2c, sleep_fn))
    }

    pub fn module_id(&mut self) -> Result<u16, RtclP3s7I2cError<I2C::Error>> {
        self.read_s7_reg(REG_P3S7_MODULE_ID)
    }

    pub fn module_version(&mut self) -> Result<u16, RtclP3s7I2cError<I2C::Error>> {
        self.read_s7_reg(REG_P3S7_MODULE_VERSION)
    }

    pub fn sensor_id(&mut self) -> Result<u16, RtclP3s7I2cError<I2C::Error>> {
        self.read_p3_spi(0)
    }

    pub fn set_sensor_power_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        // センサー電源ON/OFF
        self.write_s7_reg(REG_P3S7_SENSOR_ENABLE, if enable { 1 } else { 0 })?;
        self.usleep(50000);
        Ok(())
    }

    pub fn set_dphy_reset(&mut self, reset: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if reset {
            self.write_s7_reg(REG_P3S7_DPHY_SYS_RESET, 1)?;
            self.write_s7_reg(REG_P3S7_DPHY_CORE_RESET, 1)?;
        } else {
            self.write_s7_reg(REG_P3S7_DPHY_CORE_RESET, 0)?;
            self.write_s7_reg(REG_P3S7_DPHY_SYS_RESET, 0)?;
        }
        self.usleep(100);
        Ok(())
    }

    pub fn dphy_init_done(&mut self) -> Result<bool, RtclP3s7I2cError<I2C::Error>> {
        Ok(self.read_s7_reg(REG_P3S7_DPHY_INIT_DONE)? != 0)
    }

    pub fn set_camera_mode(
        &mut self,
        mode: CameraMode,
    ) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        self.write_s7_reg(REG_P3S7_CSI_MODE, mode as u16)?;
        Ok(())
    }

    pub fn setup(&mut self) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        // SPI 初期設定
        self.write_p3_spi(16, 0x0003)?;    // power_down  0:pwd_n, 1:PLL enable, 2: PLL Bypass
        self.write_p3_spi(32, 0x0007)?;    // config0 (10bit mode) 0: enable_analog, 1: enabale_log, 2: select PLL
        self.write_p3_spi( 8, 0x0000)?;    // pll_soft_reset, pll_lock_soft_reset
        self.write_p3_spi( 9, 0x0000)?;    // cgen_soft_reset
        self.write_p3_spi(34, 0x1)?;       // config0 Logic General Enable Configuration
        self.write_p3_spi(40, 0x7)?;       // image_core_config0 
        self.write_p3_spi(48, 0x1)?;       // AFE Power down for AFE’s
        self.write_p3_spi(64, 0x1)?;       // Bias Bias Power Down Configuration
        self.write_p3_spi(72, 0x2227)?;    // Charge Pump
        self.write_p3_spi(112, 0x7)?;      // Serializers/LVDS/IO 
        self.write_p3_spi(10, 0x0000)?;    // soft_reset_analog
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// シーケンサ有効/無効
    pub fn set_sequencer_enable(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            self.general_configuration |= 0x1;
        } else {
            self.general_configuration &= !0x1;
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// ZROTモード有効/無効
    pub fn set_zero_rot_enable(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 2;
        } else {
            self.general_configuration &= !(1 << 2);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// トリガーモード有効/無効
    pub fn set_triggered_mode(&mut self, triggered_mode: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if triggered_mode {
            self.general_configuration |= 1 << 4;
        } else {
            self.general_configuration &= !(1 << 4);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// スレーブモード有効/無効
    pub fn set_slave_mode(&mut self, slave_mode: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if slave_mode {
            self.general_configuration |= 1 << 5;
        } else {
            self.general_configuration &= !(1 << 5);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// NZROT XSM Delay 有効/無効
    pub fn set_nzrot_xsm_delay_enable(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 6;
        } else {
            self.general_configuration &= !(1 << 6);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// サブサンプリング有効/無効
    pub fn set_subsampling(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 7;
        } else {
            self.general_configuration &= !(1 << 7);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// ビニング有効/無効
    pub fn set_binning(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 8;
        } else {
            self.general_configuration &= !(1 << 8);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// ROI AEC 有効/無効
    pub fn set_roi_aec_enable(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 10;
        } else {
            self.general_configuration &= !(1 << 10);
        }
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// モニタセレクト設定
    pub fn set_monitor_select(&mut self, mode: u16) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        let mode = mode & 0x7;
        self.general_configuration &= !(0x7 << 11);
        self.general_configuration |= mode << 11;
        self.write_p3_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// XSM Delay 設定
    pub fn set_xsm_delay(&mut self, delay: u16) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        let delay = delay & 0xff;
        self.write_p3_spi(193, delay << 8)?;
        Ok(())
    }

    /// ROI0 設定
    pub fn set_roi0(&mut self, width : u16, height : u16, x : Option<u16>, y : Option<u16>) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        // 正規化
        let width  = width.max(16).min(672) & !0x0f;  // 16の倍数
        let height = height.max(2).min(512) & !0x01; // 2の倍数

        // x, y が None なら中央に配置
        let roi_x = match x {
            Some(val) => val,
            None => (672 - width) / 2,
        } & !0x0f; // 16の倍数
        let roi_y = match y {
            Some(val) => val,
            None => (512 - height) / 2,
        } & !0x01; // 2の倍数

        let x_start = roi_x / 8;
        let x_end   = x_start + width/8 - 1 ;
        let y_start = roi_y;
        let y_end   = y_start + height - 1;

        self.write_p3_spi(256, (x_end << 8) | x_start)?;
        self.write_p3_spi(257, y_start)?;
        self.write_p3_spi(258, y_end)?;

        Ok(())
    }

pub fn set_sensor_receiver_enable(&mut self, enable: bool) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        if enable {
            // シーケンサ停止(トレーニングパターン出力状態へ)
            self.set_sequencer_enable(false)?;

            self.usleep(1000);
            self.write_s7_reg(REG_P3S7_RECEIVER_RESET,  1)?;
            self.write_s7_reg(REG_P3S7_RECEIVER_CLK_DLY, 8)?;
            self.write_s7_reg(REG_P3S7_ALIGN_RESET, 1)?;
            self.usleep(1000);
            self.write_s7_reg(REG_P3S7_RECEIVER_RESET,  0)?;
            self.usleep(1000);
            self.write_s7_reg(REG_P3S7_ALIGN_RESET, 0)?;
            self.usleep(1000);

            let cam_calib_status = self.read_s7_reg(REG_P3S7_ALIGN_STATUS)?;
            if cam_calib_status != 0x01 {
                return Err(RtclP3s7I2cError::ReceiverCalibrationFailed);
            }
        }
        else {
            self.write_s7_reg(REG_P3S7_RECEIVER_RESET, 1)?;
            self.write_s7_reg(REG_P3S7_ALIGN_RESET, 1)?;
        }
        Ok(())
    }


    /// usleep
    fn usleep(&self, usec: u64) {
        (self.usleep)(usec);
    }

    /// Write a 16-bit register on the Spartan-7
    pub fn write_s7_reg(
        &mut self,
        addr: u16,
        data: u16,
    ) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
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
    pub fn read_s7_reg(&mut self, addr: u16) -> Result<u16, RtclP3s7I2cError<I2C::Error>> {
        let addr = addr << 1;
        let wbuf: [u8; 4] = [((addr >> 8) & 0xff) as u8, ((addr >> 0) & 0xff) as u8, 0, 0];
        self.i2c.write(&wbuf)?;
        let mut rbuf: [u8; 2] = [0; 2];
        self.i2c.read(&mut rbuf)?;
        Ok(rbuf[0] as u16 | ((rbuf[1] as u16) << 8))
    }

    /// Write a 16-bit register on the PYTHON300 SPI
    pub fn write_p3_spi(
        &mut self,
        addr: u16,
        data: u16,
    ) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        let addr = addr | (1 << 14);
        self.write_s7_reg(addr, data)
    }

    /// Read a 16-bit register on the PYTHON300 SPI
    pub fn read_p3_spi(&mut self, addr: u16) -> Result<u16, RtclP3s7I2cError<I2C::Error>> {
        let addr = addr | (1 << 14);
        self.read_s7_reg(addr)
    }

    // DPHY スピード設定
    pub fn set_dphy_speed(&mut self, speed: f64) -> Result<(), RtclP3s7I2cError<I2C::Error>> {
        // MMCM set reset
        self.write_s7_reg(REG_P3S7_MMCM_CONTROL, 1)?;

        if speed >= 1250000000.0 {
            // D-PHY 1250Mbps用設定
            for i in 0..MMCM_TBL_1250.len() {
                self.write_s7_reg(REG_P3S7_MMCM_DRP + MMCM_TBL_1250[i].0, MMCM_TBL_1250[i].1)?;
            }
        } else if speed >= 950000000.0 {
            // D-PHY 950Mbps用設定
            for i in 0..MMCM_TBL_1250.len() {
                self.write_s7_reg(REG_P3S7_MMCM_DRP + MMCM_TBL_950[i].0, MMCM_TBL_950[i].1)?;
            }
        } else {
            return Err(RtclP3s7I2cError::MyError);
        }

        // MMCM release reset
        self.write_s7_reg(REG_P3S7_MMCM_CONTROL, 0)?;
        self.usleep(100);

        Ok(())
    }
}

const MMCM_TBL_1250: [(u16, u16); 24] = [
    (0x06, 0x0041),
    (0x07, 0x0040),
    (0x08, 0x1041),
    (0x09, 0x0000),
    (0x0a, 0x9041),
    (0x0b, 0x0000),
    (0x0c, 0x0041),
    (0x0d, 0x0040),
    (0x0e, 0x0041),
    (0x0f, 0x0040),
    (0x10, 0x0041),
    (0x11, 0x0040),
    (0x12, 0x0041),
    (0x13, 0x0040),
    (0x14, 0x130d),
    (0x15, 0x0080),
    (0x16, 0x1041),
    (0x18, 0x0190),
    (0x19, 0x7c01),
    (0x1a, 0xffe9),
    (0x27, 0x0000),
    (0x28, 0x0100),
    (0x4e, 0x1108),
    (0x4f, 0x9000),
];

const MMCM_TBL_950: [(u16, u16); 24] = [
    (0x06, 0x0041),
    (0x07, 0x0040),
    (0x08, 0x1041),
    (0x09, 0x0000),
    (0x0a, 0x9041),
    (0x0b, 0x0000),
    (0x0c, 0x0041),
    (0x0d, 0x0040),
    (0x0e, 0x0041),
    (0x0f, 0x0040),
    (0x10, 0x0041),
    (0x11, 0x0040),
    (0x12, 0x0041),
    (0x13, 0x0040),
    (0x14, 0x124a),
    (0x15, 0x0080),
    (0x16, 0x1041),
    (0x18, 0x020d),
    (0x19, 0x7c01),
    (0x1a, 0xffe9),
    (0x27, 0x0000),
    (0x28, 0x0100),
    (0x4e, 0x9008),
    (0x4f, 0x0100),
];
