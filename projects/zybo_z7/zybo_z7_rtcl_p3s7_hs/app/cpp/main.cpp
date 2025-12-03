#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <iostream>
#include <opencv2/opencv.hpp>
#include "jelly/UioAccessor.h"
#include "jelly/UdmabufAccessor.h"
#include "jelly/JellyRegs.h"
#include "jelly/I2cAccessor.h"
#include "jelly/GpioAccessor.h"
#include "jelly/VideoDmaControl.h"
#include "rtcl/RtclP3S7Control.h"

#define SYSREG_ID                   0x0000
#define SYSREG_DPHY_SW_RESET        0x0001
#define SYSREG_CAM_ENABLE           0x0002
#define SYSREG_CSI_DATA_TYPE        0x0003
#define SYSREG_DPHY_INIT_DONE       0x0004
#define SYSREG_FPS_COUNT            0x0006
#define SYSREG_FRAME_COUNT          0x0007
#define SYSREG_IMAGE_WIDTH          0x0008
#define SYSREG_IMAGE_HEIGHT         0x0009
#define SYSREG_BLACK_WIDTH          0x000a
#define SYSREG_BLACK_HEIGHT         0x000b

#define TIMGENREG_CORE_ID           0x00
#define TIMGENREG_CORE_VERSION      0x01
#define TIMGENREG_CTL_CONTROL       0x04
#define TIMGENREG_CTL_STATUS        0x05
#define TIMGENREG_CTL_TIMER         0x08
#define TIMGENREG_PARAM_PERIOD      0x10
#define TIMGENREG_PARAM_TRIG0_START 0x20
#define TIMGENREG_PARAM_TRIG0_END   0x21
#define TIMGENREG_PARAM_TRIG0_POL   0x22

void          sensor_reg_dump(rtcl::RtclP3S7ControlI2c  &cam, const char *fname);
void          load_setting(rtcl::RtclP3S7ControlI2c  &cam);


static  volatile    bool    g_signal = false;
void signal_handler(int signo) {
    g_signal = true;
}


// メイン関数
int main(int argc, char *argv[])
{
    int width  = 640 ;
    int height = 480 ;
    int fps    = 200 ;
    int exposure = 90;  // 90%
    int gain     = 0;   // 0.0 db
    bool color = false;

    for ( int i = 1; i < argc; ++i ) {
        if ( (strcmp(argv[i], "-W") == 0 || strcmp(argv[i], "--width") == 0) && i+1 < argc) {
            ++i;
            width = strtol(argv[i], nullptr, 0);
        }
        else if ( (strcmp(argv[i], "-H") == 0 || strcmp(argv[i], "--height") == 0) && i+1 < argc) {
            ++i;
            height = strtol(argv[i], nullptr, 0);
        }
        else if ( (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--fps") == 0) && i+1 < argc) {
            ++i;
            fps = strtol(argv[i], nullptr, 0);
        }
        else if ( strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--color") == 0 ) {
            color = true;
        }
        else {
            std::cout << "unknown option : " << argv[i] << std::endl;
            return 1;
        }
    }

    width &= ~0xf;
    width  = std::max(width, 16);
    height = std::max(height, 1);

    // set signal
    signal(SIGINT, signal_handler);

    // mmap uio
    jelly::UioAccessor uio_acc("uio_pl_peri", 0x08000000);
    if ( !uio_acc.IsMapped() ) {
        std::cout << "uio_pl_peri mmap error" << std::endl;
        return 1;
    }

    auto reg_sys    = uio_acc.GetAccessor(0x00000000);
    auto reg_timgen = uio_acc.GetAccessor(0x00010000);
    auto reg_fmtr   = uio_acc.GetAccessor(0x00100000);
    auto reg_wdma0  = uio_acc.GetAccessor(0x00210000);
    auto reg_wdma1  = uio_acc.GetAccessor(0x00220000);
    
    // レジスタ確認
    std::cout << "CORE ID" << std::endl;
    std::cout << std::hex << reg_sys.ReadReg(SYSREG_ID) << std::endl;
    std::cout << std::hex << reg_timgen.ReadReg(TIMGENREG_CORE_ID) << std::endl;
    std::cout << std::hex << reg_fmtr.ReadReg(0) << std::endl;
    std::cout << std::hex << reg_wdma0.ReadReg(0) << std::endl;
    std::cout << std::hex << reg_wdma1.ReadReg(0) << std::endl;

    // mmap udmabuf0
    jelly::UdmabufAccessor udmabuf0_acc("udmabuf-jelly-vram0");
    if ( !udmabuf0_acc.IsMapped() ) {
        std::cout << "udmabuf0 mmap error" << std::endl;
        return 1;
    }
    auto dmabuf0_phys_adr = udmabuf0_acc.GetPhysAddr();
    auto dmabuf0_mem_size = udmabuf0_acc.GetSize();
    std::cout << "udmabuf0 phys addr : 0x" << std::hex << dmabuf0_phys_adr << std::endl;
    std::cout << "udmabuf0 size      : " << std::dec << dmabuf0_mem_size << std::endl;

    int rec_frames = dmabuf0_mem_size / (width * height * 2);
    std::cout << "udmabuf0 rec_frames : " << rec_frames << std::endl;

    // mmap udmabuf1
    jelly::UdmabufAccessor udmabuf1_acc("udmabuf-jelly-vram1");
    if ( !udmabuf1_acc.IsMapped() ) {
        std::cout << "udmabuf mmap error" << std::endl;
        return 1;
    }
    auto dmabuf1_phys_adr = udmabuf1_acc.GetPhysAddr();
    auto dmabuf1_mem_size = udmabuf1_acc.GetSize();
    std::cout << "udmabuf1 phys addr : 0x" << std::hex << dmabuf1_phys_adr << std::endl;
    std::cout << "udmabuf1 size      : " << std::dec << dmabuf1_mem_size << std::endl;

    rtcl::RtclP3S7ControlI2c cam;
    cam.Open("/dev/i2c-0", 0x10);

    // カメラ基板ID確認
    std::cout << "Camera Module ID      : " << std::hex << cam.GetModuleId() << std::endl;
    std::cout << "Camera Module Version : " << std::hex << cam.GetModuleVersion() << std::endl;

    // カメラモジュールリセット
    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 0);
    usleep(10000);
    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 1);
    usleep(10000);

    // MMCM 設定
    cam.SetDphySpeed(950000000);   // 950Mbps
    
    // 受信側 DPHY リセット
    reg_sys.WriteReg(SYSREG_DPHY_SW_RESET, 1);

    // カメラ基板初期化
    std::cout << "Init Camera" << std::endl;
    cam.SetSensorPowerEnable(false);
    cam.SetDphyReset(true);
    usleep(10000);

    // 受信側 DPHY 解除 (必ずこちらを先に解除)
    reg_sys.WriteReg(SYSREG_DPHY_SW_RESET, 0);
    usleep(10000);

    // 高速モード設定
    cam.SetCameraMode(rtcl::RtclP3S7ControlI2c::MODE_HIGH_SPEED);

    // センサー電源ON
    std::cout << "Sensor Power On" << std::endl;
    cam.SetSensorPowerEnable(true);
    usleep(10000);

    // センサー基板 DPHY-TX リセット解除
    cam.SetDphyReset(false);
    if ( !cam.GetDphyInitDone() ) {
        std::cout << "!!ERROR!! CAM DPHY TX init_done = 0" << std::endl;
        return 1;
    }

    // ここで RX 側も init_done が来る
    auto dphy_rx_init_done = reg_sys.ReadReg(SYSREG_DPHY_INIT_DONE);
    if ( dphy_rx_init_done == 0 ) {
        std::cout << "!!ERROR!! KV260 DPHY RX init_done = 0" << std::endl;
        return 1;
    }

    // センサーID確認
    std::cout << "Sensor ID : " << cam.GetSensorId() << std::endl;


    // 受信画像サイズ設定
    reg_sys.WriteReg(SYSREG_IMAGE_WIDTH,  width);
    reg_sys.WriteReg(SYSREG_IMAGE_HEIGHT, height);
    reg_sys.WriteReg(SYSREG_BLACK_WIDTH,  1280);
    reg_sys.WriteReg(SYSREG_BLACK_HEIGHT, 1);

    // センサー起動
    cam.SetSensorEnable(true);

    // 画像サイズ設定
    cam.SetRoi0(width, height);

    // video input start
    // video input start
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN,  1);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT,   20000000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_WIDTH,       width);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_HEIGHT,      height);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_FILL,        0x000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_TIMEOUT,     1000000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_CONTROL,       0x03);
    usleep(100000);

    // 動作開始
    std::cout << "Start Camera" << std::endl;

    cam.SetMultTimer0(72);
    cam.SetFrLength0(0);
    cam.SetExposure0(10000);


    double mergin = 0.0000001; // 100ns
    double min_line_time = width * (10.0 / (2.0 * 950000000.0));                    // 2lane 10bit 950Mbps
    double sensor_line_time  = (width + 68) *  (10.0 / (4.0 * 720000000.0)) + mergin;   // 4lane 10bit 720Mbps
    std::uint16_t xsm_delay = 0;
    if ( sensor_line_time < min_line_time ) {
        xsm_delay = std::ceil(((min_line_time - sensor_line_time) * 720000000.0) / 4.0);
    }
    cam.SetXsmDelay(xsm_delay);
    cam.SetNzrotXsmDelayEnable(true);


//  cam.SetTriggeredMode(true);
//  cam.SetSlaveMode(true);
    cam.SetSequencerEnable(true);
    usleep(100000);

    cam.SetGainDb(10.0);

    // Video DMA ドライバ生成
    jelly::VideoDmaControl vdmaw0(reg_wdma0, 2, 2, true);
    jelly::VideoDmaControl vdmaw1(reg_wdma1, 2, 2, true);


    cv::namedWindow("img", cv::WINDOW_NORMAL);
    cv::resizeWindow("img", width + 64, height + 128);
    cv::imshow("img", cv::Mat::zeros(height, width, CV_8UC3));
    cv::createTrackbar("gain", "img", nullptr, 100);
    cv::setTrackbarPos("gain", "img", gain);

    cv::createTrackbar("fps", "img", nullptr, 100);
    cv::setTrackbarMin("fps", "img", 5);
    cv::setTrackbarPos("fps", "img", fps);

    cv::createTrackbar("exposure", "img", nullptr, 90);
    cv::setTrackbarMin("exposure", "img", 10);
    cv::setTrackbarPos("exposure", "img", exposure);


    int     key;
    while ( (key = (cv::waitKey(10) & 0xff)) != 0x1b ) {
        if ( g_signal ) { break; }

        gain     = cv::getTrackbarPos("gain", "img");
        fps      = cv::getTrackbarPos("fps", "img");
        exposure = cv::getTrackbarPos("exposure", "img");

        cam.SetGainDb((float)gain / 10.0f);

        int period = 100000000 / fps;   // 100MHz / fps
        int trig_end = period * exposure / 100;
        reg_timgen.WriteReg(TIMGENREG_PARAM_PERIOD,      period-1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_TRIG0_START, 1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_TRIG0_END,   trig_end);
        reg_timgen.WriteReg(TIMGENREG_CTL_CONTROL, 3);

        // 画像読み込み
        vdmaw0.Oneshot(dmabuf0_phys_adr, width, height, 1);
        cv::Mat img(height, width, CV_16U);
        udmabuf0_acc.MemCopyTo(img.data, 0, width * height * 2);
        img = img * 64; // 10bit -> 16bit

        // 表示画像準備
        cv::Mat img_view;
        if ( color ) {
            cv::Mat img_bgr;
            cv::cvtColor(img, img_view, cv::COLOR_BayerBG2BGR);
        }
        else {
            img_view = img;
        }

        // 表示
        cv::imshow("img", img_view);

        // ユーザー操作
        switch ( key ) {
            case 'p':
            {
                std::cout << "SYSREG_ID           : 0x" << std::hex << reg_sys.ReadReg(SYSREG_ID)  << std::endl;
                std::cout << "SYSREG_IMAGE_WIDTH  : " << std::dec << reg_sys.ReadReg(SYSREG_IMAGE_WIDTH)  << std::endl;
                std::cout << "SYSREG_IMAGE_HEIGHT : " << std::dec << reg_sys.ReadReg(SYSREG_IMAGE_HEIGHT) << std::endl;
                int fps_count   = reg_sys.ReadReg(SYSREG_FPS_COUNT);
                int frame_count = reg_sys.ReadReg(SYSREG_FRAME_COUNT);
                std::cout << "SYSREG_FPS_COUNT   : " << std::dec << fps_count << std::endl;
                std::cout << "SYSREG_FRAME_COUNT : " << std::dec << frame_count << std::endl;
                std::cout << "fps = " << 250000000.0 / (double)fps_count << " [fps]" << std::endl;
            }
            break;
        
        case 'l':
            printf("load setting\n");
            load_setting(cam);
            break;
            
        case 'd':   // image dump
            cv::imwrite("img_dump.png", img);
            break;

        case 'r':   // record
            // 画像読み込み
            vdmaw0.Oneshot(dmabuf0_phys_adr, width, height, rec_frames);
            
            for ( int i = 0; i < rec_frames; i++ ) {
                // 画像読み込み
                cv::Mat img(height, width, CV_16U);
                udmabuf0_acc.MemCopyTo(img.data, width * height * 2 * i, width * height * 2);

                // 保存
                char fname[256];
                sprintf(fname, "rec/img_%03d.png", i);
                cv::imwrite(fname, img * (65535.0/1023.0));
            }
        }
    }

    std::cout << "close device" << std::endl;

    // video input stop
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x0);
    usleep(100000);

    // シーケンサ停止
    cam.SetSequencerEnable(false);
    usleep(10000);

    // センサー停止
    cam.SetSensorEnable(false);
    usleep(10000);

    // センサー電源OFF
    cam.SetSensorPowerEnable(false);
    usleep(10000);

    // カメラモジュールOFF
    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 0);
    usleep(100000);

    return 0;
}


// レジスタダンプ
void sensor_reg_dump(rtcl::RtclP3S7ControlI2c &cam, const char *fname) {
    FILE* fp = fopen(fname, "w");
    for ( int i = 0; i < 512; i++ ) {
        auto v = cam.spi_read(i);
        fprintf(fp, "%3d : 0x%04x (%d)\n", i, v, v);
    }
    fclose(fp);
}


// 設定ファイルを読み込む
void load_setting(rtcl::RtclP3S7ControlI2c &cam) {
    FILE* fp = fopen("reg_list.txt", "r");
    if ( fp == nullptr ) {
        std::cout << "reg_list.txt open error" << std::endl;
        return;
    }
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        char *p = line;
        // skip leading whitespace
        while (*p == ' ' || *p == '\t') ++p;
        if (*p == '\0' || *p == '#') continue; // skip empty/comment
        unsigned int addr, data;
        int n = sscanf(p, "%i %i", &addr, &data);
        if (n == 2) {
            cam.spi_write((std::uint16_t)addr, (std::uint16_t)data);
        } else {
            std::cout << "parse error: " << line;
        }
    }
    fclose(fp);
}



// end of file
