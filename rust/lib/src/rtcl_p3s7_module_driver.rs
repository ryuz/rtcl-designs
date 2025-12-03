#![allow(dead_code)]

//! RTCL P3S7 Module Driver
//!
//! This module provides a comprehensive driver for the RTCL P3S7 camera module, which combines
//! a Spartan-7 FPGA with a PYTHON300 image sensor. The driver supports various camera operations
//! including sensor configuration, gain control, ROI settings, D-PHY speed configuration, and
//! low-level register access.
//!
//! # Features
//!
//! - Sensor power management and initialization
//! - Camera mode configuration (High Speed / CSI-2)
//! - Analog and digital gain control
//! - ROI (Region of Interest) configuration
//! - D-PHY speed settings for different data rates
//! - Exposure and timing control
//! - Sequencer and trigger mode support
//!
//! # Example
//!
//! ```no_run
//! # use rtcl_p3s7_module_driver::RtclP3s7ModuleDriver;
//! # fn example() -> Result<(), Box<dyn std::error::Error>> {
//! #[cfg(feature = "std")]
//! let mut driver = RtclP3s7ModuleDriver::new_with_linux("/dev/i2c-1")?;
//! 
//! // Initialize the camera
//! driver.set_sensor_power_enable(true)?;
//! driver.set_camera_mode(rtcl_p3s7_module_driver::CameraMode::Csi2)?;
//! driver.set_sensor_enable(true)?;
//! 
//! // Configure gain
//! driver.set_gain_db(6.0)?;
//! 
//! // Set ROI
//! driver.set_roi0(320, 240, None, None)?;
//! # Ok(())
//! # }
//! ```

use jelly_lib::i2c_hal::I2cHal;

#[cfg(feature = "std")]
use jelly_lib::linux_i2c::LinuxI2c;

// Spartan-7 FPGA register addresses

/// Module identification register
const REG_P3S7_MODULE_ID: u16 = 0x0000;
/// Module version register
const REG_P3S7_MODULE_VERSION: u16 = 0x0001;
/// Module configuration register
const REG_P3S7_MODULE_CONFIG: u16 = 0x0002;
/// Software reset
const REG_P3S7_SW_RESET: u16 = 0x0003;
/// Sensor enable control register
const REG_P3S7_SENSOR_ENABLE: u16 = 0x0004;
/// Sensor ready status register
const REG_P3S7_SENSOR_READY: u16 = 0x0008;
/// Sensor power good status register
const REG_P3S7_SENSOR_PGOOD    : u16 = 0x000c;
/// Sensor power good enable register
const REG_P3S7_SENSOR_PGOOD_EN : u16 = 0x000d;
/// Receiver reset control register
const REG_P3S7_RECEIVER_RESET: u16 = 0x0010;
/// Receiver clock delay control register
const REG_P3S7_RECEIVER_CLK_DLY: u16 = 0x0012;
/// Alignment reset control register
const REG_P3S7_ALIGN_RESET: u16 = 0x0020;
/// Alignment pattern register
const REG_P3S7_ALIGN_PATTERN: u16 = 0x0022;
/// Alignment status register
const REG_P3S7_ALIGN_STATUS: u16 = 0x0028;
/// Clip enable control register
const REG_P3S7_CLIP_ENABLE: u16 = 0x0040;
/// CSI mode control register
const REG_P3S7_CSI_MODE: u16 = 0x0050;
/// CSI data type register
const REG_P3S7_CSI_DT: u16 = 0x0052;
/// CSI word count register
const REG_P3S7_CSI_WC: u16 = 0x0053;
/// D-PHY core reset control register
const REG_P3S7_DPHY_CORE_RESET: u16 = 0x0080;
/// D-PHY system reset control register
const REG_P3S7_DPHY_SYS_RESET: u16 = 0x0081;
/// D-PHY initialization done status register
const REG_P3S7_DPHY_INIT_DONE: u16 = 0x0088;
/// MMCM control register
const REG_P3S7_MMCM_CONTROL: u16 = 0x00a0;
/// PLL control register
const REG_P3S7_PLL_CONTROL: u16 = 0x00a1;
/// MMCM DRP base register
const REG_P3S7_MMCM_DRP: u16 = 0x1000;

/// Error types for RTCL P3S7 Module Driver operations
#[derive(Debug, PartialEq, Eq, Copy, Clone)]
pub enum RtclP3s7ModuleDriverError<E> {
    /// I2C communication error
    I2c(E),
    //// Unsupported D-PHY speed setting
    UnsupportedDphySpeed,
    /// Receiver calibration failed during initialization
    ReceiverCalibrationFailed,
    /// SPI Flash operation timeout
    SpiRomOperationTimeout,
    /// Sensor power good signal indicates failure
    SensorPowerGoodFailed,
}

impl<E> From<E> for RtclP3s7ModuleDriverError<E> {
    fn from(error: E) -> Self {
        RtclP3s7ModuleDriverError::I2c(error)
    }
}

impl<E: core::fmt::Display> core::fmt::Display for RtclP3s7ModuleDriverError<E> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            RtclP3s7ModuleDriverError::I2c(e) => write!(f, "I2C operation failed: {}", e),
            RtclP3s7ModuleDriverError::UnsupportedDphySpeed => write!(f, "Unsupported D-PHY speed setting"),
            RtclP3s7ModuleDriverError::ReceiverCalibrationFailed => write!(f, "Receiver calibration failed"),
            RtclP3s7ModuleDriverError::SpiRomOperationTimeout => write!(f, "SPI ROM operation timeout"),
            RtclP3s7ModuleDriverError::SensorPowerGoodFailed => write!(f, "Sensor power good signal indicates failure"),
        }
    }
}

#[cfg(feature = "std")]
impl<E: std::error::Error + 'static> std::error::Error for RtclP3s7ModuleDriverError<E> {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            RtclP3s7ModuleDriverError::I2c(e) => Some(e),
            _ => None,
        }
    }
}

/// Camera operation modes
pub enum CameraMode {
    /// High Speed mode
    HighSpeed = 0,
    /// CSI-2 mode for MIPI compatibility
    Csi2 = 1,
}

/// RTCL P3S7 Module Driver
/// 
/// Main driver struct for controlling the RTCL P3S7 camera module.
/// Provides high-level and low-level access to camera functions including
/// sensor configuration, gain control, timing settings, and D-PHY configuration.
pub struct RtclP3s7ModuleDriver<I2C: I2cHal>
{
    /// I2C interface for communication with the module
    i2c: I2C,
    /// Sleep function for timing delays
    usleep: fn(u64),
    /// General configuration register cache
    general_configuration: u16,
    /// Current analog gain setting (linear scale)
    analog_gain : f32,
    /// Current digital gain setting (linear scale)
    digital_gain : f32,
}

/// Default sleep function using portable delay
fn usleep(us : u64) {
    let duration = core::time::Duration::from_micros(us);
    jelly_lib::portable_delay(duration);
}


impl<I2C: I2cHal> RtclP3s7ModuleDriver<I2C>
{
    /// Create a new driver instance with default sleep function
    /// 
    /// # Arguments
    /// 
    /// * `i2c` - I2C interface implementation
    /// 
    /// # Returns
    /// 
    /// A new `RtclP3s7ModuleDriver` instance
    pub fn new(i2c: I2C) -> Self {
        Self::new_with_usleep(i2c, usleep)
    }

    /// Create a new driver instance with custom sleep function
    /// 
    /// # Arguments
    /// 
    /// * `i2c` - I2C interface implementation
    /// * `usleep` - Custom microsecond sleep function
    /// 
    /// # Returns
    /// 
    /// A new `RtclP3s7ModuleDriver` instance
    pub fn new_with_usleep(i2c: I2C, usleep: fn(u64)) -> Self {
        Self {
            i2c,
            usleep,
            general_configuration: 0x0000,
            analog_gain : 1.0,
            digital_gain : 1.0,
        }
    }

    /// Create a new driver instance using Linux I2C device
    /// 
    /// This method is only available when the `std` feature is enabled.
    /// 
    /// # Arguments
    /// 
    /// * `devname` - Path to the I2C device (e.g., "/dev/i2c-1")
    /// 
    /// # Returns
    /// 
    /// A new `RtclP3s7ModuleDriver` instance configured for Linux I2C
    /// 
    /// # Errors
    /// 
    /// Returns an error if the I2C device cannot be opened or configured
    #[cfg(feature = "std")]
    pub fn new_with_linux(
        devname: &str,
    ) -> Result<RtclP3s7ModuleDriver<LinuxI2c>, Box<dyn std::error::Error>> {
        let i2c = LinuxI2c::new(devname, 0x10)?;
        Ok(RtclP3s7ModuleDriver::new(i2c))
    }

    /// Get the module ID
    /// 
    /// # Returns
    /// 
    /// The module identification value
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn module_id(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_i2c(REG_P3S7_MODULE_ID)
    }

    /// Get the module version
    /// 
    /// # Returns
    /// 
    /// The module version value
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn module_version(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_i2c(REG_P3S7_MODULE_VERSION)
    }

    pub fn module_config(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_i2c(REG_P3S7_MODULE_CONFIG)
    }

    /// Get the sensor ID from PYTHON300
    /// 
    /// # Returns
    /// 
    /// The sensor identification value
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn sensor_id(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_sensor_spi(0)
    }

    pub fn set_color(&mut self, color: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        // chip_configuration
        self.write_sensor_spi(2, if color { 1 } else { 0 })?;
        Ok(())
    }

    pub fn softeare_reset(
        &mut self,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        // ソフトウェアリセット発行
        self.write_i2c(REG_P3S7_SW_RESET, 1)?;
        self.usleep(50000);
        Ok(())
    }

    pub fn sensor_pgood(
        &mut self
    ) -> Result<bool, RtclP3s7ModuleDriverError<I2C::Error>> {
        Ok(self.read_i2c(REG_P3S7_SENSOR_PGOOD)? != 0)
    }

    pub fn set_sensor_pgood_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_i2c(REG_P3S7_SENSOR_PGOOD_EN, if enable { 1 } else { 0 })?;
        Ok(())
    }

    pub fn spi_rom_command_write(&mut self, data: &[u8], last : bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let mut index = 0;
        while index < data.len() {
            if index + 1 < data.len() {
                let addr = if index + 2 >= data.len() && last { 0x5003 } else { 0x5002 };
                self.write_read_i2c(addr, ((data[index] as u16) << 8) | (data[index + 1] as u16))?;
                index += 2;
            } else {
                let addr = if index + 1 >= data.len() && last { 0x5001} else { 0x5000 };
                self.write_read_i2c(addr, (data[index] as u16) << 8)?;
                index += 1;
            }
        }
        Ok(())
    }

    pub fn spi_rom_command_read(&mut self, data: &mut [u8], last : bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let mut index = 0;
        while index < data.len() {
            if index + 1 < data.len() {
                let addr = if index + 2 >= data.len() && last { 0x5003 } else { 0x5002 };
                let d = self.write_read_i2c(addr, 0x0000)?;
                data[index] = ((d >> 8) & 0xff) as u8;
                index += 1;
                data[index] = ((d >> 0) & 0xff) as u8;
                index += 1;
            } else {
                let addr = if index + 1 >= data.len() && last { 0x5001} else { 0x5000 };
                let d = self.write_read_i2c(addr, 0x0000)?;
                data[index] = ((d >> 0) & 0xff) as u8;
                index += 1;
            }
        }
        Ok(())
    }

    pub fn spi_rom_id(
        &mut self,
    ) -> Result<[u8; 3], RtclP3s7ModuleDriverError<I2C::Error>> {
        let cmd : [u8; 1] = [
            0x9f,
        ];
        let mut data : [u8; 3] = [0; 3];
        self.spi_rom_command_write(&cmd, false)?;
        self.spi_rom_command_read(&mut data, true)?;
        Ok(data)
    }

    pub fn spi_rom_read(
        &mut self,
        addr: usize,
        data: &mut [u8],
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let cmd : [u8; 4] = [
            0x03,
            ((addr >> 16) & 0xff) as u8,
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 0) & 0xff) as u8,
        ];
        self.spi_rom_command_write(&cmd, false)?;
        self.spi_rom_command_read(data, true)?;
        Ok(())
    }

    pub fn spi_rom_write(
        &mut self,
        addr: usize,
        data: &[u8],
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let cmd : [u8; 4] = [
            0x02,
            ((addr >> 16) & 0xff) as u8,
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 0) & 0xff) as u8,
        ];
        self.spi_rom_command_write(&cmd, false)?;
        self.spi_rom_command_write(data, true)?;
        Ok(())
    }

    pub fn spi_rom_write_enable(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.spi_rom_command_write(&[0x06], true)?;
        Ok(())
    }

    pub fn spi_rom_write_disable(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.spi_rom_command_write(&[0x04], true)?;
        Ok(())
    }

    pub fn spi_rom_bulk_erase(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.spi_rom_command_write(&[0xc7], true)?;
        Ok(())
    }

    pub fn spi_rom_sector_erase(&mut self, addr: usize) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let cmd : [u8; 4] = [
            0x20,
            ((addr >> 16) & 0xff) as u8,
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 0) & 0xff) as u8,
        ];
        self.spi_rom_command_write(&cmd, true)?;
        Ok(())
    }

    pub fn spi_rom_read_status_register(&mut self) -> Result<u8, RtclP3s7ModuleDriverError<I2C::Error>> {
        let mut status = [0u8; 1];
        self.spi_rom_command_write(&[0x05], false)?;
        self.spi_rom_command_read(&mut status, true)?;
        Ok(status[0])
    }

    pub fn spi_rom_wait_ready(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        for _ in 0..10000 {
            if self.spi_rom_read_status_register()? & 0x01 == 0 {
                return Ok(());
            }
        }
        println!("status : {:02x}", self.spi_rom_read_status_register()?);
        Err(RtclP3s7ModuleDriverError::SpiRomOperationTimeout)
    }

    pub fn spi_rom_program(&mut self, addr: usize, data: &[u8]) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let mut addr = addr;
        for chunk in data.chunks(256) {
            self.spi_rom_write_enable()?;
            self.spi_rom_write(addr, chunk)?;
            addr += 256;
            self.spi_rom_wait_ready()?;
        }
//      self.spi_rom_write_disable()?;
        Ok(())
    }

    pub fn spi_rom_erase_region(&mut self, addr: usize, len: usize) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        assert!( addr % 4096 == 0 );
        for a in (addr..(addr+len)).step_by(4096) {
             self.spi_rom_write_enable()?;
             self.spi_rom_sector_erase(a)?;
             self.spi_rom_wait_ready()?;
        }
//      self.spi_rom_write_disable()?;
        Ok(())
    }



    /// Enable or disable sensor power
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable power, false to disable
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_sensor_power_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        // センサー電源ON/OFF
        self.write_i2c(REG_P3S7_SENSOR_ENABLE, if enable { 1 } else { 0 })?;
        self.usleep(50000);
        Ok(())
    }

    /// Reset or release D-PHY
    /// 
    /// # Arguments
    /// 
    /// * `reset` - True to reset, false to release
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_dphy_reset(&mut self, reset: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if reset {
            self.write_i2c(REG_P3S7_DPHY_SYS_RESET, 1)?;
            self.write_i2c(REG_P3S7_DPHY_CORE_RESET, 1)?;
        } else {
            self.write_i2c(REG_P3S7_DPHY_CORE_RESET, 0)?;
            self.write_i2c(REG_P3S7_DPHY_SYS_RESET, 0)?;
        }
        self.usleep(100);
        Ok(())
    }

    /// Check if D-PHY initialization is complete
    /// 
    /// # Returns
    /// 
    /// True if D-PHY initialization is done, false otherwise
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn dphy_init_done(&mut self) -> Result<bool, RtclP3s7ModuleDriverError<I2C::Error>> {
        Ok(self.read_i2c(REG_P3S7_DPHY_INIT_DONE)? != 0)
    }

    /// Set the camera operation mode
    /// 
    /// # Arguments
    /// 
    /// * `mode` - Camera mode (HighSpeed or Csi2)
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_camera_mode(
        &mut self,
        mode: CameraMode,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_i2c(REG_P3S7_CSI_MODE, mode as u16)?;
        Ok(())
    }

    /// Enable or disable the sensor
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable sensor, false to disable
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails or receiver calibration fails
    pub fn set_sensor_enable(&mut self, enable: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.sensor_boot()?;
            self.usleep(50000);
            self.set_sensor_receiver_enable(true)?;
        }
        else {
            self.set_sensor_receiver_enable(false)?;
            self.sensor_shutdown()?;
        }
        Ok(())
    }

    fn sensor_boot(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_sensor_spi(16, 0x0003)?; // power_down  0:pwd_n, 1:PLL enable, 2: PLL Bypass
        self.write_sensor_spi(32, 0x0007)?; // config0 (10bit mode) 0: enable_analog, 1: enabale_log, 2: select PLL
        self.write_sensor_spi(8, 0x0000)?; // pll_soft_reset, pll_lock_soft_reset
        self.write_sensor_spi(9, 0x0000)?; // cgen_soft_reset
        self.write_sensor_spi(34, 0x1)?; // config0 Logic General Enable Configuration
        self.write_sensor_spi(40, 0x7)?; // image_core_config0
        self.write_sensor_spi(48, 0x1)?; // AFE Power down for AFE’s
        self.write_sensor_spi(64, 0x1)?; // Bias Bias Power Down Configuration
        self.write_sensor_spi(72, 0x2227)?; // Charge Pump
        self.write_sensor_spi(112, 0x7)?; // Serializers/LVDS/IO
        self.write_sensor_spi(10, 0x0000)?; // soft_reset_analog
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    fn sensor_shutdown(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_sensor_spi(192, 0x0000)?;
        self.write_sensor_spi(10, 0x0999)?; // soft_reset_analog
        self.write_sensor_spi(112, 0x0000)?; // Serializers/LVDS/IO
        self.write_sensor_spi(72, 0x2220)?; // Charge Pump
        self.write_sensor_spi(64, 0x0000)?; // Bias Bias Power Down Configuration
        self.write_sensor_spi(48, 0x0000)?; // AFE Power down for AFE’s
        self.write_sensor_spi(40, 0x0000)?; // image_core_config0
        self.write_sensor_spi(34, 0x0000)?; // config0 Logic General Enable Configuration
        self.write_sensor_spi(9, 0x0009)?; // cgen_soft_reset
        self.write_sensor_spi(8, 0x0099)?; // pll_soft_reset, pll_lock_soft_reset
        self.write_sensor_spi(32, 0x0004)?; // config0 (10bit mode) 0: enable_analog, 1: enabale_log, 2: select PLL
        self.write_sensor_spi(16, 0x0004)?; // power_down  0:pwd_n, 1:PLL enable, 2: PLL Bypass
        Ok(())
    }

    /// Enable or disable the sensor sequencer
    /// 
    /// The sequencer controls the sensor's automatic exposure and timing operations.
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable sequencer, false to disable
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_sequencer_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.general_configuration |= 0x1;
        } else {
            self.general_configuration &= !0x1;
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// Enable or disable Zero ROT (Read Out Time) mode
    /// 
    /// Zero ROT mode minimizes the readout time for high-speed operation.
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable Zero ROT mode, false to disable
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_zero_rot_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 2;
        } else {
            self.general_configuration &= !(1 << 2);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// Enable or disable triggered capture mode
    /// 
    /// In triggered mode, image capture is synchronized to an external trigger signal.
    /// 
    /// # Arguments
    /// 
    /// * `triggered_mode` - True to enable triggered mode, false for free-running
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_triggered_mode(
        &mut self,
        triggered_mode: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if triggered_mode {
            self.general_configuration |= 1 << 4;
        } else {
            self.general_configuration &= !(1 << 4);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// Enable or disable slave mode operation
    /// 
    /// In slave mode, the sensor synchronizes to an external clock source.
    /// 
    /// # Arguments
    /// 
    /// * `slave_mode` - True to enable slave mode, false for master mode
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_slave_mode(&mut self, slave_mode: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if slave_mode {
            self.general_configuration |= 1 << 5;
        } else {
            self.general_configuration &= !(1 << 5);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// Enable or disable Non-Zero ROT XSM delay
    /// 
    /// Controls additional delay timing for Non-Zero Read Out Time operations.
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable NZROT XSM delay, false to disable
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_nzrot_xsm_delay_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 6;
        } else {
            self.general_configuration &= !(1 << 6);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// Enable or disable subsampling mode
    /// 
    /// Subsampling reduces the effective resolution by skipping pixels during readout.
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable subsampling, false for full resolution
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_subsampling(&mut self, enable: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 7;
        } else {
            self.general_configuration &= !(1 << 7);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// Enable or disable pixel binning mode
    /// 
    /// Binning combines adjacent pixels to increase sensitivity at the cost of resolution.
    /// 
    /// # Arguments
    /// 
    /// * `enable` - True to enable binning, false for normal operation
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_binning(&mut self, enable: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 8;
        } else {
            self.general_configuration &= !(1 << 8);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// ROI AEC 有効/無効
    pub fn set_roi_aec_enable(&mut self, enable: bool) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            self.general_configuration |= 1 << 10;
        } else {
            self.general_configuration &= !(1 << 10);
        }
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// モニタセレクト設定
    pub fn set_monitor_select(&mut self, mode: u16) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let mode = mode & 0x7;
        self.general_configuration &= !(0x7 << 11);
        self.general_configuration |= mode << 11;
        self.write_sensor_spi(192, self.general_configuration)?;
        Ok(())
    }

    /// XSM Delay 設定
    pub fn set_xsm_delay(&mut self, delay: u16) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let delay = delay & 0xff;
        self.write_sensor_spi(193, delay << 8)?;
        Ok(())
    }

    /// Set Region of Interest 0 (ROI0) configuration
    /// 
    /// Configures the primary region of interest for image capture.
    /// Width is automatically aligned to 16-pixel boundaries and height to 2-pixel boundaries.
    /// If x and y coordinates are not specified, the ROI will be centered.
    /// 
    /// # Arguments
    /// 
    /// * `width` - ROI width (16-672 pixels, must be multiple of 16)
    /// * `height` - ROI height (2-512 pixels, must be multiple of 2)
    /// * `x` - Optional X offset (if None, centers horizontally)
    /// * `y` - Optional Y offset (if None, centers vertically)
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_roi0(
        &mut self,
        width: u16,
        height: u16,
        x: Option<u16>,
        y: Option<u16>,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        // 正規化
        let width = width.max(16).min(672) & !0x0f; // 16の倍数
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
        let x_end = x_start + width / 8 - 1;
        let y_start = roi_y;
        let y_end = y_start + height - 1;

        self.write_sensor_spi(256, (x_end << 8) | x_start)?;
        self.write_sensor_spi(257, y_start)?;
        self.write_sensor_spi(258, y_end)?;

        Ok(())
    }

    pub fn set_sensor_receiver_enable(
        &mut self,
        enable: bool,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        if enable {
            // シーケンサ停止(トレーニングパターン出力状態へ)
            self.set_sequencer_enable(false)?;

            self.usleep(1000);
            self.write_i2c(REG_P3S7_RECEIVER_RESET, 1)?;
            self.write_i2c(REG_P3S7_RECEIVER_CLK_DLY, 8)?;
            self.write_i2c(REG_P3S7_ALIGN_RESET, 1)?;
            self.usleep(1000);
            self.write_i2c(REG_P3S7_RECEIVER_RESET, 0)?;
            self.usleep(1000);
            self.write_i2c(REG_P3S7_ALIGN_RESET, 0)?;
            self.usleep(1000);

            let cam_calib_status = self.read_i2c(REG_P3S7_ALIGN_STATUS)?;
            if cam_calib_status != 0x01 {
                if self.read_i2c(REG_P3S7_SENSOR_PGOOD_EN)? != 0 && self.read_i2c(REG_P3S7_SENSOR_PGOOD)? == 0 {
                    return Err(RtclP3s7ModuleDriverError::SensorPowerGoodFailed);
                }
                return Err(RtclP3s7ModuleDriverError::ReceiverCalibrationFailed);
            }
        } else {
            self.write_i2c(REG_P3S7_RECEIVER_RESET, 1)?;
            self.write_i2c(REG_P3S7_ALIGN_RESET, 1)?;
        }
        Ok(())
    }


    /// Set the analog gain (linear scale)
    /// 
    /// Configures the sensor's analog gain stage with predefined steps.
    /// 
    /// # Arguments
    /// 
    /// * `linear_gain` - Desired analog gain in linear scale
    ///   - >= 14.0: Sets to 14.0x gain
    ///   - >= 3.5: Sets to 3.5x gain  
    ///   - >= 1.9: Sets to 1.9x gain
    ///   - < 1.9: Sets to 1.0x gain (unity)
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_analog_gain_linear(&mut self, linear_gain: f32) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let (reg_val, gain) = if linear_gain >= 14.0 {
            (0x01e8, 14.0)
        } else if linear_gain >= 3.5 {
            (0x01e4, 3.5)
        } else if linear_gain >= 1.9 {
            (0x01e1, 1.9)
        } else {
            (0x01e3, 1.0)
        };
        self.write_sensor_spi(204, reg_val)?;
        self.analog_gain = gain;
        Ok(())
    }

    /// Get the current analog gain (linear scale)
    /// 
    /// # Returns
    /// 
    /// Current analog gain value in linear scale
    pub fn analog_gain_linear(&self) -> f32 {
        self.analog_gain
    }

    /// Set the digital gain (linear scale)
    /// 
    /// Configures the sensor's digital gain with fine-grained control.
    /// 
    /// # Arguments
    /// 
    /// * `linear_gain` - Digital gain in linear scale (quantized to 1/128 steps)
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_digital_gain_linear(&mut self, linear_gain: f32) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let reg_val = (linear_gain * 128.0).round() as u16;
        self.write_sensor_spi(205, reg_val)?;
        self.digital_gain = reg_val as f32 / 128.0;
        Ok(())
    }

    /// Get the current digital gain (linear scale)
    /// 
    /// # Returns
    /// 
    /// Current digital gain value in linear scale
    pub fn digital_gain_linear(&self) -> f32 {
        self.digital_gain
    }

    /// Set the total gain by optimally distributing between analog and digital stages
    /// 
    /// This method automatically selects the best analog gain setting and uses
    /// digital gain for the remainder to achieve the target total gain.
    /// 
    /// # Arguments
    /// 
    /// * `linear_gain` - Target total gain in linear scale
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_gain_linear(&mut self, mut linear_gain: f32) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.set_analog_gain_linear(linear_gain)?;
        linear_gain /= self.analog_gain_linear();
        self.set_digital_gain_linear(linear_gain)?;
        Ok(())
    }

    /// Get the total gain (linear scale)
    /// 
    /// # Returns
    /// 
    /// Combined analog and digital gain in linear scale
    pub fn gain_linear(&self) -> f32 {
        self.analog_gain_linear() * self.digital_gain_linear()
    }

    /// Set gain in dB
    /// 
    /// This method automatically distributes the gain between analog and digital
    /// components for optimal performance.
    /// 
    /// # Arguments
    /// 
    /// * `db_gain` - Total gain in decibels
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn set_gain_db(&mut self, db_gain: f32) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let linear_gain = 10f32.powf(db_gain / 20.0);
        self.set_gain_linear(linear_gain)
    }

    /// Get gain in dB
    /// 
    /// # Returns
    /// 
    /// Current total gain in decibels
    pub fn gain_db(&self) -> f32 {
        let linear_gain = self.gain_linear();
        20.0 * linear_gain.log10()
    }

    
    pub fn set_mult_timer0(&mut self, timer: u16) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_sensor_spi(199, timer)?;
        Ok(())
    }

    pub fn set_fr_length0(&mut self, fr_length: u16) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_sensor_spi(200, fr_length)?;
        Ok(())
    }

    pub fn set_exposure0(&mut self, exposure: u16) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        self.write_sensor_spi(201, exposure)?;
        Ok(())
    }

    pub fn mult_timer_status(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_sensor_spi(242)
    }

    pub fn reset_length_status(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_sensor_spi(243)
    }

    pub fn exposure_status(&mut self) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        self.read_sensor_spi(244)
    }


    /////////////////////////////////////

    /// usleep
    fn usleep(&self, usec: u64) {
        (self.usleep)(usec);
    }

    /// Write a 16-bit register on the Spartan-7 FPGA
    /// 
    /// Low-level register write operation for direct FPGA register access.
    /// 
    /// # Arguments
    /// 
    /// * `addr` - Register address
    /// * `data` - 16-bit data value to write
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn write_i2c(
        &mut self,
        addr: u16,
        data: u16,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
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

    /// Read a 16-bit register from the Spartan-7 FPGA
    /// 
    /// Low-level register read operation for direct FPGA register access.
    /// 
    /// # Arguments
    /// 
    /// * `addr` - Register address
    /// 
    /// # Returns
    /// 
    /// The 16-bit register value
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn read_i2c(&mut self, addr: u16) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        let addr = addr << 1;
        let wbuf: [u8; 4] = [
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 0) & 0xff) as u8,
            0,
            0
        ];
        self.i2c.write(&wbuf)?;
        let mut rbuf: [u8; 2] = [0; 2];
        self.i2c.read(&mut rbuf)?;
        Ok(rbuf[0] as u16 | ((rbuf[1] as u16) << 8))
    }

    pub fn write_read_i2c(&mut self, addr: u16, data: u16) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        let addr = addr << 1;
        let wbuf: [u8; 4] = [
            ((addr >> 8) & 0xff) as u8,
            ((addr >> 0) & 0xff) as u8,
            ((data >> 8) & 0xff) as u8,
            ((data >> 0) & 0xff) as u8,
        ];
        self.i2c.write(&wbuf)?;
        let mut rbuf: [u8; 2] = [0; 2];
        self.i2c.read(&mut rbuf)?;
        Ok(rbuf[0] as u16 | ((rbuf[1] as u16) << 8))
    }


    /// Write a 16-bit register on the PYTHON300 sensor via SPI bridge
    /// 
    /// Low-level sensor register write operation using the FPGA SPI bridge.
    /// 
    /// # Arguments
    /// 
    /// * `addr` - Sensor register address
    /// * `data` - 16-bit data value to write
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn write_sensor_spi(
        &mut self,
        addr: u16,
        data: u16,
    ) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        let addr = addr | (1 << 14);
        self.write_i2c(addr, data)
    }

    /// Read a 16-bit register from the PYTHON300 sensor via SPI bridge
    /// 
    /// Low-level sensor register read operation using the FPGA SPI bridge.
    /// 
    /// # Arguments
    /// 
    /// * `addr` - Sensor register address
    /// 
    /// # Returns
    /// 
    /// The 16-bit register value
    /// 
    /// # Errors
    /// 
    /// Returns an error if I2C communication fails
    pub fn read_sensor_spi(&mut self, addr: u16) -> Result<u16, RtclP3s7ModuleDriverError<I2C::Error>> {
        let addr = addr | (1 << 14);
        self.read_i2c(addr)
    }

    /// Set D-PHY speed configuration
    /// 
    /// Configures the D-PHY data rate by programming the MMCM (Mixed-Mode Clock Manager).
    /// Currently supports 950 Mbps and 1250 Mbps data rates.
    /// 
    /// # Arguments
    /// 
    /// * `speed` - Target D-PHY speed in bits per second (bps)
    ///   - >= 1,250,000,000.0: Uses 1250 Mbps configuration
    ///   - >= 950,000,000.0: Uses 950 Mbps configuration
    ///   - < 950,000,000.0: Returns error (unsupported)
    /// 
    /// # Errors
    /// 
    /// Returns an error if:
    /// - I2C communication fails
    /// - Speed is below 950 Mbps (unsupported)
    pub fn set_dphy_speed(&mut self, speed: f64) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        // MMCM set reset
        self.write_i2c(REG_P3S7_MMCM_CONTROL, 1)?;

        if speed >= 1250000000.0 {
            // D-PHY 1250Mbps用設定
            for i in 0..MMCM_TBL_1250.len() {
                self.write_i2c(REG_P3S7_MMCM_DRP + MMCM_TBL_1250[i].0, MMCM_TBL_1250[i].1)?;
            }
        } else if speed >= 950000000.0 {
            // D-PHY 950Mbps用設定
            for i in 0..MMCM_TBL_950.len() {
                self.write_i2c(REG_P3S7_MMCM_DRP + MMCM_TBL_950[i].0, MMCM_TBL_950[i].1)?;
            }
        } else {
            return Err(RtclP3s7ModuleDriverError::UnsupportedDphySpeed);
        }

        // MMCM release reset
        self.write_i2c(REG_P3S7_MMCM_CONTROL, 0)?;
        self.usleep(100);

        Ok(())
    }

    #[cfg(feature = "std")]
    pub fn module_reg_dump(&mut self) -> Result<(), RtclP3s7ModuleDriverError<I2C::Error>> {
        println!("REG_P3S7_MODULE_ID        : 0x{:04x}", self.read_i2c(REG_P3S7_MODULE_ID         )?);
        println!("REG_P3S7_MODULE_VERSION   : 0x{:04x}", self.read_i2c(REG_P3S7_MODULE_VERSION    )?);
        println!("REG_P3S7_SENSOR_ENABLE    : 0x{:04x}", self.read_i2c(REG_P3S7_SENSOR_ENABLE     )?);
        println!("REG_P3S7_SENSOR_READY     : 0x{:04x}", self.read_i2c(REG_P3S7_SENSOR_READY      )?);
        println!("REG_P3S7_RECEIVER_RESET   : 0x{:04x}", self.read_i2c(REG_P3S7_RECEIVER_RESET    )?);
        println!("REG_P3S7_RECEIVER_CLK_DLY : 0x{:04x}", self.read_i2c(REG_P3S7_RECEIVER_CLK_DLY  )?);
        println!("REG_P3S7_ALIGN_RESET      : 0x{:04x}", self.read_i2c(REG_P3S7_ALIGN_RESET       )?);
        println!("REG_P3S7_ALIGN_PATTERN    : 0x{:04x}", self.read_i2c(REG_P3S7_ALIGN_PATTERN     )?);
        println!("REG_P3S7_ALIGN_STATUS     : 0x{:04x}", self.read_i2c(REG_P3S7_ALIGN_STATUS      )?);
        println!("REG_P3S7_CLIP_ENABLE      : 0x{:04x}", self.read_i2c(REG_P3S7_CLIP_ENABLE       )?);
        println!("REG_P3S7_CSI_MODE         : 0x{:04x}", self.read_i2c(REG_P3S7_CSI_MODE          )?);
        println!("REG_P3S7_CSI_DT           : 0x{:04x}", self.read_i2c(REG_P3S7_CSI_DT            )?);
        println!("REG_P3S7_CSI_WC           : 0x{:04x}", self.read_i2c(REG_P3S7_CSI_WC            )?);
        println!("REG_P3S7_DPHY_CORE_RESET  : 0x{:04x}", self.read_i2c(REG_P3S7_DPHY_CORE_RESET   )?);
        println!("REG_P3S7_DPHY_SYS_RESET   : 0x{:04x}", self.read_i2c(REG_P3S7_DPHY_SYS_RESET    )?);
        println!("REG_P3S7_DPHY_INIT_DONE   : 0x{:04x}", self.read_i2c(REG_P3S7_DPHY_INIT_DONE    )?);
        println!("REG_P3S7_MMCM_CONTROL     : 0x{:04x}", self.read_i2c(REG_P3S7_MMCM_CONTROL      )?);
        println!("REG_P3S7_PLL_CONTROL      : 0x{:04x}", self.read_i2c(REG_P3S7_PLL_CONTROL       )?);
        Ok(())
    }
}

// MMCM (Mixed-Mode Clock Manager) configuration tables for different D-PHY speeds

/// MMCM configuration table for 1250 Mbps D-PHY operation
/// 
/// This table contains the DRP (Dynamic Reconfiguration Port) register 
/// address-value pairs to configure the MMCM for 1.25 Gbps data rate.
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

/// MMCM configuration table for 950 Mbps D-PHY operation
/// 
/// This table contains the DRP (Dynamic Reconfiguration Port) register 
/// address-value pairs to configure the MMCM for 0.95 Gbps data rate.
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
