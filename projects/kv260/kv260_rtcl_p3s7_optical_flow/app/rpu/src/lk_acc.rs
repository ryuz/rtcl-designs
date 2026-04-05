#![allow(unused)]

const LK_ACC_BASE: usize = 0xa0410000;

const REG_IMG_LK_ACC_CORE_ID: usize = 0x00;
const REG_IMG_LK_ACC_CORE_VERSION: usize = 0x01;
const REG_IMG_LK_ACC_CTL_CONTROL: usize = 0x04;
const REG_IMG_LK_ACC_CTL_STATUS: usize = 0x05;
const REG_IMG_LK_ACC_CTL_INDEX: usize = 0x07;
const REG_IMG_LK_ACC_IRQ_ENABLE: usize = 0x08;
const REG_IMG_LK_ACC_IRQ_STATUS: usize = 0x09;
const REG_IMG_LK_ACC_IRQ_CLR: usize = 0x0a;
const REG_IMG_LK_ACC_IRQ_SET: usize = 0x0b;
const REG_IMG_LK_ACC_PARAM_X: usize = 0x10;
const REG_IMG_LK_ACC_PARAM_Y: usize = 0x11;
const REG_IMG_LK_ACC_PARAM_WIDTH: usize = 0x12;
const REG_IMG_LK_ACC_PARAM_HEIGHT: usize = 0x13;
const REG_IMG_LK_ACC_ACC_VALID: usize = 0x40;
const REG_IMG_LK_ACC_ACC_READY: usize = 0x41;
const REG_IMG_LK_ACC_ACC_GXX0: usize = 0x42;
const REG_IMG_LK_ACC_ACC_GXX1: usize = 0x43;
const REG_IMG_LK_ACC_ACC_GYY0: usize = 0x44;
const REG_IMG_LK_ACC_ACC_GYY1: usize = 0x45;
const REG_IMG_LK_ACC_ACC_GXY0: usize = 0x46;
const REG_IMG_LK_ACC_ACC_GXY1: usize = 0x47;
const REG_IMG_LK_ACC_ACC_EX0: usize = 0x48;
const REG_IMG_LK_ACC_ACC_EX1: usize = 0x49;
const REG_IMG_LK_ACC_ACC_EY0: usize = 0x4a;
const REG_IMG_LK_ACC_ACC_EY1: usize = 0x4b;
const REG_IMG_LK_ACC_OUT_VALID: usize = 0x60;
const REG_IMG_LK_ACC_OUT_READY: usize = 0x61;
const REG_IMG_LK_ACC_OUT_DX0: usize = 0x64;
const REG_IMG_LK_ACC_OUT_DX1: usize = 0x65;
const REG_IMG_LK_ACC_OUT_DY0: usize = 0x66;
const REG_IMG_LK_ACC_OUT_DY1: usize = 0x67;

const OCM_X_MIN: usize = 0x10;
const OCM_X_MAX: usize = 0x11;
const OCM_Y_MIN: usize = 0x12;
const OCM_Y_MAX: usize = 0x13;
const OCM_PRJ_GIAN_X: usize = 0x20;
const OCM_PRJ_GIAN_Y: usize = 0x21;
const OCM_PRJ_DECAY_X: usize = 0x22;
const OCM_PRJ_DECAY_Y: usize = 0x23;
const OCM_PRJ_OFFSET_X: usize = 0x24;
const OCM_PRJ_OFFSET_Y: usize = 0x25;
const OCM_PRJ_X_MIN: usize = 0x26;
const OCM_PRJ_X_MAX: usize = 0x27;
const OCM_PRJ_Y_MIN: usize = 0x28;
const OCM_PRJ_Y_MAX: usize = 0x29;
const OCM_PRJ_X: usize = 0x40;
const OCM_PRJ_Y: usize = 0x41;


// レジスタ書き込み
fn wrtie_reg(reg: usize, data: i64) {
    let p = (LK_ACC_BASE + 8 * reg) as *mut i64;
    unsafe {
        core::ptr::write_volatile(p, data);
    }
}

// レジスタ読み出し
fn read_reg(reg: usize) -> i64 {
    let p = (LK_ACC_BASE + 8 * reg) as *const i64;
    unsafe { core::ptr::read_volatile(p) }
}

// OCM書き込み
fn write_ocm_f64(index: usize, data: f64) {
    let p = (0xfffc0000 + 8 * index) as *mut f64;
    unsafe {
        core::ptr::write_volatile(p, data);
    }
}

// OCM読み出し
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
    read_reg(REG_IMG_LK_ACC_CORE_ID) as u64
}

pub fn get_version() -> u64 {
    read_reg(REG_IMG_LK_ACC_CORE_VERSION) as u64
}

pub fn get_irq_status() -> u64 {
    read_reg(REG_IMG_LK_ACC_IRQ_STATUS) as u64
}

pub fn get_acc_valid() -> u64 {
    read_reg(REG_IMG_LK_ACC_ACC_VALID) as u64
}

pub fn start() {
    write_ocm_f64(OCM_X_MIN, -255.0);
    write_ocm_f64(OCM_X_MAX, 255.0);
    write_ocm_f64(OCM_Y_MIN, -255.0);
    write_ocm_f64(OCM_Y_MAX, 255.0);
    write_ocm_f64(OCM_PRJ_GIAN_X, 1.0);
    write_ocm_f64(OCM_PRJ_GIAN_Y, 1.0);
    write_ocm_f64(OCM_PRJ_DECAY_X, 0.999);
    write_ocm_f64(OCM_PRJ_DECAY_Y, 0.999);
    write_ocm_f64(OCM_PRJ_OFFSET_X, 0.0);
    write_ocm_f64(OCM_PRJ_OFFSET_Y, 0.0);
    write_ocm_f64(OCM_PRJ_X_MIN, -255.0*2.0);
    write_ocm_f64(OCM_PRJ_X_MAX, 255.0*2.0);
    write_ocm_f64(OCM_PRJ_Y_MIN, -255.0*2.0);
    write_ocm_f64(OCM_PRJ_Y_MAX, 255.0*2.0);
    write_ocm_f64(OCM_PRJ_X, 0.0);
    write_ocm_f64(OCM_PRJ_Y, 0.0);

    wrtie_reg(REG_IMG_LK_ACC_IRQ_ENABLE, 0x1); // IRQ enable
}

pub fn stop() {
    wrtie_reg(REG_IMG_LK_ACC_IRQ_ENABLE, 0x0); // IRQ disaable
}

pub fn irq_handler() {
    // 読み出し
    let gx2 = read_reg(REG_IMG_LK_ACC_ACC_GXX0) as f64;
    let gy2 = read_reg(REG_IMG_LK_ACC_ACC_GYY0) as f64;
    let gxy = read_reg(REG_IMG_LK_ACC_ACC_GXY0) as f64;
    let ex = read_reg(REG_IMG_LK_ACC_ACC_EX0) as f64;
    let ey = read_reg(REG_IMG_LK_ACC_ACC_EY0) as f64;
    wrtie_reg(REG_IMG_LK_ACC_ACC_READY, 0x1);
    wrtie_reg(REG_IMG_LK_ACC_IRQ_CLR, 0x1);

    // 計算
    let det = gx2 * gy2 - gxy * gxy;
    let dx = 64.0 * -(gy2 * ex - gxy * ey) / det;
    let dy = 64.0 * -(gx2 * ey - gxy * ex) / det;

    // クリップ
    let dx = dx.min(255.0).max(-255.0);
    let dy = dy.min(255.0).max(-255.0);

    // 固定小数点化
    let vx = (dx * 65536.0) as i64;
    let vy = (dy * 65536.0) as i64;

    // 書き込み
    unsafe {
        wrtie_reg(REG_IMG_LK_ACC_OUT_DX0, vx);
        wrtie_reg(REG_IMG_LK_ACC_OUT_DY0, vy);
        wrtie_reg(REG_IMG_LK_ACC_OUT_VALID, 0x1);
    }

    // Laser Projectorへ送信
    let mut prj_x : f64 = read_ocm_f64(OCM_PRJ_X);
    let mut prj_y : f64 = read_ocm_f64(OCM_PRJ_Y);

    prj_x += dx * read_ocm_f64(OCM_PRJ_GIAN_X);
    prj_y += dy * read_ocm_f64(OCM_PRJ_GIAN_Y);

    // 減衰
    prj_x *= read_ocm_f64(OCM_PRJ_DECAY_X);
    prj_y *= read_ocm_f64(OCM_PRJ_DECAY_Y);

    // クリップ
    prj_x = prj_x.min(read_ocm_f64(OCM_PRJ_X_MAX)).max(read_ocm_f64(OCM_PRJ_X_MIN));
    prj_y = prj_y.min(read_ocm_f64(OCM_PRJ_Y_MAX)).max(read_ocm_f64(OCM_PRJ_Y_MIN));

    // 現在地更新
    write_ocm_f64(OCM_PRJ_X, prj_x);
    write_ocm_f64(OCM_PRJ_Y, prj_y);

    // プロジェクタへ送信
    let px = prj_x + read_ocm_f64(OCM_PRJ_OFFSET_X);
    let py = prj_y + read_ocm_f64(OCM_PRJ_OFFSET_Y);
    send_projector_xy(px as i16, py as i16, true);

    // デバッグ出力
    if false {
        unsafe {
            static mut IRQ_COUNT: u32 = 0;
            IRQ_COUNT += 1;
            if IRQ_COUNT % 1000 == 0 {
                println!("dx : {}  dy : {}", dx, dy);
                println!("px : {}  py : {}", px, py);
            }
        }
    }
}
