
use std::error::Error;
use rtcl_d3xx::*;


fn main() -> Result<(), Box<dyn Error>> {
    println!("Tang Ptimer25k Calc Summation");

    // OpenDevice
    let (axi4l, mut axi4s_rx, axi4s_tx) = D3xxFifo32Direct::new(0)?;

    // register read
    println!("CORE_ID  : 0x{:08x}", axi4l.read_axi4l(0x0000)?);
    println!("CORE_VER : 0x{:08x}", axi4l.read_axi4l(0x0004)?);

    // 入力データ
    let input_data: [u32; 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // データ送信(リトルエンディアンでバイト配列に変換して送信)
    let input_bytes: Vec<u8> = input_data
        .iter()
        .flat_map(|&v| v.to_le_bytes())
        .collect();
    axi4s_tx.send_data(&input_bytes, 0)?;

    std::thread::sleep(std::time::Duration::from_millis(100));

    // 結果受信(4バイト受信しでリトルエンディアンでu32に変換して受信)
    let result_bytes = axi4s_rx.recv_data_exact(std::mem::size_of::<u32>())?;
    if result_bytes.len() != std::mem::size_of::<u32>() {
        return Err(format!(
            "unexpected result size: {}",
            result_bytes.len()
        )
        .into());
    }
    let result: u32 = u32::from_le_bytes([
        result_bytes[0],
        result_bytes[1],
        result_bytes[2],
        result_bytes[3],
    ]);

    println!("Summation result: {}", result);

    Ok(())
}
