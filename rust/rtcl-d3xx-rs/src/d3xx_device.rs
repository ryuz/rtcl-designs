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

impl Error for D3xxError {}

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
    fifo_id: u8,
    timeout_us: u32,
}
pub struct D3xxReader {
    device: Arc<D3xxDevice>,
    pipe_id: u8,
    fifo_id: u8,
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
                pipe_id: EP_ID_IN0 + i as u8,
                fifo_id: i as u8,
                timeout_us: 5000,
            });
        }
        let mut readers = Vec::<D3xxReader>::new();
        for i in 0..channels {
            readers.push(D3xxReader {
                device: device.clone(),
                pipe_id: EP_ID_IN0 + i as u8,
                fifo_id: i as u8,
                timeout_us: 5000,
            });
        }
        Ok((writers, readers))
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

    pub fn set_stream_pipe(&mut self, stream_size: u32) -> D3xxResult<()> {
        let status = unsafe { FT_SetStreamPipe(self.device.handle, 0, 0, self.pipe_id, stream_size) };
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
                self.fifo_id,
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

    #[cfg(target_os = "linux")]
    pub fn burst_write(&self, data: &[u8]) -> D3xxResult<usize> {
        const MAX_SIZE: usize = 4 * 1024;

        if data.is_empty() {
            return Ok(0);
        }

        let chunks: Vec<&[u8]> = data.chunks(MAX_SIZE).collect();

        // 書き込み要求
        let mut overlappeds = vec![OVERLAPPED::default(); chunks.len()];
        let mut bytes_transferred = vec![0u32; chunks.len()];
        for i in 0..overlappeds.len() {
            // Overlapp の準備
            let status = unsafe {
                FT_InitializeOverlapped(self.device.handle, &mut overlappeds[i] as *mut OVERLAPPED)
            };
            assert!(status == FT_OK, "Failed to initialize overlapped: status = {}", status);

            let status = unsafe { FT_WritePipeAsync(
                self.device.handle,
                self.fifo_id,
                chunks[i].as_ptr(),
                chunks[i].len() as ULONG,
                &mut bytes_transferred[i] as *mut ULONG,
                &mut overlappeds[i] as *mut OVERLAPPED,
            )};
            assert!(status == FT_IO_PENDING, "Failed to write pipe async: status = {}", status);
        }

        // 完了を待つ
        for i in 0..overlappeds.len() {
            let status = unsafe {
                FT_GetOverlappedResult(
                    self.device.handle,
                    &mut overlappeds[i] as *mut OVERLAPPED,
                    &mut bytes_transferred[i] as *mut ULONG,
                    1,
                )
            };
            assert!(status == FT_OK, "Failed to get overlapped result: status = {}", status);
//          assert!(bytes_transferred[i] != FT_OK, "Failed to get overlapped result: status = {}", status);

            let status = unsafe { FT_ReleaseOverlapped(self.device.handle, &mut overlappeds[i] as *mut OVERLAPPED)};
            assert!(status == FT_OK, "Failed to release overlapped: status = {}", status);
        }
        Ok(0)
    }
}


impl D3xxReader {

    #[cfg(target_os = "linux")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
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

    pub fn set_stream_pipe(&mut self, stream_size: u32) -> D3xxResult<()> {
//      let status = unsafe { FT_SetStreamPipe(self.device.handle, 0, 0, self.pipe_id, stream_size) };
        let status = unsafe { FT_SetStreamPipe(self.device.handle, 0, 1, 0, stream_size) };
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
                self.fifo_id,
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

    #[cfg(target_os = "linux")]
    pub fn burst_read(&self, len: usize) -> D3xxResult<Vec<u8>> {
        const MAX_SIZE: usize = 4 * 1024;

        if len == 0 {
            return Ok(Vec::new());
        }

        let mut buffer = vec![0u8; len];
        let mut chunks: Vec<&mut [u8]> = buffer.chunks_mut(MAX_SIZE).collect();

        // 読み込み要求
        let mut overlappeds = vec![OVERLAPPED::default(); chunks.len()];
        let mut bytes_transferred = vec![0u32; chunks.len()];
        for i in 0..overlappeds.len() {
            let status = unsafe {
                FT_InitializeOverlapped(self.device.handle, &mut overlappeds[i] as *mut OVERLAPPED)
            };
            assert!(status == FT_OK, "Failed to initialize overlapped: status = {}", status);

            let status = unsafe {
                FT_ReadPipeAsync(
                    self.device.handle,
                    self.fifo_id,
                    chunks[i].as_mut_ptr(),
                    chunks[i].len() as ULONG,
                    &mut bytes_transferred[i] as *mut ULONG,
                    &mut overlappeds[i] as *mut OVERLAPPED,
                )
            };
            assert!(status == FT_IO_PENDING, "Failed to read pipe async: status = {}", status);
        }

        // 完了を待つ
        let mut total_bytes: usize = 0;
        for i in 0..overlappeds.len() {
            let status = unsafe {
                FT_GetOverlappedResult(
                    self.device.handle,
                    &mut overlappeds[i] as *mut OVERLAPPED,
                    &mut bytes_transferred[i] as *mut ULONG,
                    1,
                )
            };

            let release_status = unsafe {
                FT_ReleaseOverlapped(self.device.handle, &mut overlappeds[i] as *mut OVERLAPPED)
            };
            assert!(release_status == FT_OK, "Failed to release overlapped: status = {}", release_status);

            status_to_result(status)?;
            status_to_result(release_status)?;
            total_bytes += bytes_transferred[i] as usize;
        }

        buffer.truncate(total_bytes);
        Ok(buffer)

    }
}
