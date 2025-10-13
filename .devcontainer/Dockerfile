FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ENV DEBIAN_FRONTEND=noninteractive

# Host
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
          build-essential \
          crossbuild-essential-arm64 \
          pkg-config \
          cmake \
          ninja-build \
          curl \
          git \
          libssl-dev \
          ca-certificates \
          clang \
          libclang-dev \
          llvm-dev \
          gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
          libopencv-dev

# Target
RUN dpkg --add-architecture arm64 \
 && release=$(. /etc/os-release && echo "$UBUNTU_CODENAME") \
 && mv /etc/apt/sources.list /etc/apt/sources.list.amd64 \
 && printf "deb [arch=amd64] http://archive.ubuntu.com/ubuntu %s main universe multiverse restricted\n" "$release" > /etc/apt/sources.list \
 && printf "deb [arch=amd64] http://archive.ubuntu.com/ubuntu %s-updates main universe multiverse restricted\n" "$release" >> /etc/apt/sources.list \
 && printf "deb [arch=amd64] http://archive.ubuntu.com/ubuntu %s-backports main universe multiverse restricted\n" "$release" >> /etc/apt/sources.list \
 && printf "deb [arch=amd64] http://security.ubuntu.com/ubuntu %s-security main universe multiverse restricted\n" "$release" >> /etc/apt/sources.list \
 && rm -f /etc/apt/sources.list.d/* \
 && printf "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports %s main universe multiverse restricted\n" "$release" > /etc/apt/sources.list.d/arm64-ports.list \
 && printf "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports %s-updates main universe multiverse restricted\n" "$release" >> /etc/apt/sources.list.d/arm64-ports.list \
 && printf "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports %s-backports main universe multiverse restricted\n" "$release" >> /etc/apt/sources.list.d/arm64-ports.list \
 && printf "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports %s-security main universe multiverse restricted\n" "$release" >> /etc/apt/sources.list.d/arm64-ports.list \
 && apt-get update \
 && apt-get install -y \
      libopencv-dev:arm64 \
      libopencv-contrib-dev:arm64 \
      libopencv-stitching-dev:arm64 \
      libopencv-calib3d-dev:arm64 \
      libopencv-dnn-dev:arm64 \
      libopencv-features2d-dev:arm64 \
      libopencv-flann-dev:arm64 \
      libopencv-highgui-dev:arm64 \
      libopencv-imgcodecs-dev:arm64 \
      libopencv-imgproc-dev:arm64 \
      libopencv-ml-dev:arm64 \
      libopencv-objdetect-dev:arm64 \
      libopencv-photo-dev:arm64 \
      libopencv-shape-dev:arm64 \
      libopencv-video-dev:arm64 \
      libopencv-videoio-dev:arm64 \
      libopencv-viz-dev:arm64 \
      libblas-dev:arm64 \
      liblapack-dev:arm64 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# additional
RUN apt-get update \
 && apt-get install -y x11-apps \
            libtinfo5 libncurses5

