use std::error::Error;

//mod ffi;
//use ffi::*;

// lib.rs の定義を使えるようにする
use ftdi_ffi_test::*;

const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
const OPCODE_AXI4S_TRANS: u8 = 0x10;

fn main() -> Result<(), Box<dyn Error>>
{
    println!("Hello, world!");

    let (mut usb_tx, mut usb_rx) = D3xxDevice::new(0)?;

    usb_tx.set_timeout(1000)?;
    usb_rx.set_timeout(500)?;

    
    std::thread::spawn(move || {
        loop {
//            std::thread::sleep(std::time::Duration::from_millis(1000));
//            println!("Read");
//            std::thread::sleep(std::time::Duration::from_millis(1000));
            let result = usb_rx.read(4);

            match result {
                Err(e) => {
                    eprintln!("Error reading data: {}", e);
                    continue;
                }
                Ok(data) => {
                    println!("Read data: {:?}", data);
                    break;
                }
            }
        }
    });
    
    std::thread::sleep(std::time::Duration::from_millis(5000));

    // write
    let mut write_buf = Vec::<u8>::with_capacity(8);
    write_buf.push(OPCODE_AXI4L_READ);
    write_buf.push(0);
    write_buf.extend_from_slice(&4u16.to_le_bytes());
    write_buf.extend_from_slice(&0u32.to_le_bytes());
    usb_tx.write(&write_buf)?;

    // read
//  let read_data = usb_rx.read(8)?;
//  println!("Read data: {:?}", read_data);

    std::thread::sleep(std::time::Duration::from_millis(10000));

    Ok(())
}


/*
fn main() -> Result<(), Box<dyn Error>>
{
    println!("Hello, world!");

    // デバイスの初期化
    // ここで FT_CreateDeviceInfoList を呼び出す
    let mut num_devs: DWORD = 0;   
    let status = unsafe {FT_CreateDeviceInfoList(&mut num_devs as *mut DWORD)};
    if status != 0 {
        panic!("Failed to create device info list: status = {}", status);
    }
    println!("Number of devices: {}", num_devs);

    let mut table_len: DWORD = 0;
    let mut devices: Vec<FT_DEVICE_LIST_INFO_NODE> = Vec::with_capacity(num_devs as usize);
    let status = unsafe { FT_GetDeviceInfoList(devices.as_mut_ptr(), std::ptr::addr_of_mut!(table_len))};
    if status != 0 {
        eprintln!("Failed to get device info list (status = {})", status);
        return Err(Box::new(std::io::Error::new(std::io::ErrorKind::Other, "Failed to get device info list")));
    }
    unsafe { devices.set_len(table_len.min(num_devs) as usize) };
    
    println!("{:?} (status = {})", devices, status);
    println!("Table length: {}", table_len);
    println!("Devices: {:?}", devices);

    let dev_index = 0; // 使用するデバイスのインデックスを指定

    devices[dev_index].SerialNumber[15] = 0; // null terminate the string

    let mut handle: FT_HANDLE = std::ptr::null_mut();
    let status = unsafe {
        FT_Create(
            devices[dev_index].SerialNumber.as_ptr() as PVOID,
            FT_OPEN_BY_SERIAL_NUMBER,
            &mut handle,
        )
    };
    println!("FT_Create status: {}, handle: {:?}", status, handle);

    let mut write_buf = Vec::<u8>::with_capacity(8);
    write_buf.push(OPCODE_AXI4L_READ);
    write_buf.push(0);
    write_buf.extend_from_slice(&4u16.to_le_bytes());
    write_buf.extend_from_slice(&0u32.to_le_bytes());

    let mut bytes_written : DWORD = 0;
    let status = unsafe{FT_WritePipe(handle, EP_ID_OUT0, write_buf.as_ptr(), write_buf.len() as u32, &mut bytes_written, std::ptr::null_mut())};
    println!("FT_WritePipe status: {}, bytes_written: {}", status, bytes_written);
    std::thread::sleep(std::time::Duration::from_millis(100));

    let status = unsafe{FT_SetPipeTimeout(handle, EP_ID_IN0, 1000)};
    println!("FT_SetPipeTimeout status: {}", status);

    let mut read_buf = vec![0u8; 8];
    let mut bytes_read : DWORD = 0;
    let status = unsafe{FT_ReadPipe(handle, EP_ID_IN0, read_buf.as_mut_ptr(), read_buf.len() as u32, &mut bytes_read, std::ptr::null_mut())};
//  let status = unsafe{FT_ReadPipeEx(handle, 0, read_buf.as_mut_ptr(), read_buf.len() as u32, &mut bytes_read, 1000)};//std::ptr::null_mut())};
    println!("FT_ReadPipe status: {}, bytes_read: {}, read_buf: {:?}", status, bytes_read, read_buf);
    std::thread::sleep(std::time::Duration::from_millis(100));

    let mut read_buf = vec![0u8; 8];
    let mut bytes_read : DWORD = 0;
//  let status = unsafe{FT_ReadPipe(handle, EP_ID_IN0, read_buf.as_mut_ptr(), read_buf.len() as u32, &mut bytes_read, std::ptr::null_mut())};
    let status = unsafe{FT_ReadPipeEx(handle, 0, read_buf.as_mut_ptr(), read_buf.len() as u32, &mut bytes_read, 1000)};//, std::ptr::null_mut())};
    println!("FT_ReadPipe status: {}, bytes_read: {}, read_buf: {:?}", status, bytes_read, read_buf);

    unsafe {FT_Close(handle)};

    Ok(())
}
*/