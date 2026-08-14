use std::error::Error;
use std::fmt;
use std::sync::Arc;

use crate::ffi::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum D3xxError {
    InvalidHandle,
    DeviceNotFound,
    DeviceNotOpened,
    IoError,
    InsufficientResources,
    InvalidParameter,
    InvalidArgs,
    NotSupported,
    NoMoreItems,
    Timeout,
    OperationAborted,
    ReservedPipe,
    InvalidControlRequestDirection,
    InvalidControlRequestType,
    IoPending,
    IoIncomplete,
    HandleEof,
    Busy,
    NoSystemResources,
    DeviceListNotReady,
    DeviceNotConnected,
    IncorrectDevicePath,
    OtherError,
    Unknown(FT_STATUS),
}

impl D3xxError {
    pub fn from_status(status: FT_STATUS) -> Self {
        match status {
            FT_INVALID_HANDLE => Self::InvalidHandle,
            FT_DEVICE_NOT_FOUND => Self::DeviceNotFound,
            FT_DEVICE_NOT_OPENED => Self::DeviceNotOpened,
            FT_IO_ERROR => Self::IoError,
            FT_INSUFFICIENT_RESOURCES => Self::InsufficientResources,
            FT_INVALID_PARAMETER => Self::InvalidParameter,
            FT_INVALID_ARGS => Self::InvalidArgs,
            FT_NOT_SUPPORTED => Self::NotSupported,
            FT_NO_MORE_ITEMS => Self::NoMoreItems,
            FT_TIMEOUT => Self::Timeout,
            FT_OPERATION_ABORTED => Self::OperationAborted,
            FT_RESERVED_PIPE => Self::ReservedPipe,
            FT_INVALID_CONTROL_REQUEST_DIRECTION => Self::InvalidControlRequestDirection,
            FT_INVALID_CONTROL_REQUEST_TYPE => Self::InvalidControlRequestType,
            FT_IO_PENDING => Self::IoPending,
            FT_IO_INCOMPLETE => Self::IoIncomplete,
            FT_HANDLE_EOF => Self::HandleEof,
            FT_BUSY => Self::Busy,
            FT_NO_SYSTEM_RESOURCES => Self::NoSystemResources,
            FT_DEVICE_LIST_NOT_READY => Self::DeviceListNotReady,
            FT_DEVICE_NOT_CONNECTED => Self::DeviceNotConnected,
            FT_INCORRECT_DEVICE_PATH => Self::IncorrectDevicePath,
            FT_OTHER_ERROR => Self::OtherError,
            code => Self::Unknown(code),
        }
    }

    pub fn status_code(self) -> FT_STATUS {
        match self {
            Self::InvalidHandle => FT_INVALID_HANDLE,
            Self::DeviceNotFound => FT_DEVICE_NOT_FOUND,
            Self::DeviceNotOpened => FT_DEVICE_NOT_OPENED,
            Self::IoError => FT_IO_ERROR,
            Self::InsufficientResources => FT_INSUFFICIENT_RESOURCES,
            Self::InvalidParameter => FT_INVALID_PARAMETER,
            Self::InvalidArgs => FT_INVALID_ARGS,
            Self::NotSupported => FT_NOT_SUPPORTED,
            Self::NoMoreItems => FT_NO_MORE_ITEMS,
            Self::Timeout => FT_TIMEOUT,
            Self::OperationAborted => FT_OPERATION_ABORTED,
            Self::ReservedPipe => FT_RESERVED_PIPE,
            Self::InvalidControlRequestDirection => FT_INVALID_CONTROL_REQUEST_DIRECTION,
            Self::InvalidControlRequestType => FT_INVALID_CONTROL_REQUEST_TYPE,
            Self::IoPending => FT_IO_PENDING,
            Self::IoIncomplete => FT_IO_INCOMPLETE,
            Self::HandleEof => FT_HANDLE_EOF,
            Self::Busy => FT_BUSY,
            Self::NoSystemResources => FT_NO_SYSTEM_RESOURCES,
            Self::DeviceListNotReady => FT_DEVICE_LIST_NOT_READY,
            Self::DeviceNotConnected => FT_DEVICE_NOT_CONNECTED,
            Self::IncorrectDevicePath => FT_INCORRECT_DEVICE_PATH,
            Self::OtherError => FT_OTHER_ERROR,
            Self::Unknown(code) => code,
        }
    }
}

impl From<FT_STATUS> for D3xxError {
    fn from(status: FT_STATUS) -> Self {
        Self::from_status(status)
    }
}

impl fmt::Display for D3xxError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?} (FT_STATUS={})", self, self.status_code())
    }
}

#[derive(Clone)]
pub struct Overlapped {
    overlapped : OVERLAPPED,
}


impl Overlapped {
    pub fn new() -> Self {
        Self { overlapped : OVERLAPPED::default() }
    }

    fn as_mut_ptr(&mut self) -> *mut OVERLAPPED {
        &mut self.overlapped as *mut OVERLAPPED
    }
}


impl Error for D3xxError {}

unsafe impl Send for D3xxError {}
unsafe impl Sync for D3xxError {}

pub type D3xxResult<T> = Result<T, D3xxError>;

fn status_to_result(status: FT_STATUS) -> D3xxResult<()> {
    if status == FT_OK {
        Ok(())
    } else {
        Err(status.into())
    }
}

pub struct D3xxDevice {
    handle: FT_HANDLE,
}

unsafe impl Send for D3xxDevice {}
unsafe impl Sync for D3xxDevice {}

pub struct D3xxWriter {
    device: Arc<D3xxDevice>,
    pipe_id: u8,
//  fifo_id: u8,
    timeout_us: u32,
}
pub struct D3xxReader {
    device: Arc<D3xxDevice>,
    pipe_id: u8,
//  fifo_id: u8,
    timeout_us: u32,
}

impl D3xxDevice {
    pub fn new(dev_index: usize,  channels: usize) -> D3xxResult<(Vec::<D3xxWriter>, Vec::<D3xxReader>)> {
        let mut handle: FT_HANDLE = std::ptr::null_mut();
        let status = unsafe { FT_Create(dev_index as PVOID, FT_OPEN_BY_INDEX, &mut handle) };
        status_to_result(status)?;

        let device = Arc::new(D3xxDevice { handle });

        let mut writers = Vec::<D3xxWriter>::new();
        for i in 0..channels {
            writers.push(D3xxWriter {
                device: device.clone(),
                pipe_id: EP_ID_OUT0 + i as u8,
//              fifo_id: i as u8,
                timeout_us: 5000,
            });
        }
        let mut readers = Vec::<D3xxReader>::new();
        for i in 0..channels {
            readers.push(D3xxReader {
                device: device.clone(),
                pipe_id: EP_ID_IN0 + i as u8,
//              fifo_id: i as u8,
                timeout_us: 5000,
            });
        }
        Ok((writers, readers))
    }

    #[cfg(any(target_os = "linux", target_os = "macos"))]
    pub fn set_transfer_params_for_fifo(
        fifo_id: usize,
        transfer_conf: &mut FT_TRANSFER_CONF,
    ) -> D3xxResult<()> {
        transfer_conf.wStructSize = std::mem::size_of::<FT_TRANSFER_CONF>() as WORD;

        let status = unsafe { FT_SetTransferParams(transfer_conf, fifo_id as DWORD) };
        status_to_result(status)
    }
}

impl Drop for D3xxDevice {
    fn drop(&mut self) {
        let status = unsafe { FT_Close(self.handle) };
        if let Err(err) = status_to_result(status) {
            eprintln!("Failed to close device: {}", err);
        }
        println!("Device closed");
    }
}

impl D3xxWriter {
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        self.timeout_us = timeout_us;
        Ok(())
    }

    pub fn set_stream_pipe(&mut self, stream_size: usize) -> D3xxResult<()> {
        let status = unsafe { FT_SetStreamPipe(self.device.handle, 0, 0, self.pipe_id, stream_size as u32) };
        status_to_result(status)?;
        Ok(())
    }

    pub fn clear_stream_pipe(&mut self) -> D3xxResult<()> {
        let status = unsafe { FT_ClearStreamPipe(self.device.handle, 0, 0, self.pipe_id) };
        status_to_result(status)?;
        Ok(())
    }

    #[cfg(target_os = "linux")]
    pub fn write(&self, data: &[u8]) -> D3xxResult<usize> {
        let mut bytes_written: ULONG = 0;
        let status = unsafe {
            FT_WritePipeEx(
                self.device.handle,
//              self.fifo_id,
                self.pipe_id - EP_ID_OUT0,
                data.as_ptr(),
                data.len() as ULONG,
                &mut bytes_written,
                self.timeout_us,
            )
        };
        status_to_result(status)?;
        Ok(bytes_written as usize)
    }

    #[cfg(target_os = "windows")]
    pub fn write(&self, data: &[u8]) -> D3xxResult<usize> {
        let mut bytes_written: ULONG = 0;
        let status = unsafe {
            FT_WritePipe(
                self.device.handle,
                self.pipe_id,
                data.as_ptr(),
                data.len() as ULONG,
                &mut bytes_written,
                std::ptr::null_mut(),
            )
        };
        status_to_result(status)?;
        Ok(bytes_written as usize)
    }

    pub fn initialize_overlapped(&self, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe { FT_InitializeOverlapped(self.device.handle, overlaped.as_mut_ptr()) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        Ok(())
    }    

    pub fn release_overlapped(&self, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe { FT_ReleaseOverlapped(self.device.handle, overlaped.as_mut_ptr()) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        Ok(())
    }

    #[cfg(target_os = "windows")]
    pub fn write_async(&self, buffer: &[u8], bytes_transferred: &mut u32, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe {
            FT_WritePipe(
                self.device.handle,
                self.pipe_id,
                buffer.as_ptr(),
                buffer.len() as ULONG,
                bytes_transferred,
                overlaped.as_mut_ptr(),
            )
        };
        if status != FT_IO_PENDING {
            status_to_result(status)?;
        }
        Ok(())
    }

    #[cfg(target_os = "linux")]
    pub fn write_async(&self, buffer: &[u8], bytes_transferred: &mut u32, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe {
            FT_WritePipeAsync(
                self.device.handle,
//              self.fifo_id,
                self.pipe_id - EP_ID_OUT0,
                buffer.as_ptr(),
                buffer.len() as ULONG,
                bytes_transferred,
                overlaped.as_mut_ptr(),
            )
        };
        if status != FT_IO_PENDING {
            status_to_result(status)?;
        }
        Ok(())
    }

    pub fn get_async_result(&self, overlaped: &mut Overlapped, bytes_transferred: &mut u32, wait: bool) -> D3xxResult<()> {
        let status = unsafe {
            FT_GetOverlappedResult(
                self.device.handle,
                overlaped.as_mut_ptr(),
                bytes_transferred,
                if wait { 1 } else { 0 },
        )};
        if status != FT_OK {
            status_to_result(status)?;
        }
        Ok(())
    }
}


impl D3xxReader {

    #[cfg(target_os = "linux")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        let status = unsafe { FT_SetPipeTimeout(self.device.handle, self.pipe_id, timeout_us) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        self.timeout_us = timeout_us;
        Ok(())
    }

    #[cfg(target_os = "windows")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        let status = unsafe { FT_SetPipeTimeout(self.device.handle, self.pipe_id, timeout_us) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        self.timeout_us = timeout_us;
        Ok(())
    }

    pub fn set_stream_pipe(&mut self, stream_size: usize) -> D3xxResult<()> {
        let status = unsafe { FT_SetStreamPipe(self.device.handle, 0, 0, self.pipe_id, stream_size as u32) };
//      let status = unsafe { FT_SetStreamPipe(self.device.handle, 0, 1, 0, stream_size) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        Ok(())
    }

    pub fn clear_stream_pipe(&mut self) -> D3xxResult<()> {
        let status = unsafe { FT_ClearStreamPipe(self.device.handle, 0, 0, self.pipe_id) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        Ok(())
    }

    #[cfg(target_os = "linux")]
    pub fn read(&self, len: usize) -> D3xxResult<Vec<u8>> {
        let mut buffer = vec![0u8; len];
        let mut bytes_read: ULONG = 0;
        let status = unsafe {
            FT_ReadPipeEx(
                self.device.handle,
//              self.fifo_id,
                self.pipe_id - EP_ID_IN0,
                buffer.as_mut_ptr(),
                buffer.len() as ULONG,
                &mut bytes_read,
                self.timeout_us,
            )
        };
        if status != FT_TIMEOUT {
            status_to_result(status)?;
        }
        Ok(buffer[0..bytes_read as usize].to_vec())
    }

    #[cfg(target_os = "windows")]
    pub fn read(&self, len: usize) -> D3xxResult<Vec<u8>> {
        let mut buffer = vec![0u8; len];
        let mut bytes_read: ULONG = 0;
        let status = unsafe {
            FT_ReadPipe(
                self.device.handle,
                self.pipe_id,
                buffer.as_mut_ptr(),
                buffer.len() as ULONG,
                &mut bytes_read,
                std::ptr::null_mut(),
            )
        };
        if status != FT_TIMEOUT {
            status_to_result(status)?;
        }
        Ok(buffer[0..bytes_read as usize].to_vec())
    }

    #[cfg(any(target_os = "linux", target_os = "windows"))]
    pub fn read_until_size(&self, len: usize, max_reads: usize) -> D3xxResult<Vec<u8>> {
        let mut buffer = Vec::with_capacity(len);

        for _ in 0..max_reads {
            if buffer.len() >= len {
                break;
            }

            let mut data = self.read(len - buffer.len())?;
//          println!("read_until_size: read {} bytes, total {} bytes", data.len(), buffer.len() + data.len());
            std::thread::sleep(std::time::Duration::from_micros(1000));
            buffer.append(&mut data);
        }

        Ok(buffer)
    }

    pub fn initialize_overlapped(&self, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe { FT_InitializeOverlapped(self.device.handle, overlaped.as_mut_ptr()) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        Ok(())
    }

    pub fn release_overlapped(&self, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe { FT_ReleaseOverlapped(self.device.handle, overlaped.as_mut_ptr()) };
        if status != FT_OK {
            return Err(D3xxError::from_status(status));
        }
        Ok(())
    }

    #[cfg(target_os = "windows")]
    pub fn read_async(&self, buffer: &mut [u8], bytes_transferred: &mut u32, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe {
            FT_ReadPipe(
                self.device.handle,
                self.pipe_id,
                buffer.as_mut_ptr(),
                buffer.len() as ULONG,
                bytes_transferred,
                overlaped.as_mut_ptr(),
            )
        };
        if status != FT_IO_PENDING {
            status_to_result(status)?;
        }
        Ok(())
    }

    #[cfg(target_os = "linux")]
    pub fn read_async(&self, buffer: &mut [u8], bytes_transferred: &mut u32, overlaped: &mut Overlapped) -> D3xxResult<()> {
        let status = unsafe {
            FT_ReadPipeAsync(
                self.device.handle,
//              self.fifo_id,
                self.pipe_id - EP_ID_IN0,
                buffer.as_mut_ptr(),
                buffer.len() as ULONG,
                bytes_transferred,
                overlaped.as_mut_ptr(),
            )
        };
        if status != FT_IO_PENDING {
            status_to_result(status)?;
        }
        Ok(())
    }

    pub fn get_async_result(&self, overlaped: &mut Overlapped, bytes_transferred: &mut u32, wait: bool) -> D3xxResult<()> {
        let status = unsafe {
            FT_GetOverlappedResult(
                self.device.handle,
                overlaped.as_mut_ptr(),
                bytes_transferred,
                if wait { 1 } else { 0 },
        )};
        if status != FT_OK && status != FT_TIMEOUT {
            status_to_result(status)?;
        }
        Ok(())
    }
}
