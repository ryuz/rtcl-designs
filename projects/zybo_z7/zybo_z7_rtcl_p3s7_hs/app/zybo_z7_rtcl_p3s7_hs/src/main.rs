use opencv::{
    core::*,
    highgui::*,
};

fn main() {
    println!("Hello, world!");
    let img : Mat = Mat::zeros(480, 640, opencv::core::CV_8UC3).unwrap().to_mat().unwrap();
    println!("img = {:?}", img);
    imshow("test", &img).unwrap();
    wait_key(0).unwrap();
}
