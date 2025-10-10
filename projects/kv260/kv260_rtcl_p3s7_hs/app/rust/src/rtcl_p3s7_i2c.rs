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

pub struct RtclP3s7I2c<I2C: I2cAccess, F>
where
    F: Fn(u64),
{
    i2c: I2C,
    usleep: F,
}

impl<I2C: I2cAccess, F> RtclP3s7I2c<I2C, F>
where
    F: Fn(u64),
{
    pub fn new(i2c: I2C, usleep: F) -> Self {
        Self { i2c, usleep }
    }

    #[cfg(feature = "std")]
    pub fn new_with_linux(
        devname: &str,
    ) -> Result<RtclP3s7I2c<LinuxI2c, fn(u64)>, Box<dyn std::error::Error>> {
        let i2c = LinuxI2c::new(devname, 0x10)?;
        let sleep_fn: fn(u64) = |t| std::thread::sleep(std::time::Duration::from_micros(t));
        Ok(RtclP3s7I2c::new(i2c, sleep_fn))
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
    pub fn set_dphy_speed(&mut self, speed: f64) -> Result<(), RtclP3s7I2cError<I2C::Error>>
    {
        // MMCM set reset
        self.write_s7_reg(REG_P3S7_MMCM_CONTROL, 1)?;

        if speed >= 1250000000.0 {
            // D-PHY 1250Mbps用設定
            for i in 0..MMCM_TBL_1250.len() {
                self.write_s7_reg(REG_P3S7_MMCM_DRP + MMCM_TBL_1250[i].0, MMCM_TBL_1250[i].1)?;
            }
        }
        else if speed >= 950000000.0 {
            // D-PHY 950Mbps用設定
            for i in 0..MMCM_TBL_1250.len() {
                self.write_s7_reg(REG_P3S7_MMCM_DRP + MMCM_TBL_950[i].0, MMCM_TBL_950[i].1)?;
            }
        }
        else {
            return Err(RtclP3s7I2cError::MyError);
        }

        // MMCM release reset
        self.write_s7_reg(REG_P3S7_MMCM_CONTROL, 0)?;
        (self.usleep)(100);

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
