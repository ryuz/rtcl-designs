
use std::error::Error;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
use kv260_rtcl_p3s7_hs::camera_driver::CameraDriver;


fn main() -> Result<(), Box<dyn Error>> {
    println!("RTCL-P3S7-MIPI camera flash rom util");

    // カメラ初期化
    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;
    let uio_acc = UioAccessor::<usize>::new_with_name("uio_pl_peri").expect("Failed to open uio");
    let reg_sys = uio_acc.subclone(0x00000000, 0x400);
    let reg_fmtr = uio_acc.subclone(0x00100000, 0x400);
    let mut cam = CameraDriver::new(i2c, reg_sys, reg_fmtr);

    // ステータス表示
    println!("module id      : {:04x}", cam.module_id()?);
    println!("module version : {:04x}", cam.module_version()?);
    println!("module rom_id  : {:?}",   cam.flash_rom_id()?);
    let rom_id = cam.flash_rom_id()?;
    println!("rom id         : {:02x} {:02x} {:02x}", rom_id[0], rom_id[1], rom_id[2]);


    
    Ok(())
}
