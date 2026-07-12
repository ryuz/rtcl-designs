use std::error::Error;
use std::time::Instant;
use rtcl_d3xx::*;

const CHHANNELS: usize = 1;

fn calc_lfsr(lfsr: u32) -> u32 {
    let bit = ((lfsr >> 0) ^ (lfsr >> 1) ^ (lfsr >> 21) ^ (lfsr >> 31)) & 1;
    (lfsr >> 1) | (bit << 31)
}


fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 read/write test");

    // Open the first device found.
    let (mut usb_txs, mut usb_rxs) = D3xxDevice::new(0, CHHANNELS)?;

    usb_rxs[0].set_stream_pipe(0x100000)?;
    
    read_lsfr_test(&mut usb_rxs[0])?; 
    write_lsfr_test(&mut usb_txs[0])?;

    burst_read_test(&mut usb_rxs[0])?;
    burst_write_test(&mut usb_txs[0])?;

    // Rewad Speed test
    Ok(())
}

fn read_lsfr_test(reader: &mut D3xxReader) -> Result<(), Box<dyn Error>> {
    // 受信テスト
    const PACKET_SIZE: usize = 4*128;
    const ITERETIONS: usize = 1000;

    println!("\n=================================");
    println!("Receiving {} packets of size {} bytes...", ITERETIONS, PACKET_SIZE);
    let mut rx_index = 0;
    let mut rx_lsfr = 0x1234_5678;
    for _ in 0..ITERETIONS {
        // 受信
        let rx_u8 = reader.read(PACKET_SIZE).expect("failed to read from device");
        // 32bit 化
        let rx_u32: Vec<u32> = rx_u8.chunks_exact(4).map(|chunk| {u32::from_le_bytes(chunk.try_into().unwrap())}).collect();

        // データチェック
        let mut err = false;
        for &data in rx_u32.iter() {
            if data != rx_lsfr {
                eprintln!("Data mismatch! 0x{:08x}: expected {:08x}, got {:08x}", rx_index, rx_lsfr, data);
                err = true;
            }
            rx_lsfr = calc_lfsr(rx_lsfr);
            rx_index += 1;
        }

        if err {
            return Err("Data mismatch".into());
        }
    }
    println!("Receiving test completed successfully!");
    println!("=================================");
    Ok(())
}

fn write_lsfr_test(writer: &mut D3xxWriter) -> Result<(), Box<dyn Error>> {
    // 送信テスト
    const PACKET_SIZE: usize = 4*128;
    const ITERETIONS: usize = 1000;
    println!("\n=================================");
    println!("Sending {} packets of size {} bytes...", ITERETIONS, PACKET_SIZE);
    let mut tx_lsfr: u32 = 0x1234_5678;
    for _ in 0..ITERETIONS {
        let mut tx_data = Vec::with_capacity(PACKET_SIZE);
        for _ in 0..(PACKET_SIZE/4) {
            tx_data.extend_from_slice(&tx_lsfr.to_le_bytes());
            tx_lsfr = calc_lfsr(tx_lsfr);
        }
        writer.write(&tx_data).expect("failed to write to device");
    }
    println!("Sending test completed successfully!");
    println!("=================================");
    Ok(())
}



// 連続読み出しテスト
fn burst_read_test(reader: &mut D3xxReader) -> Result<(), Box<dyn Error>> {

    println!("\n=================================");
    println!("Starting burst read test...");

    const ITERETIONS: usize = 1000;
    const OVERLAPS : usize = 8;
    const READ_UNIT : usize = 0x10000;
    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let mut buffer = vec![[0u8; READ_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];

    reader.set_timeout(100)?;
    reader.set_stream_pipe(0x100000)?;

    // overlappedを初期化
    for i in 0..OVERLAPS {
        reader.initialize_overlapped(&mut overlapped[i])?; 
    }

    // 時間計測開始
    let rx_start = Instant::now();

    // 読み出し要求を発行
    for i in 0..OVERLAPS {
        reader.read_async(&mut buffer[i], &mut bytes_transferred[i], &mut overlapped[i])?;
    }
    
    // 転送
    let mut index = 0;
    for _ in 0..(ITERETIONS-OVERLAPS) {
        reader.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
        reader.read_async(&mut buffer[index], &mut bytes_transferred[index], &mut overlapped[index])?;
        index = (index + 1) % OVERLAPS;
    }

    // 残りの転送を回収
    for _ in 0..OVERLAPS {
        reader.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
        index = (index + 1) % OVERLAPS;
    }

    // 経過時間計測
    let rx_elapsed = rx_start.elapsed();

    // overlappedを開放
    for i in 0..OVERLAPS {
        reader.release_overlapped(&mut overlapped[i])?; 
    }

    // 結果表示
    let rx_seconds = rx_elapsed.as_secs_f64();
    let rx_total_bytes = (ITERETIONS * READ_UNIT) as f64;
    let rx_byte_per_sec = rx_total_bytes / rx_seconds;
    let rx_bit_per_sec = rx_byte_per_sec * 8.0;
    let rx_mbyte_per_sec = rx_byte_per_sec / 1_000_000.0;
    let rx_mbit_per_sec = rx_bit_per_sec / 1_000_000.0;
    println!("Receiving {} packets of size {} bytes took {:.6} seconds", ITERETIONS, READ_UNIT, rx_elapsed.as_secs_f64());
    println!("Read throughput: {:.3} Mbyte/s, {:.3} Mbit/s", rx_mbyte_per_sec, rx_mbit_per_sec);
    println!("=================================");

    Ok(())
}



fn burst_write_test(writer: &mut D3xxWriter) -> Result<(), Box<dyn Error>> {
    println!("\n=================================");
    println!("Starting burst write test...");

    const ITERETIONS: usize = 1000;
    const OVERLAPS : usize = 8;
    const READ_UNIT : usize = 0x10000;
    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let buffer = vec![[0u8; READ_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];

    writer.set_timeout(100)?;
    writer.set_stream_pipe(0x100000)?;

    // overlappedを初期化
    for i in 0..OVERLAPS {
        writer.initialize_overlapped(&mut overlapped[i])?; 
    }

    let tx_start = Instant::now();

    // 書き込み要求を発行
    for i in 0..OVERLAPS {
        writer.write_async(&buffer[i], &mut bytes_transferred[i], &mut overlapped[i])?;
    }
    
    // 転送
    let mut index = 0;
    for _ in 0..(ITERETIONS-OVERLAPS) {
        writer.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
        writer.write_async(&buffer[index], &mut bytes_transferred[index], &mut overlapped[index])?;
        index = (index + 1) % OVERLAPS;
    }

    // 残りの転送を回収
    for _ in 0..OVERLAPS {
        writer.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
        index = (index + 1) % OVERLAPS;
    }

    let tx_elapsed = tx_start.elapsed();

    // overlappedを開放
    for i in 0..OVERLAPS {
        writer.release_overlapped(&mut overlapped[i])?; 
    }

    // 結果表示
    let tx_seconds = tx_elapsed.as_secs_f64();
    let tx_total_bytes = (ITERETIONS * READ_UNIT) as f64;
    let tx_byte_per_sec = tx_total_bytes / tx_seconds;
    let tx_bit_per_sec = tx_byte_per_sec * 8.0;
    let tx_mbyte_per_sec = tx_byte_per_sec / 1_000_000.0;
    let tx_mbit_per_sec = tx_bit_per_sec / 1_000_000.0;
    println!("Sending {} packets of size {} bytes took {:.6} seconds", ITERETIONS, READ_UNIT, tx_elapsed.as_secs_f64());
    println!("Write throughput: {:.3} Mbyte/s, {:.3} Mbit/s", tx_mbyte_per_sec, tx_mbit_per_sec);
    println!("=================================");

    Ok(())
}

