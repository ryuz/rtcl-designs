import os
import argparse
import time
import PyD3XX


# デバイスを開く
Status, DeviceCount = PyD3XX.FT_CreateDeviceInfoList()
print(f"Devices detected: {DeviceCount}")
assert Status == PyD3XX.FT_OK and DeviceCount > 0, "No FT601 device found"

Status, Device = PyD3XX.FT_GetDeviceInfoDetail(0)
Status = PyD3XX.FT_Create(0, PyD3XX.FT_OPEN_BY_INDEX, Device)
assert Status == PyD3XX.FT_OK, f"FT_Create failed: {PyD3XX.FT_STATUS_STR[Status]}"

# InterfaceIndex=1 がデータパイプ, PipeIndex=0 が OUT (host→device)
Status, WritePipe = PyD3XX.FT_GetPipeInformation(Device, 1, 0)
assert Status == PyD3XX.FT_OK, "Failed to get OUT pipe info"
Status, ReadPipe = PyD3XX.FT_GetPipeInformation(Device, 1, 1)
assert Status == PyD3XX.FT_OK, "Failed to get IN pipe info"
print(f"OUT PipeID=0x{WritePipe.PipeID:02x}, MaxPacketSize={WritePipe.MaximumPacketSize}")
print(f"IN  PipeID=0x{ReadPipe.PipeID:02x}, MaxPacketSize={ReadPipe.MaximumPacketSize}")
Status = PyD3XX.FT_SetPipeTimeout(Device, ReadPipe, 50)
assert Status == PyD3XX.FT_OK, f"FT_SetPipeTimeout failed: {PyD3XX.FT_STATUS_STR[Status]}"

def write_axi4l(addr, data, strb=0xf):
    packet = bytes([
            0x02, 
            strb << 4,
            0x08,
            0x00,
            (addr >> 0) & 0xff,
            (addr >> 8) & 0xff,
            (addr >> 16) & 0xff,
            (addr >> 24) & 0xff,
            (data >> 0) & 0xff,
            (data >> 8) & 0xff,
            (data >> 16) & 0xff,
            (data >> 24) & 0xff,
        ])
    tx_buf = PyD3XX.FT_Buffer.from_bytes(packet)
    Status, BytesWrote = PyD3XX.FT_WritePipe(Device, WritePipe, tx_buf, len(packet), PyD3XX.NULL)
    assert Status == PyD3XX.FT_OK, f"FT_WritePipe failed at iter {i+1}: {PyD3XX.FT_STATUS_STR[Status]}"
    assert BytesWrote == len(packet), f"Short write : {BytesWrote}/{len(packet)}"

    Status, ReadBuffer, BytesRead = PyD3XX.FT_ReadPipe(Device, ReadPipe, 4, 100)
    assert Status == PyD3XX.FT_OK, f"FT_ReadPipe failed: {PyD3XX.FT_STATUS_STR[Status]}"
    assert BytesRead == 4, f"Short read : {BytesRead}/4"
    return int.from_bytes(ReadBuffer.Value()[:4], "little")

def read_axi4l(addr):
    packet = bytes([
            0x03,
            0x00,
            0x04,
            0x00,
            (addr >> 0) & 0xff,
            (addr >> 8) & 0xff,
            (addr >> 16) & 0xff,
            (addr >> 24) & 0xff,
        ])
    tx_buf = PyD3XX.FT_Buffer.from_bytes(packet)
    Status, BytesWrote = PyD3XX.FT_WritePipe(Device, WritePipe, tx_buf, len(packet), PyD3XX.NULL)
    assert Status == PyD3XX.FT_OK, f"FT_WritePipe failed at iter {i+1}: {PyD3XX.FT_STATUS_STR[Status]}"
    assert BytesWrote == len(packet), f"Short write : {BytesWrote}/{len(packet)}"
    time.sleep(0.01)  # デバイス側で処理されるのを待つ
    Status, ReadBuffer, BytesRead = PyD3XX.FT_ReadPipe(Device, ReadPipe, 8, PyD3XX.NULL)
    assert Status == PyD3XX.FT_OK, f"FT_ReadPipe failed: {PyD3XX.FT_STATUS_STR[Status]}"
    assert BytesRead == 8, f"Short read : {BytesRead}/4"
    return ReadBuffer.Value()[:8]

a = read_axi4l(0x00)
print(a)

PyD3XX.FT_Close(Device)

