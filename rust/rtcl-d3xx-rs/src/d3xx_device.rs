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

fn async_status_to_result(status: FT_STATUS) -> D3xxResult<()> {
    if status == FT_OK || status == FT_IO_PENDING {
        Ok(())
    } else {
        Err(status.into())
    }
}

fn reset_overlapped(overlapped: &mut OVERLAPPED) {
    overlapped.Internal = 0;
    overlapped.InternalHigh = 0;
}

#[cfg(target_os = "linux")]
unsafe fn submit_async_write(
    handle: FT_HANDLE,
    buffer: &[u8],
    bytes_transferred: &mut ULONG,
    overlapped: &mut OVERLAPPED,
) -> FT_STATUS {
    unsafe {
        FT_WritePipeAsync(
            handle,
            0,
            buffer.as_ptr(),
            buffer.len() as ULONG,
            bytes_transferred,
            overlapped as *mut OVERLAPPED,
        )
    }
}

#[cfg(target_os = "windows")]
unsafe fn submit_async_write(
    handle: FT_HANDLE,
    buffer: &[u8],
    bytes_transferred: &mut ULONG,
    overlapped: &mut OVERLAPPED,
) -> FT_STATUS {
    unsafe {
        FT_WritePipeEx(
            handle,
            EP_ID_OUT0,
            buffer.as_ptr(),
            buffer.len() as ULONG,
            bytes_transferred,
            overlapped as *mut OVERLAPPED,
        )
    }
}

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
    pub fn new(dev_index: usize) -> D3xxResult<(D3xxWriter, D3xxReader)> {
        let mut handle: FT_HANDLE = std::ptr::null_mut();
        let status = unsafe { FT_Create(dev_index as PVOID, FT_OPEN_BY_INDEX, &mut handle) };
        status_to_result(status)?;

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

    pub fn write(&self, data: &[u8]) -> D3xxResult<usize> {
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
        status_to_result(status)?;
        Ok(bytes_written as usize)
    }

    pub fn burst_write(&self, data: &[u8]) -> D3xxResult<usize> {
        const MAX_SIZE: usize = 4 * 1024;
        const QUEUE_LEN: usize = 4;

        if data.is_empty() {
            return Ok(0);
        }

        let queue_len = std::cmp::min(QUEUE_LEN, (data.len() + MAX_SIZE - 1) / MAX_SIZE);
        let mut overlappeds = vec![OVERLAPPED::default(); queue_len];
        let mut pending = vec![false; queue_len];
        let mut requested_sizes = vec![0usize; queue_len];
        let mut initialized = 0usize;
        let mut stream_pipe_enabled = false;

        let result = (|| -> D3xxResult<usize> {
            let status = unsafe {
                FT_SetStreamPipe(self.device.handle, 0, 0, EP_ID_OUT0, MAX_SIZE as ULONG)
            };
            status_to_result(status)?;
            stream_pipe_enabled = true;

            for overlapped in &mut overlappeds {
                let status = unsafe {
                    FT_InitializeOverlapped(self.device.handle, overlapped as *mut OVERLAPPED)
                };
                status_to_result(status)?;
                initialized += 1;
            }

            let mut next_offset = 0usize;
            let mut submitted = 0usize;
            let mut completed = 0usize;
            let mut total_written = 0usize;

            for slot in 0..queue_len {
                if next_offset >= data.len() {
                    break;
                }

                let end = std::cmp::min(next_offset + MAX_SIZE, data.len());
                let chunk = &data[next_offset..end];
                let mut bytes_submitted = 0;

                reset_overlapped(&mut overlappeds[slot]);
                let status = unsafe {
                    submit_async_write(
                        self.device.handle,
                        chunk,
                        &mut bytes_submitted,
                        &mut overlappeds[slot],
                    )
                };
                async_status_to_result(status)?;

                requested_sizes[slot] = chunk.len();
                pending[slot] = true;
                submitted += 1;
                next_offset = end;
            }

            let mut slot = 0usize;
            while completed < submitted {
                if !pending[slot] {
                    slot = (slot + 1) % queue_len;
                    continue;
                }

                let mut bytes_transferred = 0;
                let status = unsafe {
                    FT_GetOverlappedResult(
                        self.device.handle,
                        &mut overlappeds[slot] as *mut OVERLAPPED,
                        &mut bytes_transferred,
                        1,
                    )
                };
                status_to_result(status)?;

                if bytes_transferred as usize != requested_sizes[slot] {
                    return Err(D3xxError::IoError);
                }

                total_written += bytes_transferred as usize;
                requested_sizes[slot] = 0;
                pending[slot] = false;
                completed += 1;

                if next_offset < data.len() {
                    let end = std::cmp::min(next_offset + MAX_SIZE, data.len());
                    let chunk = &data[next_offset..end];
                    let mut bytes_submitted = 0;

                    reset_overlapped(&mut overlappeds[slot]);
                    let status = unsafe {
                        submit_async_write(
                            self.device.handle,
                            chunk,
                            &mut bytes_submitted,
                            &mut overlappeds[slot],
                        )
                    };
                    async_status_to_result(status)?;

                    requested_sizes[slot] = chunk.len();
                    pending[slot] = true;
                    submitted += 1;
                    next_offset = end;
                }

                slot = (slot + 1) % queue_len;
            }

            Ok(total_written)
        })();

        if result.is_err() {
            let _ = unsafe { FT_AbortPipe(self.device.handle, EP_ID_OUT0) };

            for slot in 0..initialized {
                if pending[slot] {
                    let mut bytes_transferred = 0;
                    let _ = unsafe {
                        FT_GetOverlappedResult(
                            self.device.handle,
                            &mut overlappeds[slot] as *mut OVERLAPPED,
                            &mut bytes_transferred,
                            1,
                        )
                    };
                }
            }
        }

        for slot in 0..initialized {
            let _ = unsafe {
                FT_ReleaseOverlapped(self.device.handle, &mut overlappeds[slot] as *mut OVERLAPPED)
            };
        }

        if stream_pipe_enabled {
            let _ = unsafe { FT_ClearStreamPipe(self.device.handle, 0, 0, EP_ID_OUT0) };
        }

        result
    }

}

impl D3xxReader {
    #[cfg(target_os = "linux")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        self.timeout_us = timeout_us;
        Ok(())
    }

    #[cfg(target_os = "linux")]
    pub fn read(&self, len: usize) -> D3xxResult<Vec<u8>> {
        let mut buffer = vec![0u8; len];
        let mut bytes_read: ULONG = 0;
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
        if status != FT_TIMEOUT {
            status_to_result(status)?;
        }
        Ok(buffer[0..bytes_read as usize].to_vec())
    }

    #[cfg(target_os = "windows")]
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        let status = unsafe { FT_SetPipeTimeout(self.device.handle, EP_ID_IN0, timeout_us) };
        status_to_result(status)?;
        self.timeout_us = timeout_us;
        Ok(())
    }

    #[cfg(target_os = "windows")]
    pub fn read(&self, len: usize) -> D3xxResult<Vec<u8>> {
        let mut buffer = vec![0u8; len];
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
        if status != FT_TIMEOUT {
            status_to_result(status)?;
        }
        Ok(buffer[0..bytes_read as usize].to_vec())
    }
}
