use std::error::Error;
use rtcl_d3xx::*;

//const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
//const OPCODE_AXI4S_TRANS: u8 = 0x10;


fn main() -> Result<(), Box<dyn Error>> {
    println!("Hello, world!");

    let (mut usb_tx, mut usb_rx) = D3xxDevice::new(0)?;

    usb_tx.set_timeout(1000)?;
    usb_rx.set_timeout(1000)?;

    // スレッドで応答をポーリングしてみる
    std::thread::spawn(move || {
        loop {
            let result = usb_rx.read(1024);
            match result {
                Ok(data) => {
                    println!("Read data: {:?}", data);
                    if data.len() > 0 {
                        break;  // 何か受信出来たら終了
                    }
                }
                Err(e) => {
                    eprintln!("Error reading data: {}", e);
                    break;
                }
            }
        }
    });

    // 5秒待ってから書き込み開始
    std::thread::sleep(std::time::Duration::from_millis(5000));

    // write
    let mut write_buf = Vec::<u8>::with_capacity(8);
    write_buf.push(OPCODE_AXI4L_READ);
    write_buf.push(0);
    write_buf.extend_from_slice(&4u16.to_le_bytes());
    write_buf.extend_from_slice(&0u32.to_le_bytes());
    usb_tx.write(&write_buf)?;

    // read
    // let read_data = usb_rx.read(8)?;
    // println!("Read data: {:?}", read_data);

    // 読み出しスレッドの完了も少し待つ
    std::thread::sleep(std::time::Duration::from_millis(5000));

    Ok(())
}
