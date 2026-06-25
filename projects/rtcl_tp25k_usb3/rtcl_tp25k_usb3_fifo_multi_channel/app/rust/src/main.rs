use std::error::Error;
use std::time::Instant;
use rtcl_d3xx::*;

const CHHANNELS: usize = 2;

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

    
    for ch in 0..CHHANNELS {
//      usb_txs[ch].set_stream_pipe(0x10000)?;
        usb_rxs[ch].set_stream_pipe(0x10000)?;
    }
    

    let mut tx_data: Vec<Vec<u8>> = (0..CHHANNELS)
        .map(|_| vec![0; PACKET_SIZE])
        .collect();

    // データチェック
    for itr in 0..ITERETIONS {
        // 乱数で初期化
        for ch in 0..CHHANNELS {
            for i in 0..tx_data[ch].len() {
                tx_data[ch][i] = rand::random::<u8>();
            }
        }

        // write
        for ch in (0..CHHANNELS).rev() {
            usb_txs[ch].write(&tx_data[ch]).expect("failed to write to device");
        }

        // read
        let mut rx_data: Vec<Vec<u8>> = (0..CHHANNELS)
            .map(|_| Vec::new())
            .collect();
        for ch in 0..CHHANNELS {
//          rx_data[ch] = usb_rxs[ch].read(tx_data[ch].len()).expect("failed to read from device");
            let mut rx_buf = Vec::with_capacity(tx_data[ch].len());
            while rx_buf.len() < tx_data[ch].len() {
                let mut temp_buf = usb_rxs[ch].read(tx_data[ch].len() - rx_buf.len()).expect("failed to read from device");
                rx_buf.extend_from_slice(&temp_buf);
            }
            rx_data[ch] = rx_buf;
        }

        // verify
        for ch in 0..CHHANNELS {
            // 32bit配列に変換
            let tx_data_32bit: Vec<i32> = tx_data[ch].chunks_exact(4).map(|chunk| {i32::from_le_bytes(chunk.try_into().unwrap())}).collect();
            let rx_data_32bit: Vec<i32> = rx_data[ch].chunks_exact(4).map(|chunk| {i32::from_le_bytes(chunk.try_into().unwrap())}).collect();
            if tx_data_32bit != rx_data_32bit {
                for i in 0..rx_data_32bit.len() {
                    if rx_data_32bit[i] != tx_data_32bit[i] {
                        println!("Data mismatch at ch {} index {:08x}: tx = {:08x}, rx = {:08x} diff = {:08x}", ch, i, tx_data_32bit[i], rx_data_32bit[i], tx_data_32bit[i] ^ rx_data_32bit[i]);
                    }
                }
                eprintln!("Data mismatch! {}", itr);
                return Err("Data mismatch".into());
            }
        }
    }

    // Speed test
    println!("\nSpeed test starting...");
    
    // Initialize test data for all channels
    for ch in 0..CHHANNELS {
        for i in 0..tx_data[ch].len() {
            tx_data[ch][i] = rand::random::<u8>();
        }
    }

    let start = Instant::now();
    for _ in 0..ITERETIONS {
        // write to all channels
        for ch in (0..CHHANNELS).rev() {
            usb_txs[ch].write(&tx_data[ch]).expect("failed to write to device");
        }
        // read from all channels
        for ch in 0..CHHANNELS {
            let _ = usb_rxs[ch].read(tx_data[ch].len()).expect("failed to read from device");
        }
    }
    let elapsed = start.elapsed();

    let elapsed_sec = elapsed.as_secs_f64();
    let transferred_bytes = (PACKET_SIZE * ITERETIONS * 2 * CHHANNELS) as f64;
    let bytes_per_sec = transferred_bytes / elapsed_sec;
    let mbyte_per_sec = bytes_per_sec / (1024.0 * 1024.0);
    let mbit_per_sec = bytes_per_sec * 8.0 / (1024.0 * 1024.0);

    println!("Elapsed: {:.6} sec", elapsed_sec);
    println!("Throughput: {:.2} MByte/s", mbyte_per_sec);
    println!("Throughput: {:.2} Mbit/s", mbit_per_sec);

    Ok(())
}
