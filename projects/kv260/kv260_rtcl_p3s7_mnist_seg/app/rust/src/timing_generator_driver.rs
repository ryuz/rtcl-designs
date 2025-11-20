#![allow(dead_code)]

const TIMGENREG_CORE_ID: usize = 0x0000;
const TIMGENREG_CORE_VERSION: usize = 0x0001;
const TIMGENREG_CTL_CONTROL: usize = 0x0004;
const TIMGENREG_CTL_STATUS: usize = 0x0005;
const TIMGENREG_CTL_TIMER: usize = 0x0008;
const TIMGENREG_PARAM_PERIOD: usize = 0x0010;
const TIMGENREG_PARAM_TRIG0_START: usize = 0x0020;
const TIMGENREG_PARAM_TRIG0_END: usize = 0x0021;
const TIMGENREG_PARAM_TRIG0_POL: usize = 0x0022;

use jelly_mem_access::*;

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

pub struct TimingGeneratorDriver<T: MemAccess>
{
    reg_timgen: T,
}

impl<T: MemAccess> TimingGeneratorDriver<T>
{
    pub fn new(reg_timgen: T) -> Self {
        Self {
            reg_timgen: reg_timgen,
        }
    }

    pub fn set_timing(&mut self, period_us: f32, exposure_us: f32) -> Result<()> {
        let period_us   = period_us.max(1000.0);
        let exposure_us = exposure_us.clamp(100.0, period_us-100.0);

        let us_unit = 0.01; // 100MHz(10ns)
        let timgen_period : usize = (period_us / us_unit) as usize;
        let trig0_start   : usize = 1;
        let trig0_end     : usize = ((exposure_us / us_unit) as usize).max(1);
        unsafe {
            self.reg_timgen.write_reg(TIMGENREG_PARAM_PERIOD,      timgen_period);
            self.reg_timgen.write_reg(TIMGENREG_PARAM_TRIG0_START, trig0_start);
            self.reg_timgen.write_reg(TIMGENREG_PARAM_TRIG0_END,   trig0_end);
            self.reg_timgen.write_reg(TIMGENREG_CTL_CONTROL,       0x03);
        }

        Ok(())
    }

}


