use std::error::Error;
use std::time::Instant;
use rtcl_d3xx::*;

fn main() -> Result<(), Box<dyn Error>> {
    println!("FT601 loopback test");

    // Open the first device found.
    let (mut usb_tx, mut usb_rx) = D3xxDevice::new(0)?;

    usb_tx.set_timeout(1000)?;
    usb_rx.set_timeout(1000)?;

    const PACKET_SIZE: usize = 1024*4*16;
    const ITERETIONS: usize = 1000;

//  usb_tx.set_stream_pipe(0x10000)?;
//  usb_rx.set_stream_pipe(0x10000)?;

    let mut tx_buf = vec![0; PACKET_SIZE];

    // データチェック
    for _ in 0..ITERETIONS {
        // 乱数で初期化
        for i in 0..tx_buf.len() {
            tx_buf[i] = rand::random::<u8>();
        }

        // write
        usb_tx.write(&tx_buf).expect("failed to write to device");

        // read
        let rx_data = usb_rx.read(tx_buf.len()).expect("failed to read from device");

        // verify
        if rx_data != tx_buf {
            eprintln!("Data mismatch!");
            return Err("Data mismatch".into());
        }
    }


    // Spped test
    for i in 0..tx_buf.len() {
        tx_buf[i] = rand::random::<u8>();
    }
  
    let start = Instant::now();
    for _ in 0..ITERETIONS {
        // write
        usb_tx.write(&tx_buf).expect("failed to write to device");
        // read
        let _ = usb_rx.read(tx_buf.len()).expect("failed to read from device");
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
