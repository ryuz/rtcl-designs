use std::error::Error;
use std::time::Instant;
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
    let (mut usb_tx, mut usb_rx) = D3xxDevice::new(0)?;

    usb_tx.set_timeout(1000)?;
    usb_rx.set_timeout(1000)?;

    const PACKET_SIZE: usize = 1024*4*16;
    const ITERETIONS: usize = 1000;

    let mut tx_buf = vec![0; PACKET_SIZE];
    
    // データチェック
    for itr in 0..ITERETIONS {
        // 乱数で初期化
        for i in 0..tx_buf.len() {
            tx_buf[i] = if i % 2 == 0 { 0xaa } else { 0x55 };
        }
        rng.fill_bytes(&mut tx_buf);

        // write
        usb_tx.burst_write(&tx_buf).expect("failed to write to device");

        // read
        let rx_data = usb_rx.burst_read(tx_buf.len()).expect("failed to read from device");

        // verify
        if rx_data != tx_buf {
            for i in 0..rx_data.len() {
                if rx_data[i] != tx_buf[i] {
                    println!("Data mismatch at index {}: tx = {:02x}, rx = {:02x}", i, tx_buf[i], rx_data[i]);
                }
            }
            eprintln!("Data mismatch! {}", itr);
            return Err("Data mismatch".into());
        }
    }


    // Spped test
    rng.fill_bytes(&mut tx_buf);
  
    let start = Instant::now();
    for _ in 0..ITERETIONS {
        // write
        usb_tx.burst_write(&tx_buf).expect("failed to write to device");
        // read
        let _ = usb_rx.burst_read(tx_buf.len()).expect("failed to read from device");
    }

    let elapsed = start.elapsed();
    let elapsed_sec = elapsed.as_secs_f64();
    let transferred_bytes = (PACKET_SIZE * ITERETIONS * 2) as f64;
    let bytes_per_sec = transferred_bytes / elapsed_sec;
    let mbyte_per_sec = bytes_per_sec / (1024.0 * 1024.0);
    let mbit_per_sec = bytes_per_sec * 8.0 / (1024.0 * 1024.0);

    println!("Elapsed: {:.6} sec", elapsed_sec);
    println!("Throughput: {:.2} MByte/s", mbyte_per_sec);
    println!("Throughput: {:.2} Mbit/s", mbit_per_sec);

    Ok(())
}
