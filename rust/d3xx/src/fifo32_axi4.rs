use std::error::Error;
use std::collections::VecDeque;
use std::sync::mpsc;
use std::time::Duration;
use std::io::Write;

const OPCODE_THREAD_STOP: u8 = 0xff;


use crate::d3xx_device::*;
#[cfg(target_os = "linux")]
use crate::ffi::FT_TRANSFER_CONF;

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
    rd_axi4s_rx: mpsc::Receiver<Axi4Stream>,
    wr_stop_rx: mpsc::Sender<()>,
}

//unsafe impl Send for D3xxFifo32Axi4sRx {}
//unsafe impl Sync for D3xxFifo32Axi4sRx {}

pub struct D3xxFifo32Axi4sTx {
    thread_handle: Option<std::thread::JoinHandle<()>>,
    wr_packet_tx: mpsc::Sender<Vec<u8>>,
}

unsafe impl Send for D3xxFifo32Axi4sTx {}
unsafe impl Sync for D3xxFifo32Axi4sTx {}

impl D3xxFifo32 {
    pub fn new(dev_index: usize) -> Result<(D3xxFifo32Axi4l, D3xxFifo32Axi4sRx, D3xxFifo32Axi4sTx), Box<dyn Error>> {
        #[cfg(target_os = "linux")]
        {
            // FT_Create 前に設定必須。スレッドセーフ転送のままだと非同期書き込みが直列化される
            let mut transfer_conf = FT_TRANSFER_CONF::default();
            transfer_conf.pipe[0].fNonThreadSafeTransfer = 1;
            transfer_conf.pipe[1].fNonThreadSafeTransfer = 1;
            D3xxDevice::set_transfer_params_for_fifo(0, &mut transfer_conf)?;
            D3xxDevice::set_transfer_params_for_fifo(1, &mut transfer_conf)?;
        }

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;

        let [axi4l_writer, axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
            Ok(readers) => readers,
            Err(_) => panic!("Expected 2 readers"),
        };

        let (wr_axi4s_rx, rd_axi4s_rx) = mpsc::channel::<Axi4Stream>();
        let (wr_stop_rx, rd_stop_rx) = mpsc::channel::<()>();
        let (wr_packet_tx, rd_packet_tx) = mpsc::channel::<Vec<u8>>();
        
        let thread_handle_rx = std::thread::spawn(move || {
            if let Err(err) = recv_axi4s_thread(axi4s_reader, wr_axi4s_rx, rd_stop_rx) {
                eprintln!("recv_axi4s_thread error: {}", err);
            }
        });

        let thread_handle_tx = std::thread::spawn(move || {
            if let Err(err) = send_axi4s_thread(axi4s_writer, rd_packet_tx) {
                eprintln!("send_axi4s_thread error: {}", err);
            }
        });

        let axi4l = D3xxFifo32Axi4l {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
        };
        let axi4s_rx = D3xxFifo32Axi4sRx {
            thread_handle: Some(thread_handle_rx),
            rd_axi4s_rx: rd_axi4s_rx,
            wr_stop_rx: wr_stop_rx,
        };
        let axi4s_tx = D3xxFifo32Axi4sTx {
            thread_handle: Some(thread_handle_tx),
            wr_packet_tx: wr_packet_tx,
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
        self.rd_axi4s_rx.recv().map_err(|e| e.into())
    }

    pub fn recv_axi4s_timeout(&self, timeout: Duration) -> Result<Axi4Stream, Box<dyn Error>> {
        self.rd_axi4s_rx.recv_timeout(timeout).map_err(|e| e.into())
    }


    pub fn try_recv_axi4s(&self) -> Result<Axi4Stream, Box<dyn Error>> {
        if let Ok(packet) = self.rd_axi4s_rx.try_recv() {
            return Ok(packet);
        }
        Err("No AXI4S packet available".into())
    }
    
    pub fn try_recv_axi4s_opt(&self) -> Option<Axi4Stream> {
        self.rd_axi4s_rx.try_recv().ok()
    }
}

impl D3xxFifo32Axi4sTx {
    pub fn send_axi4s(&self, stream: &Axi4Stream) -> Result<(), Box<dyn Error>> {
        if (stream.tdata.len() & 0x3) != 0 {
            return Err("AXI4S payload size must be 4-byte aligned".into());
        }

        const MAX_CHUNK_SIZE: usize = (u16::MAX as usize) & !0x3; // keep each packet 4-byte aligned

        // Preserve zero-length transfer behavior with a single TLAST packet.
        if stream.tdata.is_empty() {
            let mut packet = Vec::<u8>::with_capacity(4);
            packet.push(OPCODE_AXI4S_TRANS);
            packet.push((stream.tuser & 0x7f) | 0x80);
            packet.extend_from_slice(&0u16.to_le_bytes());
            self.wr_packet_tx.send(packet)?;
            return Ok(());
        }

        let mut offset = 0usize;
        while offset < stream.tdata.len() {
            let remain = stream.tdata.len() - offset;
            let chunk_size = remain.min(MAX_CHUNK_SIZE);
            let is_last = offset + chunk_size >= stream.tdata.len();

            let mut packet = Vec::<u8>::with_capacity(4 + chunk_size);
            packet.push(OPCODE_AXI4S_TRANS);
            packet.push((stream.tuser & 0x7f) | if is_last { 0x80 } else { 0x00 });
            packet.extend_from_slice(&(chunk_size as u16).to_le_bytes());
            packet.extend_from_slice(&stream.tdata[offset..offset + chunk_size]);

            self.wr_packet_tx.send(packet)?;
            offset += chunk_size;
        }

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


fn recv_axi4s_thread(mut reader: D3xxReader, wr_axi4s_rx: mpsc::Sender<Axi4Stream>, rd_stop_rx: mpsc::Receiver<()>) -> Result<(), Box<dyn Error>> {

    const OVERLAPS : usize = 8;     // 8以上に増やすとLinuxで発行待ちが起こる？
//  const READ_UNIT : usize = 2048;
//  const READ_UNIT : usize = 0x8000;
    const READ_UNIT : usize = 0x8000;
    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let mut buffer = vec![[0u8; READ_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];
    let mut index = 0;

    std::io::stdout().flush().ok();


    reader.set_timeout(10)?;
    reader.set_stream_pipe(READ_UNIT)?;
    
    // 読み出し要求を発行
    for i in 0..OVERLAPS {
        reader.initialize_overlapped(&mut overlapped[i])?; 
        reader.read_async(&mut buffer[i], &mut bytes_transferred[i], &mut overlapped[i])?;
    }
    let mut pending = OVERLAPS;

    std::io::stdout().flush().ok();

    let mut stream = Axi4Stream {tuser: 0, tdata: Vec::<u8>::new()};

    let mut header = true;
    let mut rx_buffer = Vec::<u8>::new();
    let mut packet_size = 0;
    let mut packet_last = false;

    let mut stop = false;
    loop {
        if rd_stop_rx.try_recv().is_ok() {
            stop = true;
        }

        // 受信
        std::io::stdout().flush().ok();
        reader.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
        let rx_size = bytes_transferred[index] as usize;
        rx_buffer.extend_from_slice(&buffer[index][..rx_size]);
        // if rx_size > 0 {
        //     println!("recv_thread: rx_size: {} bytes", rx_size);
        // }

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
                assert!(opcode == OPCODE_NOP || opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S opcode={:02x}, oprand={:02x}, size={:04x}", opcode, operand, packet_size);
                // if opcode == OPCODE_NOP {
                //     println!("recv_thread: NOP packet received, size={}", packet_size);
                // }
                // else {
                //     println!("recv_thread: AXI4S packet received, size={}, last={}", packet_size, packet_last);
                // }
                rx_buffer.drain(0..4);
                header = packet_size == 0;
            }
            else {
                if rx_buffer.len() >= packet_size {
                    stream.tdata.extend_from_slice(&rx_buffer[0..packet_size]);
                    rx_buffer.drain(0..packet_size);
                    header = true;

                    // 受信データを送信
                    if packet_last {
                        wr_axi4s_rx.send(stream.clone())?;
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

    Ok(())
}


fn send_axi4s_thread(
    mut writer: D3xxWriter,
    rd_packet_tx: mpsc::Receiver<Vec<u8>>,
) -> Result<(), Box<dyn Error>> {
    const OVERLAPS: usize = 8;
    const WRITE_UNIT: usize = 0x8000;

    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let mut buffers = vec![vec![0u8; WRITE_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];
    let mut pending_count = 0usize;     // オーバーラップ発行中の個数
    let mut issue_index = 0usize;       // 次に発行するスロット
    let mut wait_index = 0usize;        // 次に完了を待つスロット
    let mut fifo = VecDeque::<u8>::new();
    let mut stop = false;
   
//  writer.set_timeout(10)?;
    writer.set_stream_pipe(WRITE_UNIT)?;    // stream size は毎回の転送サイズと一致させる

    for i in 0..OVERLAPS {
        writer.initialize_overlapped(&mut overlapped[i])?;
    }

    loop {
        // 送信データ受信 (fifo が空で継続中のときのみブロックして待つ)
        if !stop && fifo.is_empty() {
            match rd_packet_tx.recv() {
                Ok(packet) if packet.first() == Some(&OPCODE_THREAD_STOP) => stop = true,
                Ok(packet) => fifo.extend(packet),
                Err(_) => stop = true,
            }
        }

        // 後続が溜まっていれば纏めて取り込む
        while !stop {
            match rd_packet_tx.try_recv() {
                Ok(packet) if packet.first() == Some(&OPCODE_THREAD_STOP) => stop = true,
                Ok(packet) => fifo.extend(packet),
                Err(mpsc::TryRecvError::Empty) => break,
                Err(mpsc::TryRecvError::Disconnected) => stop = true,
            }
        }

        // 発行順に完了チェック (待たない)
        while pending_count > 0 {
            if writer.get_async_result(&mut overlapped[wait_index], &mut bytes_transferred[wait_index], false).is_err() {
                break;
            }
            wait_index = (wait_index + 1) % OVERLAPS;
            pending_count -= 1;
        }

        // 空きがある分だけオーバーラップ転送を発行
        while pending_count < OVERLAPS && !fifo.is_empty() {
            let slot = issue_index;
            let tx_size = fifo.len().min(WRITE_UNIT);
            let (front, back) = fifo.as_slices();
            let front_len = front.len().min(tx_size);
            buffers[slot][..front_len].copy_from_slice(&front[..front_len]);
            if front_len < tx_size {
                buffers[slot][front_len..tx_size].copy_from_slice(&back[..tx_size - front_len]);
            }
            fifo.drain(..tx_size);
            writer.write_async(&buffers[slot][..tx_size], &mut bytes_transferred[slot], &mut overlapped[slot])?;
            issue_index = (issue_index + 1) % OVERLAPS;
            pending_count += 1;
        }

        if stop && fifo.is_empty() && pending_count == 0 {
            break;
        }

        // これ以上発行できない場合のみ、1つだけ完了を待つ
        if pending_count > 0 && (pending_count == OVERLAPS || (stop && fifo.is_empty())) {
            writer.get_async_result(&mut overlapped[wait_index], &mut bytes_transferred[wait_index], true)?;
            wait_index = (wait_index + 1) % OVERLAPS;
            pending_count -= 1;
        }
    }

    for i in 0..OVERLAPS {
        let _ = writer.release_overlapped(&mut overlapped[i]);
    }

    Ok(())
}


impl Drop for D3xxFifo32Axi4sRx {
    fn drop(&mut self) {
        let _ = self.wr_stop_rx.send(());  // 受信スレッドに停止を通知
        if let Some(handle) = self.thread_handle.take() {
            let _ = handle.join();
        }
    }
}

impl Drop for D3xxFifo32Axi4sTx {
    fn drop(&mut self) {
        let _ = self.wr_packet_tx.send(vec![OPCODE_THREAD_STOP]);
        if let Some(handle) = self.thread_handle.take() {
            let _ = handle.join();
        }
    }
}

