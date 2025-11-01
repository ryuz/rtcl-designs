fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_prost_build::compile_protos("protos/rtcl_p3s7_control.proto")?;
    Ok(())
}
