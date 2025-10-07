FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    build-essential \
    crossbuild-essential-armhf \
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
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf

RUN dpkg --add-architecture armhf \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        libopencv-dev:armhf \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
