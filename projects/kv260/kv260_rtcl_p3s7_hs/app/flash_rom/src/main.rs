
use std::error::Error;
use std::io::Write;
use clap::Parser;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
use rtcl_lib::rtcl_p3s7_module_driver::*;
//use kv260_rtcl_p3s7_hs::camera_driver::CameraDriver;


#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    #[arg(short = 'r', long = "read", requires = "output_file")]
    read: bool,

    #[arg(short = 'w', long, group = "use_input_file")]
    write: bool,

    #[arg(short = 'v', long, group = "use_input_file")]
    verify: bool,

    #[arg(short = 'a', long, default_value_t = 0x100000)]
    address: usize,

    #[arg(short = 's', long, default_value_t = 0x100000)]
    size: usize,

    #[arg(short = 'o', long)]
    output_file: Option<String>,

    #[arg(value_name = "INPUT_FILE")]
    input_file: Option<String>,
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("RTCL-P3S7-MIPI camera flash rom util");

    let args = Args::parse();
    println!("input_file : {:?}", args.input_file);
    println!("write : {}", args.write);
    println!("read  : {:?}", args.read);

    // カメラ初期化
    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;
    let mut cam = RtclP3s7ModuleDriver::new(i2c);

    let uio_acc = UioAccessor::<usize>::new_with_name("uio_pl_peri").expect("Failed to open uio");
    unsafe { uio_acc.write_reg(0x0002, 1); } // モジュールリセットOFF

    //  let reg_sys = uio_acc.subclone(0x00000000, 0x400);
//  let reg_fmtr = uio_acc.subclone(0x00100000, 0x400);
//  let mut cam = CameraDriver::new(i2c, reg_sys, reg_fmtr);

    // ステータス表示
    println!("module id      : {:04x}", cam.module_id()?);
    println!("module version : {:04x}", cam.module_version()?);
    let rom_id = cam.spi_rom_id()?;
    println!("rom id         : {:02x} {:02x} {:02x}", rom_id[0], rom_id[1], rom_id[2]);

//  let chunk = cam.spi_rom_read(args.address + offset, len)?;

//  cam.spi_rom_erase_region(0x100000, 4096)?;

    {
        println!("status : {:02x}", cam.spi_rom_read_status_register()?);

        let addr = 0x000000;
        let mut chunk = [0u8; 256];
        cam.spi_rom_read(addr, &mut chunk)?;
        for (i, &d) in chunk.iter().enumerate() {
            if i % 16 == 0 {
                print!("\n{:06x} :", addr + i);
            }
            print!(" {:02x}", d);
        }
        println!();

        let addr = 0x100000;
        cam.spi_rom_read(addr, &mut chunk)?;
        for (i, &d) in chunk.iter().enumerate() {
            if i % 16 == 0 {
                print!("\n{:06x} :", addr + i);
            }
            print!(" {:02x}", d);
        }
        println!();
//      return Ok(());
    }

    if args.read {
        const CHUNK_SIZE: usize = 4 * 1024;
        let mut remaining = args.size;
        let mut offset = 0usize;

        let output_file = args.output_file.unwrap(); // ここに到達する時点で必ず Some
        let mut file = std::fs::File::create(output_file)?;
        while remaining > 0 {
            let len = remaining.min(CHUNK_SIZE);
            let mut chunk = [0u8; CHUNK_SIZE];
            cam.spi_rom_read(args.address + offset, &mut chunk[0..len])?;
            std::io::Write::write_all(&mut file, &chunk[0..len])?;
            offset += len;
            remaining -= len;
            let pct = (offset * 100) / args.size;
            print!("\rRead {}/{} bytes ({}%)  ", offset, args.size, pct);
            std::io::stdout().flush()?;
        }
        println!("\nFlash ROM data saved to file");
        return Ok(());
    }

    // ROM書き込み
    let input_file = args.input_file.as_ref().ok_or("Input file is required for write/verify operations")?;
    let input_data = std::fs::read(input_file)?;
    if args.write {
        print!("Erasing flash ROM...");
        std::io::stdout().flush()?;
        cam.spi_rom_erase_region(args.address, input_data.len())?;
        println!("  done");

        println!("Writing flash ROM...");
        const CHUNK: usize = 4 * 1024;
        let mut remaining = input_data.len();
        let mut offset = 0usize;
        while remaining > 0 {
            let len = remaining.min(CHUNK);
            cam.spi_rom_program(args.address + offset, &input_data[offset..offset + len])?;
            offset += len;
            remaining -= len;
            let pct = (offset * 100) / input_data.len();
            print!("\rWrite {}/{} bytes ({}%)  ", offset, input_data.len(), pct);
            std::io::stdout().flush()?;
        }
        println!("\nFlash ROM write completed.");
    }

    if args.verify {
        println!("Verifying flash ROM...");
        const CHUNK_SIZE: usize = 4 * 1024;
        let mut remaining = input_data.len();
        let mut offset = 0usize;
        while remaining > 0 {
            let len = remaining.min(CHUNK_SIZE);
            let mut chunk = [0u8; CHUNK_SIZE];
            cam.spi_rom_read(args.address + offset, &mut chunk[0..len])?;
            if chunk[0..len] != input_data[offset..offset + len] {
                return Err(format!("Verification failed at offset 0x{:x}", args.address + offset).into());
            }
            offset += len;
            remaining -= len;
            let pct = (offset * 100) / input_data.len();
            print!("\rVerify {}/{} bytes ({}%)  ", offset, input_data.len(), pct);
            std::io::stdout().flush()?;
        }
        println!("\nFlash ROM verification succeeded.");
    }

    Ok(())
}
