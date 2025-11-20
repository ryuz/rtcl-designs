#include <memory>
#include <verilated.h>
//#include <opencv2/opencv.hpp>
#include "Vtb_main.h"
#include "jelly/simulator/Manager.h"
#include "jelly/simulator/ResetNode.h"
#include "jelly/simulator/ClockNode.h"
#include "jelly/simulator/VerilatorNode.h"
#include "jelly/simulator/Axi4LiteMasterNode.h"
//#include "jelly/simulator/Axi4sImageLoadNode.h"
//#include "jelly/simulator/Axi4sImageDumpNode.h"
#include "jelly/JellyRegs.h"


namespace jsim = jelly::simulator;


#if VM_TRACE
#include <verilated_fst_c.h> 
#include <verilated_vcd_c.h> 
#endif


int main(int argc, char** argv)
{
    auto contextp = std::make_shared<VerilatedContext>();
    contextp->debug(0);
    contextp->randReset(2);
    contextp->commandArgs(argc, argv);
    
    const auto top = std::make_shared<Vtb_main>(contextp.get(), "top");


    jsim::trace_ptr_t tfp = nullptr;
#if VM_TRACE
    contextp->traceEverOn(true);

    tfp = std::make_shared<jsim::trace_t>();
    top->trace(tfp.get(), 100);
    tfp->open("tb_verilator" TRACE_EXT);
#endif

    auto mng = jsim::Manager::Create();

    mng->AddNode(jsim::VerilatorNode_Create(top, tfp));

    mng->AddNode(jsim::ResetNode_Create(&top->reset, 100));
    mng->AddNode(jsim::ClockNode_Create(&top->clk100, 1000.0/100.0));
    mng->AddNode(jsim::ClockNode_Create(&top->clk200, 1000.0/200.0));
    mng->AddNode(jsim::ClockNode_Create(&top->clk250, 1000.0/250.0));

    jsim::Axi4Lite axi4lite_signals =
            {
                &top->s_axi4l_aresetn   ,
                &top->s_axi4l_aclk      ,
                &top->s_axi4l_awaddr    ,
                &top->s_axi4l_awprot    ,
                &top->s_axi4l_awvalid   ,
                &top->s_axi4l_awready   ,
                &top->s_axi4l_wdata     ,
                &top->s_axi4l_wstrb     ,
                &top->s_axi4l_wvalid    ,
                &top->s_axi4l_wready    ,
                &top->s_axi4l_bresp     ,
                &top->s_axi4l_bvalid    ,
                &top->s_axi4l_bready    ,
                &top->s_axi4l_araddr    ,
                &top->s_axi4l_arprot    ,
                &top->s_axi4l_arvalid   ,
                &top->s_axi4l_arready   ,
                &top->s_axi4l_rdata     ,
                &top->s_axi4l_rresp     ,
                &top->s_axi4l_rvalid    ,
                &top->s_axi4l_rready    ,
            };
    auto axi4l = jsim::Axi4LiteMasterNode_Create(axi4lite_signals);
    mng->AddNode(axi4l);

    // シミュレーションを進めて値を確定させてから取り出す
    mng->Run(1);
    const int X_NUM = top->img_x_num;
    const int Y_NUM = top->img_y_num;
    std::cout << "X_NUM = " << X_NUM << std::endl;
    std::cout << "Y_NUM = " << Y_NUM << std::endl;

    const int reg_gid    = (0x00000000 >> 3);
    const int reg_fmtr   = (0x00100000 >> 3);
    const int reg_demos  = (0x00120000 >> 3);
    const int reg_colmat = (0x00120800 >> 3);
    const int reg_wdma   = (0x00210000 >> 3);
    const int reg_bin    = (0x00300000 >> 3);
        
    axi4l->Wait(1000);
    axi4l->Display("start");

    axi4l->Wait(1000);
    axi4l->Display("read core ID");
    axi4l->ExecRead (reg_gid);     // gid
    axi4l->ExecRead (reg_fmtr);    // fmtr
    axi4l->ExecRead (reg_demos);   // demosaic
    axi4l->ExecRead (reg_colmat);  // col mat
    axi4l->ExecRead (reg_wdma);    // wdma

    axi4l->Display("set format regularizer");
    axi4l->ExecRead (reg_fmtr + REG_VIDEO_FMTREG_CORE_ID);                         // CORE ID
    axi4l->ExecWrite(reg_fmtr + REG_VIDEO_FMTREG_PARAM_WIDTH,      X_NUM, 0xf);    // width
    axi4l->ExecWrite(reg_fmtr + REG_VIDEO_FMTREG_PARAM_HEIGHT,     Y_NUM, 0xf);    // height
//  axi4l->ExecWrite(reg_fmtr + REG_VIDEO_FMTREG_PARAM_FILL,           0, 0xf);    // fill
//  axi4l->ExecWrite(reg_fmtr + REG_VIDEO_FMTREG_PARAM_TIMEOUT,     1024, 0xf);    // timeout
    axi4l->ExecWrite(reg_fmtr + REG_VIDEO_FMTREG_CTL_CONTROL,          3, 0xf);    // enable
    axi4l->ExecWait(1000);

    axi4l->Display("set DEMOSIC");
    axi4l->ExecRead (reg_demos + REG_IMG_DEMOSAIC_CORE_ID);
    axi4l->ExecWrite(reg_demos + REG_IMG_DEMOSAIC_PARAM_PHASE,    0x0, 0xf);
    axi4l->ExecWrite(reg_demos + REG_IMG_DEMOSAIC_CTL_CONTROL,    0x3, 0xf);

    axi4l->Display("set colmat");
    axi4l->ExecRead (reg_colmat + REG_IMG_COLMAT_CORE_ID);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX00, 0x00010000, 0xf); // 0x0003a83a
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX01, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX02, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX03, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX10, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX11, 0x00010000, 0xf); // 0x00030c30
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX12, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX13, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX20, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX21, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX22, 0x00010000, 0xf); // 0x000456c7
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_PARAM_MATRIX23, 0x00000000, 0xf);
    axi4l->ExecWrite(reg_colmat + REG_IMG_COLMAT_CTL_CONTROL, 3, 0xf);

#define REG_BIN_PARAM_END           0x04
#define REG_BIN_PARAM_INV           0x05
#define REG_BIN_TBL(x)              (0x40 +(x))

    axi4l->ExecWrite(reg_bin + REG_BIN_PARAM_END, 3, 0xf);
    axi4l->ExecWrite(reg_bin + REG_BIN_TBL(0), 0x10, 0xf);
    axi4l->ExecWrite(reg_bin + REG_BIN_TBL(1), 0x20, 0xf);
    axi4l->ExecWrite(reg_bin + REG_BIN_TBL(2), 0x30, 0xf);


    axi4l->ExecWait(10000);
    axi4l->Display("set write DMA");
    axi4l->ExecRead (reg_wdma + REG_VDMA_WRITE_CORE_ID);                               // CORE ID
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_PARAM_ADDR,          0x00000000, 0xf);  // address
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_PARAM_LINE_STEP,        X_NUM*4, 0xf);  // stride
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_PARAM_H_SIZE,           X_NUM-1, 0xf);  // width
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_PARAM_V_SIZE,           Y_NUM-1, 0xf);  // height
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_PARAM_F_SIZE,               1-1, 0xf);
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_PARAM_FRAME_STEP, X_NUM*Y_NUM*4, 0xff);
//  axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_CTL_CONTROL,                  3, 0xf);  // update & enable
    axi4l->ExecWrite(reg_wdma + REG_VDMA_WRITE_CTL_CONTROL,                  7, 0xf);  // update & enable & oneshot
    axi4l->ExecWait(1000);

    axi4l->Display("wait for DMA end");
//    wb->SetVerbose(false);
    while ( axi4l->ExecRead (reg_wdma + REG_VDMA_WRITE_CTL_STATUS) != 0 ) {
//      wb->ExecWait(10000);
        mng->Run(100000);
    }
    axi4l->Display("DMA end");

    mng->Run(10000);
    
//    mng->Run(1000000);
//    mng->Run();

#if VM_TRACE
    tfp->close();
#endif

#if VM_COVERAGE
    contextp->coveragep()->write("coverage.dat");
#endif

    return 0;
}


// end of file
