#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <iostream>
#include <vector>
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

#define REG_BIN_PARAM_END   0x04
#define REG_BIN_TBL0        0x40
#define REG_BIN_TBL1        0x41
#define REG_BIN_TBL2        0x42
#define REG_BIN_TBL3        0x43
#define REG_BIN_TBL4        0x44
#define REG_BIN_TBL5        0x45
#define REG_BIN_TBL6        0x46
#define REG_BIN_TBL7        0x47
#define REG_BIN_TBL8        0x48
#define REG_BIN_TBL9        0x49
#define REG_BIN_TBL10       0x4a
#define REG_BIN_TBL11       0x4b
#define REG_BIN_TBL12       0x4c
#define REG_BIN_TBL13       0x4d
#define REG_BIN_TBL14       0x4e
#define REG_LPF_PARAM_ALPHA 0x08

void          sensor_reg_dump(rtcl::RtclP3S7ControlI2c  &cam, const char *fname);
void          load_setting(rtcl::RtclP3S7ControlI2c  &cam);

static  volatile    bool    g_signal = false;
void signal_handler(int signo) {
    g_signal = true;
}


// メイン関数
int main(int argc, char *argv[])
{
    int width  = 256 ;
    int height = 256 ;
    int fps = 1000;
    int exposure = 900;
    int gain = 10;
    bool pgood_enable = true;

    for ( int i = 1; i < argc; ++i ) {
        if ( (strcmp(argv[i], "-W") == 0 || strcmp(argv[i], "--width") == 0 || strcmp(argv[i], "-width") == 0) && i+1 < argc) {
            ++i;
            width = strtol(argv[i], nullptr, 0);
        }
        else if ( (strcmp(argv[i], "-H") == 0 || strcmp(argv[i], "--height") == 0 || strcmp(argv[i], "-height") == 0) && i+1 < argc) {
            ++i;
            height = strtol(argv[i], nullptr, 0);
        }
        else if ( (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--fps") == 0) && i+1 < argc) {
            ++i;
            fps = strtol(argv[i], nullptr, 0);
        }
        else if ( strcmp(argv[i], "--pgood-off") == 0 ) {
            pgood_enable = false;
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
    auto reg_bin    = uio_acc.GetAccessor(0x00300000);
    auto reg_lpf    = uio_acc.GetAccessor(0x00320000);
    
    // レジスタ確認
    std::cout << "CORE ID" << std::endl;
    std::cout << std::hex << reg_sys.ReadReg(SYSREG_ID) << std::endl;
    std::cout << std::hex << reg_timgen.ReadReg(TIMGENREG_CORE_ID) << std::endl;
    std::cout << std::hex << reg_fmtr.ReadReg(0) << std::endl;
    std::cout << std::hex << reg_wdma0.ReadReg(0) << std::endl;
    std::cout << std::hex << reg_wdma1.ReadReg(0) << std::endl;
    std::cout << std::hex << reg_bin.ReadReg(0) << std::endl;
    std::cout << std::hex << reg_lpf.ReadReg(0) << std::endl;

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
    cam.Open("/dev/i2c-6", 0x10);

    // カメラ基板ID確認
    std::cout << "Camera Module ID      : " << std::hex << cam.GetModuleId() << std::endl;
    std::cout << "Camera Module Version : " << std::hex << cam.GetModuleVersion() << std::endl;

    // カメラモジュールリセット
    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 0);
    usleep(10000);
    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 1);
    usleep(10000);

    // MMCM 設定
    cam.SetDphySpeed(1250000000);   // 1250Mbps

    // センサー電源OK監視有無設定
    std::cout << "Sensor PGood Enable : " << (pgood_enable ? "ON" : "OFF") << std::endl;
    cam.SetSensorPGoodEnable(pgood_enable);
    
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

    // D-PHY速度とライン長から XSM delay を計算して設定
    auto xsm_delay = cam.CalcXsmDelay(width);
    cam.SetXsmDelay(xsm_delay);
    cam.SetNzrotXsmDelayEnable(true);
    cam.SetZeroRotEnable(true);

    // センサー起動
    if ( !cam.SetSensorEnable(true) ) {
        if ( !cam.GetSensorPGood() ) {
            std::cout << "\n!! sensor power good error. !! Retry with --pgood-off option." << std::endl;
        }
        else {
            std::cout << "!!ERROR!! CAM sensor enable failed" << std::endl;
        }
        cam.SetSensorPowerEnable(false);
        usleep(10000);
        reg_sys.WriteReg(SYSREG_CAM_ENABLE, 0);
        return 1;
    }

    // 画像サイズ設定
    cam.SetRoi0(width, height);

    // video input start
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN,  1);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT,   20000000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_WIDTH,       width);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_HEIGHT,      height);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_FILL,        0x0);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_TIMEOUT,     100000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_CONTROL,       0x03);

    // 動作開始
    std::cout << "Start Camera" << std::endl;

    cam.SetMultTimer0(72);
    cam.SetFrLength0(0);
    cam.SetExposure0(10000);

//  cam.SetTriggeredMode(true);
//  cam.SetSlaveMode(true);
    cam.SetTriggeredMode(true);
    cam.SetSlaveMode(true);
    cam.SetSequencerEnable(true);
    usleep(100000);

    cam.SetGainDb((float)(gain - 10) / 10.0f);

    // Video DMA ドライバ生成
    jelly::VideoDmaControl vdmaw0(reg_wdma0, 2, 2, true);
    jelly::VideoDmaControl vdmaw1(reg_wdma1, 2, 2, true);

    cv::namedWindow("img", cv::WINDOW_AUTOSIZE);
    cv::resizeWindow("img", width + 64, height + 256);
    cv::namedWindow("class", cv::WINDOW_AUTOSIZE);
    cv::resizeWindow("class", width + 64, height + 256);
    cv::imshow("img", cv::Mat::zeros(height, width, CV_8UC3));
    cv::createTrackbar("gain", "img", nullptr, 200);
    cv::setTrackbarPos("gain", "img", gain);

    cv::createTrackbar("fps", "img", nullptr, 1000);
    cv::setTrackbarMin("fps", "img", 10);
    cv::setTrackbarPos("fps", "img", fps);

    cv::createTrackbar("exposure", "img", nullptr, 900);
    cv::setTrackbarMin("exposure", "img", 10);
    cv::setTrackbarPos("exposure", "img", exposure);

    cv::createTrackbar("lpf", "img", nullptr, 255);
    cv::setTrackbarPos("lpf", "img", 200);

    cv::createTrackbar("bin_th", "img", nullptr, 1023);
    cv::setTrackbarPos("bin_th", "img", 64);

    int     key;
    while ( (key = (cv::waitKey(10) & 0xff)) != 0x1b ) {
        if ( g_signal ) { break; }

        gain     = cv::getTrackbarPos("gain", "img");
        fps      = cv::getTrackbarPos("fps", "img");
        exposure = cv::getTrackbarPos("exposure", "img");
        int lpf = cv::getTrackbarPos("lpf", "img");
        int bin_th = cv::getTrackbarPos("bin_th", "img");

        cam.SetGainDb((float)(gain - 10) / 10.0f);

        double period_us = std::max(1000000.0 / static_cast<double>(fps), 1000.0);
        double exposure_us = period_us * (static_cast<double>(exposure) / 1000.0);
        exposure_us = std::clamp(exposure_us, 100.0, period_us - 100.0);
        int period = static_cast<int>(period_us / 0.01);    // 100MHz / fps
        int trig_end = std::max(static_cast<int>(exposure_us / 0.01), 1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_PERIOD,      period-1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_TRIG0_START, 1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_TRIG0_END,   trig_end);
        reg_timgen.WriteReg(TIMGENREG_CTL_CONTROL, 3);

        // binarize / lpf パラメータ設定
        reg_lpf.WriteReg(REG_LPF_PARAM_ALPHA, lpf);
        int amp = 4;
        reg_bin.WriteReg(REG_BIN_TBL0,  bin_th + (0x1*amp));
        reg_bin.WriteReg(REG_BIN_TBL1,  bin_th + (0xf*amp));
        reg_bin.WriteReg(REG_BIN_TBL2,  bin_th + (0x7*amp));
        reg_bin.WriteReg(REG_BIN_TBL3,  bin_th + (0x9*amp));
        reg_bin.WriteReg(REG_BIN_TBL4,  bin_th + (0x3*amp));
        reg_bin.WriteReg(REG_BIN_TBL5,  bin_th + (0xd*amp));
        reg_bin.WriteReg(REG_BIN_TBL6,  bin_th + (0x5*amp));
        reg_bin.WriteReg(REG_BIN_TBL7,  bin_th + (0xb*amp));
        reg_bin.WriteReg(REG_BIN_TBL8,  bin_th + (0x2*amp));
        reg_bin.WriteReg(REG_BIN_TBL9,  bin_th + (0xe*amp));
        reg_bin.WriteReg(REG_BIN_TBL10, bin_th + (0x6*amp));
        reg_bin.WriteReg(REG_BIN_TBL11, bin_th + (0xa*amp));
        reg_bin.WriteReg(REG_BIN_TBL12, bin_th + (0x4*amp));
        reg_bin.WriteReg(REG_BIN_TBL13, bin_th + (0xc*amp));
        reg_bin.WriteReg(REG_BIN_TBL14, bin_th + (0x8*amp));
        reg_bin.WriteReg(REG_BIN_PARAM_END, 14);

        // 画像読み込み
        vdmaw0.Oneshot(dmabuf0_phys_adr, width, height, 1);
        std::vector<std::uint8_t> src(width * height * 2);
        udmabuf0_acc.MemCopyTo(src.data(), 0, src.size());

        cv::Mat img(height, width, CV_8UC1);
        cv::Mat cls(height, width, CV_8UC3, cv::Scalar(0, 0, 0));
        for ( int y = 0; y < height; y++ ) {
            for ( int x = 0; x < width; x++ ) {
                std::size_t index = static_cast<std::size_t>(y * width + x);
                std::uint8_t img_v = src[index * 2 + 0];
                std::uint8_t cls_v = src[index * 2 + 1];
                img.at<std::uint8_t>(y, x) = img_v;
                cv::Vec3b color;
                switch ( cls_v ) {
                case 0: color = cv::Vec3b(0,   0,   0);   break;
                case 1: color = cv::Vec3b(42,  42,  165); break;
                case 2: color = cv::Vec3b(0,   0,   255); break;
                case 3: color = cv::Vec3b(0,   165, 255); break;
                case 4: color = cv::Vec3b(0,   255, 255); break;
                case 5: color = cv::Vec3b(0,   255, 0);   break;
                case 6: color = cv::Vec3b(255, 0,   0);   break;
                case 7: color = cv::Vec3b(128, 0,   128); break;
                case 8: color = cv::Vec3b(192, 192, 192); break;
                case 9: color = cv::Vec3b(255, 255, 255); break;
                default:color = cv::Vec3b(64,  64,  64);  break;
                }
                cls.at<cv::Vec3b>(y, x) = color;
            }
        }

        cv::imshow("img", img);
        cv::imshow("class", cls);

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
            cv::imwrite("class_dump.png", cls);
            break;

        case 'r':   // record
            // 画像読み込み
            vdmaw0.Oneshot(dmabuf0_phys_adr, width, height, rec_frames);
            
            for ( int i = 0; i < rec_frames; i++ ) {
                std::vector<std::uint8_t> rec(width * height * 2);
                udmabuf0_acc.MemCopyTo(rec.data(), width * height * 2 * i, width * height * 2);

                cv::Mat rec_img(height, width, CV_8UC1);
                cv::Mat rec_cls(height, width, CV_8UC3, cv::Scalar(0, 0, 0));
                for ( int y = 0; y < height; y++ ) {
                    for ( int x = 0; x < width; x++ ) {
                        std::size_t index = static_cast<std::size_t>(y * width + x);
                        std::uint8_t img_v = rec[index * 2 + 0];
                        std::uint8_t cls_v = rec[index * 2 + 1];
                        rec_img.at<std::uint8_t>(y, x) = img_v;
                        cv::Vec3b color;
                        switch ( cls_v ) {
                        case 0: color = cv::Vec3b(0,   0,   0);   break;
                        case 1: color = cv::Vec3b(42,  42,  165); break;
                        case 2: color = cv::Vec3b(0,   0,   255); break;
                        case 3: color = cv::Vec3b(0,   165, 255); break;
                        case 4: color = cv::Vec3b(0,   255, 255); break;
                        case 5: color = cv::Vec3b(0,   255, 0);   break;
                        case 6: color = cv::Vec3b(255, 0,   0);   break;
                        case 7: color = cv::Vec3b(128, 0,   128); break;
                        case 8: color = cv::Vec3b(192, 192, 192); break;
                        case 9: color = cv::Vec3b(255, 255, 255); break;
                        default:color = cv::Vec3b(64,  64,  64);  break;
                        }
                        rec_cls.at<cv::Vec3b>(y, x) = color;
                    }
                }

                // 保存
                char fname[256];
                sprintf(fname, "rec/img_%03d.png", i);
                cv::imwrite(fname, rec_img);
                sprintf(fname, "rec/class_%03d.png", i);
                cv::imwrite(fname, rec_cls);
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


// センサーのレジスタダンプ
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
