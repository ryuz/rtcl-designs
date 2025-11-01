
use tonic::{transport::Server, Request, Response, Status};
use std::sync::{Arc, Mutex};

use rtcl_p3s7_control::rtcl_p3s7_control_server::{RtclP3s7Control, RtclP3s7ControlServer};
//use rtcl_p3s7_control::{WriteRegRequest, BoolResponse, ReadRegRequest, ReadRegResponse};
use rtcl_p3s7_control::*;

//mod rtcl_p3s7_i2c;
mod rtcl_p3s7_mng;
use rtcl_p3s7_mng::RtclP3s7Mng;

pub mod rtcl_p3s7_control {
    tonic::include_proto!("rtcl_p3s7_control"); // The string specified here must match the proto package name
}

// #[derive(Debug, Default)]

pub struct RtclP3s7ControlService {
    verbose: i32,
    mng : Arc<Mutex<RtclP3s7Mng>>,
}


#[tonic::async_trait]
impl RtclP3s7Control for RtclP3s7ControlService {
    async fn get_version(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<VersionResponse>, Status> {
        if self.verbose >= 1 {
            println!("get_version");
        }
        Ok(Response::new(VersionResponse {
            version: env!("CARGO_PKG_VERSION").to_string(),
        }))
    }

    async fn camera_open(&self, request: Request<Empty>) -> Result<Response<BoolResponse>, Status> {
        let _req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.cam_mut().open() {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_open()");
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_open failed for addr: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_close(&self, request: Request<Empty>) -> Result<Response<BoolResponse>, Status> {
        let _req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.cam_mut().close() {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_close()");
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_close failed for addr: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_is_opened(&self, _request: Request<Empty>) -> Result<Response<BoolResponse>, Status> {
        let mng = self.mng.lock().unwrap();
        let result = mng.camera_is_opened();
        if self.verbose >= 1 {
            println!("camera_is_opened() => {}", result);
        }
        Ok(Response::new(BoolResponse { result }))
    }

    async fn camera_get_module_id(&self, _request: Request<Empty>) -> Result<Response<U16Response>, Status> {
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_get_module_id() {
            Ok(value) => {
                if self.verbose >= 1 {
                    println!("camera_get_module_id() => {}", value);
                }
                Ok(Response::new(U16Response { result: true, value: value as u32 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_get_module_id failed: {}", e);
                }
                Ok(Response::new(U16Response { result: false, value: 0 }))
            }
        }
    }

    async fn camera_get_module_version(&self, _request: Request<Empty>) -> Result<Response<U16Response>, Status> {
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_get_module_version() {
            Ok(value) => {
                if self.verbose >= 1 {
                    println!("camera_get_module_version() => {}", value);
                }
                Ok(Response::new(U16Response { result: true, value: value as u32 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_get_module_version failed: {}", e);
                }
                Ok(Response::new(U16Response { result: false, value: 0 }))
            }
        }
    }

    async fn camera_get_sensor_id(&self, _request: Request<Empty>) -> Result<Response<U16Response>, Status> {
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_get_sensor_id() {
            Ok(value) => {
                if self.verbose >= 1 {
                    println!("camera_get_sensor_id() => {}", value);
                }
                Ok(Response::new(U16Response { result: true, value: value as u32 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_get_sensor_id failed: {}", e);
                }
                Ok(Response::new(U16Response { result: false, value: 0 }))
            }
        }
    }

    async fn camera_set_slave_mode(&self, request: Request<BoolRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_set_slave_mode(req.value) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_set_slave_mode({})", req.value);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_set_slave_mode failed: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_set_trigger_mode(&self, request: Request<BoolRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_set_trigger_mode(req.value) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_set_trigger_mode({})", req.value);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_set_trigger_mode failed: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_set_image_size(&self, request: Request<ImageSizeRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_set_image_size(req.width as usize, req.height as usize) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_set_image_size({}, {})", req.width, req.height);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_set_image_size failed: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_get_image_width(&self, _request: Request<Empty>) -> Result<Response<U64Response>, Status> {
        let mng = self.mng.lock().unwrap();
        let value = mng.camera_get_image_width();
        if self.verbose >= 1 {
            println!("camera_get_image_width() => {}", value);
        }
        Ok(Response::new(U64Response { result: true, value: value as u64 }))
    }

    async fn camera_get_image_height(&self, _request: Request<Empty>) -> Result<Response<U64Response>, Status> {
        let mng = self.mng.lock().unwrap();
        let value = mng.camera_get_image_height();
        if self.verbose >= 1 {
            println!("camera_get_image_height() => {}", value);
        }
        Ok(Response::new(U64Response { result: true, value: value as u64 }))
    }

    async fn camera_set_gain(&self, request: Request<F32Request>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_set_gain(req.value) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_set_gain({})", req.value);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_set_gain failed: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_get_gain(&self, _request: Request<Empty>) -> Result<Response<F32Response>, Status> {
        let mng = self.mng.lock().unwrap();
        let value = mng.camera_get_gain();
        if self.verbose >= 1 {
            println!("camera_get_gain() => {}", value);
        }
        Ok(Response::new(F32Response { result: true, value }))
    }

    async fn camera_set_exposure(&self, request: Request<F32Request>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.camera_set_exposure(req.value) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("camera_set_exposure({})", req.value);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_set_exposure failed: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn camera_get_exposure(&self, _request: Request<Empty>) -> Result<Response<F32Response>, Status> {
        let mng = self.mng.lock().unwrap();
        match mng.camera_get_exposure() {
            Ok(value) => {
                if self.verbose >= 1 {
                    println!("camera_get_exposure() => {}", value);
                }
                Ok(Response::new(F32Response { result: true, value }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("camera_get_exposure failed: {}", e);
                }
                Ok(Response::new(F32Response { result: false, value: 0.0 }))
            }
        }
    }

    async fn camera_measure_fps(&self, _request: Request<Empty>) -> Result<Response<F32Response>, Status> {
        let mng = self.mng.lock().unwrap();
        let value = mng.camera_measure_fps();
        if self.verbose >= 1 {
            println!("camera_measure_fps() => {}", value);
        }
        Ok(Response::new(F32Response { result: true, value }))
    }

    async fn camera_measure_frame_period(&self, _request: Request<Empty>) -> Result<Response<F32Response>, Status> {
        let mng = self.mng.lock().unwrap();
        let value = mng.camera_measure_frame_period();
        if self.verbose >= 1 {
            println!("camera_measure_frame_period() => {}", value);
        }
        Ok(Response::new(F32Response { result: true, value }))
    }


    // --- Capture ---

    async fn record_image(&self, request: Request<RecordImageRequest>) -> Result<Response<U64Response>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.record_image(req.width as usize, req.height as usize, req.frames as usize) {
            Ok(frames) => {
                if self.verbose >= 1 {
                    println!("record_image: width={} height={} frames={}", req.width, req.height, req.frames);
                }
                Ok(Response::new(U64Response { result: true, value: frames as u64 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("record_image failed: {}", e);
                }
                Ok(Response::new(U64Response { result: false, value: 0 }))
            }
        }
    }

    async fn read_image(&self, request: Request<ReadImageRequest>) -> Result<Response<ReadImageResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.read_image(req.index as usize) {
            Ok(buf) => {
                if self.verbose >= 1 {
                    println!("read_image: index={}", req.index);
                }
                Ok(Response::new(ReadImageResponse { result: true, image: buf }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("read_image failed: {}", e);
                }
                // On error return empty data
                Ok(Response::new(ReadImageResponse { result: false, image: vec![] }))
            }
        }
    }

    async fn record_black(&self, request: Request<RecordImageRequest>) -> Result<Response<U64Response>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.record_black(req.width as usize, req.height as usize, req.frames as usize) {
            Ok(frames) => {
                if self.verbose >= 1 {
                    println!("record_black: width={} height={} frames={}", req.width, req.height, req.frames);
                }
                Ok(Response::new(U64Response { result: true, value: frames as u64 }) )
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("record_black failed: {}", e);
                }
                Ok(Response::new(U64Response { result: false, value: 0 }) )
            }
        }
    }

    async fn read_black(&self, request: Request<ReadImageRequest>) -> Result<Response<ReadImageResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.read_black(req.index as usize) {
            Ok(buf) => {
                if self.verbose >= 1 {
                    println!("read_black: index={}", req.index);
                }
                Ok(Response::new(ReadImageResponse { result: true, image: buf }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("read_black failed: {}", e);
                }
                // On error return empty data
                Ok(Response::new(ReadImageResponse { result: false, image: vec![] }))
            }
        }
    }


    // --- Timing Generator ---

    async fn set_timing_generator(&self, request: Request<SetTimingGeneratorRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.set_timing_generator(req.period_us, req.exposure_us) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("set_timing_generator: period_us={} exposure_us={}", req.period_us, req.exposure_us);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("set_timing_generator failed: {}", e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }


    // --- Primitive ---

    async fn write_sys_reg(&self, request: Request<WriteRegRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.write_sys_reg(req.addr as usize, req.data as usize) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("write_sys_reg: addr={} data={}", req.addr, req.data);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("write_sys_reg failed for addr {}: {}", req.addr, e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn read_sys_reg(&self, request: Request<ReadRegRequest>) -> Result<Response<ReadRegResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.read_sys_reg(req.addr as usize) {
            Ok(data) => {
                if self.verbose >= 1 {
                    println!("read_sys_reg: addr={}", req.addr);
                }
                Ok(Response::new(ReadRegResponse { result: true, data: data as u64 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("read_sys_reg failed for addr {}: {}", req.addr, e);
                }
                // On error return result=false and zero data
                Ok(Response::new(ReadRegResponse { result: false, data: 0 }))
            }
        }
    }


    async fn write_cam_reg(&self, request: Request<WriteRegRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.write_cam_reg(req.addr as u16, req.data as u16) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("write_cam_reg: addr={} data={}", req.addr, req.data);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("write_cam_reg failed for addr {}: {}", req.addr, e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn read_cam_reg(&self, request: Request<ReadRegRequest>) -> Result<Response<ReadRegResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.read_cam_reg(req.addr as u16) {
            Ok(data) => {
                if self.verbose >= 1 {
                    println!("read_cam_reg: addr={}", req.addr);
                }
                Ok(Response::new(ReadRegResponse { result: true, data: data as u64 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("read_cam_reg failed for addr {}: {}", req.addr, e);
                }
                // On error return result=false and zero data
                Ok(Response::new(ReadRegResponse { result: false, data: 0 }))
            }
        }
    }

    async fn write_sensor_reg(&self, request: Request<WriteRegRequest>) -> Result<Response<BoolResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.write_sensor_reg(req.addr as u16, req.data as u16) {
            Ok(()) => {
                if self.verbose >= 1 {
                    println!("write_sensor_reg: addr={} data={}", req.addr, req.data);
                }
                Ok(Response::new(BoolResponse { result: true }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("write_sensor_reg failed for addr {}: {}", req.addr, e);
                }
                Ok(Response::new(BoolResponse { result: false }))
            }
        }
    }

    async fn read_sensor_reg(&self, request: Request<ReadRegRequest>) -> Result<Response<ReadRegResponse>, Status> {
        let req = request.into_inner();
        let mut mng = self.mng.lock().unwrap();
        match mng.read_sensor_reg(req.addr as u16) {
            Ok(data) => {
                if self.verbose >= 1 {
                    println!("read_sensor_reg: addr={} data=>{}", req.addr, data);
                }
                Ok(Response::new(ReadRegResponse { result: true, data: data as u64 }))
            }
            Err(e) => {
                if self.verbose >= 1 {
                    eprintln!("read_sensor_reg failed for addr {}: {}", req.addr, e);
                }
                // On error return result=false and zero data
                Ok(Response::new(ReadRegResponse { result: false, data: 0 }))
            }
        }
    }

}


#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let address = "0.0.0.0:50051".parse().unwrap();

    println!("Starting RTCL P3S7 Control gRPC server...");
    println!("address : {}", address);
    let mng = Arc::new(Mutex::new(RtclP3s7Mng::new()?));

    let rtcl_p3s7_control_service = RtclP3s7ControlService{
        verbose: 0,
        mng: mng,
    };

    Server::builder()
        .add_service(RtclP3s7ControlServer::new(rtcl_p3s7_control_service))
        .serve(address)
        .await?;

    Ok(())
}

