

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
unsafe extern "C" {
    pub fn FT_CreateDeviceInfoList(lpdwNumDevs: *mut u32) -> FT_STATUS;

//  pub fn FT_Create(deviceIndex: u32, flags: u32, pHandle: *mut *mut std::ffi::c_void) -> u32;
//  pub fn FT_Close(handle: *mut std::ffi::c_void) -> u32;
}


		// FT_STATUS WINAPI FT_CreateDeviceInfoList(
		// LPDWORD lpdwNumDevs
		// );