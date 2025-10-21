
use jelly_mem_access::*;


use opencv::{
    core::*,
    highgui::*,
};

fn main() {
    println!("start zybo_z7_rtcl_p3s7_hs");

    /*
    let img : Mat = Mat::zeros(480, 640, opencv::core::CV_8UC3).unwrap().to_mat().unwrap();
    println!("img = {:?}", img);
    imshow("test", &img).unwrap();
    wait_key(0).unwrap();
    */


    // mmap udmabuf
    let udmabuf_device_name = "udmabuf-jelly-vram0";
    println!("\nudmabuf open");
    let udmabuf_acc =
        UdmabufAccessor::<usize>::new(udmabuf_device_name, false).expect("Failed to open udmabuf");
    println!(
        "{} phys addr : 0x{:x}",
        udmabuf_device_name,
        udmabuf_acc.phys_addr()
    );
    println!(
        "{} size      : 0x{:x}",
        udmabuf_device_name,
        udmabuf_acc.size()
    );

}
