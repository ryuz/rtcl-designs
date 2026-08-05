

const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
const OPCODE_AXI4S_TRANS: u8 = 0x10;


#[derive(Debug, Clone)]
pub struct Axi4Stream {
    pub tuser: u8,
    pub tdata: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct VideoFrame {
    pub frame_id: u64,
    pub height: u32,
    pub width: usize,
    pub data: Vec<u8>,
}


// FFI module
mod ffi;
pub use ffi::*;

// D3xx device module
mod d3xx_device;
pub use d3xx_device::*;

// FIFO32 AXI を直接操作するモジュール
mod fifo32_axi4_direct;
pub use fifo32_axi4_direct::*;

// FIFO32 AXI をスレッド経由で操作するモジュール
mod fifo32_axi4;
pub use fifo32_axi4::*;

// Video capture module
mod video_capture;
pub use video_capture::*;
