use std::error::Error;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use rtcl_d3xx::*;

fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 loopback test");

    const RANDOM_SEED: u64 = 0x1234_5678_9abc_deff;
    let seed = RANDOM_SEED;
    println!("Random seed: {}", seed);
    let mut rng = StdRng::seed_from_u64(seed);

    // Open the first device found.
    let (mut usb_tx, mut usb_rx) = D3xxDevice::new(0, 1)?;

    usb_tx[0].set_timeout(1000)?;
    usb_rx[0].set_timeout(1000)?;

    const PACKET_SIZE: usize = 1024;
    const ITERETIONS: usize = 1000;

    let mut tx_buf = vec![0; PACKET_SIZE];
    
    // データチェック
    for itr in 0..ITERETIONS {
        // 乱数で初期化
        rng.fill_bytes(&mut tx_buf);

        // write
        usb_tx[0].write(&tx_buf).expect("failed to write to device");

        // read
        let rx_data = usb_rx[0].read_with_timeout(tx_buf.len(), std::time::Duration::from_millis(1000)).expect("failed to read from device");

        // 32bit配列に変換
        let tx_data_32bit: Vec<i32> = tx_buf.chunks_exact(4).map(|chunk| {i32::from_le_bytes(chunk.try_into().unwrap())}).collect();
        let rx_data_32bit: Vec<i32> = rx_data.chunks_exact(4).map(|chunk| {i32::from_le_bytes(chunk.try_into().unwrap())}).collect();
//      println!("tx_len = {}, rx_len = {}", tx_data_32bit.len(), rx_data_32bit.len());
        // verify
        if tx_data_32bit != rx_data_32bit {
            for i in 0..rx_data_32bit.len() {
                if rx_data_32bit[i] != tx_data_32bit[i] {
                    println!("Data mismatch at index {:08x}: tx = {:08x}, rx = {:08x} diff = {:08x}", i, tx_data_32bit[i], rx_data_32bit[i], tx_data_32bit[i] ^ rx_data_32bit[i]);
                }
            }
            eprintln!("Data mismatch! {}", itr);
            return Err("Data mismatch".into());
        }
    }

    Ok(())
}
