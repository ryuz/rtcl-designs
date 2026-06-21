#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

// Windowsの場合は FTD3XXWU をリンク
#[cfg(target_os = "windows")]
#[link(name = "FTD3XXWU")]
unsafe extern "C" {}


// Linuxの場合は ftd3xx をリンク
#[cfg(target_os = "linux")]
#[link(name = "ftd3xx")]
unsafe extern "C" {}

type FT_STATUS = u32;

// 共通の関数定義（リンク指定なしの extern "C" ブロック）
#[link(name = "FTD3XXWU")]
unsafe extern "C" {
	// FT_STATUS WINAPI FT_CreateDeviceInfoList(LPDWORD lpdwNumDevs);
	pub fn FT_CreateDeviceInfoList(lpdwNumDevs: *mut u32) -> FT_STATUS;

	

}


