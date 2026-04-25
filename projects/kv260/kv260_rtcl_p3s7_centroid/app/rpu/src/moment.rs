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

const OCM_X: usize = 0x08;
const OCM_Y: usize = 0x01;
const OCM_OFFSET_X: usize = 0x10;
const OCM_OFFSET_Y: usize = 0x11;
const OCM_M00_LIMIT: usize = 0x14;
const OCM_LATENCY: usize = 0x18;
const OCM_PRJ_GIAN_X: usize = 0x20;
const OCM_PRJ_GIAN_Y: usize = 0x21;
const OCM_PRJ_OFFSET_X: usize = 0x24;
const OCM_PRJ_OFFSET_Y: usize = 0x25;
const OCM_PRJ_X_MIN: usize = 0x26;
const OCM_PRJ_X_MAX: usize = 0x27;
const OCM_PRJ_Y_MIN: usize = 0x28;
const OCM_PRJ_Y_MAX: usize = 0x29;
const OCM_PRJ_X: usize = 0x40;
const OCM_PRJ_Y: usize = 0x41;

const MAX_FRAME_LATENCY: usize = 999;
const FRAME_HISTORY_LEN: usize = MAX_FRAME_LATENCY + 1;

static mut X_HISTORY: [f64; FRAME_HISTORY_LEN] = [0.0; FRAME_HISTORY_LEN];
static mut Y_HISTORY: [f64; FRAME_HISTORY_LEN] = [0.0; FRAME_HISTORY_LEN];
static mut HISTORY_WR_INDEX: usize = 0;
static mut HISTORY_VALID_COUNT: usize = 0;



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

// OCM書き込み
fn write_ocm_u64(index: usize, data: u64) {
    let p = (0xfffc0000 + 8 * index) as *mut u64;
    unsafe {
        core::ptr::write_volatile(p, data);
    }
}

// OCM読み出し
pub fn read_ocm_u64(index: usize) -> u64 {
    let p = (0xfffc0000 + 8 * index) as *mut u64;
    unsafe { core::ptr::read_volatile(p) }
}

// OCM書き込み(f64)
fn write_ocm_f64(index: usize, data: f64) {
    let p = (0xfffc0000 + 8 * index) as *mut f64;
    unsafe {
        core::ptr::write_volatile(p, data);
    }
}

// OCM読み出し(f64)
pub fn read_ocm_f64(index: usize) -> f64 {
    let p = (0xfffc0000 + 8 * index) as *mut f64;
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
    write_ocm_f64(OCM_X, 0.0);
    write_ocm_f64(OCM_Y, 0.0);
    write_ocm_f64(OCM_OFFSET_X, 0.0);
    write_ocm_f64(OCM_OFFSET_Y, 0.0);
    write_ocm_f64(OCM_M00_LIMIT, 0.0);
    write_ocm_u64(OCM_LATENCY, 0);
    write_ocm_f64(OCM_PRJ_GIAN_X, 1.0);
    write_ocm_f64(OCM_PRJ_GIAN_Y, 1.0);
    write_ocm_f64(OCM_PRJ_OFFSET_X, 0.0);
    write_ocm_f64(OCM_PRJ_OFFSET_Y, 0.0);
    write_ocm_f64(OCM_PRJ_X_MIN, -255.0*2.0);
    write_ocm_f64(OCM_PRJ_X_MAX, 255.0*2.0);
    write_ocm_f64(OCM_PRJ_Y_MIN, -255.0*2.0);
    write_ocm_f64(OCM_PRJ_Y_MAX, 255.0*2.0);
    write_ocm_f64(OCM_PRJ_X, 0.0);
    write_ocm_f64(OCM_PRJ_Y, 0.0);

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
    let limit = read_ocm_f64(OCM_M00_LIMIT);
    let old_x = read_ocm_f64(OCM_X);
    let old_y = read_ocm_f64(OCM_Y);
    let x = if m00 > limit { m10 / m00 } else { old_x };
    let y = if m00 > limit { m01 / m00 } else { old_y };

    // オフセット補正
    let x = x + read_ocm_f64(OCM_OFFSET_X);
    let y = y + read_ocm_f64(OCM_OFFSET_Y);

    // 保存
    write_ocm_f64(OCM_X, x);
    write_ocm_f64(OCM_Y, y);

    
    // ここまでの x, y を保存して、指定レイテンシ数前のフレームの計算結果を利用
    let latency = (read_ocm_u64(OCM_LATENCY) as usize).min(MAX_FRAME_LATENCY);
    let (x, y) = unsafe {
        X_HISTORY[HISTORY_WR_INDEX] = x;
        Y_HISTORY[HISTORY_WR_INDEX] = y;

        if HISTORY_VALID_COUNT < FRAME_HISTORY_LEN {
            HISTORY_VALID_COUNT += 1;
        }

        let delay = latency.min(HISTORY_VALID_COUNT - 1);
        let read_index = (HISTORY_WR_INDEX + FRAME_HISTORY_LEN - delay) % FRAME_HISTORY_LEN;

        let delayed_x = X_HISTORY[read_index];
        let delayed_y = Y_HISTORY[read_index];

        HISTORY_WR_INDEX = (HISTORY_WR_INDEX + 1) % FRAME_HISTORY_LEN;

        (delayed_x, delayed_y)
    };

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
    let px = x * read_ocm_f64(OCM_PRJ_GIAN_X) + read_ocm_f64(OCM_PRJ_OFFSET_X);
    let py = y * read_ocm_f64(OCM_PRJ_GIAN_Y) + read_ocm_f64(OCM_PRJ_OFFSET_Y);
    let px = px.min(read_ocm_f64(OCM_PRJ_X_MAX)).max(read_ocm_f64(OCM_PRJ_X_MIN));
    let py = py.min(read_ocm_f64(OCM_PRJ_Y_MAX)).max(read_ocm_f64(OCM_PRJ_Y_MIN));
    write_ocm_f64(OCM_PRJ_X, px);
    write_ocm_f64(OCM_PRJ_Y, py);
    send_projector_xy(px as i16, py as i16, true);

    // デバッグ用
    if true {
        unsafe {
            static mut IRQ_COUNT: u32 = 0;
            IRQ_COUNT += 1;
            if IRQ_COUNT % 1000 == 0 {
                println!("x:{}  y:{} px:{} py:{}", x, y, px, py);
            }
        }
    }
}
