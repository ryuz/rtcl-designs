#![allow(dead_code)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

use std::ffi::c_void;
use std::os::raw::c_char;

// Windowsの場合は FTD3XXWU をリンク
#[cfg(target_os = "windows")]
#[link(name = "FTD3XXWU")]
unsafe extern "C" {}

// Linuxの場合は ftd3xx をリンク
#[cfg(target_os = "linux")]
#[link(name = "ftd3xx")]
unsafe extern "C" {}

pub type DWORD = u32;
pub type ULONG = u32;
pub type ULONG_PTR = usize;
#[cfg(target_os = "windows")]
pub type BOOL = i32;
#[cfg(target_os = "linux")]
pub type BOOL = u32;
pub type BOOLEAN = u8;
pub type PVOID = *mut c_void;
pub type LPVOID = PVOID;
pub type HANDLE = *mut c_void;

pub type FT_HANDLE = *mut c_void;
pub type FT_STATUS = ULONG;

pub const FT_OK: FT_STATUS = 0;
pub const FT_INVALID_HANDLE: FT_STATUS = 1;
pub const FT_DEVICE_NOT_FOUND: FT_STATUS = 2;
pub const FT_DEVICE_NOT_OPENED: FT_STATUS = 3;
pub const FT_IO_ERROR: FT_STATUS = 4;
pub const FT_INSUFFICIENT_RESOURCES: FT_STATUS = 5;
pub const FT_INVALID_PARAMETER: FT_STATUS = 6;
pub const FT_INVALID_ARGS: FT_STATUS = 16;
pub const FT_NOT_SUPPORTED: FT_STATUS = 17;
pub const FT_NO_MORE_ITEMS: FT_STATUS = 18;
pub const FT_TIMEOUT: FT_STATUS = 19;
pub const FT_OPERATION_ABORTED: FT_STATUS = 20;
pub const FT_RESERVED_PIPE: FT_STATUS = 21;
pub const FT_INVALID_CONTROL_REQUEST_DIRECTION: FT_STATUS = 22;
pub const FT_INVALID_CONTROL_REQUEST_TYPE: FT_STATUS = 23;
pub const FT_IO_PENDING: FT_STATUS = 24;
pub const FT_IO_INCOMPLETE: FT_STATUS = 25;
pub const FT_HANDLE_EOF: FT_STATUS = 26;
pub const FT_BUSY: FT_STATUS = 27;
pub const FT_NO_SYSTEM_RESOURCES: FT_STATUS = 28;
pub const FT_DEVICE_LIST_NOT_READY: FT_STATUS = 29;
pub const FT_DEVICE_NOT_CONNECTED: FT_STATUS = 30;
pub const FT_INCORRECT_DEVICE_PATH: FT_STATUS = 31;
pub const FT_OTHER_ERROR: FT_STATUS = 32;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct OVERLAPPED_OFFSET {
    pub Offset: DWORD,
    pub OffsetHigh: DWORD,
}

impl Default for OVERLAPPED_OFFSET {
    fn default() -> Self {
        Self {
            Offset: 0,
            OffsetHigh: 0,
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union OVERLAPPED_UNION {
    pub offset: OVERLAPPED_OFFSET, // 構造体（Offset と OffsetHigh）
    pub Pointer: PVOID,            // ポインタ
}

impl Default for OVERLAPPED_UNION {
    fn default() -> Self {
        Self {
            offset: OVERLAPPED_OFFSET::default(),
        }
    }
}

// 3. 本体構造体
#[repr(C)]
#[derive(Clone, Copy)]
pub struct OVERLAPPED {
    pub Internal: ULONG_PTR,
    pub InternalHigh: ULONG_PTR,
    pub u: OVERLAPPED_UNION, // 無名unionだった部分に名前（uなど）を付ける
    pub hEvent: HANDLE,
}

impl Default for OVERLAPPED {
    fn default() -> Self {
        Self {
            Internal: 0,
            InternalHigh: 0,
            u: OVERLAPPED_UNION::default(),
            hEvent: std::ptr::null_mut(),
        }
    }
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct FT_DEVICE_LIST_INFO_NODE {
    pub Flags: u32,
    pub Type: u32,
    pub ID: u32,
    pub LocId: u32,
    pub SerialNumber: [c_char; 16], // 固定長配列 char[16]
    pub Description: [c_char; 32],  // 固定長配列 char[32]
    pub ftHandle: FT_HANDLE,
}

pub const FT_OPEN_BY_SERIAL_NUMBER: DWORD = 0x00000001;
pub const FT_OPEN_BY_DESCRIPTION: DWORD = 0x00000002;
pub const FT_OPEN_BY_LOCATION: DWORD = 0x00000004;
pub const FT_OPEN_BY_GUID: DWORD = 0x00000008;
pub const FT_OPEN_BY_INDEX: DWORD = 0x00000010;
pub const FT_LIST_ALL: DWORD = 0x20000000;
pub const FT_LIST_BY_INDEX: DWORD = 0x40000000;
pub const FT_LIST_NUMBER_ONLY: DWORD = 0x80000000;

// Endpoint IDs
pub const EP_ID_IN0: u8 = 0x82;
pub const EP_ID_IN1: u8 = 0x83;
pub const EP_ID_IN2: u8 = 0x84;
pub const EP_ID_IN3: u8 = 0x85;
pub const EP_ID_OUT0: u8 = 0x02;
pub const EP_ID_OUT1: u8 = 0x03;
pub const EP_ID_OUT2: u8 = 0x04;
pub const EP_ID_OUT3: u8 = 0x05;

// 共通の関数定義（リンク指定なしの extern "C" ブロック）
unsafe extern "C" {
    // FT_STATUS FT_CreateDeviceInfoList(LPDWORD lpdwNumDevs);
    pub fn FT_CreateDeviceInfoList(lpdwNumDevs: *mut DWORD) -> FT_STATUS;

    // FT_STATUS FT_GetDeviceInfoList(FT_DEVICE_LIST_INFO_NODE *ptDest, LPDWORD lpdwNumDevs);
    pub fn FT_GetDeviceInfoList(
        ptDest: *mut FT_DEVICE_LIST_INFO_NODE,
        lpdwNumDevs: *mut DWORD,
    ) -> FT_STATUS;

    // FT_STATUS FT_Create(PVOID pvArg, DWORD dwFlags, FT_HANDLE *pftHandle);
    pub fn FT_Create(pvArg: PVOID, dwFlags: DWORD, pftHandle: *mut FT_HANDLE) -> FT_STATUS;

    // FT_STATUS FT_Close(FT_HANDLE ftHandle);
    pub fn FT_Close(ftHandle: FT_HANDLE) -> FT_STATUS;

    // FT_STATUS FT_WritePipe(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, DWORD dwTimeoutInMs);
    #[cfg(target_os = "linux")]
    pub fn FT_WritePipe(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *const u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        dwTimeoutInMs: DWORD,
    ) -> FT_STATUS;

    // FT_STATUS FT_WritePipe(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "windows")]
    pub fn FT_WritePipe(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *const u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED,
    ) -> FT_STATUS;

    // FT_STATUS FT_WritePipeEx(FT_HANDLE ftHandle, UCHAR ucFifoID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, DWORD dwTimeoutInMs);
    #[cfg(target_os = "linux")]
    pub fn FT_WritePipeEx(
        ftHandle: FT_HANDLE,
        ucFifoID: u8,
        pucBuffer: *const u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        dwTimeoutInMs: DWORD,
    ) -> FT_STATUS;

    // FT_STATUS FT_WritePipeEx(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "windows")]
    pub fn FT_WritePipeEx(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *const u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED,
    ) -> FT_STATUS;

    // FT_STATUS FT_WritePipeAsync(FT_HANDLE ftHandle, UCHAR ucFifoID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "linux")]
    pub fn FT_WritePipeAsync(
        ftHandle: FT_HANDLE,
        ucFifoID: u8,
        pucBuffer: *const u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED,
    ) -> FT_STATUS;

    // FT_STATUS FT_ReadPipe(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, DWORD dwTimeoutInMs);
    #[cfg(target_os = "linux")]
    pub fn FT_ReadPipe(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        dwTimeoutInMs: DWORD,
    ) -> FT_STATUS;

    // FT_STATUS FT_ReadPipe(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "windows")]
    pub fn FT_ReadPipe(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED,
    ) -> FT_STATUS;

    // FT_STATUS FT_ReadPipeEx(FT_HANDLE ftHandle, UCHAR ucFifoID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, DWORD dwTimeoutInMs);
    #[cfg(target_os = "linux")]
    pub fn FT_ReadPipeEx(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        dwTimeout: DWORD,
    ) -> FT_STATUS;

    // FT_STATUS FT_ReadPipeEx(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "windows")]
    pub fn FT_ReadPipeEx(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED,
    ) -> FT_STATUS;

    // FT_STATUS FT_ReadPipeAsync(FT_HANDLE ftHandle, UCHAR ucFifoID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "linux")]
    pub fn FT_ReadPipeAsync(
        ftHandle: FT_HANDLE,
        ucFifoID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED,
    ) -> FT_STATUS;

    // FT_STATUS FT_SetPipeTimeout(FT_HANDLE ftHandle, UCHAR ucPipeID, DWORD dwTimeoutInMs);
    pub fn FT_SetPipeTimeout(ftHandle: FT_HANDLE, ucPipeID: u8, TimeoutInMs: ULONG) -> FT_STATUS;

    // FT_STATUS FT_GetPipeTimeout(FT_HANDLE ftHandle, UCHAR ucPipeID, PULONG pTimeoutInMs);
    #[cfg(target_os = "windows")]
    pub fn FT_GetPipeTimeout(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pTimeoutInMs: *mut ULONG,
    ) -> FT_STATUS;


    // FT_STATUS FT_InitializeOverlapped(FT_HANDLE ftHandle, LPOVERLAPPED pOverlapped);
    pub fn FT_InitializeOverlapped(ftHandle: FT_HANDLE, pOverlapped: *mut OVERLAPPED) -> FT_STATUS;

    // FT_STATUS FT_GetOverlappedResult(FT_HANDLE ftHandle, LPOVERLAPPED pOverlapped, PULONG pulBytesTransferred, BOOL bWait);
    pub fn FT_GetOverlappedResult(
        ftHandle: FT_HANDLE,
        pOverlapped: *mut OVERLAPPED,
        pulBytesTransferred: *mut ULONG,
        bWait: BOOL,
    ) -> FT_STATUS;

    // FT_STATUS FT_ReleaseOverlapped(FT_HANDLE ftHandle, LPOVERLAPPED pOverlapped);
    pub fn FT_ReleaseOverlapped(ftHandle: FT_HANDLE, pOverlapped: *mut OVERLAPPED) -> FT_STATUS;

    // FT_STATUS FT_SetStreamPipe(FT_HANDLE ftHandle, BOOL bAllWritePipes, BOOL bAllReadPipes, UCHAR ucPipeID, ULONG ulStreamSize);
    #[cfg(target_os = "linux")]
    pub fn FT_SetStreamPipe(
        ftHandle: FT_HANDLE,
        bAllWritePipes: BOOL,
        bAllReadPipes: BOOL,
        ucPipeID: u8,
        ulStreamSize: ULONG,
    ) -> FT_STATUS;

    // FT_STATUS FT_SetStreamPipe(FT_HANDLE ftHandle, BOOLEAN bAllWritePipes, BOOLEAN bAllReadPipes, UCHAR ucPipeID, ULONG ulStreamSize);
    #[cfg(target_os = "windows")]
    pub fn FT_SetStreamPipe(
        ftHandle: FT_HANDLE,
        bAllWritePipes: BOOLEAN,
        bAllReadPipes: BOOLEAN,
        ucPipeID: u8,
        ulStreamSize: ULONG,
    ) -> FT_STATUS;

    // FT_STATUS FT_ClearStreamPipe(FT_HANDLE ftHandle, BOOL bAllWritePipes, BOOL bAllReadPipes, UCHAR ucPipeID);
    #[cfg(target_os = "linux")]
    pub fn FT_ClearStreamPipe(
        ftHandle: FT_HANDLE,
        bAllWritePipes: BOOL,
        bAllReadPipes: BOOL,
        ucPipeID: u8,
    ) -> FT_STATUS;

    // FT_STATUS FT_ClearStreamPipe(FT_HANDLE ftHandle, BOOLEAN bAllWritePipes, BOOLEAN bAllReadPipes, UCHAR ucPipeID);
    #[cfg(target_os = "windows")]
    pub fn FT_ClearStreamPipe(
        ftHandle: FT_HANDLE,
        bAllWritePipes: BOOLEAN,
        bAllReadPipes: BOOLEAN,
        ucPipeID: u8,
    ) -> FT_STATUS;

    // FT_STATUS FT_FlushPipe(FT_HANDLE ftHandle, UCHAR ucPipeID);
    pub fn FT_FlushPipe(ftHandle: FT_HANDLE, ucPipeID: u8) -> FT_STATUS;

    // FT_STATUS FT_AbortPipe(FT_HANDLE ftHandle, UCHAR ucPipeID);
    pub fn FT_AbortPipe(ftHandle: FT_HANDLE, ucPipeID: u8) -> FT_STATUS;



        

}
