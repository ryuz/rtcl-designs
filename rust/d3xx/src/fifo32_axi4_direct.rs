use std::error::Error;

use crate::d3xx_device::*;
#[cfg(target_os = "linux")]
use crate::ffi::{FT_PIPE_TRANSFER_CONF, FT_TRANSFER_CONF};

use super::*;


pub struct D3xxFifo32Direct;

pub struct D3xxFifo32DirectAxi4l {
    axi4l_writer: D3xxWriter,
    axi4l_reader: D3xxReader,
}

unsafe impl Send for D3xxFifo32DirectAxi4l {}
unsafe impl Sync for D3xxFifo32DirectAxi4l {}

pub struct D3xxFifo32DirectAxi4sRx {
    axi4s_reader: D3xxReader,
}

unsafe impl Send for D3xxFifo32DirectAxi4sRx {}
unsafe impl Sync for D3xxFifo32DirectAxi4sRx {}

pub struct D3xxFifo32DirectAxi4sTx {
    axi4s_writer: D3xxWriter,
}

unsafe impl Send for D3xxFifo32DirectAxi4sTx {}
unsafe impl Sync for D3xxFifo32DirectAxi4sTx {}

impl D3xxFifo32Direct {
    pub fn new(dev_index: usize) -> Result<(D3xxFifo32DirectAxi4l, D3xxFifo32DirectAxi4sRx, D3xxFifo32DirectAxi4sTx), Box<dyn Error>> {
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
        
        let axi4l = D3xxFifo32DirectAxi4l {
            axi4l_writer: axi4l_writer,
            axi4l_reader: axi4l_reader,
        };
        let axi4s_rx = D3xxFifo32DirectAxi4sRx {
            axi4s_reader: axi4s_reader,
        };
        let axi4s_tx = D3xxFifo32DirectAxi4sTx {
            axi4s_writer: axi4s_writer,
        };

        Ok((axi4l, axi4s_rx, axi4s_tx))
    }
}

impl D3xxFifo32DirectAxi4l {
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

fn parse_axi4s_packet(data: &[u8], expected_size: usize) -> Result<AxiStream, Box<dyn Error>> {
    if data.len() != 4 + expected_size {
        return Err(format!(
            "AXI4S receive size mismatch: {} != {}",
            data.len(),
            4 + expected_size
        )
        .into());
    }

    let opcode = data[0];
    let operand = data[1];
    let packet_last = (operand & 0x80) != 0;
    let packet_size = u16::from_le_bytes([data[2], data[3]]) as usize;
    assert!(opcode == OPCODE_AXI4S_TRANS, "Expected OPCODE_AXI4S opcode={:02x}, oprand={:02x}, size={:04x}", opcode, operand, packet_size);

    if packet_size != expected_size {
        return Err(format!(
            "AXI4S payload size mismatch in header: {} != {}",
            packet_size,
            expected_size
        )
        .into());
    }

    if !packet_last {
        return Err("AXI4S stream is not terminated at requested size".into());
    }

    Ok(AxiStream {
        tuser: operand & 0x7f,
        tdata: data[4..].to_vec(),
    })
}

impl D3xxFifo32DirectAxi4sRx {
    pub fn set_timeout(&mut self, timeout_us: u32) -> D3xxResult<()> {
        self.axi4s_reader.set_timeout(timeout_us)
    }

    pub fn recv_axi4s(&mut self, size: usize) -> Result<AxiStream, Box<dyn Error>> {
        if size == 0 {
            return Err("AXI4S requested size must be > 0".into());
        }

        let request_size = 4 + size;
        let mut rx_data = self.axi4s_reader.read_with_timeout(request_size, std::time::Duration::from_secs(1))?;
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

        parse_axi4s_packet(&rx_data, size)
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
        let rx_data = self.axi4s_reader.read_with_timeout((width + 4) * height, std::time::Duration::from_secs(1))?;
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


impl D3xxFifo32DirectAxi4sTx {
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

        const CHUNK_SIZE: usize = 1024*2;
        if packet.len() > CHUNK_SIZE {
            for chunk in packet.chunks(CHUNK_SIZE) {
                self.axi4s_writer.write(chunk)?;
            }
        } else {
            self.axi4s_writer.write(&packet)?;
        }

        Ok(())
    }
}


#[derive(Debug, Clone)]
pub struct AxiStream {
    pub tuser: u8,
    pub tdata: Vec<u8>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_axi4s_payload_accepts_single_packet_of_expected_size() {
        let expected = vec![0x11, 0x22, 0x33, 0x44];
        let mut data = Vec::with_capacity(4 + expected.len());
        data.push(OPCODE_AXI4S_TRANS);
        data.push(0x81);
        data.extend_from_slice(&(expected.len() as u16).to_le_bytes());
        data.extend_from_slice(&expected);

        let stream = parse_axi4s_packet(&data, expected.len()).unwrap();
        assert_eq!(stream.tuser, 0x01);
        assert_eq!(stream.tdata, expected);
    }
}

