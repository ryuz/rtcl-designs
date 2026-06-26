use std::error::Error;

use crate::d3xx_device::*;


const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
//const OPCODE_AXI4S_TRANS: u8 = 0x10;

const CH_AXI4L: usize = 0;
const CH_AXI4S: usize = 1;


pub struct RtclFifo32CtlD3xx {
    writers: Vec<D3xxWriter>,
    readers: Vec<D3xxReader>,
}

impl RtclFifo32CtlD3xx {
    pub fn new(dev_index: usize) -> Result<Self, Box<dyn Error>> {

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;
        Ok(Self {
            writers: dev_writers,
            readers: dev_readers,
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
        self.writers[CH_AXI4L].write(&command)?;

        // 応答受信
        let response = self.readers[CH_AXI4L].read(4)?;
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
        self.writers[CH_AXI4L].write(&command)?;

        // 応答受信
        let response = self.readers[CH_AXI4L].read(4*2)?;
        assert!(response[0] == OPCODE_AXI4L_READ, "Expected OPCODE_AXI4L_READ response");
        assert!(response[1] == 0, "Expected AXI4L response");
        assert!(u16::from_le_bytes([response[2], response[3]]) == 4u16);
        Ok(u32::from_le_bytes([response[4], response[5], response[6], response[7]]))
    }

    pub fn recv_axi4s(&mut self, len: usize) -> Result<Vec<u8>, Box<dyn Error>> {
        let response = self.readers[CH_AXI4S].read(len)?;
        Ok(response)
    }
}


impl Drop for RtclFifo32CtlD3xx {
    fn drop(&mut self) {
//      println!("RtclFifo32D3xx: drop");
    }
}

