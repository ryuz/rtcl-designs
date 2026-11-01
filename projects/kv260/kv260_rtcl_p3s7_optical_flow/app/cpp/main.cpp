#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <time.h>

#include <algorithm>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#include <opencv2/opencv.hpp>

#include "jelly/UioAccessor.h"
#include "jelly/UdmabufAccessor.h"
#include "jelly/JellyRegs.h"
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
#define TIMGENREG_CTL_CONTROL       0x04
#define TIMGENREG_PARAM_PERIOD      0x10
#define TIMGENREG_PARAM_TRIG0_START 0x20
#define TIMGENREG_PARAM_TRIG0_END   0x21

#define REG_IMG_GAUSS_PARAM_ENABLE   0x08
#define REG_IMG_GAUSS_CTL_CONTROL    0x04

#define REG_IMG_LK_ACC_PARAM_X       0x10
#define REG_IMG_LK_ACC_PARAM_Y       0x11
#define REG_IMG_LK_ACC_PARAM_WIDTH   0x12
#define REG_IMG_LK_ACC_PARAM_HEIGHT  0x13
#define REG_IMG_LK_ACC_CTL_CONTROL   0x04

#define REG_IMG_SELECTOR_CTL_SELECT  0x08

#define REG_LOGGER_CTL_STATUS        0x05
#define REG_LOGGER_READ_DATA         0x10
#define REG_LOGGER_POL_DATA1         0x21

#define REG_VIDEO_FMTREG_CTL_CONTROL      0x04
#define REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN 0x0a
#define REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT  0x0b
#define REG_VIDEO_FMTREG_PARAM_WIDTH      0x10
#define REG_VIDEO_FMTREG_PARAM_HEIGHT     0x11
#define REG_VIDEO_FMTREG_PARAM_FILL       0x12
#define REG_VIDEO_FMTREG_PARAM_TIMEOUT    0x13

#define OCM_LATENCY      0x18
#define OCM_PRJ_GAIN_X   0x20
#define OCM_PRJ_GAIN_Y   0x21
#define OCM_PRJ_DECAY_X  0x22
#define OCM_PRJ_DECAY_Y  0x23
#define OCM_PRJ_OFFSET_X 0x24
#define OCM_PRJ_OFFSET_Y 0x25

static volatile bool g_signal = false;

static void signal_handler(int)
{
    g_signal = true;
}

static double clamp_double(double value, double min_value, double max_value)
{
    return std::max(min_value, std::min(value, max_value));
}

static void write_reg_f64(jelly::MemAccessor64& acc, std::size_t reg, double value)
{
    std::uint64_t bits = 0;
    static_assert(sizeof(bits) == sizeof(value), "double size mismatch");
    std::memcpy(&bits, &value, sizeof(bits));
    acc.WriteReg64(reg, bits);
}

static std::string make_record_dir(void)
{
    mkdir("record", 0777);

    time_t now = time(nullptr);
    struct tm tm_buf;
    localtime_r(&now, &tm_buf);

    char path[128];
    strftime(path, sizeof(path), "record/%Y%m%d-%H%M%S", &tm_buf);
    mkdir(path, 0777);
    return std::string(path);
}

static void create_trackbar(const char* name, int min_value, int max_value, int initial)
{
    cv::createTrackbar(name, "img", nullptr, max_value);
    cv::setTrackbarMin(name, "img", min_value);
    cv::setTrackbarPos(name, "img", initial);
}

int main(int argc, char* argv[])
{
    int width = 320;
    int height = 320;
    int fps = 1000;
    int rec_frames = 1000;
    bool pgood_enable = true;

    for (int i = 1; i < argc; ++i) {
        if ((strcmp(argv[i], "-W") == 0 || strcmp(argv[i], "--width") == 0 || strcmp(argv[i], "-width") == 0) && i + 1 < argc) {
            width = strtol(argv[++i], nullptr, 0);
        }
        else if ((strcmp(argv[i], "-H") == 0 || strcmp(argv[i], "--height") == 0 || strcmp(argv[i], "-height") == 0) && i + 1 < argc) {
            height = strtol(argv[++i], nullptr, 0);
        }
        else if ((strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--fps") == 0) && i + 1 < argc) {
            fps = strtol(argv[++i], nullptr, 0);
        }
        else if ((strcmp(argv[i], "-r") == 0 || strcmp(argv[i], "--rec-frames") == 0) && i + 1 < argc) {
            rec_frames = strtol(argv[++i], nullptr, 0);
        }
        else if (strcmp(argv[i], "--pgood-off") == 0) {
            pgood_enable = false;
        }
        else {
            std::cout << "unknown option : " << argv[i] << std::endl;
            return 1;
        }
    }

    width &= ~0xf;
    width = std::max(width, 16);
    height = std::max(height, 1);
    fps = std::max(fps, 1);
    rec_frames = std::max(rec_frames, 1);

    std::cout << "start kv260_rtcl_p3s7_optical_flow" << std::endl;
    std::cout << "width       : " << width << std::endl;
    std::cout << "height      : " << height << std::endl;
    std::cout << "fps         : " << fps << std::endl;
    std::cout << "rec_frames  : " << rec_frames << std::endl;
    std::cout << "pgood       : " << (pgood_enable ? "on" : "off") << std::endl;

    signal(SIGINT, signal_handler);

    jelly::UdmabufAccessor udmabuf_acc("udmabuf-jelly-vram0");
    if (!udmabuf_acc.IsMapped()) {
        std::cout << "udmabuf-jelly-vram0 mmap error" << std::endl;
        return 1;
    }
    auto dmabuf_phys_addr = udmabuf_acc.GetPhysAddr();
    auto dmabuf_mem_size = udmabuf_acc.GetSize();
    std::cout << "udmabuf-jelly-vram0 phys addr : 0x" << std::hex << dmabuf_phys_addr << std::endl;
    std::cout << "udmabuf-jelly-vram0 size      : 0x" << std::hex << dmabuf_mem_size << std::dec << std::endl;

    jelly::UioAccessor uio_acc("uio_pl_peri", 0x08000000);
    if (!uio_acc.IsMapped()) {
        std::cout << "uio_pl_peri mmap error" << std::endl;
        return 1;
    }

    jelly::UioAccessor64 uio_ocm("uio_ocm");
    if (!uio_ocm.IsMapped()) {
        std::cout << "uio_ocm mmap error" << std::endl;
        return 1;
    }

    auto reg_sys      = uio_acc.GetAccessor(0x00000000);
    auto reg_timgen   = uio_acc.GetAccessor(0x00010000);
    auto reg_fmtr     = uio_acc.GetAccessor(0x00100000);
    auto reg_wdma_img = uio_acc.GetAccessor(0x00210000);
    auto reg_log_of   = uio_acc.GetAccessor(0x00300000);
    auto reg_gauss    = uio_acc.GetAccessor(0x00401000);
    auto reg_lk       = uio_acc.GetAccessor(0x00410000);
    auto reg_sel      = uio_acc.GetAccessor(0x0040f000);
    auto reg_ocm      = uio_ocm.GetAccessor64(0x00000000, 8);

    std::cout << "CORE ID" << std::endl;
    std::cout << "reg_sys      : " << std::hex << reg_sys.ReadReg(SYSREG_ID) << std::endl;
    std::cout << "reg_timgen   : " << std::hex << reg_timgen.ReadReg(TIMGENREG_CORE_ID) << std::endl;
    std::cout << "reg_fmtr     : " << std::hex << reg_fmtr.ReadReg(0) << std::endl;
    std::cout << "reg_wdma_img : " << std::hex << reg_wdma_img.ReadReg(0) << std::dec << std::endl;

    rtcl::RtclP3S7ControlI2c cam;
    if (!cam.Open("/dev/i2c-6", 0x10)) {
        std::cout << "i2c open error" << std::endl;
        return 1;
    }

    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 1);
    usleep(100000);

    cam.SetSensorPGoodEnable(pgood_enable);
    cam.SetDphySpeed(1250000000);

    reg_sys.WriteReg(SYSREG_DPHY_SW_RESET, 1);
    cam.SetSensorPowerEnable(false);
    cam.SetDphyReset(true);
    usleep(10000);

    reg_sys.WriteReg(SYSREG_DPHY_SW_RESET, 0);
    cam.SetCameraMode(rtcl::RtclP3S7ControlI2c::MODE_HIGH_SPEED);
    cam.SetSensorPowerEnable(true);
    usleep(10000);

    cam.SetDphyReset(false);
    if (!cam.GetDphyInitDone()) {
        std::cout << "!!ERROR!! CAM DPHY TX init_done = 0" << std::endl;
        return 1;
    }
    if (reg_sys.ReadReg(SYSREG_DPHY_INIT_DONE) == 0) {
        std::cout << "!!ERROR!! KV260 DPHY RX init_done = 0" << std::endl;
        return 1;
    }

    reg_sys.WriteReg(SYSREG_IMAGE_WIDTH, width);
    reg_sys.WriteReg(SYSREG_IMAGE_HEIGHT, height);
    reg_sys.WriteReg(SYSREG_BLACK_WIDTH, 1280);
    reg_sys.WriteReg(SYSREG_BLACK_HEIGHT, 1);

    auto xsm_delay = cam.CalcXsmDelay(width);
    cam.SetXsmDelay(xsm_delay);
    cam.SetNzrotXsmDelayEnable(true);
    cam.SetZeroRotEnable(true);
    cam.SetSlaveMode(true);
    cam.SetTriggeredMode(true);

    if (!cam.SetSensorEnable(true)) {
        if (!cam.GetSensorPGood()) {
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

    cam.SetRoi0(width, height);
    cam.SetMultTimer0(72);
    cam.SetFrLength0(0);
    cam.SetExposure0(10000);

    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_FRM_TIMER_EN, 1);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_FRM_TIMEOUT, 20000000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_WIDTH, width);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_HEIGHT, height);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_FILL, 0x0);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_PARAM_TIMEOUT, 100000);
    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x03);
    usleep(1000);

    cam.SetSequencerEnable(true);
    usleep(1000000);

    std::cout << "camera module id      : " << std::hex << cam.GetModuleId() << std::endl;
    std::cout << "camera module version : " << std::hex << cam.GetModuleVersion() << std::endl;
    std::cout << "camera sensor id      : " << std::hex << cam.GetSensorId() << std::dec << std::endl;
    cam.SetPmodMode(0x10);

    jelly::VideoDmaControl vdmaw(reg_wdma_img, 2, 2, true);

    cv::namedWindow("img", cv::WINDOW_AUTOSIZE);
    cv::resizeWindow("img", width + 64, height + 256);
    cv::namedWindow("graph", cv::WINDOW_AUTOSIZE);
    cv::namedWindow("x-y", cv::WINDOW_AUTOSIZE);

    create_trackbar("gain", 0, 200, 10);
    create_trackbar("fps", 10, 1000, fps);
    create_trackbar("gauss", 0, 4, 3);
    create_trackbar("exposure", 10, 900, 900);
    create_trackbar("sel", 0, 3, 0);
    create_trackbar("latency", 0, 199, 0);
    create_trackbar("pgx", -200, 200, 150);
    create_trackbar("pgy", -200, 200, -150);
    create_trackbar("pox", -500, 500, 0);
    create_trackbar("poy", -500, 500, 300);

    reg_lk.WriteReg(REG_IMG_LK_ACC_PARAM_X, 16);
    reg_lk.WriteReg(REG_IMG_LK_ACC_PARAM_Y, 16);
    reg_lk.WriteReg(REG_IMG_LK_ACC_PARAM_WIDTH, width - 32);
    reg_lk.WriteReg(REG_IMG_LK_ACC_PARAM_HEIGHT, height - 32);
    reg_lk.WriteReg(REG_IMG_LK_ACC_CTL_CONTROL, 3);

    std::vector<double> hist_dx;
    std::vector<double> hist_dy;
    double track_x = 0.0;
    double track_y = 0.0;

    while (!g_signal) {
        int key = cv::waitKey(10) & 0xff;
        if (key == 0x1b) {
            break;
        }

        int gain_pos = cv::getTrackbarPos("gain", "img");
        int fps_pos = cv::getTrackbarPos("fps", "img");
        int gauss = cv::getTrackbarPos("gauss", "img");
        int exposure_pos = cv::getTrackbarPos("exposure", "img");
        int sel = cv::getTrackbarPos("sel", "img");
        int latency = cv::getTrackbarPos("latency", "img");
        int prj_gain_x = cv::getTrackbarPos("pgx", "img");
        int prj_gain_y = cv::getTrackbarPos("pgy", "img");
        int prj_offset_x = cv::getTrackbarPos("pox", "img");
        int prj_offset_y = cv::getTrackbarPos("poy", "img");

        cam.SetGainDb(static_cast<float>(gain_pos - 10) / 10.0f);

        reg_gauss.WriteReg(REG_IMG_GAUSS_PARAM_ENABLE, (1 << gauss) - 1);
        reg_gauss.WriteReg(REG_IMG_GAUSS_CTL_CONTROL, 3);
        reg_sel.WriteReg(REG_IMG_SELECTOR_CTL_SELECT, sel);

        write_reg_f64(reg_ocm, OCM_PRJ_DECAY_X, 0.998);
        write_reg_f64(reg_ocm, OCM_PRJ_DECAY_Y, 0.998);
        write_reg_f64(reg_ocm, OCM_PRJ_GAIN_X, static_cast<double>(prj_gain_x) / 100.0);
        write_reg_f64(reg_ocm, OCM_PRJ_GAIN_Y, static_cast<double>(prj_gain_y) / 100.0);
        write_reg_f64(reg_ocm, OCM_PRJ_OFFSET_X, static_cast<double>(prj_offset_x));
        write_reg_f64(reg_ocm, OCM_PRJ_OFFSET_Y, static_cast<double>(prj_offset_y));
        reg_ocm.WriteReg64(OCM_LATENCY, static_cast<std::uint64_t>(latency));

        double period_us = 1000000.0 / static_cast<double>(std::max(fps_pos, 1));
        double exposure_us = period_us * static_cast<double>(exposure_pos) / 1000.0;
        exposure_us = clamp_double(exposure_us, 100.0, std::max(period_us - 100.0, 100.0));
        int period = std::max(static_cast<int>(period_us / 0.01), 1);
        int trig_end = std::max(static_cast<int>(exposure_us / 0.01), 1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_PERIOD, period - 1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_TRIG0_START, 1);
        reg_timgen.WriteReg(TIMGENREG_PARAM_TRIG0_END, trig_end);
        reg_timgen.WriteReg(TIMGENREG_CTL_CONTROL, 3);

        vdmaw.Oneshot(dmabuf_phys_addr, width, height, 1, 0, 0, 0, 0, 1000000);

        cv::Mat img(height, width, CV_16UC1);
        udmabuf_acc.MemCopyTo(img.data, 0, static_cast<std::size_t>(width * height * 2));

        cv::Mat view;
        img.convertTo(view, CV_16U, 64.0, 0.0);
        cv::imshow("img", view);

        while (reg_log_of.ReadReg(REG_LOGGER_CTL_STATUS) != 0) {
            double dy = static_cast<double>(static_cast<int32_t>(reg_log_of.ReadReg(REG_LOGGER_POL_DATA1))) / 65536.0;
            double dx = static_cast<double>(static_cast<int32_t>(reg_log_of.ReadReg(REG_LOGGER_READ_DATA))) / 65536.0;

            hist_dx.push_back(dx);
            hist_dy.push_back(dy);
            if (hist_dx.size() > 1000) {
                hist_dx.erase(hist_dx.begin());
                hist_dy.erase(hist_dy.begin());
            }

            track_x = clamp_double(track_x + dx, 0.0, static_cast<double>(width));
            track_y = clamp_double(track_y + dy, 0.0, static_cast<double>(height));
        }

        cv::Mat graph = cv::Mat::zeros(200, 1000, CV_8UC3);
        for (std::size_t i = 0; i < hist_dx.size(); ++i) {
            int y0 = 100 - static_cast<int>(hist_dx[i] * 10.0);
            int y1 = 100 - static_cast<int>(hist_dy[i] * 10.0);
            cv::circle(graph, cv::Point(static_cast<int>(i), y0), 1, cv::Scalar(0, 255, 0), -1, cv::LINE_8);
            cv::circle(graph, cv::Point(static_cast<int>(i), y1), 1, cv::Scalar(255, 0, 0), -1, cv::LINE_8);
        }
        cv::imshow("graph", graph);

        cv::Mat xy = cv::Mat::zeros(200, 200, CV_8UC3);
        for (std::size_t i = 0; i < hist_dx.size(); ++i) {
            int x = 100 - static_cast<int>(hist_dx[i] * 10.0);
            int y = 100 - static_cast<int>(hist_dy[i] * 10.0);
            cv::circle(xy, cv::Point(x, y), 1, cv::Scalar(0, 255, 0), -1, cv::LINE_8);
        }
        cv::imshow("x-y", xy);

        switch (key) {
        case 'q':
            g_signal = true;
            break;

        case 'p':
        {
            int fps_count = reg_sys.ReadReg(SYSREG_FPS_COUNT);
            int frame_count = reg_sys.ReadReg(SYSREG_FRAME_COUNT);
            std::cout << "camera module id      : " << std::hex << cam.GetModuleId() << std::endl;
            std::cout << "camera module version : " << std::hex << cam.GetModuleVersion() << std::endl;
            std::cout << "camera sensor id      : " << std::hex << cam.GetSensorId() << std::dec << std::endl;
            std::cout << "sensor_pgood          : " << cam.GetSensorPGood() << std::endl;
            std::cout << "SYSREG_FPS_COUNT      : " << fps_count << std::endl;
            std::cout << "SYSREG_FRAME_COUNT    : " << frame_count << std::endl;
            if (fps_count != 0) {
                std::cout << "fps                   : " << (250000000.0 / static_cast<double>(fps_count)) << std::endl;
            }
            break;
        }

        case 'd':
            std::cout << "write : dump.png" << std::endl;
            cv::imwrite("dump.png", view);
            break;

        case 'r':
        {
            std::string dir_name = make_record_dir();
            std::cout << "record to " << dir_name << std::endl;

            int frames = std::min(rec_frames, static_cast<int>(dmabuf_mem_size / static_cast<std::size_t>(width * height * 2)));
            vdmaw.Oneshot(dmabuf_phys_addr, width, height, frames, 0, 0, 0, 0, 1000000 * frames);
            for (int frame = 0; frame < frames; ++frame) {
                cv::Mat rec_img(height, width, CV_16UC1);
                std::size_t offset = static_cast<std::size_t>(frame) * static_cast<std::size_t>(width * height * 2);
                udmabuf_acc.MemCopyTo(rec_img.data, offset, static_cast<std::size_t>(width * height * 2));

                cv::Mat rec_view;
                rec_img.convertTo(rec_view, CV_16U, 64.0, 0.0);

                char filename[256];
                snprintf(filename, sizeof(filename), "%s/img%04d.png", dir_name.c_str(), frame);
                cv::imwrite(filename, rec_view);
            }
            std::cout << "record done" << std::endl;
            break;
        }

        default:
            break;
        }
    }

    std::cout << "close device" << std::endl;

    reg_fmtr.WriteReg(REG_VIDEO_FMTREG_CTL_CONTROL, 0x00);
    usleep(10000);

    cam.SetSequencerEnable(false);
    cam.SetSensorEnable(false);
    usleep(10000);

    cam.SetSensorPowerEnable(false);
    usleep(10000);

    reg_sys.WriteReg(SYSREG_CAM_ENABLE, 0);
    usleep(10000);

    return 0;
}
