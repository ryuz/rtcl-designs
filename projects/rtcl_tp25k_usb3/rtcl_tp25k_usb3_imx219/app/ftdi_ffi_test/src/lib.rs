use std::error::Error;
use std::sync::Arc;


mod ffi;
pub use ffi::*;


pub struct D3xxDevice {
    handle: FT_HANDLE,
}

unsafe impl Send for D3xxDevice {}
unsafe impl Sync for D3xxDevice {}

pub struct D3xxWriter {
    device: Arc<D3xxDevice>,
    timeout_us: u32,
}
pub struct D3xxReader {
    device: Arc<D3xxDevice>,
    timeout_us: u32,
}

impl D3xxDevice {
    pub fn new(dev_index: usize) -> Result<(D3xxWriter, D3xxReader), Box<dyn Error>> {
    let mut handle: FT_HANDLE = std::ptr::null_mut();
        let status = unsafe {
            FT_Create(
                dev_index as PVOID,
                FT_OPEN_BY_INDEX,
                &mut handle,
            )
        };
        if status != 0 {
            return Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("FT_Create failed with status: {}", status),
            )));
        }
        
        let device = Arc::new(D3xxDevice { handle });
        Ok((
            D3xxWriter {
                device: device.clone(),
                timeout_us: 5000,
            },
            D3xxReader {
                device: device,
                timeout_us: 5000,
            },
        ))
    }
}

impl Drop for D3xxDevice {
    fn drop(&mut self) {
        let status = unsafe { FT_Close(self.handle) };
        if status != 0 {
            eprintln!("Failed to close device: status = {}", status);
        }
        println!("Device closed");
    }
}


impl D3xxWriter {
    pub fn set_timeout(&mut self, timeout_us: u32) -> Result<(), Box<dyn Error>> {
        self.timeout_us = timeout_us;
        Ok(())
    }

    pub fn write(&self, data: &[u8]) -> Result<usize, Box<dyn Error>> {
        let mut bytes_written: ULONG = 0;
        let status = unsafe {
            FT_WritePipe(
                self.device.handle,
                EP_ID_OUT0,
                data.as_ptr(),
                data.len() as ULONG,
                &mut bytes_written,
                std::ptr::null_mut(),
            )
        };
        if status == 0 {
            Ok(bytes_written as usize)
        } else {
            Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("FT_WritePipe failed with status: {}", status),
            )))
        }
    }
}


impl D3xxReader {
    #[cfg(target_os = "linux")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> Result<(), Box<dyn Error>> {
        self.timeout_us = timeout_us;
        Ok(())
    }

    #[cfg(target_os = "linux")]
    pub fn read(&self, len : usize) -> Result<Vec::<u8>, Box<dyn Error>> {
        let mut buffer = vec![0u8; len];
        let mut bytes_read: ULONG = 0;
        println!("Calling FT_ReadPipeEx with timeout {} us...", self.timeout_us);
        let status = unsafe {
            FT_ReadPipeEx(
                self.device.handle,
                0,
                buffer.as_mut_ptr(),
                buffer.len() as ULONG,
                &mut bytes_read,
                self.timeout_us,
            )
        };
        if status == 0 {
            Ok(buffer[0..bytes_read as usize].to_vec())
        } else {
            Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("FT_ReadPipe failed with status: {}", status),
            )))
        }
    }


    #[cfg(target_os = "windows")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> Result<(), Box<dyn Error>> {
        let status = unsafe { FT_SetPipeTimeout(self.device.handle, EP_ID_IN0, timeout_us) };
        if status != 0 {
            return Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("FT_SetPipeTimeout failed with status: {}", status),
            )));
        }
        self.timeout_us = timeout_us;
        Ok(())
    }

    #[cfg(target_os = "windows")]
    pub fn read(&self, buffer: &mut [u8], timeout_us: u32) -> Result<usize, Box<dyn Error>> {
        let mut bytes_read: ULONG = 0;
        let status = unsafe {
            FT_ReadPipe(
                self.device.handle,
                EP_ID_IN0,
                buffer.as_mut_ptr(),
                buffer.len() as ULONG,
                &mut bytes_read,
                std::ptr::null_mut(),
            )
        };
        if status == 0 {
            Ok(bytes_read as usize)
        } else {
            Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("FT_ReadPipe failed with status: {}", status),
            )))
        }
    }
}

