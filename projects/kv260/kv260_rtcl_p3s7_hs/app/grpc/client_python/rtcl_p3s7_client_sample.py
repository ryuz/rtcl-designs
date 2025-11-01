#!/usr/bin/env python3

import os
import numpy as np
import cv2
import matplotlib.pyplot as plt
from datetime import datetime
from rtcl_p3s7_client import *

from rtcl_p3s7_client import *


def main():
    address = "192.168.16.1:50051"
    env_addr = os.environ.get('KV260_IP_ADDRESS')
    if env_addr:
        address = f"{env_addr}:50051"

    width = 640
    height = 320
    frames = 20

    print(f"connecting to {address} ...")
    client = RtclP3s7Client(address=address)
    print(f"server version        : {client.get_version()}")
    print(f"camera module id      : 0x{client.camera_get_module_id():04x}")
    print(f"camera module version : 0x{client.camera_get_module_version():04x}")
    print(f"camera sensor id      : 0x{client.camera_get_sensor_id():04x}")

    print("open camera")
    client.camera_set_image_size(width, height)
    client.camera_open()

    # KV260 のメモリ内に連続画像を記録
    print(f"record images to {rec_path} ...")
    client.record_image(width, height, frames)

    # 画像を取得して保存
    rec_path = f"record/{datetime.now():%Y%m%d_%H%M%S}"
    os.makedirs(rec_path, exist_ok=True)
    print("saving images ...")
    for i in range(frames):
        buf = client.read_image(i)
        img = np.frombuffer(buf, dtype=np.uint16).reshape((height, width))
        img = img << 6  # 10bit RAW -> 16bit
        cv2.imwrite(os.path.join(rec_path, f"img_{i:04}.png"), img)

    # クローズ
    print("close camera")
    client.camera_close()


if __name__ == "__main__":
    main()

