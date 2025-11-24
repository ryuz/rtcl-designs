
use std::error::Error;
use std::io::Write;
use clap::Parser;
use jelly_lib::linux_i2c::LinuxI2c;
use jelly_mem_access::*;
use rtcl_lib::rtcl_p3s7_module_driver::*;
//use kv260_rtcl_p3s7_hs::camera_driver::CameraDriver;

fn parse_number(s: &str) -> Result<usize, std::num::ParseIntError> {
    if let Some(hex) = s.strip_prefix("0x").or_else(|| s.strip_prefix("0X")) {
        usize::from_str_radix(hex, 16)
    } else {
        s.parse::<usize>()
    }
}


#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    #[arg(short = 'r', long, requires = "output_file")]
    read: bool,

    #[arg(short = 'w', long, requires = "input_file")]
    write: bool,

    #[arg(short = 'v', long, requires = "input_file")]
    verify: bool,

    #[arg(short = 'e', long = "erase")]
    erase: bool,

    #[arg(short = 'a', long, default_value_t = 0x100000, value_parser = parse_number)]
    address: usize,

    #[arg(short = 's', long, default_value_t = 0x0f0000, value_parser = parse_number)]
    size: usize,

    #[arg(short = 'd', long, value_parser = parse_number)]
    display: Option<usize>,

    #[arg(short = 'o', long, value_name = "OUTPUT_FILE")]
    output: Option<String>,

    #[arg(value_name = "INPUT_FILE")]
    input: Option<String>,
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("RTCL-P3S7-MIPI camera flash rom util");

    let args = Args::parse();

    // カメラ初期化
    let i2c = LinuxI2c::new("/dev/i2c-6", 0x10)?;
    let mut cam = RtclP3s7ModuleDriver::new(i2c);

    let uio_acc = UioAccessor::<usize>::new_with_name("uio_pl_peri").expect("Failed to open uio");
    unsafe { uio_acc.write_reg(0x0002, 1); }

    // ステータス表示
    println!("module id      : {:04x}", cam.module_id()?);
    println!("module version : {:04x}", cam.module_version()?);
    println!("module config  : {:04x}", cam.module_config()?);
    let rom_id = cam.spi_rom_id()?;
    println!("rom id         : {:02x} {:02x} {:02x}", rom_id[0], rom_id[1], rom_id[2]);

    if let Some(addr) = args.display {
        let mut chunk = [0u8; 256];
        cam.spi_rom_read(addr, &mut chunk)?;
        for (i, &d) in chunk.iter().enumerate() {
            if i % 16 == 0 {
                print!("\n{:06x} :", addr + i);
            }
            print!(" {:02x}", d);
        }
        println!();
    }

    if false {
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

    // ROM読み出し
    if args.read {
        const CHUNK_SIZE: usize = 4 * 1024;
        let mut remaining = args.size;
        let mut offset = 0usize;

        let output_file = args.output.unwrap(); // ここに到達する時点で必ず Some
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

    // 入力ファイルがあれば読み込み
    let input_data = if let Some(input_file) = args.input.as_ref() {
        std::fs::read(input_file)?
    } else {
        Vec::new()
    };
    let region_size = if input_data.len() > 0 { input_data.len() } else { args.size };

    // addrss が 0x100000 未満の場合、ゴールデンイメージの上書きになるが問題ないか確認
    if args.write || args.erase {
        if args.address < 0x100000 || (args.address + region_size) > 0x1ff000 {
            println!("Warning: this will overwrite the golden image. Continue? (y/N): ");
            std::io::stdout().flush()?;
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;
            if input.trim().to_lowercase() != "y" {
                return Ok(());
            }
        }
    }

    // ROM消去
    if args.erase {
        print!("Erasing flash ROM...");
        std::io::stdout().flush()?;
        cam.spi_rom_erase_region(args.address, region_size)?;
        println!("  done");
    }

    // ROM書き込み
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

    // ROM検証
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
