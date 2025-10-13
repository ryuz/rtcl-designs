
TARGET    = kv260_rtcl_p3s7_hs.out

# 実行環境のネイティブアーキテクチャを取得
HOST_ARCH := $(shell uname -m)

TARGET_ARCH := aarch64
TARGET_TRIPLET := aarch64-linux-gnu-

CFLAGS  += -Wall -g -O2 -I../../../../../include  -I../../../../../jelly/include
LDFLAGS += -g

ifeq ($(HOST_ARCH),$(TARGET_ARCH))
    CC  := gcc
    CXX := g++
    CFLAGS  += `pkg-config --cflags opencv4`
    LDFLAGS += `pkg-config --libs opencv4`
else
    CC  = $(TARGET_TRIPLET)gcc
    CXX = $(TARGET_TRIPLET)g++
    CFLAGS  += -I/usr/include/opencv4
    LDFLAGS += -L/usr/lib/aarch64-linux-gnu
    LDFLAGS += -lopencv_stitching -lopencv_alphamat -lopencv_aruco -lopencv_bgsegm -lopencv_bioinspired -lopencv_ccalib -lopencv_dnn_objdetect -lopencv_dnn_superres -lopencv_dpm -lopencv_face -lopencv_freetype -lopencv_fuzzy -lopencv_hdf -lopencv_hfs -lopencv_img_hash -lopencv_intensity_transform -lopencv_line_descriptor -lopencv_mcc -lopencv_quality -lopencv_rapid -lopencv_reg -lopencv_rgbd -lopencv_saliency -lopencv_stereo -lopencv_structured_light -lopencv_phase_unwrapping -lopencv_superres -lopencv_optflow -lopencv_surface_matching -lopencv_tracking -lopencv_highgui -lopencv_datasets -lopencv_text -lopencv_plot -lopencv_videostab -lopencv_videoio -lopencv_viz -lopencv_wechat_qrcode -lopencv_shape -lopencv_ml -lopencv_ximgproc -lopencv_video -lopencv_xobjdetect -lopencv_objdetect -lopencv_calib3d -lopencv_imgcodecs -lopencv_features2d -lopencv_dnn -lopencv_flann -lopencv_xphoto -lopencv_photo -lopencv_imgproc -lopencv_core
endif


RUN_OPT ?=

OBJS = main.o

.PHONY: all
all: $(TARGET)

.PHONY: clean
clean:
	rm -rf $(TARGET) $(OBJS)

.PHONY: run
run: $(TARGET)
	mkdir -p rec
	./$(TARGET) $(RUN_OPT)

$(TARGET): $(OBJS)
	$(CXX) -o $(TARGET) $(OBJS) $(LDFLAGS)

%.o : %.cpp
	$(CXX) $(CFLAGS) -c $< -o $@

main.o: main.cpp ../../../../../include/rtcl/RtclP3S7Control.h
