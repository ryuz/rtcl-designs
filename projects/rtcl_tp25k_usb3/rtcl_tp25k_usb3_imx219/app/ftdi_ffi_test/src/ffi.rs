#![allow(dead_code)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

use std::os::raw::{c_char};

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
pub type PVOID = *mut std::ffi::c_void;
pub type LPVOID = PVOID;

pub type FT_STATUS = ULONG;
pub type FT_HANDLE = *mut std::ffi::c_void;

pub const FT_OPEN_BY_SERIAL_NUMBER : DWORD = 0x00000001;
pub const FT_OPEN_BY_DESCRIPTION   : DWORD = 0x00000002;
pub const FT_OPEN_BY_LOCATION      : DWORD = 0x00000004;
pub const FT_OPEN_BY_GUID          : DWORD = 0x00000008;
pub const FT_OPEN_BY_INDEX	       : DWORD = 0x00000010;


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

}
