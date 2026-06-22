use std::io::{Read, Write};
use std::time::Instant;
use d3xx::{list_devices, Pipe};

fn main() {
    println!("FT601 loopback test");

    // Scan for connected devices.
    let all_devices = list_devices().expect("failed to list devices");
    println!("Found {} devices", all_devices.len());

    // Open the first device found.
    let device = all_devices[0].open().expect("failed to open device");

    const PACKET_SIZE: usize = 1024*64;
    const ITERETIONS: usize = 10000;

    // Read 1024 bytes from input pipe 1
    let mut buf = vec![0; PACKET_SIZE];
    for i in 0..buf.len() {
        buf[i] = i as u8;
    }
  
    let start = Instant::now();
    for _ in 0..ITERETIONS {
        // write
        device
            .pipe(Pipe::Out0)
            .write(&buf)
            .expect("failed to write to pipe");

        // read
        device
            .pipe(Pipe::In0)
            .read(&mut buf)
            .expect("failed to read from pipe");
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
}
