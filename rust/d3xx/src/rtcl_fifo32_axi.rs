use std::error::Error;

use crate::d3xx_device::*;
#[cfg(target_os = "linux")]
use crate::ffi::{FT_PIPE_TRANSFER_CONF, FT_TRANSFER_CONF};


const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
const OPCODE_AXI4S_TRANS: u8 = 0x10;


pub struct RtclFifo32AxiD3xx;

pub struct RtclFifo32AxilD3xx {
    axi4l_writer: D3xxWriter,
    axi4l_reader: D3xxReader,
}

pub struct RtRtclFifo32AxisRxD3xx {
    axi4s_reader: D3xxReader,
}

pub struct RtclFifo32AxisTxD3xx {
    axi4s_writer: D3xxWriter,
}

impl RtclFifo32AxiD3xx {
    pub fn new(dev_index: usize) -> Result<(RtclFifo32AxilD3xx, RtRtclFifo32AxisRxD3xx, RtclFifo32AxisTxD3xx), Box<dyn Error>> {
        #[cfg(target_os = "linux")]
        {
            let mut transfer_conf = FT_TRANSFER_CONF::default();
//            transfer_conf.pipe[0].dwURBBufferSize = 1024;
//            transfer_conf.pipe[1].dwURBBufferSize = 1024;
//          D3xxDevice::set_transfer_params_for_fifo(0, &mut transfer_conf)?;
//          D3xxDevice::set_transfer_params_for_fifo(1, &mut transfer_conf)?;
        }

        let (dev_writers, dev_readers) = D3xxDevice::new(dev_index, 2)?;

        let [axi4l_writer, mut axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, mut axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
            Ok(readers) => readers,
            Err(_) => panic!("Expected 2 readers"),
        };

        /*
        axi4s_writer.set_timeout(10)?;
        axi4s_writer.set_stream_pipe(0x100000)?;
        axi4s_reader.set_timeout(10)?;
        axi4s_reader.set_stream_pipe(0x100000)?;
        */
        
        let axi4l = RtclFifo32AxilD3xx {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
        };
        let axi4s_rx = RtRtclFifo32AxisRxD3xx {
            axi4s_reader: axi4s_reader,
        };
        let axi4s_tx = RtclFifo32AxisTxD3xx {
            axi4s_writer: axi4s_writer,
        };

        Ok((axi4l, axi4s_rx, axi4s_tx))
    }
}

impl RtclFifo32AxilD3xx {
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

impl RtRtclFifo32AxisRxD3xx {
    pub fn recv_axi4s(&mut self, size: usize) -> Result<AxiStream, Box<dyn Error>> {
        if size == 0 {
            return Err("AXI4S requested size must be > 0".into());
        }

        let request_size = 4 + size;
        let mut rx_data = self.axi4s_reader.read(request_size)?;
        while rx_data.len() < request_size {
            let remain_size = request_size - rx_data.len();
            let mut remain_data = self.axi4s_reader.read(remain_size)?;
            if remain_data.is_empty() {
                break;
            }
            rx_data.append(&mut remain_data);
        }
        if rx_data.len() != request_size {
            return Err(format!(
                "AXI4S receive size mismatch: {} != {}",
                rx_data.len(),
                request_size
            )
            .into());
        }
        assert!((rx_data.len() & 0x3) == 0); // 32bit単位でしか通信しない

        let opcode = rx_data[0];
        let operand = rx_data[1];
        let packet_last = (operand & 0x80) != 0;
        let packet_size = u16::from_le_bytes([rx_data[2], rx_data[3]]) as usize;
        assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S opcode={:02x}, oprand={:02x}, size={:04x}", opcode, operand, packet_size);
        if packet_size != size {
            return Err(format!(
                "AXI4S payload size mismatch in header: {} != {}",
                packet_size,
                size
            )
            .into());
        }

        if !packet_last {
            return Err("AXI4S stream is not terminated at requested size".into());
        }

        Ok(AxiStream {
            tuser: operand & 0x7f,
            tdata: rx_data[4..].to_vec(),
        })
    }
}

impl RtclFifo32AxisTxD3xx {
    pub fn send_axi4s(&self, stream: &AxiStream) -> Result<(), Box<dyn Error>> {
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

        self.axi4s_writer.write(&packet)?;
        Ok(())
    }
}


#[derive(Debug, Clone)]
pub struct AxiStream {
    pub tuser: u8,
    pub tdata: Vec<u8>,
}

