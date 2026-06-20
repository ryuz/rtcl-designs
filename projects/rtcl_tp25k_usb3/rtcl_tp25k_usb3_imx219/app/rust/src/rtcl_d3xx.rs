use std::collections::VecDeque;
use std::io::{Error, ErrorKind, Read, Write, Result};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use d3xx::{Device, Pipe};

const OPCODE_AXI4L_WRITE: u8 = 0x02;
const OPCODE_AXI4L_READ: u8 = 0x03;
const OPCODE_AXI4S_TRANS: u8 = 0x10;

#[derive(Debug, Clone)]
pub struct RtclPacket {
    pub opcode: u8,
    pub opland: u8,
    pub payload: Vec<u8>,
}

type PacketFifo = Arc<(Mutex<VecDeque<RtclPacket>>, Condvar)>;

pub struct RtclD3xx {
    device: Device,
    axi4s_buf: Vec<u8>,
    axi4s_packets: Vec<Vec<u8>>,
}

impl RtclD3xx {
    pub fn new(device: Device) -> Self {
        Self {
            device,
            axi4s_buf: Vec::<u8>::new(),
            axi4s_packets: Vec::<Vec<u8>>::new(),
        }
    }

    // 送信パケットを作成して送信する
    fn send_packet(&mut self, opcode: u8, operand: u8, payload: &[u8]) -> Result<()> {
        let length = payload.len() as u16;
        let mut packet = Vec::<u8>::with_capacity(4 + payload.len());
        packet.push(opcode);
        packet.push(operand);
        packet.extend_from_slice(&length.to_le_bytes());
        packet.extend_from_slice(payload);
//      println!("send_packet: packet = {:?}", packet);
        self.device.pipe(Pipe::Out0).write_all(&packet)?;
        Ok(())
    }

    // 受信パケットを1つ読み込む
    fn recv_packet(&mut self) -> Result<(u8, u8, Vec<u8>)> {
        let mut header = [0u8; 4];
        self.device.pipe(Pipe::In0).read_exact(&mut header)?;
        println!("recv_packet: header = {:?}", header);
        let opcode = header[0];
        let operand = header[1];
        let length = u16::from_le_bytes([header[2], header[3]]) as usize;
        println!("recv_packet: opcode = 0x{:02x}, operand = 0x{:02x}, length = 0x{:04x}", opcode, operand, length);

        let mut payload = vec![0u8; length as usize];
        if length > 0 {
            self.device.pipe(Pipe::In0).read_exact(&mut payload)?;
            println!("recv_packet: payload = {:?}", payload);
        }
        Ok((opcode, operand, payload))
    }

    fn recv_command(&mut self) -> Result<(u8, u8, Vec<u8>)> {
        loop {
            let (opcode, operand, payload) = self.recv_packet()?;
            if opcode == OPCODE_AXI4S_TRANS {
                println!("recv_command: AXI4S packet received, opcode = {}, operand = {}, payload length = {}", opcode, operand, payload.len());
                self.axi4s_buf.extend_from_slice(&payload);
                if operand & 0x80 != 0 {
                    self.axi4s_packets.push(self.axi4s_buf.clone());
                    self.axi4s_buf.clear();
                }
            }
            else {
                return Ok((opcode, operand, payload));
            }
        }
    }

    pub fn recv_axi4s(&mut self) -> Result<Vec<u8>> {
        if self.axi4s_buf.is_empty() {
            loop {
                let (opcode, operand, payload) = self.recv_packet()?;
                assert!(opcode == OPCODE_AXI4S_TRANS, "Expected AXI4S packet");
                self.axi4s_buf.extend_from_slice(&payload);
                if operand & 0x80 != 0 {
                    self.axi4s_packets.push(self.axi4s_buf.clone());
                    self.axi4s_buf.clear();
                    break;
                }
            }
        }
        Ok(self.axi4s_packets.remove(0))
    }


    pub fn write_axi4l(&mut self, addr: u32, data: u32, strb: u8) -> Result<()> {
        // コマンド送信
        let mut payload = Vec::<u8>::with_capacity(8);
        payload.extend_from_slice(addr.to_le_bytes().as_ref());
        payload.extend_from_slice(data.to_le_bytes().as_ref());
        self.send_packet(OPCODE_AXI4L_WRITE, strb << 4, &payload)?;

        // 応答受信
        let (opcode, operand, payload) = self.recv_command()?;
        assert!(opcode == OPCODE_AXI4L_WRITE, "Expected AXI4L_WRITE response");
        assert!(operand == 0, "Expected AXI4L response");
        assert!(payload.len() == 0, "Expected 04 bytes in AXI4L_WRITE response");
        Ok(())
    }

    pub fn read_axi4l(&mut self, addr: u32) -> Result<u32> {
        // コマンド送信
        let mut payload = Vec::<u8>::with_capacity(4);
        payload.extend_from_slice(addr.to_le_bytes().as_ref());
        self.send_packet(OPCODE_AXI4L_READ, 0, &payload)?;

        // 応答受信
        let (opcode, operand, payload) = self.recv_command()?;
        assert!(opcode == OPCODE_AXI4L_READ, "Expected AXI4L_READ response");
        assert!(operand == 0, "Expected AXI4L response");
        assert!(payload.len() == 4, "Expected 4 bytes in AXI4L_READ response");
        let data = u32::from_le_bytes(payload[0..4].try_into().unwrap());
        Ok(data)
    }
}
