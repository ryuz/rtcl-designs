
use std::error::Error;
use rtcl_d3xx::*;


const ADDR_ID      : u32 =0x0000_0000;
const ADDR_VERSION : u32 =0x0000_0004;
const ADDR_USER0   : u32 =0x0000_0008;
const ADDR_USER1   : u32 =0x0000_000c;
const ADDR_PUSH_SW : u32 =0x0000_0010;
const ADDR_DIP_SW  : u32 =0x0000_0014;
const ADDR_LED     : u32 =0x0000_0018;
const ADDR_PMOD    : u32 =0x0000_001c;


fn main() -> Result<(), Box<dyn Error>> {
    println!("Tang Ptimer25k Calc Summation");

    // OpenDevice
    let (axi4l, mut axi4s_rx, axi4s_tx) = D3xxFifo32Direct::new(0)?;

    // register read
    println!("read  ID      : 0x{:08x}", axi4l.read_axi4l(ADDR_ID)?);
    println!("read  VERSION : 0x{:08x}", axi4l.read_axi4l(ADDR_VERSION)?);
    println!("read  PUSH_SW : 0x{:08x}", axi4l.read_axi4l(ADDR_PUSH_SW)?);
    println!("read  DIP_SW  : 0x{:08x}", axi4l.read_axi4l(ADDR_DIP_SW)?);

    // User Registe Read Write
    println!("read  USER0   : 0x{:08x}", axi4l.read_axi4l(ADDR_USER0)?);
    println!("read  USER1   : 0x{:08x}", axi4l.read_axi4l(ADDR_USER1)?);

    println!("write USER0   : wdata = 0x12345678 wstrb=0b1111");
    axi4l.write_axi4l(ADDR_USER0, 0x12345678, 0b1111)?;
    println!("write USER1   : wdata = 0xfedcba98 wstrb=0b1111");
    axi4l.write_axi4l(ADDR_USER1, 0xfedcba98, 0b1111)?;
    println!("read  USER0   : 0x{:08x}", axi4l.read_axi4l(ADDR_USER0)?);
    println!("read  USER1   : 0x{:08x}", axi4l.read_axi4l(ADDR_USER1)?);

    println!("write USER0   : wdata = 0xaa55aa55 wstrb=0b1010");
    axi4l.write_axi4l(ADDR_USER0, 0xaa55aa55, 0b1010)?;
    println!("write USER1   : wdata = 0xaa55aa55 wstrb=0b0101");
    axi4l.write_axi4l(ADDR_USER1, 0xaa55aa55, 0b0101)?;
    println!("read  USER0   : 0x{:08x}", axi4l.read_axi4l(ADDR_USER0)?);
    println!("read  USER1   : 0x{:08x}", axi4l.read_axi4l(ADDR_USER1)?);


    // LED Blink
    for i in 0..3 {
        println!("LED ON");
        axi4l.write_axi4l(ADDR_LED, 0x03, 0b1111)?;
        axi4l.write_axi4l(ADDR_PMOD, 0xff, 0b1111)?;
        std::thread::sleep(std::time::Duration::from_millis(500));
        println!("LED OFF");
        axi4l.write_axi4l(ADDR_LED, 0x00, 0b1111)?;
        axi4l.write_axi4l(ADDR_PMOD, 0x00, 0b1111)?;
        std::thread::sleep(std::time::Duration::from_millis(500));
    }

    // AXI4-Stream データ送信
    let input_data: [u32; 10] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // データ送信(リトルエンディアンでバイト配列に変換して送信)
    let input_bytes: Vec<u8> = input_data
        .iter()
        .flat_map(|&v| v.to_le_bytes())
        .collect();
    axi4s_tx.send_data(&input_bytes, 0)?;


    // AXI4-Stream データ受信
    let result_bytes = axi4s_rx.recv_data_exact(input_bytes.len())?;
    // バイト配列をu32配列に変換
    let result: Vec<u32> = result_bytes
        .chunks(4)
        .map(|chunk| u32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]))
        .collect();

    println!("Summation result: {:?}", result);

    Ok(())
}
