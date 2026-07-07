use std::error::Error;
use std::sync::mpsc;
use std::time::Duration;

use crate::d3xx_device::*;


const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
const OPCODE_AXI4S_TRANS: u8 = 0x10;


pub struct RtclFifo32CtlD3xx {
    axi4l_writer: D3xxWriter,
    axi4l_reader: D3xxReader,
    thread_handle: Option<std::thread::JoinHandle<()>>,
    rx_stream: mpsc::Receiver<Axi4Stream>,
    tx_stop: mpsc::Sender<()>,
}

impl RtclFifo32CtlD3xx {
    pub fn new(dev_index: usize) -> Result<Self, Box<dyn Error>> {

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;

        let [axi4l_writer, _axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
            Ok(readers) => readers,
            Err(_) => panic!("Expected 2 readers"),
        };

        let (tx_stream, rx_stream) = mpsc::channel::<Axi4Stream>();
        let (tx_stop, rx_stop) = mpsc::channel::<()>();
        
        let thread_handle = std::thread::spawn(move || {
            if let Err(err) = recv_axi4s_thread(axi4s_reader, tx_stream, rx_stop) {
                eprintln!("recv_axi4s_thread error: {}", err);
            }
        });
        
        Ok(Self {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
            thread_handle: Some(thread_handle),
            rx_stream: rx_stream,
            tx_stop: tx_stop,
        })
    }

    pub fn write_axi4l(&mut self, addr: u32, data: u32, strb: u8) -> Result<(), Box<dyn Error>> {
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

    pub fn read_axi4l(&mut self, addr: u32) -> Result<u32, Box<dyn Error>> {
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

    pub fn recv_axi4s(&mut self) -> Result<Axi4Stream, Box<dyn Error>> {
        self.rx_stream.recv().map_err(|e| e.into())
    }

    pub fn recv_axi4s_timeout(&mut self, timeout: Duration) -> Result<Axi4Stream, Box<dyn Error>> {
        self.rx_stream.recv_timeout(timeout).map_err(|e| e.into())
    }


    pub fn try_recv_axi4s(&mut self) -> Result<Axi4Stream, Box<dyn Error>> {
        if let Ok(packet) = self.rx_stream.try_recv() {
            return Ok(packet);
        }
        Err("No AXI4S packet available".into())
    }
}


#[derive(Debug, Clone)]
pub struct Axi4Stream {
    pub tuser: u8,
    pub tdata: Vec<u8>,
}

fn recv_axi4s_thread(mut reader: D3xxReader, tx_stream: mpsc::Sender<Axi4Stream>, rx_stop: mpsc::Receiver<()>) -> Result<(), Box<dyn Error>> {

    const OVERLAPS : usize = 16;
    const READ_UNIT : usize = 0x10000;
//  const READ_UNIT : usize = 256*10/8 + 4;
    let mut overlapped = vec![Overlapped::new(); OVERLAPS];
    let mut buffer = vec![[0u8; READ_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];
    let mut index = 0;

    reader.set_timeout(100)?;
    reader.set_stream_pipe(0x100000)?;

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
        println!("recv_thread: rx_size: {} bytes", rx_size);

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
//              println!("axi4s : tuser : {} packet_size: {} bytes", stream.tuser, packet_size);
                header = false;
            }
            else {
                if rx_buffer.len() >= packet_size {
                    stream.tdata.extend_from_slice(&rx_buffer[0..packet_size]);
                    rx_buffer.drain(0..packet_size);
                    header = true;

                    // 受信データを送信
                    if packet_last {
                        tx_stream.send(stream.clone()).unwrap();
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


impl Drop for RtclFifo32CtlD3xx {
    fn drop(&mut self) {
        println!("RtclFifo32D3xx: drop");
        let _ = self.tx_stop.send(());  // 受信スレッドに停止を通知
        if let Some(handle) = self.thread_handle.take() {
            let _ = handle.join();
        }
    }
}

