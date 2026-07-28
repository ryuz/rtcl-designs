use std::error::Error;
use std::collections::VecDeque;
use std::sync::mpsc;
use std::time::Duration;

use crate::d3xx_device::*;
#[cfg(target_os = "linux")]
use crate::ffi::{FT_PIPE_TRANSFER_CONF, FT_TRANSFER_CONF};

use super::*;


pub struct D3xxFifo32;

pub struct D3xxFifo32Axi4l {
    axi4l_writer: D3xxWriter,
    axi4l_reader: D3xxReader,
}

unsafe impl Send for D3xxFifo32Axi4l {}
unsafe impl Sync for D3xxFifo32Axi4l {}

pub struct D3xxFifo32Axi4sRx {
    thread_handle: Option<std::thread::JoinHandle<()>>,
    rx_stream: mpsc::Receiver<Axi4Stream>,
    tx_stop: mpsc::Sender<()>,
}

unsafe impl Send for D3xxFifo32Axi4sRx {}
unsafe impl Sync for D3xxFifo32Axi4sRx {}

pub struct D3xxFifo32Axi4sTx {
    thread_handle: Option<std::thread::JoinHandle<()>>,
    tx_queue: mpsc::Sender<Vec<u8>>,
    tx_stop: mpsc::Sender<()>,
}

unsafe impl Send for D3xxFifo32Axi4sTx {}
unsafe impl Sync for D3xxFifo32Axi4sTx {}

impl D3xxFifo32 {
    pub fn new(dev_index: usize) -> Result<(D3xxFifo32Axi4l, D3xxFifo32Axi4sRx, D3xxFifo32Axi4sTx), Box<dyn Error>> {
        #[cfg(target_os = "linux")]
        {
            let mut transfer_conf = FT_TRANSFER_CONF::default();
            transfer_conf.pipe[0].dwURBBufferSize = 1024;
            transfer_conf.pipe[1].dwURBBufferSize = 1024;
//          D3xxDevice::set_transfer_params_for_fifo(0, &mut transfer_conf)?;
//          D3xxDevice::set_transfer_params_for_fifo(1, &mut transfer_conf)?;
        }

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;

        let [axi4l_writer, mut axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
            Ok(readers) => readers,
            Err(_) => panic!("Expected 2 readers"),
        };

        axi4s_writer.set_timeout(10)?;
        axi4s_writer.set_stream_pipe(0x100000)?;

        let (tx_stream, rx_stream) = mpsc::channel::<Axi4Stream>();
        let (tx_stop, rx_stop) = mpsc::channel::<()>();
        let (tx_queue, rx_queue) = mpsc::channel::<Vec<u8>>();
        let (tx_stop_tx, rx_stop_tx) = mpsc::channel::<()>();
        
        let thread_handle_rx = std::thread::spawn(move || {
            if let Err(err) = recv_axi4s_thread(axi4s_reader, tx_stream, rx_stop) {
                eprintln!("recv_axi4s_thread error: {}", err);
            }
        });

        let thread_handle_tx = std::thread::spawn(move || {
            if let Err(err) = send_axi4s_thread(axi4s_writer, rx_queue, rx_stop_tx) {
                eprintln!("send_axi4s_thread error: {}", err);
            }
        });

        let axi4l = D3xxFifo32Axi4l {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
        };
        let axi4s_rx = D3xxFifo32Axi4sRx {
            thread_handle: Some(thread_handle_rx),
            rx_stream: rx_stream,
            tx_stop: tx_stop,
        };
        let axi4s_tx = D3xxFifo32Axi4sTx {
            thread_handle: Some(thread_handle_tx),
            tx_queue: tx_queue,
            tx_stop: tx_stop_tx,
        };

        Ok((axi4l, axi4s_rx, axi4s_tx))
    }
}

impl D3xxFifo32Axi4l {
    pub fn write_axi4l(&self, addr: u32, data: u32, strb: u8) -> Result<(), Box<dyn Error>> {
        // コマンド送信
        let mut command = Vec::<u8>::with_capacity(4*3);
        command.push(OPCODE_AXI4L_WRITE);
        command.push(strb << 4);
        command.extend_from_slice(&8u16.to_le_bytes());
        command.extend_from_slice(&addr.to_le_bytes());
        command.extend_from_slice(&data.to_le_bytes());
        self.axi4l_writer.write(&command)?;

        // 応答受信
        let response = self.axi4l_reader.read(4)?;
        assert!(response[0] == OPCODE_AXI4L_WRITE, "Expected AXI4L_WRITE response");
        assert!(response[1] == 0, "Expected AXI4L response");
        assert!(u16::from_le_bytes([response[2], response[3]]) == 0u16);
        Ok(())
    }

    pub fn read_axi4l(&self, addr: u32) -> Result<u32, Box<dyn Error>> {
        // コマンド送信
        let mut command = Vec::<u8>::with_capacity(4*3);
        command.push(OPCODE_AXI4L_READ);
        command.push(0u8);
        command.extend_from_slice(&4u16.to_le_bytes());
        command.extend_from_slice(&addr.to_le_bytes());
        self.axi4l_writer.write(&command)?;

        // 応答受信
        let response = self.axi4l_reader.read(4*2)?;
        assert!(response[0] == OPCODE_AXI4L_READ, "Expected OPCODE_AXI4L_READ response");
        assert!(response[1] == 0, "Expected AXI4L response");
        assert!(u16::from_le_bytes([response[2], response[3]]) == 4u16);
        Ok(u32::from_le_bytes([response[4], response[5], response[6], response[7]]))
    }
}

impl D3xxFifo32Axi4sRx {
    pub fn recv_axi4s(&self) -> Result<Axi4Stream, Box<dyn Error>> {
        self.rx_stream.recv().map_err(|e| e.into())
    }

    pub fn recv_axi4s_timeout(&self, timeout: Duration) -> Result<Axi4Stream, Box<dyn Error>> {
        self.rx_stream.recv_timeout(timeout).map_err(|e| e.into())
    }


    pub fn try_recv_axi4s(&self) -> Result<Axi4Stream, Box<dyn Error>> {
        if let Ok(packet) = self.rx_stream.try_recv() {
            return Ok(packet);
        }
        Err("No AXI4S packet available".into())
    }
    
    pub fn try_recv_axi4s_opt(&self) -> Option<Axi4Stream> {
        self.rx_stream.try_recv().ok()
    }
}

impl D3xxFifo32Axi4sTx {
    pub fn send_axi4s(&self, stream: &Axi4Stream) -> Result<(), Box<dyn Error>> {
        if stream.tdata.len() > u16::MAX as usize {
            return Err("AXI4S payload too large (must be <= 65535 bytes)".into());
        }

        if (stream.tdata.len() & 0x3) != 0 {
            return Err("AXI4S payload size must be 4-byte aligned".into());
        }

        let mut packet = Vec::<u8>::with_capacity(4 + stream.tdata.len());
        packet.push(OPCODE_AXI4S_TRANS);
        packet.push((stream.tuser & 0x7f) | 0x80);
        packet.extend_from_slice(&(stream.tdata.len() as u16).to_le_bytes());
        packet.extend_from_slice(&stream.tdata);

        self.tx_queue.send(packet)?;
        Ok(())
    }

    pub fn send_frame(&self, width: usize, height: usize, image: &[u8]) -> Result<(), Box<dyn Error>> {
        if width == 0 || height == 0 {
            return Err("frame width and height must be > 0".into());
        }
        if width > u16::MAX as usize {
            return Err("frame width must be <= 65535 bytes".into());
        }

        let image_size = width
            .checked_mul(height)
            .ok_or("frame size overflow")?;
        if image.len() != image_size {
            return Err(format!(
                "image buffer size mismatch: {} != {}",
                image.len(),
                image_size
            )
            .into());
        }

        for y in 0..height {
            let start = y * width;
            let end = start + width;
            let stream = Axi4Stream {
                tuser: if y == 0 { 0x01 } else { 0x00 },
                tdata: image[start..end].to_vec(),
            };
            self.send_axi4s(&stream)?;
        }

        Ok(())
    }
}


//#[cfg(target_os = "windows")]
fn recv_axi4s_thread(mut reader: D3xxReader, tx_stream: mpsc::Sender<Axi4Stream>, rx_stop: mpsc::Receiver<()>) -> Result<(), Box<dyn Error>> {

    const OVERLAPS : usize = 16;
//  const READ_UNIT : usize = 1024;
    const READ_UNIT : usize = 0x8000;
    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let mut buffer = vec![[0u8; READ_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];
    let mut index = 0;

    reader.set_timeout(10)?;
    reader.set_stream_pipe(READ_UNIT)?;
//  reader.set_stream_pipe(0x4)?;

    // 読み出し要求を発行
    for i in 0..OVERLAPS {
        reader.initialize_overlapped(&mut overlapped[i])?; 
        reader.read_async(&mut buffer[i], &mut bytes_transferred[i], &mut overlapped[i])?;
    }
    let mut pending = OVERLAPS;


    let mut stream = Axi4Stream {tuser: 0, tdata: Vec::<u8>::new()};

    let mut header = true;
    let mut rx_buffer = Vec::<u8>::new();
    let mut packet_size = 0;
    let mut packet_last = false;

    let mut stop = false;
    loop {
        if rx_stop.try_recv().is_ok() {
            println!("recv_thread: stop");
            stop = true;
        }

        // 受信
        reader.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
        let rx_size = bytes_transferred[index] as usize;
        rx_buffer.extend_from_slice(&buffer[index][..rx_size]);
        if rx_size > 0 {
//          println!("recv_thread: rx_size: {} bytes", rx_size);
        }

        if stop {
            reader.release_overlapped(&mut overlapped[index])?;
            pending -= 1;
            if pending == 0 {
                break;
            }
        }
        else {
            // 次の読み出し待機
            reader.read_async(&mut buffer[index], &mut bytes_transferred[index], &mut overlapped[index])?;
        }
        index = (index + 1) % OVERLAPS;

        while rx_buffer.len() > 0 {
            assert!(rx_buffer.len() % 4 == 0);  // 32bit単位でしか通信しない

            if header {
                let opcode = rx_buffer[0];
                let operand = rx_buffer[1];
                stream.tuser = operand & 0x7f;
                packet_last = (operand & 0x80) != 0;
                packet_size = u16::from_le_bytes([rx_buffer[2], rx_buffer[3]]) as usize;
                assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S opcode={:02x}, oprand={:02x}, size={:04x}", opcode, operand, packet_size);
                rx_buffer.drain(0..4);
//              println!("axi4s : tuser : {} last : {}, packet_size: {} bytes", stream.tuser, packet_last, packet_size);
                header = false;
            }
            else {
                if rx_buffer.len() >= packet_size {
                    stream.tdata.extend_from_slice(&rx_buffer[0..packet_size]);
                    rx_buffer.drain(0..packet_size);
                    header = true;

                    // 受信データを送信
                    if packet_last {
                        tx_stream.send(stream.clone())?;
                        stream.tdata.clear();
                    }
                }
                else {
                    stream.tdata.extend_from_slice(&rx_buffer);
                    packet_size -= rx_buffer.len();
                    rx_buffer.clear();
                }
            }
        }
    }
    println!("recv_thread: exit");
    Ok(())
}

/*
#[cfg(target_os = "linux")]
fn recv_axi4s_thread(mut reader: D3xxReader, tx_stream: mpsc::Sender<Axi4Stream>, rx_stop: mpsc::Receiver<()>) -> Result<(), Box<dyn Error>> {

//  const READ_UNIT : usize = 1024;
    const READ_UNIT : usize = 0x10000;

    reader.set_timeout(10)?;
    reader.set_stream_pipe(0x100000)?;
//  reader.set_stream_pipe(0x4)?;

  
    let mut stream = Axi4Stream {tuser: 0, tdata: Vec::<u8>::new()};

    let mut header = true;
    let mut rx_buffer = Vec::<u8>::new();
    let mut packet_size = 0;
    let mut packet_last = false;

    loop {
        if rx_stop.try_recv().is_ok() {
            println!("recv_thread: stop");
            break;
        }

        // 受信
        let rx_data = reader.read(READ_UNIT)?;
        rx_buffer.extend_from_slice(&rx_data);
        if rx_data.len() > 0 {
//          println!("recv_thread: rx_size: {} bytes", rx_data.len());
        }

        while rx_buffer.len() > 0 {
            assert!(rx_buffer.len() % 4 == 0);  // 32bit単位でしか通信しない

            if header {
                let opcode = rx_buffer[0];
                let operand = rx_buffer[1];
                stream.tuser = operand & 0x7f;
                packet_last = (operand & 0x80) != 0;
                packet_size = u16::from_le_bytes([rx_buffer[2], rx_buffer[3]]) as usize;
                assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S opcode={:02x}, oprand={:02x}, size={:04x}", opcode, operand, packet_size);
                rx_buffer.drain(0..4);
//              println!("axi4s : tuser : {} last : {}, packet_size: {} bytes", stream.tuser, packet_last, packet_size);
                header = false;
            }
            else {
                if rx_buffer.len() >= packet_size {
                    stream.tdata.extend_from_slice(&rx_buffer[0..packet_size]);
                    rx_buffer.drain(0..packet_size);
                    header = true;

                    // 受信データを送信
                    if packet_last {
                        tx_stream.send(stream.clone())?;
                        stream.tdata.clear();
                    }
                }
                else {
                    stream.tdata.extend_from_slice(&rx_buffer);
                    packet_size -= rx_buffer.len();
                    rx_buffer.clear();
                }
            }
        }
    }
    println!("recv_thread: exit");
    Ok(())
}
*/

fn send_axi4s_thread(
    writer: D3xxWriter,
    rx_queue: mpsc::Receiver<Vec<u8>>,
    rx_stop: mpsc::Receiver<()>,
) -> Result<(), Box<dyn Error>> {
    const OVERLAPS: usize = 16;
    const WRITE_UNIT: usize = 0x10000;

    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let mut buffers = vec![vec![0u8; WRITE_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];
    let mut pending = vec![false; OVERLAPS];
    let mut pending_count = 0usize;
    let mut issue_index = 0usize;
    let mut wait_index = 0usize;
    let mut fifo = VecDeque::<u8>::new();
    let mut stop = false;

    for i in 0..OVERLAPS {
        writer.initialize_overlapped(&mut overlapped[i])?;
    }

    loop {
        while !stop {
            match rx_queue.try_recv() {
                Ok(packet) => fifo.extend(packet),
                Err(mpsc::TryRecvError::Empty) => break,
                Err(mpsc::TryRecvError::Disconnected) => {
                    stop = true;
                    break;
                }
            }
        }

        if !stop && rx_stop.try_recv().is_ok() {
            stop = true;
        }

        while pending_count < OVERLAPS && !fifo.is_empty() {
            while pending[issue_index] {
                issue_index = (issue_index + 1) % OVERLAPS;
            }

            let slot = issue_index;
            let tx_size = fifo.len().min(WRITE_UNIT);
            let tx_buf = &mut buffers[slot];
            for i in 0..tx_size {
                tx_buf[i] = fifo.pop_front().expect("fifo should have enough bytes");
            }

            bytes_transferred[slot] = tx_size as u32;
            writer.write_async(&tx_buf[..tx_size], &mut bytes_transferred[slot], &mut overlapped[slot])?;
            pending[slot] = true;
            pending_count += 1;
            issue_index = (issue_index + 1) % OVERLAPS;
        }

        if stop && fifo.is_empty() && pending_count == 0 {
            break;
        }

        if pending_count == 0 {
            match rx_queue.recv_timeout(Duration::from_millis(1)) {
                Ok(packet) => fifo.extend(packet),
                Err(mpsc::RecvTimeoutError::Timeout) => {}
                Err(mpsc::RecvTimeoutError::Disconnected) => stop = true,
            }
            continue;
        }

        while !pending[wait_index] {
            wait_index = (wait_index + 1) % OVERLAPS;
        }

        let slot = wait_index;
        writer.get_async_result(&mut overlapped[slot], &mut bytes_transferred[slot], true)?;
        let tx_size = bytes_transferred[slot] as usize;
        if tx_size > WRITE_UNIT {
            return Err(format!("invalid async tx size: {}", tx_size).into());
        }

        pending[slot] = false;
        pending_count -= 1;
        wait_index = (wait_index + 1) % OVERLAPS;
    }

    for i in 0..OVERLAPS {
        let _ = writer.release_overlapped(&mut overlapped[i]);
    }

    Ok(())
}


impl Drop for D3xxFifo32Axi4sRx {
    fn drop(&mut self) {
        let _ = self.tx_stop.send(());  // 受信スレッドに停止を通知
        if let Some(handle) = self.thread_handle.take() {
            let _ = handle.join();
        }
    }
}

impl Drop for D3xxFifo32Axi4sTx {
    fn drop(&mut self) {
        let _ = self.tx_stop.send(());  // 送信スレッドに停止を通知
        if let Some(handle) = self.thread_handle.take() {
            let _ = handle.join();
        }
    }
}

