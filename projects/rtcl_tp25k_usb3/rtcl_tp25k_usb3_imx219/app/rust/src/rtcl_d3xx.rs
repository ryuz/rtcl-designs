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
    pub operand: u8,
    pub payload: Vec<u8>,
}

use std::sync::mpsc;

type PacketFifo = Arc<(Mutex<VecDeque<RtclPacket>>, Condvar)>;

pub struct RtclD3xx {
    device: Arc<Mutex<Device>>,
//  axi4s_buf: Vec<u8>,
    rx_command: mpsc::Receiver<RtclPacket>,
    rx_stream: mpsc::Receiver<RtclPacket>,
}

impl RtclD3xx {
    pub fn new(device: Arc<Mutex<Device>>) -> Self {
        let (tx_command, rx_command) = mpsc::channel::<RtclPacket>();
        let (tx_stream, rx_stream) = mpsc::channel::<RtclPacket>();

        std::thread::spawn(|| {
//          let all_devices = d3xx::list_devices().expect("failed to list devices");
//          let device = all_devices[0].open().expect("failed to open device");
            let mut recv_pipe = device.lock().unwrap().pipe(Pipe::In0).clone();

            recv_pipe.set_timeout(1).expect("failed to set timeout");
            let mut buf = vec![0u8; 4096];
            let mut header = true;
            let mut packet = RtclPacket { opcode : 0, operand: 0, payload: Vec::new() };
            let mut pkt_len = 0;
            loop {
                // 受信
                let mut offset = 0;
                let ret = recv_pipe.read(&mut buf);

                // パケット分析
                if let Ok(mut size) = ret {
                    assert!(size % 4 == 0);  // 32bit単位でしか通信しない
                    while size > 0 {
                        if header {
                            // ヘッダを処理
                            packet.opcode = buf[offset];
                            packet.operand = buf[offset + 1];
                            pkt_len = u16::from_le_bytes([buf[offset + 2], buf[offset + 3]]) as usize;
                            offset += 4;
                            size -= 4;
                            if pkt_len == 0 {
                                // ショートコマンドなら即処理
                                if packet.opcode == OPCODE_AXI4S_TRANS {
                                    tx_stream.send(packet.clone()).unwrap();
                                }
                                else {
                                    tx_command.send(packet.clone()).unwrap();
                                }
                                packet.payload.clear();
                                println!("recv_packet: opcode = 0x{:02x}, operand = 0x{:02x}, length = 0x{:04x}", packet.opcode, packet.operand, pkt_len);
                            }
                            else {
                                header = false;
                            }
                        }
                        else {
                            // 後続ペイロードの処理
                            if size >= pkt_len {
                                packet.payload.extend_from_slice(buf[offset..offset + pkt_len].as_ref());
                                offset += pkt_len;
                                size -= pkt_len;
                                header = true;
                                if packet.opcode == OPCODE_AXI4S_TRANS {
                                    tx_stream.send(packet.clone()).unwrap();
                                }
                                else {
                                    tx_command.send(packet.clone()).unwrap();
                                }
                                packet.payload.clear();
                                println!("recv_packet: opcode = 0x{:02x}, operand = 0x{:02x}, length = 0x{:04x}", packet.opcode, packet.operand, pkt_len);
                            }
                            else {
                                packet.payload.extend_from_slice(buf[offset..offset + size].as_ref());
                                pkt_len -= size;
                                size = 0;
                            }
                        }
                    }
                }
            }
        });

        Self {
            device,
//          axi4s_buf: Vec::<u8>::new(),
            rx_command: rx_command,
            rx_stream: rx_stream,
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
    /*
    fn recv_packet(&mut self) -> Result<(u8, u8, Vec<u8>)> {
        let mut header = [0u8; 4];
        self.device.pipe(Pipe::In0).read_exact(&mut header)?;
//      println!("recv_packet: header = {:?}", header);
        let opcode = header[0];
        let operand = header[1];
        let length = u16::from_le_bytes([header[2], header[3]]) as usize;// & 0xff;
        println!("recv_packet: opcode = 0x{:02x}, operand = 0x{:02x}, length = 0x{:04x}", opcode, operand, length);

        let mut payload = vec![0u8; length as usize];
        if length > 0 {
            self.device.pipe(Pipe::In0).read_exact(&mut payload)?;
//          println!("recv_packet: payload = {:?}", payload);
        }
        Ok((opcode, operand, payload))
    }
    */

    fn recv_command(&mut self) -> Result<(u8, u8, Vec<u8>)> {
        self.rx_command.recv().map(|packet| (packet.opcode, packet.operand, packet.payload)).map_err(|e| Error::new(ErrorKind::Other, e))
    }

    pub fn recv_axi4s(&mut self) -> Result<Vec<u8>> {
        let mut payload = Vec::<u8>::new();
        loop {
            let packet = self.rx_stream.recv().map_err(|e| Error::new(ErrorKind::Other, e))?;
            assert!(packet.opcode == OPCODE_AXI4S_TRANS, "Expected AXI4S packet");
            payload.extend_from_slice(&packet.payload);
            if packet.operand & 0x80 != 0 {
                return Ok(payload);
            }
        }
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
