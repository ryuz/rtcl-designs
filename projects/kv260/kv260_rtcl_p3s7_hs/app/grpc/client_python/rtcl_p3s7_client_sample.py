#!/usr/bin/env python3

import os
import numpy as np
import cv2
import matplotlib.pyplot as plt
from rtcl_p3s7_client import *

from rtcl_p3s7_client import *


def main():
    address = "192.168.16.1:50051"
    env_addr = os.environ.get('KV260_IP_ADDRESS')
    if env_addr:
        address = f"{env_addr}:50051"

    width = 640
    height = 320

    print(f"connecting to {address} ...")
    client = RtclP3s7Client(address=address)
    print(f"server version        : {client.get_version()}")
    print(f"camera module id      : 0x{client.camera_get_module_id():04x}")
    print(f"camera module version : 0x{client.camera_get_module_version():04x}")
    print(f"camera sensor id      : 0x{client.camera_get_sensor_id():04x}")

    print("open camera")
    client.camera_set_image_size(width, height)
    client.camera_open()

    # 1フレーム撮影
    print("record image")
    client.record_image(width, height, 1)
    buf = client.read_image(0)
    img = np.frombuffer(buf, dtype=np.uint16).reshape((height, width))
    img = img << 6  # 10bit RAW -> 16bit

    # 画像保存
    print("saving capture.png ...")
    cv2.imwrite("capture.png", img)

    # クローズ
    print("close camera")
    client.camera_close()


if __name__ == "__main__":
    main()

