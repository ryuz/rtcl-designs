#![allow(unused)]

const MOMENT_BASE: usize = 0xa040_4000;

const REG_IMG_MOMENT_CORE_ID      : usize = 0x00;
const REG_IMG_MOMENT_CORE_VERSION : usize = 0x01;
const REG_IMG_MOMENT_IRQ_ENABLE   : usize = 0x08;
const REG_IMG_MOMENT_IRQ_STATUS   : usize = 0x09;
const REG_IMG_MOMENT_IRQ_CLR      : usize = 0x0a;
const REG_IMG_MOMENT_IRQ_SET      : usize = 0x0b;
const REG_IMG_MOMENT_OUT_VALID    : usize = 0x20;
const REG_IMG_MOMENT_OUT_READY    : usize = 0x21;
const REG_IMG_MOMENT_OUT_X_LO     : usize = 0x30;
const REG_IMG_MOMENT_OUT_X_HI     : usize = 0x31;
const REG_IMG_MOMENT_OUT_Y_LO     : usize = 0x32;
const REG_IMG_MOMENT_OUT_Y_HI     : usize = 0x33;
const REG_IMG_MOMENT_MOMENT_VALID : usize = 0x40;
const REG_IMG_MOMENT_MOMENT_READY : usize = 0x41;
const REG_IMG_MOMENT_MOMENT_M00   : usize = 0x50;
const REG_IMG_MOMENT_MOMENT_M10   : usize = 0x52;
const REG_IMG_MOMENT_MOMENT_M01   : usize = 0x54;


// レジスタ書き込み
fn wrtie_reg(reg: usize, data: i64) {
    let p = (MOMENT_BASE + 8 * reg) as *mut i64;
    unsafe {
        core::ptr::write_volatile(p, data);
    }
}

// レジスタ読み出し
fn read_reg(reg: usize) -> i64 {
    let p = (MOMENT_BASE + 8 * reg) as *const i64;
    unsafe { core::ptr::read_volatile(p) }
}

// UART書き込み
fn wrtie_uart(tx: u8) {
    let p = 0xa0500000 as *mut u8;
    unsafe {
        core::ptr::write_volatile(p, tx);
    }
}

// レーザープロジェクタへ座標送信
fn send_projector_xy(x: i16, y: i16, laser_on: bool) {
    let xh = ((x as u16) >> 8) as u8;
    let xl = (x as u16 & 0xff) as u8;
    let yh = ((y as u16) >> 8) as u8;
    let yl = (y as u16 & 0xff) as u8;
    let flg = if laser_on { 0x01 } else { 0x00 };
    let chk = xh ^ xl ^ yh ^ yl ^ flg;
    wrtie_uart(0xa5);
    wrtie_uart(xh);
    wrtie_uart(xl);
    wrtie_uart(yh);
    wrtie_uart(yl);
    wrtie_uart(flg);
    wrtie_uart(chk);
}


pub fn get_id() -> u64 {
    read_reg(REG_IMG_MOMENT_CORE_ID) as u64
}

pub fn get_version() -> u64 {
    read_reg(REG_IMG_MOMENT_CORE_VERSION) as u64
}

pub fn get_irq_status() -> u64 {
    read_reg(REG_IMG_MOMENT_IRQ_STATUS) as u64
}

pub fn get_moment_valid() -> u64 {
    read_reg(REG_IMG_MOMENT_MOMENT_VALID) as u64
}

pub fn start() {
    wrtie_reg(REG_IMG_MOMENT_IRQ_ENABLE, 0x1); // IRQ enable
}

pub fn stop() {
    wrtie_reg(REG_IMG_MOMENT_IRQ_ENABLE, 0x0); // IRQ disaable
}

pub fn irq_handler() {
    // 読み出し
    let m00 = read_reg(REG_IMG_MOMENT_MOMENT_M00) as f64;
    let m10 = read_reg(REG_IMG_MOMENT_MOMENT_M10) as f64;
    let m01 = read_reg(REG_IMG_MOMENT_MOMENT_M01) as f64;
    wrtie_reg(REG_IMG_MOMENT_MOMENT_READY, 0x1);
    wrtie_reg(REG_IMG_MOMENT_IRQ_CLR, 0x1);
    
    // 計算
    let x = m10 / m00;
    let y = m01 / m00;

    unsafe {
        static mut IRQ_COUNT: u32 = 0;
        IRQ_COUNT += 1;
        if IRQ_COUNT % 1000 == 0 {
            println!("x : {}  y : {}", x, y);
        }
    }

    // クリップ
//  let x = x.min(255.0).max(-255.0);
//  let y = y.min(255.0).max(-255.0);

    // 固定小数点化
    let vx = (x * 65536.0) as i64;
    let vy = (y * 65536.0) as i64;

    // 書き込み
    unsafe {
        wrtie_reg(REG_IMG_MOMENT_OUT_X_LO, vx);
        wrtie_reg(REG_IMG_MOMENT_OUT_Y_LO, vy);
        wrtie_reg(REG_IMG_MOMENT_OUT_VALID, 0x1);
    }

    // Laser Projectorへ送信
    unsafe {
        let gain = 1.0;
        let px = (x * gain) as i16;
        let py = (y * gain) as i16;
        send_projector_xy(px as i16, py as i16, true);
    }
}
