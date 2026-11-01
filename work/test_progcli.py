import os
import subprocess
from pathlib import Path

SYN_DIR = Path(r"D:\home\ryuji\git_work\rtcl-designs\projects\rtcl_tp25k_usb3\rtcl_tp25k_usb3_usermodule_sample\syn\cli")
FS_FILE = SYN_DIR / "impl" / "pnr" / "rtcl_tp25k_usb3_usermodule_sample.fs"
CMD = ["programmer_cli", "--device", "GW5A-25B", "--run", "2", "--fsFile", str(FS_FILE), "--location", "11555"]

build_env = os.environ | {
    "DEVICE_PART_NUMBER": "GW5A-LV25MG121NC1/I0",
    "DEVICE_NAME": "GW5A-25A",
    "TOP_MODULE": "rtcl_tp25k_usb3_usermodule_sample",
}

cases = [
    ("baseline (no cwd, no env, no pipe)", {}),
    ("pipe only", {"stdout": subprocess.PIPE, "stderr": subprocess.STDOUT, "text": True}),
    ("cwd only", {"cwd": SYN_DIR}),
    ("env only", {"env": build_env}),
    ("cwd+env+pipe (notebook conditions)", {"cwd": SYN_DIR, "env": build_env, "stdout": subprocess.PIPE, "stderr": subprocess.STDOUT, "text": True}),
]

for name, kwargs in cases:
    proc = subprocess.Popen(CMD, **kwargs)
    out = None
    if kwargs.get("stdout") == subprocess.PIPE:
        out = proc.stdout.read()
    proc.wait()
    print(f"=== {name}: returncode={proc.returncode} ({proc.returncode & 0xFFFFFFFF:#x})")
    if out:
        print(out[-500:])
    if proc.returncode == 0:
        continue
