use std::sync::Mutex;
use std::time::Duration;

use pyo3::exceptions::{PyRuntimeError, PyTimeoutError};
use pyo3::prelude::*;

use rtcl_d3xx_core as d3xx;

fn runtime_err(msg: String) -> PyErr {
    PyRuntimeError::new_err(msg)
}

/// AXI4-Stream packet (data is exposed as `bytes`)
#[pyclass(get_all, skip_from_py_object)]
#[derive(Clone)]
struct Axi4Stream {
    tuser: u8,
    data: Vec<u8>,
}

#[pymethods]
impl Axi4Stream {
    #[new]
    #[pyo3(signature = (data, tuser=0))]
    fn new(data: Vec<u8>, tuser: u8) -> Self {
        Self { tuser, data }
    }

    fn __len__(&self) -> usize {
        self.data.len()
    }

    fn __repr__(&self) -> String {
        format!("Axi4Stream(tuser=0x{:02x}, len={})", self.tuser, self.data.len())
    }
}

impl From<d3xx::Axi4Stream> for Axi4Stream {
    fn from(s: d3xx::Axi4Stream) -> Self {
        Self { tuser: s.tuser, data: s.tdata }
    }
}

/// Captured video frame (data is exposed as `bytes`)
#[pyclass(get_all, skip_from_py_object)]
#[derive(Clone)]
struct VideoFrame {
    frame_id: u64,
    width: usize,
    height: u32,
    data: Vec<u8>,
}

#[pymethods]
impl VideoFrame {
    fn __repr__(&self) -> String {
        format!(
            "VideoFrame(frame_id={}, width={}, height={}, len={})",
            self.frame_id,
            self.width,
            self.height,
            self.data.len()
        )
    }
}

impl From<d3xx::VideoFrame> for VideoFrame {
    fn from(f: d3xx::VideoFrame) -> Self {
        Self {
            frame_id: f.frame_id,
            width: f.width,
            height: f.height,
            data: f.data,
        }
    }
}

#[pyclass(get_all, skip_from_py_object)]
#[derive(Clone)]
struct VideoCaptureStats {
    frame_completed: u64,
    frame_dropped_buffer_overflow: u64,
    frame_dropped_line_size_mismatch: u64,
    packet_total: u64,
    frame_start_count: u64,
}

#[pymethods]
impl VideoCaptureStats {
    fn __repr__(&self) -> String {
        format!(
            "VideoCaptureStats(frame_completed={}, frame_dropped_buffer_overflow={}, frame_dropped_line_size_mismatch={}, packet_total={}, frame_start_count={})",
            self.frame_completed,
            self.frame_dropped_buffer_overflow,
            self.frame_dropped_line_size_mismatch,
            self.packet_total,
            self.frame_start_count
        )
    }
}

impl From<d3xx::VideoCaptureStats> for VideoCaptureStats {
    fn from(s: d3xx::VideoCaptureStats) -> Self {
        Self {
            frame_completed: s.frame_completed,
            frame_dropped_buffer_overflow: s.frame_dropped_buffer_overflow,
            frame_dropped_line_size_mismatch: s.frame_dropped_line_size_mismatch,
            packet_total: s.packet_total,
            frame_start_count: s.frame_start_count,
        }
    }
}

/// FT601 FIFO32 device (AXI4-Lite register access + AXI4-Stream transfer)
#[pyclass]
struct Fifo32 {
    axi4l: d3xx::D3xxFifo32Axi4l,
    rx: Mutex<d3xx::D3xxFifo32Axi4sRx>,
    tx: d3xx::D3xxFifo32Axi4sTx,
}

#[pymethods]
impl Fifo32 {
    #[new]
    #[pyo3(signature = (dev_index=0))]
    fn new(py: Python<'_>, dev_index: usize) -> PyResult<Self> {
        let (axi4l, rx, tx) = py
            .detach(|| d3xx::D3xxFifo32::new(dev_index).map_err(|e| e.to_string()))
            .map_err(runtime_err)?;
        Ok(Self { axi4l, rx: Mutex::new(rx), tx })
    }

    #[pyo3(signature = (addr, data, strb=0x0f))]
    fn write_axi4l(&self, py: Python<'_>, addr: u32, data: u32, strb: u8) -> PyResult<()> {
        py.detach(|| self.axi4l.write_axi4l(addr, data, strb).map_err(|e| e.to_string()))
            .map_err(runtime_err)
    }

    fn read_axi4l(&self, py: Python<'_>, addr: u32) -> PyResult<u32> {
        py.detach(|| self.axi4l.read_axi4l(addr).map_err(|e| e.to_string()))
            .map_err(runtime_err)
    }

    /// Blocking receive. `timeout` is in seconds (None blocks forever).
    #[pyo3(signature = (timeout=None))]
    fn recv_axi4s(&self, py: Python<'_>, timeout: Option<f64>) -> PyResult<Axi4Stream> {
        let result = py.detach(|| {
            let rx = self.rx.lock().map_err(|_| "rx lock poisoned".to_string())?;
            match timeout {
                Some(t) => rx
                    .recv_axi4s_timeout(Duration::from_secs_f64(t))
                    .map_err(|e| e.to_string()),
                None => rx.recv_axi4s().map_err(|e| e.to_string()),
            }
        });
        match result {
            Ok(s) => Ok(s.into()),
            Err(msg) if timeout.is_some() => Err(PyTimeoutError::new_err(msg)),
            Err(msg) => Err(runtime_err(msg)),
        }
    }

    /// Non-blocking receive. Returns None when no packet is available.
    fn try_recv_axi4s(&self, py: Python<'_>) -> PyResult<Option<Axi4Stream>> {
        let result = py.detach(|| {
            let rx = self.rx.lock().map_err(|_| "rx lock poisoned".to_string())?;
            Ok::<_, String>(rx.try_recv_axi4s_opt())
        });
        result.map(|opt| opt.map(Into::into)).map_err(runtime_err)
    }

    /// Send one AXI4-Stream packet. `data` length must be 4-byte aligned.
    #[pyo3(signature = (data, tuser=0))]
    fn send_axi4s(&self, py: Python<'_>, data: Vec<u8>, tuser: u8) -> PyResult<()> {
        let stream = d3xx::Axi4Stream { tuser, tdata: data };
        py.detach(|| self.tx.send_axi4s(&stream).map_err(|e| e.to_string()))
            .map_err(runtime_err)
    }

    /// Send an image as one frame (one AXI4-Stream packet per line).
    fn send_frame(&self, py: Python<'_>, width: usize, height: usize, image: Vec<u8>) -> PyResult<()> {
        py.detach(|| self.tx.send_frame(width, height, &image).map_err(|e| e.to_string()))
            .map_err(runtime_err)
    }
}

/// Video capture with background frame-assembly thread
#[pyclass]
struct VideoCapture {
    inner: d3xx::D3xxVideoCapture,
}

#[pymethods]
impl VideoCapture {
    #[new]
    #[pyo3(signature = (dev_index=0, max_buffered_frames=4))]
    fn new(py: Python<'_>, dev_index: usize, max_buffered_frames: usize) -> PyResult<Self> {
        let inner = py
            .detach(|| {
                d3xx::D3xxVideoCapture::new_capture(dev_index, max_buffered_frames)
                    .map_err(|e| e.to_string())
            })
            .map_err(runtime_err)?;
        Ok(Self { inner })
    }

    #[pyo3(signature = (addr, data, strb=0x0f))]
    fn write_axi4l(&self, py: Python<'_>, addr: u32, data: u32, strb: u8) -> PyResult<()> {
        py.detach(|| self.inner.write_axi4l(addr, data, strb).map_err(|e| e.to_string()))
            .map_err(runtime_err)
    }

    fn read_axi4l(&self, py: Python<'_>, addr: u32) -> PyResult<u32> {
        py.detach(|| self.inner.read_axi4l(addr).map_err(|e| e.to_string()))
            .map_err(runtime_err)
    }

    /// Blocking receive of a completed frame. `timeout` is in seconds (None blocks forever).
    #[pyo3(signature = (timeout=None))]
    fn recv_video(&self, py: Python<'_>, timeout: Option<f64>) -> PyResult<VideoFrame> {
        let result = py.detach(|| match timeout {
            Some(t) => self
                .inner
                .recv_video_timeout(Duration::from_secs_f64(t))
                .map_err(|e| e.to_string()),
            None => self.inner.recv_video().map_err(|e| e.to_string()),
        });
        match result {
            Ok(f) => Ok(f.into()),
            Err(msg) if timeout.is_some() => Err(PyTimeoutError::new_err(msg)),
            Err(msg) => Err(runtime_err(msg)),
        }
    }

    /// Non-blocking receive. Returns None when no frame is available.
    fn try_recv_video(&self, py: Python<'_>) -> Option<VideoFrame> {
        py.detach(|| self.inner.try_recv_video().ok()).map(Into::into)
    }

    /// Peek the newest buffered frame without consuming it. Returns None when empty.
    fn peek_latest_video(&self, py: Python<'_>) -> Option<VideoFrame> {
        py.detach(|| self.inner.peek_latest_video().ok()).map(Into::into)
    }

    fn stats(&self, py: Python<'_>) -> PyResult<VideoCaptureStats> {
        py.detach(|| self.inner.stats().map_err(|e| e.to_string()))
            .map(Into::into)
            .map_err(runtime_err)
    }
}

#[pymodule]
fn rtcl_d3xx(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<Axi4Stream>()?;
    m.add_class::<VideoFrame>()?;
    m.add_class::<VideoCaptureStats>()?;
    m.add_class::<Fifo32>()?;
    m.add_class::<VideoCapture>()?;
    Ok(())
}
