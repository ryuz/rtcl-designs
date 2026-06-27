use std::error::Error;
use std::time::Instant;
use rtcl_d3xx::*;

const CHHANNELS: usize = 1;

fn calc_lfsr(lfsr: u32) -> u32 {
    let bit = ((lfsr >> 0) ^ (lfsr >> 1) ^ (lfsr >> 21) ^ (lfsr >> 31)) & 1;
    (lfsr >> 1) | (bit << 31)
}


fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 loopback test");

    // Open the first device found.
    let (mut usb_txs, mut usb_rxs) = D3xxDevice::new(0, CHHANNELS)?;

    for i in 0..CHHANNELS {
        usb_txs[i].set_timeout(1000)?;
        usb_rxs[i].set_timeout(1000)?;
    }

    const PACKET_SIZE: usize = 4*128;
    const ITERETIONS: usize = 1000;
    
//   for ch in 0..CHHANNELS {
//      usb_txs[ch].set_stream_pipe(0x10000)?;
//      usb_rxs[ch].set_stream_pipe(0x10000)?;
//  }

    
    let mut rx_index = 0;
    let mut rx_lsfr = 0x1234_5678;

    // 受信テスト
    println!("Receiving {} packets of size {} bytes...", ITERETIONS, PACKET_SIZE);
    for _ in 0..ITERETIONS {
        // 受信
        let rx_u8 = usb_rxs[0].read(PACKET_SIZE).expect("failed to read from device");
        // 32bit 化
        let rx_u32: Vec<u32> = rx_u8.chunks_exact(4).map(|chunk| {u32::from_le_bytes(chunk.try_into().unwrap())}).collect();

        // データチェック
        let mut err = false;
        for &data in rx_u32.iter() {
            if data != rx_lsfr {
                eprintln!("Data mismatch! {}: expected {:08x}, got {:08x}", rx_index, rx_lsfr, data);
                err = true;
//              return Err("Data mismatch".into());
            }
            else {
//              println!("Data match! {}: {:08x}", rx_index, data);
            }
            rx_lsfr = calc_lfsr(rx_lsfr);
            rx_index += 1;
        }

        if err {
            return Err("Data mismatch".into());
        }
    }
    println!("Receiving test completed successfully!");


    // 送信テスト
    println!("Sending {} packets of size {} bytes...", ITERETIONS, PACKET_SIZE);
    let mut tx_lsfr: u32 = 0x1234_5678;
    let mut tx_data = Vec::with_capacity(PACKET_SIZE);
    for _ in 0..ITERETIONS {
        for _ in 0..(PACKET_SIZE/4) {
            tx_data.extend_from_slice(&tx_lsfr.to_le_bytes());
            tx_lsfr = calc_lfsr(tx_lsfr);
        }
        usb_txs[0].write(&tx_data).expect("failed to write to device");
    }
    println!("Sending test completed successfully!");


    // Rewad Speed test
    println!("Read speed test starting...");
    let rx_start = Instant::now();
    for _ in 0..ITERETIONS {
        let _ = usb_rxs[0].read(PACKET_SIZE).expect("failed to read to device");
    }
    let rx_elapsed = rx_start.elapsed();
    println!("Receiving {} packets of size {} bytes took {:.6} seconds", ITERETIONS, PACKET_SIZE, rx_elapsed.as_secs_f64());


    // Write Speed test
    println!("\nWrite speed test starting...");
    let tx_start = Instant::now();
    let tx_data = vec![0u8; PACKET_SIZE];
    for _ in 0..ITERETIONS {
        usb_txs[0].write(&tx_data).expect("failed to write to device");
    }
    let tx_elapsed = tx_start.elapsed();
    println!("Sending {} packets of size {} bytes took {:.6} seconds", ITERETIONS, PACKET_SIZE, tx_elapsed.as_secs_f64());


    Ok(())
}
