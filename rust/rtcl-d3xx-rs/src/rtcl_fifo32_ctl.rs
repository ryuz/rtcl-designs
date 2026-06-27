use std::error::Error;
use std::collections::VecDeque;
use std::sync::{Arc, Condvar, Mutex};

use crate::d3xx_device::*;


const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
//const OPCODE_AXI4S_TRANS: u8 = 0x10;

//const CH_AXI4L: usize = 0;
//const CH_AXI4S: usize = 1;


pub struct RtclFifo32CtlD3xx {
    axi4l_writer: D3xxWriter,
    axi4l_reader: D3xxReader,
    axi4s_fifo: Arc<(Mutex<VecDeque<u8>>, Condvar)>,
}

impl RtclFifo32CtlD3xx {
    pub fn new(dev_index: usize) -> Result<Self, Box<dyn Error>> {

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;
        let axi4s_fifo = Arc::new((Mutex::new(VecDeque::new()), Condvar::new()));

        let [axi4l_writer, _axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
            Ok(readers) => readers,
            Err(_) => panic!("Expected 2 readers"),
        };

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

//      dev_readers[CH_AXI4S].set_timeout(100)?;
//      dev_readers[CH_AXI4S].set_stream_pipe(0x100000)?;

        Ok(Self {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
            axi4s_fifo: axi4s_fifo,
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


impl Drop for RtclFifo32CtlD3xx {
    fn drop(&mut self) {
//      println!("RtclFifo32D3xx: drop");
    }
}

