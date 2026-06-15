use std::io::{Read, Write};
use d3xx::{list_devices, Pipe};

fn main() {
    println!("Hello, world!");

    // Scan for connected devices.
    let all_devices = list_devices().expect("failed to list devices");
    println!("Found {} devices", all_devices.len());

    // Open the first device found.
    let device = all_devices[0].open().expect("failed to open device");

    // Read 1024 bytes from input pipe 1
    let mut buf = vec![0; 1024];
    for i in 0..1024 {
        buf[i] = i as u8;
    }

    // Write 1024 bytes to output pipe 2
    device
        .pipe(Pipe::Out0)
        .write(&buf)
        .expect("failed to write to pipe");

    device
        .pipe(Pipe::In0)
        .read(&mut buf)
        .expect("failed to read from pipe");

    println!("Read back {:?} bytes", buf);
    println!("Read back {} bytes", buf.len());
}
