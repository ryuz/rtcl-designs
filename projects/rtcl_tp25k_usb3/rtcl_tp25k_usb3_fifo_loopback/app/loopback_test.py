import os
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

ITERATIONS = 1000
RESPONSE_TIMEOUT_SEC = 1.0
pkt = WritePipe.MaximumPacketSize
assert pkt > 0, "MaximumPacketSize must be > 0"

total_payload_bytes = 0
test_start = time.monotonic()

for i in range(ITERATIONS):
    # 1..MaximumPacketSize のランダム長パケットを毎回生成
    payload_len = 1 + int.from_bytes(os.urandom(2), "little") % pkt
    payload = os.urandom(payload_len)
    tx_buf = PyD3XX.FT_Buffer.from_bytes(payload)

    Status, BytesWrote = PyD3XX.FT_WritePipe(Device, WritePipe, tx_buf, len(payload), PyD3XX.NULL)
    assert Status == PyD3XX.FT_OK, f"FT_WritePipe failed at iter {i+1}: {PyD3XX.FT_STATUS_STR[Status]}"
    assert BytesWrote == len(payload), f"Short write at iter {i+1}: {BytesWrote}/{len(payload)}"

    rx_chunks = []
    rx_total = 0
    deadline = time.monotonic() + RESPONSE_TIMEOUT_SEC

    while rx_total < len(payload):
        if time.monotonic() >= deadline:
            print(f"Timeout: no complete response within {RESPONSE_TIMEOUT_SEC:.1f}s at iter {i+1}")
            PyD3XX.FT_Close(Device)
            raise SystemExit(1)

        Status, ReadBuffer, BytesRead = PyD3XX.FT_ReadPipe(Device, ReadPipe, ReadPipe.MaximumPacketSize, PyD3XX.NULL)
        if Status == PyD3XX.FT_TIMEOUT:
            continue
        assert Status == PyD3XX.FT_OK, f"FT_ReadPipe failed at iter {i+1}: {PyD3XX.FT_STATUS_STR[Status]}"
        if BytesRead == 0:
            continue

        rx_chunks.append(bytes(ReadBuffer.Value()[:BytesRead]))
        rx_total += BytesRead

    rx_data = b"".join(rx_chunks)[:len(payload)]
    if rx_data != payload:
        print(f"Data mismatch at iter {i+1}: sent {len(payload)} bytes, received {len(rx_data)} bytes")
        PyD3XX.FT_Close(Device)
        raise SystemExit(1)

    total_payload_bytes += len(payload)

    if (i + 1) % 10 == 0 or i == 0:
        print(f"[{i+1:4d}/{ITERATIONS}] OK packet_len={len(payload):3d}B")

elapsed = time.monotonic() - test_start
payload_bps = (total_payload_bytes * 2) / elapsed if elapsed > 0 else 0.0

print("Loopback test passed")
print(f"Iterations: {ITERATIONS}")
print(f"Packet length range: 1..{pkt} bytes (random per iteration)")
print(f"Elapsed: {elapsed:.3f} s")
print(f"Total payload bytes (TX+RX): {total_payload_bytes * 2}")
print(f"Approx throughput (payload): {payload_bps / (1024 * 1024):.3f} MiB/s")

PyD3XX.FT_Close(Device)

