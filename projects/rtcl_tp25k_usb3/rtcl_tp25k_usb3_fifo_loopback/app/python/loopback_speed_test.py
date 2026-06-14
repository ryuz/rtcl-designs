import os
import argparse
import time
import PyD3XX


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="FT601 FIFO loopback random packet test")
    parser.add_argument(
        "-n",
        "--iterations",
        type=int,
        default=10000,
        help="Number of random loopback iterations (default: 10)",
    )
    args = parser.parse_args()
    if args.iterations <= 0:
        parser.error("--iterations must be greater than 0")
    return args


ARGS = _parse_args()

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

ITERATIONS = ARGS.iterations
RESPONSE_TIMEOUT_SEC = 1.0
pkt = WritePipe.MaximumPacketSize
assert pkt > 0, "MaximumPacketSize must be > 0"

total_payload_bytes = 0
loop_start = time.monotonic()

send_packets = []

send_bytes = 0
recv_bytes = 0

tx_len = WritePipe.MaximumPacketSize*32

payload = os.urandom(tx_len)
tx_buf = PyD3XX.FT_Buffer.from_bytes(payload)
for i in range(ITERATIONS):
    Status, BytesWrote = PyD3XX.FT_WritePipe(Device, WritePipe, tx_buf, len(payload), PyD3XX.NULL)
    if Status == PyD3XX.FT_OK:
        send_bytes += BytesWrote

    Status, ReadBuffer, BytesRead = PyD3XX.FT_ReadPipe(Device, ReadPipe, tx_len, PyD3XX.NULL)
    if Status == PyD3XX.FT_OK:
        recv_bytes += BytesRead

loop_elapsed = time.monotonic() - loop_start

PyD3XX.FT_Close(Device)

print(f"send_size : {send_bytes}")
print(f"recv_size : {recv_bytes}")
print(f"loop_elapsed_sec : {loop_elapsed:.2f}")
print(f"{send_bytes / loop_elapsed:.2f} Bytes/s")
