

mod ffi;
use ffi::*;

fn main() {
    println!("Hello, world!");

    // デバイスの初期化
    // ここで FT_CreateDeviceInfoList を呼び出す
    let mut num_devs: u32 = 0;   
    let status = unsafe {FT_CreateDeviceInfoList(&mut num_devs as *mut u32)};
    if status != 0 {
        panic!("Failed to create device info list: status = {}", status);
    }
    println!("Number of devices: {}", num_devs);
}
