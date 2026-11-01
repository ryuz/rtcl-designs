#![allow(dead_code)]

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

use jelly_mem_access::*;
use jelly_lib::video_dma_pac::VideoDmaPac;

#[cfg(feature = "opencv")]
use opencv::core::*;

pub struct CaptureDriver<T0: MemAccess, T1: MemAccess>
{
    vdmaw: VideoDmaPac<T0>,
    dmabuf: T1,
    record_frames: usize,
    record_width: usize,
    record_height: usize,
}

impl<T0: MemAccess, T1: MemAccess> CaptureDriver<T0, T1>
{
    pub fn new(reg_vdmaw: T0, dmabuf: T1) -> Result<Self> {
        Ok(Self {
            vdmaw: VideoDmaPac::<T0>::new(reg_vdmaw, 2, 2, None)?,
            dmabuf: dmabuf,
            record_frames: 0,
            record_width: 0,
            record_height: 0,
        })
    }

    pub fn record(&mut self, width: usize, height: usize, frames: usize) -> Result<usize> {
        // 録画情報クリア
        self.record_width = width;
        self.record_height = height;
        self.record_frames = 0;

        // DMAバッファへ録画
        let buf_size = self.dmabuf.size();
        let max_frames = buf_size / (width * height * 2);
        let frames = core::cmp::min(frames, max_frames);
        self.vdmaw.oneshot(
            self.dmabuf.phys_addr(),
            width as i32,
            height as i32,
            frames as i32,
            0,
            0,
            0,
            0,
            Some(1000000 * frames),
        )?;

        // 成功したら録画情報を更新
        self.record_frames = frames;

        Ok(frames)
    }

    #[cfg(feature = "opencv")]
    pub fn read_image_mat(&mut self, index : usize) -> Result<Mat> {
        // 範囲チェック
        if index >= self.record_frames {
            return Err("index out of range".into());
        }

        // 読み出し
        let width = self.record_width;
        let height = self.record_height;
        let pixels = width * height;
        unsafe {
            let mut img = Mat::new_rows_cols(height as i32, width as i32, CV_16UC1)?;
            debug_assert!(img.is_continuous());
            let buf: &mut [u16] = img.data_typed_mut::<u16>()?;
            let offset = index * pixels * 2;
            self.dmabuf.copy_to_u16(offset, buf.as_mut_ptr(), pixels);
            Ok(img)
        }
    }

    pub fn read_image_vec(&mut self, index : usize) -> Result<Vec::<u8>> {
        let size = self.record_width * self.record_height * 2;
        let mut buf = vec![0u8; size as usize];
        let offset = index * size;
        unsafe {
            self.dmabuf.copy_to_u8(offset, buf.as_mut_ptr(), size);
        }
        Ok(buf)
    }

    pub fn record_frames(&self) -> usize {
        self.record_frames
    }
    pub fn record_width(&self) -> usize {
        self.record_width
    }
    pub fn record_height(&self) -> usize {
        self.record_height
    }
}


