#![allow(dead_code)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

use std::os::raw::c_char;
use std::ffi::c_void;

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
pub type PVOID = *mut c_void;
pub type LPVOID = PVOID;
pub type HANDLE = *mut c_void;

pub type FT_STATUS = ULONG;
pub type FT_HANDLE = *mut c_void;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct OVERLAPPED_OFFSET {
    pub Offset: DWORD,
    pub OffsetHigh: DWORD,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union OVERLAPPED_UNION {
    pub offset: OVERLAPPED_OFFSET, // 構造体（Offset と OffsetHigh）
    pub Pointer: PVOID,            // ポインタ
}

// 3. 本体構造体
#[repr(C)]
#[derive(Clone, Copy)]
pub struct OVERLAPPED {
    pub Internal: DWORD,
    pub InternalHigh: DWORD,
    pub u: OVERLAPPED_UNION,       // 無名unionだった部分に名前（uなど）を付ける
    pub hEvent: HANDLE,
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

pub const FT_OPEN_BY_SERIAL_NUMBER : DWORD = 0x00000001;
pub const FT_OPEN_BY_DESCRIPTION   : DWORD = 0x00000002;
pub const FT_OPEN_BY_LOCATION      : DWORD = 0x00000004;
pub const FT_OPEN_BY_GUID          : DWORD = 0x00000008;
pub const FT_OPEN_BY_INDEX	       : DWORD = 0x00000010;

pub const PIPE_ID_IN0  : u8 = 0x82;
pub const PIPE_ID_IN1  : u8 = 0x83;
pub const PIPE_ID_IN2  : u8 = 0x84;
pub const PIPE_ID_IN3  : u8 = 0x85;
pub const PIPE_ID_OUT0 : u8  = 0x02;
pub const PIPE_ID_OUT1 : u8  = 0x03;
pub const PIPE_ID_OUT2 : u8  = 0x04;
pub const PIPE_ID_OUT3 : u8  = 0x05;


// 共通の関数定義（リンク指定なしの extern "C" ブロック）
unsafe extern "C" {
    // FT_STATUS WINAPI FT_CreateDeviceInfoList(LPDWORD lpdwNumDevs);
    pub fn FT_CreateDeviceInfoList(lpdwNumDevs: *mut DWORD) -> FT_STATUS;

    // FT_STATUS FT_GetDeviceInfoList(FT_DEVICE_LIST_INFO_NODE *ptDest, LPDWORD lpdwNumDevs);
    pub fn FT_GetDeviceInfoList(ptDest: *mut FT_DEVICE_LIST_INFO_NODE, lpdwNumDevs: *mut DWORD) -> FT_STATUS;

    // FT_STATUS FT_Create(PVOID pvArg, DWORD dwFlags, FT_HANDLE *pftHandle;
    pub fn FT_Create(pvArg: PVOID, dwFlags: DWORD, pftHandle: *mut FT_HANDLE) -> FT_STATUS;

    // FT_STATUS FT_Close(FT_HANDLE ftHandle);
    pub fn FT_Close(ftHandle: FT_HANDLE) -> FT_STATUS;

   // FT_STATUS FT_WritePipe(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
   pub fn FT_WritePipe(
       ftHandle: FT_HANDLE,
       ucPipeID: u8,
       pucBuffer: *const u8,
       ulBufferLength: ULONG,
       pulBytesTransferred: *mut ULONG,
       pOverlapped: *mut OVERLAPPED, // LPOVERLAPPED は Windows の OVERLAPPED 構造体へのポインタ
    ) -> FT_STATUS;

    // FT_STATUS FT_ReadPipe(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    pub fn FT_ReadPipe(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED // LPOVERLAPPED は Windows の OVERLAPPED 構造体へのポインタ
    ) -> FT_STATUS;

    // FT_STATUS WINAPI FT_ReadPipeEx(FT_HANDLE ftHandle, UCHAR ucPipeID, PUCHAR pucBuffer, ULONG ulBufferLength, PULONG pulBytesTransferred, LPOVERLAPPED pOverlapped);
    #[cfg(target_os = "linux")]
    pub fn FT_ReadPipeEx(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        dwTimeout: DWORD
    ) -> FT_STATUS;

    #[cfg(target_os = "windows")]
    pub fn FT_ReadPipeEx(
        ftHandle: FT_HANDLE,
        ucPipeID: u8,
        pucBuffer: *mut u8,
        ulBufferLength: ULONG,
        pulBytesTransferred: *mut ULONG,
        pOverlapped: *mut OVERLAPPED
    ) -> FT_STATUS;

    // FT_STATUS FT_SetPipeTimeout(FT_HANDLE ftHandle, UCHAR ucPipeID, ULONG TimeoutInMs);
    pub fn FT_SetPipeTimeout(ftHandle: FT_HANDLE, ucPipeID: u8, TimeoutInMs: ULONG) -> FT_STATUS;

    // FT_STATUS WINAPI FT_GetPipeTimeout(FT_HANDLE ftHandle, UCHAR ucPipeID, PULONG pTimeoutInMs);
    #[cfg(target_os = "windows")]
    pub fn FT_GetPipeTimeout(ftHandle: FT_HANDLE, ucPipeID: u8, pTimeoutInMs: *mut ULONG) -> FT_STATUS;
}

