#![allow(unused)]

use std::error::Error;

use jelly_lib::i2c_hal::I2cHal;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
//use rtcl_lib::rtcl_p3s7_module_driver::*;
use kv260_rtcl_p3s7_hs::*;

type UioAccessor = jelly_mem_access::UioAccessor<usize>;
type UdmabufAccessor = jelly_mem_access::UdmabufAccessor<usize>;
type CameraDriver = camera_driver::CameraDriver<LinuxI2c, usize>;
type CaptureDriver =  capture_driver::CaptureDriver<UioAccessor, UdmabufAccessor>;
use kv260_rtcl_p3s7_hs::timing_generator_driver::TimingGeneratorDriver;

pub struct RtclP3s7Mng {
    uio_acc : UioAccessor,
    buf_img : UdmabufAccessor,
    buf_blk : UdmabufAccessor,
    cam: CameraDriver,
    cap_img : CaptureDriver,
    cap_blk : CaptureDriver,
}

impl RtclP3s7Mng {
    pub fn new() -> Result<Self, Box<dyn Error>> {
        let buf_img = UdmabufAccessor::new("udmabuf-jelly-vram0", false)?;
        let buf_blk = UdmabufAccessor::new("udmabuf-jelly-vram1", false)?;
        let uio_acc = UioAccessor::new_with_name("uio_pl_peri")?;
        let reg_sys = uio_acc.subclone(0x00000000, 0x400);
        let reg_timgen = uio_acc.subclone(0x00010000, 0x400);
        let reg_fmtr = uio_acc.subclone(0x00100000, 0x400);
        let reg_wdma_img = uio_acc.subclone(0x00210000, 0x400);
        let reg_wdma_blk = uio_acc.subclone(0x00220000, 0x400);

        let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;
        let cam = CameraDriver::new(i2c, reg_sys, reg_fmtr);
        let timgen = TimingGeneratorDriver::new(reg_timgen);
        let cap_img = CaptureDriver::new(reg_wdma_img, buf_img.clone())?;
        let cap_blk = CaptureDriver::new(reg_wdma_blk, buf_blk.clone())?;
        Ok(RtclP3s7Mng {
            uio_acc,
            buf_img,
            buf_blk,
            cam,
            cap_img,
            cap_blk,
        })
    }

    pub fn write_sys_reg(&mut self, addr: usize, data: usize) -> Result<(), Box<dyn Error>> {
        unsafe{self.uio_acc.write_reg(addr, data)};
        Ok(())
    }

    pub fn read_sys_reg(&mut self, addr : usize) -> Result<usize, Box<dyn Error>> {
        Ok(unsafe{self.uio_acc.read_reg(addr)})
    }

    pub fn write_cam_reg(&mut self, addr: u16, data: u16) -> Result<(), Box<dyn Error>> {
        Ok(self.cam.cam_i2c_mut().write_i2c(addr, data)?)
    }

    pub fn read_cam_reg(&mut self, addr: u16) -> Result<u16, Box<dyn Error>> {
        Ok(self.cam.cam_i2c_mut().read_i2c(addr)?)
    }

    pub fn write_sensor_reg(&mut self, addr: u16, data: u16) -> Result<(), Box<dyn Error>> {
        Ok(self.cam.cam_i2c_mut().write_sensor_spi(addr, data)?)
    }

    pub fn read_sensor_reg(&mut self, addr: u16) -> Result<u16, Box<dyn Error>> {
        Ok(self.cam.cam_i2c_mut().read_sensor_spi(addr)?)
    }

    pub fn record_image(&mut self, width: usize, height: usize, frames: usize) -> Result<(), Box<dyn Error>> {
        self.cap_img.record(width, height, frames)?;
        Ok(())
    }

    pub fn read_image(&mut self, index : usize) -> Result<Vec<u8>, Box<dyn Error>> {
        Ok(self.cap_img.read_image_vec(index)?)
    }


    pub fn record_black(&mut self, width: usize, height: usize, frames: usize) -> Result<(), Box<dyn Error>> {
        self.cap_blk.record(width, height, frames)?;
        Ok(())
    }

    pub fn read_black(&mut self, index: usize) -> Result<Vec<u8>, Box<dyn Error>> {
        Ok(self.cap_blk.read_image_vec(index)?)
    }
}


fn usleep() {
    std::thread::sleep(std::time::Duration::from_micros(1));
}
