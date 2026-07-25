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

unsafe impl Send for RtclFifo32AxilD3xx {}
unsafe impl Sync for RtclFifo32AxilD3xx {}

pub struct RtRtclFifo32AxisRxD3xx {
    axi4s_reader: D3xxReader,
}

unsafe impl Send for RtRtclFifo32AxisRxD3xx {}
unsafe impl Sync for RtRtclFifo32AxisRxD3xx {}

pub struct RtclFifo32AxisTxD3xx {
    axi4s_writer: D3xxWriter,
}

unsafe impl Send for RtclFifo32AxisTxD3xx {}
unsafe impl Sync for RtclFifo32AxisTxD3xx {}

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

        let [axi4l_writer, axi4s_writer]: [D3xxWriter; 2] = match dev_writers.try_into() {
            Ok(writers) => writers,
            Err(_) => panic!("Expected 2 writers"),
        };
        let [axi4l_reader, axi4s_reader]: [D3xxReader; 2] = match dev_readers.try_into() {
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
        std::thread::sleep(std::time::Duration::from_millis(1)); // 応答が返ってくるまで少し待つ

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
        std::thread::sleep(std::time::Duration::from_millis(1)); // 応答が返ってくるまで少し待つ

        // 応答受信
        let response = self.axi4l_reader.read(4*2)?;
        assert!(response[0] == OPCODE_AXI4L_READ, "Expected OPCODE_AXI4L_READ response");
        assert!(response[1] == 0, "Expected AXI4L response");
        assert!(u16::from_le_bytes([response[2], response[3]]) == 4u16);
        Ok(u32::from_le_bytes([response[4], response[5], response[6], response[7]]))
    }
}

impl RtRtclFifo32AxisRxD3xx {
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        self.axi4s_reader.set_timeout(timeout_us)
    }

    pub fn recv_axi4s(&mut self, size: usize) -> Result<AxiStream, Box<dyn Error>> {
        if size == 0 {
            return Err("AXI4S requested size must be > 0".into());
        }

        let request_size = 4 + size;
        let mut rx_data = self.axi4s_reader.read_until_size(request_size, 1000)?;
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

    pub fn recv_data(&mut self, size: usize) -> Result<Vec<u8>, Box<dyn Error>> {
        let stream = self.recv_axi4s(size)?;
        Ok(stream.tdata)
    }


    pub fn recv_image(&mut self, width: usize, height: usize) -> Result<Vec<u8>, Box<dyn Error>> {
        let line_transfer_size = width + 4;

        let image_size = width * height;
        let mut image = vec![0u8; image_size];

        const MAX_OVERLAPS: usize = 16;

        let overlaps = height.min(MAX_OVERLAPS);
        let mut overlapped = vec![Overlapped::new(); overlaps];
        let mut buffers = vec![vec![0u8; line_transfer_size]; overlaps];
        let mut bytes_transferred = vec![0u32; overlaps];

        // 読み出し要求を発行
        for i in 0..overlaps {
            self.axi4s_reader.initialize_overlapped(&mut overlapped[i])?;
            self.axi4s_reader.read_async(&mut buffers[i], &mut bytes_transferred[i], &mut overlapped[i])?;
        }

        let mut issued_lines = overlaps;
        let mut completed_lines = 0usize;
        let mut index = 0usize;

        while completed_lines < height {
            self.axi4s_reader.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
            let rx_size = bytes_transferred[index] as usize;
//          println!("Received line {}: {} bytes", completed_lines, rx_size);
            assert!(rx_size == line_transfer_size);

            let line_data = &buffers[index];
            let opcode = line_data[0];
            let operand = line_data[1];
            let packet_last = (operand & 0x80) != 0;
            let packet_size = u16::from_le_bytes([line_data[2], line_data[3]]) as usize;
            assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S opcode={:02x}, oprand={:02x}, size={:04x}", opcode, operand, packet_size);
            assert!(packet_last, "Expected AXI4S packet_last to be set");
            assert!(packet_size == width);

            let dst_offset = completed_lines * width;
            image[dst_offset..dst_offset + width].copy_from_slice(&line_data[4..]);
            completed_lines += 1;

            if issued_lines < height {
                self.axi4s_reader.read_async(
                    &mut buffers[index],
                    &mut bytes_transferred[index],
                    &mut overlapped[index],
                )?;
                issued_lines += 1;
            }

            index = (index + 1) % overlaps;
        }

        for i in 0..overlaps {
            let _ = self.axi4s_reader.release_overlapped(&mut overlapped[i]);
        }

        Ok(image)
    }

    pub fn recv_frame(&mut self, width: usize, height: usize) -> Result<Vec<u8>, Box<dyn Error>> {
//      self.axi4s_reader.set_timeout(5000)?;
        let rx_data = self.axi4s_reader.read_until_size((width + 4) * height, 100)?;
//      let rx_data = self.axi4s_reader.read((width + 4) * height)?;
//      return Ok(vec![0u8; width * height]);
//      let rx_data = self.axi4s_reader.read((width + 4) * height)?;
//      println!("Received frame: {} bytes req:{}", rx_data.len(), (width + 4) * height);
        let mut image = Vec::with_capacity(width * height);
        for y in 0..height {
            let start = y * (width + 4);
            let end = start + (width + 4);
            let line_data = &rx_data[start..end];
            let opcode = line_data[0];
            let operand = line_data[1];
            let packet_last = (operand & 0x80) != 0;
            let packet_size = u16::from_le_bytes([line_data[2], line_data[3]]) as usize;
            assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S y={} opcode={:02x}, oprand={:02x}, size={:04x}", y, opcode, operand, packet_size);
            assert!(packet_last, "Expected AXI4S packet_last to be set");
            assert!(packet_size == width, "Expected AXI4S packet_size to match width: {} != {}", packet_size, width);
            image.extend_from_slice(&line_data[4..]);
        }
        Ok(image)
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

    pub fn send_data(&self, tdata : &[u8], tuser : usize) -> Result<(), Box<dyn Error>> {
        if (tdata.len() & 0x3) != 0 {
            return Err("AXI4S payload size must be 4-byte aligned".into());
        }

        let mut le_data = Vec::with_capacity(tdata.len());
        for chunk in tdata.chunks_exact(4) {
            let word = u32::from_ne_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
            le_data.extend_from_slice(&word.to_le_bytes());
        }

        let stream = AxiStream {
            tuser: tuser as u8,
            tdata: le_data,
        };
        self.send_axi4s(&stream)
    }

    pub fn send_frame(&self, width: usize, height: usize, image: &[u8]) -> Result<(), Box<dyn Error>> {
        let mut packet = Vec::<u8>::with_capacity((width + 4) * height);

        for y in 0..height {
            let header : [u8; 4] = [OPCODE_AXI4S_TRANS, if y == 0 { 0x81 } else { 0x80 }, (width as u16).to_le_bytes()[0], (width as u16).to_le_bytes()[1]];
            packet.extend_from_slice(&header);
            let start = y * width;
            let end = start + width;
            packet.extend_from_slice(&image[start..end]);
        }
        self.axi4s_writer.write(&packet)?;

        Ok(())
    }


    pub fn send_image(&self, width: usize, height: usize, image: &[u8]) -> Result<(), Box<dyn Error>> {
        assert!(width > 0, "image width must be > 0");
        assert!(height > 0, "image height must be > 0");

        let image_size = width * height;
        assert!(image.len() == image_size, "image buffer size mismatch: {} != {}", image.len(), image_size);
        assert!(width <= u16::MAX as usize, "image line width too large: {}", width);

        let line_transfer_size = width + 4;
        assert!((line_transfer_size & 0x3) == 0, "image line transfer size (width + 4) must be 4-byte aligned");

        const MAX_OVERLAPS: usize = 16;
        let overlaps = height.min(MAX_OVERLAPS);
        let mut overlapped = vec![Overlapped::new(); overlaps];
        let mut buffers = vec![vec![0u8; line_transfer_size]; overlaps];
        let mut bytes_transferred = vec![0u32; overlaps];

        // 先行してoverlap本数分の書き込み要求を発行
        for i in 0..overlaps {
            let line_index = i;
            let src_offset = line_index * width;
            let line_buf = &mut buffers[i];
            line_buf[0] = OPCODE_AXI4S_TRANS;
            line_buf[1] = if i == 0 { 0x81 } else { 0x80 };
            line_buf[2..4].copy_from_slice(&(width as u16).to_le_bytes());
            line_buf[4..].copy_from_slice(&image[src_offset..src_offset + width]);

            self.axi4s_writer.initialize_overlapped(&mut overlapped[i])?;
            bytes_transferred[i] = buffers[i].len() as u32;
            self.axi4s_writer.write_async(&buffers[i], &mut bytes_transferred[i], &mut overlapped[i])?;
//          println!("Issued line {}: {} bytes", line_index, line_transfer_size);
        }

        let mut issued_lines = overlaps;
        let mut completed_lines = 0usize;
        let mut index = 0usize;

        while completed_lines < height {
            self.axi4s_writer.get_async_result(&mut overlapped[index], &mut bytes_transferred[index], true)?;
            let tx_size = bytes_transferred[index] as usize;
            assert!(tx_size == line_transfer_size, "AXI4S image line transfer size mismatch at line {}: {} != {}", completed_lines, tx_size, line_transfer_size);
//          println!("Completed line {}: {} bytes", completed_lines, tx_size);
            completed_lines += 1;

            if issued_lines < height {
                let line_index = issued_lines;
                let src_offset = line_index * width;
                let line_buf = &mut buffers[index];
                line_buf[0] = OPCODE_AXI4S_TRANS;
                line_buf[1] = 0x80;
                line_buf[2..4].copy_from_slice(&(width as u16).to_le_bytes());
                line_buf[4..].copy_from_slice(&image[src_offset..src_offset + width]);
                
                bytes_transferred[index] = buffers[index].len() as u32;
                self.axi4s_writer.write_async(
                    &buffers[index],
                    &mut bytes_transferred[index],
                    &mut overlapped[index],
                )?;
//              println!("Issued line {}: {} bytes", line_index, line_transfer_size);
                issued_lines += 1;
            }

            index = (index + 1) % overlaps;
        }

        for i in 0..overlaps {
            let _ = self.axi4s_writer.release_overlapped(&mut overlapped[i]);
        }

        Ok(())
    }
}


#[derive(Debug, Clone)]
pub struct AxiStream {
    pub tuser: u8,
    pub tdata: Vec<u8>,
}

