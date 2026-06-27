use std::error::Error;
use std::collections::VecDeque;
use std::sync::{Arc, Condvar, Mutex};
use std::sync::mpsc;

use crate::d3xx_device::*;


const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
const OPCODE_AXI4S_TRANS: u8 = 0x10;

//const CH_AXI4L: usize = 0;
//const CH_AXI4S: usize = 1;


pub struct RtclFifo32CtlD3xx {
    axi4l_writer: D3xxWriter,
    axi4l_reader: D3xxReader,
//  axi4s_fifo: Arc<(Mutex<VecDeque<u8>>, Condvar)>,

    thread_handle: Option<std::thread::JoinHandle<()>>,
    rx_stream: mpsc::Receiver<Axi4Stream>,
    tx_stop: mpsc::Sender<()>,
}

impl RtclFifo32CtlD3xx {
    pub fn new(dev_index: usize) -> Result<Self, Box<dyn Error>> {

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;
//      let axi4s_fifo = Arc::new((Mutex::new(VecDeque::new()), Condvar::new()));

        let [axi4l_writer, _axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
            Ok(readers) => readers,
            Err(_) => panic!("Expected 2 readers"),
        };

        /*
        // axi4s_reader を move して AXI4Sをリードするスレッドを作る 
        let axi4s_fifo_thread = Arc::clone(&axi4s_fifo);
        std::thread::spawn(move || {
            let mut total_size = 0;
            loop {
                let response = axi4s_reader.read(1024*1024).unwrap();
                if response.is_empty() {
                    continue;
                }

                let (fifo, ready) = &*axi4s_fifo_thread;
                let mut fifo = fifo.lock().unwrap();
                fifo.extend(response.iter().copied());
                ready.notify_all();

                total_size += response.len();
                println!("recv_thread: axi4s_reader read {} bytes, total_size = {}", response.len(), total_size);
            }
        });
        */

        let (tx_stream, rx_stream) = mpsc::channel::<Axi4Stream>();
        let (tx_stop, rx_stop) = mpsc::channel::<()>();
        let thread_handle = std::thread::spawn(move || {
            let _ = recv_axi4s_thread(axi4s_reader, tx_stream, rx_stop);
        });


//      dev_readers[CH_AXI4S].set_timeout(100)?;
//      dev_readers[CH_AXI4S].set_stream_pipe(0x100000)?;

        Ok(Self {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
//          axi4s_fifo: axi4s_fifo,
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

    pub fn try_recv_axi4s(&mut self) -> Result<Axi4Stream, Box<dyn Error>> {
        if let Ok(packet) = self.rx_stream.try_recv() {
            return Ok(packet);
        }
        Err("No AXI4S packet available".into())
    }

    /*
    pub fn recv_axi4s(&mut self, mut len: usize) -> Result<Vec<u8>, Box<dyn Error>> {
        let (fifo, ready) = &*self.axi4s_fifo;
        let mut fifo = fifo.lock().unwrap();
        while fifo.len() < len {
            fifo = ready.wait(fifo).unwrap();
        }

        let mut buf = Vec::<u8>::with_capacity(len);
        while len > 0 {
            if let Some(byte) = fifo.pop_front() {
                buf.push(byte);
                len -= 1;
            }
        }
        Ok(buf)
    }
    */

    /*
    pub fn recv_axi4s(&mut self, mut len: usize) -> Result<Vec<u8>, Box<dyn Error>> {
        let mut i = 0;
        let mut buf = Vec::<u8>::new();
        while len > 0 {
            let response = self.readers[CH_AXI4S].read(len)?;
            buf.extend_from_slice(&response);
            len -= response.len();

            i += 1;
            if i > 100 { break; }
        }
        Ok(buf)
    }
    */
}


#[derive(Debug, Clone)]
pub struct Axi4Stream {
    pub tuser: u8,
    pub tdata: Vec<u8>,
}

fn recv_axi4s_thread(mut reader: D3xxReader, tx_stream: mpsc::Sender<Axi4Stream>, rx_stop: mpsc::Receiver<()>) -> Result<(), Box<dyn Error>> {
    const OVERLAPS : usize = 3;
    const READ_UNIT : usize = 0x10000;
    let mut overlappeds = vec![Overlapped::new(); OVERLAPS];
    let mut buffers = vec![[0u8; READ_UNIT]; OVERLAPS];
    let mut bytes_transferred = vec![0u32; OVERLAPS];
    let mut pending = 0;
    let mut index = 0;

    reader.set_timeout(10)?;

    // 読み出し要求を発行
    for i in 0..OVERLAPS {
        reader.read_async(&mut buffers[i], &mut bytes_transferred[i], &mut overlappeds[i])?;
    }

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
        reader.get_async_result(&mut overlappeds[index], &mut bytes_transferred[index], true)?;
        let rx_size = bytes_transferred[index] as usize;
        rx_buffer.extend_from_slice(&buffers[index][..rx_size]);
        if stop {
            pending -= 1;
            if pending == 0 {
                break;
            }
        }
        else {
            reader.read_async(&mut buffers[index], &mut bytes_transferred[index], &mut overlappeds[index])?;
        }
        index = (index + 1) % OVERLAPS;

        while rx_buffer.len() > 0 {
            assert!(rx_buffer.len() % 4 == 0);  // 32bit単位でしか通信しない

            if header {
                let opcode = rx_buffer[0];
                let operand = rx_buffer[1];
                assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S");
                stream.tuser = operand & 0x7f;
                packet_last = (operand & 0x80) != 0;
                packet_size = u16::from_le_bytes([rx_buffer[2], rx_buffer[3]]) as usize;
                rx_buffer.drain(0..4);
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


