use std::error::Error;
use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::Duration;

use super::*;

/*
use crate::fifo32_axi4::{
    D3xxFifo32Axi4l, D3xxFifo32Axi4l, RtclAxi4sTxD3xx, RtclFifo32CtlD3xx,
};
*/

pub type RtclVideoCaptureHandlesD3xx = (D3xxFifo32Axi4l, D3xxFifo32Axi4sRx, D3xxFifo32Axi4sTx);



#[derive(Debug, Clone, Default)]
pub struct VideoCaptureStats {
    pub frame_completed: u64,
    pub frame_dropped_buffer_overflow: u64,
    pub frame_dropped_line_size_mismatch: u64,
    pub packet_total: u64,
    pub frame_start_count: u64,
}

struct FrameAssembler {
    started: bool,
    current_frame_id: u64,
    next_frame_id: u64,
    lines: Vec<Vec<u8>>,
}

impl FrameAssembler {
    fn new() -> Self {
        Self {
            started: false,
            current_frame_id: 0,
            next_frame_id: 0,
            lines: Vec::new(),
        }
    }

    fn start_new_frame(&mut self) {
        self.started = true;
        self.current_frame_id = self.next_frame_id;
        self.next_frame_id = self.next_frame_id.wrapping_add(1);
        self.lines.clear();
    }

    fn has_pending_frame(&self) -> bool {
        self.started && !self.lines.is_empty()
    }

    fn push_line(&mut self, line: Vec<u8>) {
        self.lines.push(line);
    }

    fn finalize_frame_if_valid(&mut self) -> Result<Option<VideoFrame>, ()> {
        if !self.started || self.lines.is_empty() {
            return Ok(None);
        }

        let line_bytes = self.lines[0].len();
        if self.lines.iter().any(|line| line.len() != line_bytes) {
            self.lines.clear();
            return Err(());
        }

        let line_count = self.lines.len() as u32;
        let mut data = Vec::with_capacity(line_bytes.saturating_mul(self.lines.len()));
        for line in &self.lines {
            data.extend_from_slice(line);
        }

        let frame = VideoFrame {
            frame_id: self.current_frame_id,
            height: line_count,
            width: line_bytes,
            data,
        };

        self.lines.clear();
        Ok(Some(frame))
    }
}

struct FrameQueueState {
    queue: VecDeque<VideoFrame>,
    max_frames: usize,
}

pub struct D3xxVideoCapture {
    axi4l: D3xxFifo32Axi4l,
    stop: Arc<AtomicBool>,
    frame_queue: Arc<(Mutex<FrameQueueState>, Condvar)>,
    thread_handle: Option<thread::JoinHandle<()>>,
    stats: Arc<Mutex<VideoCaptureStats>>,
}

impl D3xxVideoCapture {
    pub fn new(
        dev_index: usize,
        _max_buffered_frames: usize,
    ) -> Result<RtclVideoCaptureHandlesD3xx, Box<dyn Error>> {
        D3xxFifo32::new(dev_index)
    }

    pub fn with_handles(
        axi4l: D3xxFifo32Axi4l,
        axi4s_rx: D3xxFifo32Axi4sRx,
        axi4s_tx: D3xxFifo32Axi4sTx,
        _max_buffered_frames: usize,
    ) -> Result<RtclVideoCaptureHandlesD3xx, Box<dyn Error>> {
        Ok((axi4l, axi4s_rx, axi4s_tx))
    }

    pub fn new_capture(dev_index: usize, max_buffered_frames: usize) -> Result<Self, Box<dyn Error>> {
        let (axi4l, axi4s_rx, _axi4s_tx) = D3xxFifo32::new(dev_index)?;
        Self::with_capture_handles(axi4l, axi4s_rx, max_buffered_frames)
    }

    pub fn with_capture_handles(
        axi4l: D3xxFifo32Axi4l,
        axi4s_rx: D3xxFifo32Axi4sRx,
        max_buffered_frames: usize,
    ) -> Result<Self, Box<dyn Error>> {
        let max_frames = max_buffered_frames.max(1);
        let stats = Arc::new(Mutex::new(VideoCaptureStats::default()));
        let stop = Arc::new(AtomicBool::new(false));
        let frame_queue = Arc::new((
            Mutex::new(FrameQueueState {
                queue: VecDeque::with_capacity(max_frames),
                max_frames,
            }),
            Condvar::new(),
        ));

        let thread_stats = Arc::clone(&stats);
        let thread_stop = Arc::clone(&stop);
        let thread_queue = Arc::clone(&frame_queue);
        let thread_handle = thread::spawn(move || {
            recv_video_thread(axi4s_rx, thread_queue, thread_stop, thread_stats);
        });

        Ok(Self {
            axi4l,
            stop,
            frame_queue,
            thread_handle: Some(thread_handle),
            stats,
        })
    }

    // AXI4L APIs are intentionally exposed as pass-through.
    pub fn write_axi4l(&self, addr: u32, data: u32, strb: u8) -> Result<(), Box<dyn Error>> {
        self.axi4l.write_axi4l(addr, data, strb)
    }

    pub fn read_axi4l(&self, addr: u32) -> Result<u32, Box<dyn Error>> {
        self.axi4l.read_axi4l(addr)
    }

    pub fn recv_video(&self) -> Result<VideoFrame, Box<dyn Error>> {
        let (lock, cvar) = &*self.frame_queue;
        let mut state = lock
            .lock()
            .map_err(|_| "failed to lock frame queue for recv_video")?;

        while state.queue.is_empty() {
            state = cvar
                .wait(state)
                .map_err(|_| "failed to wait frame queue for recv_video")?;
        }

        state
            .queue
            .pop_front()
            .ok_or_else(|| "frame queue is empty".into())
    }

    pub fn recv_video_timeout(&self, timeout: Duration) -> Result<VideoFrame, Box<dyn Error>> {
        let (lock, cvar) = &*self.frame_queue;
        let mut state = lock
            .lock()
            .map_err(|_| "failed to lock frame queue for recv_video_timeout")?;

        if state.queue.is_empty() {
            let (new_state, timeout_result) = cvar
                .wait_timeout(state, timeout)
                .map_err(|_| "failed to wait frame queue for recv_video_timeout")?;
            state = new_state;
            if timeout_result.timed_out() && state.queue.is_empty() {
                return Err("timeout waiting for video frame".into());
            }
        }

        state
            .queue
            .pop_front()
            .ok_or_else(|| "frame queue is empty".into())
    }

    pub fn try_recv_video(&self) -> Result<VideoFrame, Box<dyn Error>> {
        let (lock, _) = &*self.frame_queue;
        let mut state = lock
            .lock()
            .map_err(|_| "failed to lock frame queue for try_recv_video")?;
        state
            .queue
            .pop_front()
            .ok_or_else(|| "No video frame available".into())
    }

    pub fn peek_latest_video(&self) -> Result<VideoFrame, Box<dyn Error>> {
        let (lock, _) = &*self.frame_queue;
        let state = lock
            .lock()
            .map_err(|_| "failed to lock frame queue for peek_latest_video")?;
        state
            .queue
            .back()
            .cloned()
            .ok_or_else(|| "No video frame available".into())
    }

    pub fn stats(&self) -> Result<VideoCaptureStats, Box<dyn Error>> {
        let guard = self
            .stats
            .lock()
            .map_err(|_| "failed to lock stats for snapshot")?;
        Ok(guard.clone())
    }
}

fn recv_video_thread(
    axi4s_rx: D3xxFifo32Axi4sRx,
    frame_queue: Arc<(Mutex<FrameQueueState>, Condvar)>,
    stop: Arc<AtomicBool>,
    stats: Arc<Mutex<VideoCaptureStats>>,
) {
    const IDLE_SLEEP: Duration = Duration::from_micros(200);
    let mut assembler = FrameAssembler::new();

    loop {
        if stop.load(Ordering::Relaxed) {
            break;
        }

        let packet = match axi4s_rx.try_recv_axi4s_opt() {
            Some(packet) => packet,
            None => {
                thread::sleep(IDLE_SLEEP);
                continue;
            }
        };

        update_stats(&stats, |s| {
            s.packet_total = s.packet_total.wrapping_add(1);
        });

        if is_frame_start(&packet) {
            update_stats(&stats, |s| {
                s.frame_start_count = s.frame_start_count.wrapping_add(1);
            });

            match assembler.finalize_frame_if_valid() {
                Ok(Some(frame)) => {
                    push_completed_frame(&frame_queue, &stats, frame);
                }
                Ok(None) => {}
                Err(()) => {
                    update_stats(&stats, |s| {
                        s.frame_dropped_line_size_mismatch =
                            s.frame_dropped_line_size_mismatch.wrapping_add(1);
                    });
                }
            }

            assembler.start_new_frame();
        }

        if assembler.started {
            assembler.push_line(packet.tdata);
        }
    }

    if assembler.has_pending_frame() {
        match assembler.finalize_frame_if_valid() {
            Ok(Some(frame)) => {
                push_completed_frame(&frame_queue, &stats, frame);
            }
            Ok(None) => {}
            Err(()) => {
                update_stats(&stats, |s| {
                    s.frame_dropped_line_size_mismatch =
                        s.frame_dropped_line_size_mismatch.wrapping_add(1);
                });
            }
        }
    }
}

fn is_frame_start(packet: &Axi4Stream) -> bool {
    (packet.tuser & 0x01) != 0
}

fn push_completed_frame(
    frame_queue: &Arc<(Mutex<FrameQueueState>, Condvar)>,
    stats: &Arc<Mutex<VideoCaptureStats>>,
    frame: VideoFrame,
) {
    let (lock, cvar) = &**frame_queue;
    let mut state = match lock.lock() {
        Ok(state) => state,
        Err(_) => return,
    };

    if state.queue.len() >= state.max_frames {
        state.queue.pop_front();
        update_stats(stats, |s| {
            s.frame_dropped_buffer_overflow = s.frame_dropped_buffer_overflow.wrapping_add(1);
        });
    }

    state.queue.push_back(frame);
    drop(state);
    cvar.notify_one();

    update_stats(stats, |s| {
        s.frame_completed = s.frame_completed.wrapping_add(1);
    });
}

fn update_stats<F>(stats: &Arc<Mutex<VideoCaptureStats>>, f: F)
where
    F: FnOnce(&mut VideoCaptureStats),
{
    if let Ok(mut guard) = stats.lock() {
        f(&mut guard);
    }
}

impl Drop for D3xxVideoCapture {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        let (_, cvar) = &*self.frame_queue;
        cvar.notify_all();
        if let Some(handle) = self.thread_handle.take() {
            let _ = handle.join();
        }
    }
}
