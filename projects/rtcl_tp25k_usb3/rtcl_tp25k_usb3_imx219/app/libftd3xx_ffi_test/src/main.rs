use std::error::Error;
use libftd3xx_ffi::*;


fn main() -> Result<(), Box<dyn Error>> {
    println!("Hello, world!");

    
    let mut num_devs : DWORD = 0;
    let status = unsafe {FT_CreateDeviceInfoList(&mut num_devs)};
    println!("Number of devices: {} (status = {})", num_devs, status);

    let mut table_len: DWORD = 0;
    let mut devices: Vec<FT_DEVICE_LIST_INFO_NODE> = Vec::with_capacity(num_devs as usize);
    let status = unsafe { FT_GetDeviceInfoList(devices.as_mut_ptr(), std::ptr::addr_of_mut!(table_len))};
    if status != 0 {
        eprintln!("Failed to get device info list (status = {})", status);
        return Err(Box::new(std::io::Error::new(std::io::ErrorKind::Other, "Failed to get device info list")));
    }

    unsafe { devices.set_len(table_len as usize) };
    println!("{:?} (status = {})", devices, status);
    println!("Table length: {}", table_len);
    println!("Devices: {:?}", devices);

    /*
    let mut handle: FT_HANDLE = std::ptr::null_mut();
    unsafe {
        FT_Create(
                &mut devices[0].SerialNumber as PVOID,
                FT_OPEN_BY_SERIAL_NUMBER,
                &mut handle,
            );
    }
    */

    Ok(())
}
